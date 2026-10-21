"""Release tags for any mananutils app repo. A pushed v* tag runs the repo's release workflow:
deploy.yml, or the one named by a "# workflow: <file>" line in scripts/release.pin.

Shared copy: mananutils-platform/scripts/release.py. App repos vendor a pinned copy with
scripts/vendor-release.sh; see README.md, "Shared processes".

    python3 scripts/release.py rc 0.1.6        # tag origin/v0.1.6 as the next v0.1.6-rc.N
    python3 scripts/release.py final 0.1.6     # tag origin/main as v0.1.6 (after the merge)
    python3 scripts/release.py cleanup 0.1.6   # delete v0.1.6-rc.* once v0.1.6 is released

Add --dry-run to any command to see what it would do; nothing is tagged, pushed or deleted.
Run it from anywhere inside the app's clone; it works on that clone's origin. It guards against
the slips these repos have hit:
  - tags are always pushed as refs/tags/... (a branch named v0.1.6 makes a bare name ambiguous);
  - branches are fetched by full ref (refs/heads/...), for the same reason;
  - rc picks the next free number itself (no "tag already exists");
  - final refuses when main's files differ from the last release candidate you tested
    (e.g. tagging before the merge), unless --force.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

VERSION = re.compile(r"^v?(\d+\.\d+\.\d+)$")
PIN = Path(__file__).resolve().parent / "release.pin"
WORKFLOW = re.compile(r"^#\s*workflow:\s*([\w.-]+\.ya?ml)\s*$")


def git(*args: str, check: bool = True) -> str:
    # Fixed git argv built in this file; no shell.
    result = subprocess.run(["git", *args], text=True, capture_output=True)  # noqa: S603, S607
    if check and result.returncode != 0:
        print(f"git {' '.join(args)} failed:\n{result.stderr.strip()}", file=sys.stderr)
        sys.exit(result.returncode)
    return result.stdout.strip()


def change(dry_run: bool, *args: str) -> None:
    """Run a git command that changes something (or only show it, with --dry-run)."""
    print(f"{'[DRY RUN] ' if dry_run else '$ '}git {' '.join(args)}")
    if not dry_run:
        git(*args)


def remote_tags() -> dict[str, str]:
    """Tag name -> commit sha on origin (annotated tags resolved to their commit)."""
    tags: dict[str, str] = {}
    for line in git("ls-remote", "--tags", "origin").splitlines():
        sha, ref = line.split("\t")
        name = ref.removeprefix("refs/tags/")
        if name.endswith("^{}"):
            tags[name[:-3]] = sha  # the peeled commit wins over the tag object
        else:
            tags.setdefault(name, sha)
    return tags


def rc_numbers(tags: dict[str, str], version: str) -> list[int]:
    pattern = re.compile(rf"^v{re.escape(version)}-rc\.(\d+)$")
    return sorted(int(m.group(1)) for t in tags if (m := pattern.match(t)))


def workflow_name(pin: Path = PIN) -> str:
    """The workflow a pushed tag runs: the pin's "# workflow: <file>" line, else deploy.yml.

    A comment line, so the app's `sha256sum -c --strict` check of the pin skips it.
    """
    try:
        lines = pin.read_text().splitlines()
    except OSError:
        return "deploy.yml"
    return next((m.group(1) for line in lines if (m := WORKFLOW.match(line))), "deploy.yml")


def deploy_link() -> str:
    url = git("remote", "get-url", "origin")
    m = re.search(r"github\.com[:/]([^/]+)/([^/]+?)(?:\.git)?$", url)
    if not m:
        return ""
    return f"https://github.com/{m.group(1)}/{m.group(2)}/actions/workflows/{workflow_name(PIN)}"


def fetch_branch(branch: str) -> str:
    """Fetch origin's branch (by full ref, never ambiguous with a tag); return its commit."""
    exists = git("ls-remote", "--heads", "origin", f"refs/heads/{branch}")
    if not exists:
        print(f"No branch '{branch}' on origin. Push it first.", file=sys.stderr)
        sys.exit(2)
    git("fetch", "origin", f"+refs/heads/{branch}:refs/remotes/origin/{branch}")
    return git("rev-parse", f"refs/remotes/origin/{branch}")


