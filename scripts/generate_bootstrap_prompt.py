import os
import argparse
from pathlib import Path
from datetime import datetime
try:
    from google import genai
    from dotenv import load_dotenv
except ImportError:
    print("ERROR: Required packages not found. Please run: pip install -r requirements.txt")
    import sys
    sys.exit(1)

def select_model(client, model_override=None):
    """Resolve the Gemini model to use, in priority order:
    1. an explicit --model override (automation-first bypass),
    2. an interactive pick from the live model list,
    3. index 0 as the default (empty/invalid input, or non-interactive stdin)."""
    if model_override:
        return model_override
    try:
        available_models = [m for m in client.models.list() if 'generateContent' in m.supported_actions]
    except Exception:
        return 'models/gemini-1.5-flash'
    if not available_models:
        return 'models/gemini-1.5-flash'

    default = available_models[0].name
    print("\nAvailable Gemini models:")
    for i, m in enumerate(available_models):
        print(f"  [{i}] {m.name}")
    try:
        choice = input(f"Select a model index [Enter for default 0: {default}]: ").strip()
    except EOFError:
        # Non-interactive stdin (CI / piped) -> use the default without blocking.
        choice = ""
    if choice.isdigit() and int(choice) < len(available_models):
        return available_models[int(choice)].name
    return default

def get_context_content(root):
    """Ingests core MD files to provide context to the generator."""
    context = ""
    files_to_read = ["Project_Structure.md", "PATTERNS.md", "GEMINI.md"]
    for filename in files_to_read:
        file_path = root / filename
        if file_path.exists():
            with open(file_path, "r", encoding="utf-8") as f:
                context += f"\n--- {filename} ---\n{f.read()}\n"
    return context

def generate_prompt(intent, requested_model=None, dry_run=False):
    root = Path(__file__).resolve().parent.parent
    load_dotenv(dotenv_path=root / ".env")

    api_key = os.getenv("GOOGLE_API_KEY")
    if not api_key:
        print(f"Error: GOOGLE_API_KEY not found (checked environment and {root / '.env'}).")
        return
    # Masked confirmation that the key loaded, without leaking the secret.
    print(f"GOOGLE_API_KEY loaded ({api_key[:4]}...{api_key[-4:]}).")

    context = get_context_content(root)

    system_prompt = """
    You are the 'Prompt Architect' for the VoiceBridge project. Your task is to turn a simple English
    intent into a systematic 'Bootstrap Prompt' for a Lead Agent (Gemini).

    STANDING INSTRUCTIONS TO INCLUDE IN THE BOOTSTRAP:
    - After every commit, run `python ./scripts/verify_structure.py`.
    - If it's a backend change, run Bruno validation.
    - No commit is allowed without successful Bruno results unless the owner provides the exception string.
    - Update Project_Structure.md immediately after file changes.
    - For any new pipeline stage, update the Pipeline Stage Registry in Project_Structure.md.
    - For any new endpoint, update Function_Mapping.md.

    FOR NEW FEATURES:
    1. Analyze the context provided to see if existing patterns or code can be reused.
    2. If reuse is possible, list the file references.
    3. If brand new, the first line of the prompt must be: 'STATION CHECK: This appears to be a brand-new feature with no reusable components. Confirm to proceed.'

    FOR BUGS:
    1. Convert observations into a systematic troubleshooting hypothesis.
    2. The prompt must require the agent to: Create Hypothesis -> Ask for Confirmation -> Report Findings -> Implementation.

    FOR VOICE PIPELINE CHANGES:
    1. Always note the affected pipeline stage (STT / LLM / TTS / Audio I/O).
    2. Verify streaming contract is maintained.
    3. Check latency budget impact and document in Project_Structure.md.

    Output ONLY the final Markdown content for the prompt.
    """

    user_query = f"CONTEXT:\n{context}\n\nUSER INTENT: {intent}"

    # Resolve the output path up front so a dry-run can report exactly what would be written.
    prompt_dir = root / "bootstrap_prompts"
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    target_file = prompt_dir / f"prompt_{timestamp}.md"

    # True dry-run: short-circuit BEFORE any network call or file write.
    if dry_run:
        print("\n--- DRY RUN: no API call made, no file written ---")
        print(f"Model       : {requested_model or '<resolved dynamically at run time>'}")
        print(f"Output file : {target_file}")
        print("\n--- REQUEST PREVIEW (system prompt + user query) ---")
        print(system_prompt)
        print(user_query)
        print("--- END PREVIEW ---")
        return

    client = genai.Client(api_key=api_key, http_options={'api_version': 'v1'})
    model_id = select_model(client, requested_model)

    print(f"Generating bootstrap prompt using {model_id}...")
    try:
        response = client.models.generate_content(
            model=model_id,
            contents=[system_prompt, user_query]
        )
        prompt_content = response.text.strip()

        prompt_dir.mkdir(exist_ok=True)
        with open(target_file, "w", encoding="utf-8") as f:
            f.write(prompt_content)
        print(f"Successfully created bootstrap prompt: {target_file}")
        print("Action: Copy the content of this file to start your new session.")

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate a systematic bootstrap prompt from English intent.")
    parser.add_argument("intent", type=str, help="The English description of the feature or bug.")
    parser.add_argument("--model", type=str, help="Specify the Gemini model ID.")
    parser.add_argument("--dry-run", action="store_true", help="Preview the prompt without saving.")
    args = parser.parse_args()
    generate_prompt(args.intent, requested_model=args.model, dry_run=args.dry_run)