def tag_and_push(tag: str, commit: str, dry_run: bool) -> None:
    local = git("rev-parse", "-q", "--verify", f"refs/tags/{tag}^{{commit}}", check=False)
    if local and local != commit:
        print(
            f"A local tag {tag} points at {local[:7]}, not {commit[:7]}. "
            f"Remove it first: git tag -d {tag}",
            file=sys.stderr,
        )
        sys.exit(2)
    if not local:
        change(dry_run, "tag", "-a", tag, commit, "-m", tag)
    change(dry_run, "push", "origin", f"refs/tags/{tag}")
    if not dry_run:
        print(f"\nPushed {tag} ({commit[:7]}). Deploy: {deploy_link()}")


def cmd_rc(version: str, branch: str | None, dry_run: bool) -> None:
    branch = branch or f"v{version}"
    tags = remote_tags()
    if f"v{version}" in tags:
        print(f"v{version} is already released; start a new version.", file=sys.stderr)
        sys.exit(2)
    commit = fetch_branch(branch)
    existing = rc_numbers(tags, version)
    tag = f"v{version}-rc.{(existing[-1] + 1) if existing else 1}"
    last = tags.get(f"v{version}-rc.{existing[-1]}") if existing else None
    if last == commit:
        print(f"Note: v{version}-rc.{existing[-1]} already points at {commit[:7]}.")
    print(f"Next release candidate: {tag} = origin/{branch} ({commit[:7]})")
    tag_and_push(tag, commit, dry_run)


def cmd_final(version: str, force: bool, dry_run: bool) -> None:
    tag = f"v{version}"
    tags = remote_tags()
    if tag in tags:
        print(f"{tag} already exists on origin (at {tags[tag][:7]}).", file=sys.stderr)
        sys.exit(2)
    main = fetch_branch("main")
    rcs = rc_numbers(tags, version)
    if rcs:
        rc = f"v{version}-rc.{rcs[-1]}"
        git("fetch", "origin", tags[rc])
        same = git("rev-parse", f"{main}^{{tree}}") == git("rev-parse", f"{tags[rc]}^{{tree}}")
        if same:
            print(f"main ({main[:7]}) has the same files as {rc}, the last one you tested.")
        elif force:
            print(f"Warning: main's files differ from {rc}; continuing because of --force.")
        else:
            print(
                f"main ({main[:7]}) has different files from {rc} ({tags[rc][:7]}), the last\n"
                "release candidate you tested. Is the version merged into main and pushed? If\n"
                "main is right as it is (e.g. a later docs-only change), run again with --force.",
                file=sys.stderr,
            )
            sys.exit(3)
    else:
        print(f"Note: no {tag}-rc.* was tagged; releasing main as it is.")
    tag_and_push(tag, main, dry_run)


def cmd_cleanup(version: str, force: bool, dry_run: bool) -> None:
    tags = remote_tags()
    if f"v{version}" not in tags and not force:
        print(f"v{version} isn't released yet; keep its release candidates.", file=sys.stderr)
        sys.exit(2)
    rcs = [f"v{version}-rc.{n}" for n in rc_numbers(tags, version)]
    if not rcs:
        print(f"No v{version}-rc.* tags on origin.")
        return
    change(dry_run, "push", "origin", "--delete", *(f"refs/tags/{t}" for t in rcs))
    for t in rcs:
        if git("rev-parse", "-q", "--verify", f"refs/tags/{t}", check=False):
            change(dry_run, "tag", "-d", t)


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    sub = parser.add_subparsers(dest="cmd", required=True)
    for name, text in (
        ("rc", "tag the version's branch as its next release candidate"),
        ("final", "tag main as the release (after the version branch is merged)"),
        ("cleanup", "delete the version's release-candidate tags once it's released"),
    ):
        p = sub.add_parser(name, help=text)
        p.add_argument("version", help="e.g. 0.1.6 or v0.1.6")
        p.add_argument("--dry-run", action="store_true", help="show, don't change anything")
        if name == "rc":
            p.add_argument("--branch", help="branch to tag (default: v<version>)")
        else:
            p.add_argument("--force", action="store_true", help="skip the safety check")
    args = parser.parse_args(argv)
    m = VERSION.match(args.version)
    if not m:
        parser.error(f"version must look like 0.1.6, got {args.version!r}")
    version = m.group(1)
    if args.cmd == "rc":
        cmd_rc(version, args.branch, args.dry_run)
    elif args.cmd == "final":
        cmd_final(version, args.force, args.dry_run)
    else:
        cmd_cleanup(version, args.force, args.dry_run)


if __name__ == "__main__":
    main()
