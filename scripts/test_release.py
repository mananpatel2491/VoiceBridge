"""release.py against a throwaway origin: numbering, guards and cleanup.

Standard library only, so every repo can run it:  python3 -m unittest discover -s scripts -p 'test_release.py'
"""

from __future__ import annotations

import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "release.py"
ENV = {
    **os.environ,
    "GIT_AUTHOR_NAME": "t",
    "GIT_AUTHOR_EMAIL": "t@example.com",
    "GIT_COMMITTER_NAME": "t",
    "GIT_COMMITTER_EMAIL": "t@example.com",
    "GIT_CONFIG_GLOBAL": os.devnull,  # no user config (signing, hooks) in the test repos
    "GIT_CONFIG_NOSYSTEM": "1",
}


def sh(cwd: Path, *args: str) -> str:
    return subprocess.run(
        args, cwd=cwd, env=ENV, text=True, capture_output=True, check=True
    ).stdout.strip()


def release(cwd: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args], cwd=cwd, env=ENV, text=True, capture_output=True
    )


def commit(repo: Path, name: str) -> None:
    (repo / name).write_text(name)
    sh(repo, "git", "add", name)
    sh(repo, "git", "commit", "-qm", name)


class ReleaseScript(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        self.origin, self.work = root / "origin.git", root / "work"
        sh(root, "git", "init", "-q", "--bare", "-b", "main", str(self.origin))
        sh(root, "git", "clone", "-q", str(self.origin), str(self.work))
        sh(self.work, "git", "checkout", "-qb", "main")
        commit(self.work, "base")
        sh(self.work, "git", "push", "-q", "origin", "main")
        sh(self.work, "git", "checkout", "-qb", "v0.2.0")
        commit(self.work, "feature")
        sh(self.work, "git", "push", "-q", "origin", "refs/heads/v0.2.0")

    def ok(self, *args: str) -> subprocess.CompletedProcess[str]:
        out = release(self.work, *args)
        self.assertEqual(out.returncode, 0, out.stderr)
        return out

    def remote_tags(self) -> set[str]:
        return set(sh(self.origin, "git", "tag").split())

    def merge_into_main(self, *how: str) -> None:
        sh(self.work, "git", "checkout", "-q", "main")
        sh(self.work, "git", "merge", "-q", *how, "v0.2.0", "-m", "merge v0.2.0")
        if "--squash" in how:
            sh(self.work, "git", "commit", "-qm", "squash merge")
        sh(self.work, "git", "push", "-q", "origin", "refs/heads/main")

    def test_rc_numbers_itself_and_dry_run_changes_nothing(self) -> None:
        out = self.ok("rc", "0.2.0", "--dry-run")
        self.assertIn("v0.2.0-rc.1", out.stdout)
        self.assertIn("[DRY RUN] git push origin refs/tags/v0.2.0-rc.1", out.stdout)
        self.assertEqual(self.remote_tags(), set())

        self.ok("rc", "v0.2.0")
        self.ok("rc", "0.2.0")
        self.assertEqual(self.remote_tags(), {"v0.2.0-rc.1", "v0.2.0-rc.2"})

    def test_final_refuses_before_the_merge_then_releases(self) -> None:
        self.ok("rc", "0.2.0")
        early = release(self.work, "final", "0.2.0")  # main still has the old files
        self.assertEqual(early.returncode, 3, early.stderr)
        self.assertIn("merged into main", early.stderr)
        self.assertNotIn("v0.2.0", self.remote_tags())

        self.merge_into_main("--squash")
        self.ok("final", "0.2.0")
        self.assertEqual(
            sh(self.origin, "git", "rev-parse", "refs/tags/v0.2.0^{commit}"),
            sh(self.origin, "git", "rev-parse", "refs/heads/main"),
        )

        again = release(self.work, "final", "0.2.0")
        self.assertEqual(again.returncode, 2)
        self.assertIn("already exists", again.stderr)
        self.assertEqual(release(self.work, "rc", "0.2.0").returncode, 2)  # released: no more rcs

    def test_final_after_a_no_ff_merge(self) -> None:
        self.ok("rc", "0.2.0")
        self.merge_into_main("--no-ff")
        out = self.ok("final", "0.2.0")
        self.assertIn("same files as v0.2.0-rc.1", out.stdout)

    def test_final_force_skips_the_check(self) -> None:
        self.ok("rc", "0.2.0")
        self.ok("final", "0.2.0", "--force")
        self.assertIn("v0.2.0", self.remote_tags())

    def test_cleanup_only_after_release_and_keeps_the_branch(self) -> None:
        for _ in range(2):
            self.ok("rc", "0.2.0")
        self.assertEqual(release(self.work, "cleanup", "0.2.0").returncode, 2)  # not released
        self.ok("final", "0.2.0", "--force")
        self.ok("cleanup", "0.2.0")
        self.assertEqual(self.remote_tags(), {"v0.2.0"})
        self.assertNotIn("v0.2.0-rc.1", sh(self.work, "git", "tag").split())
        # The tag v0.2.0 and the branch v0.2.0 share a name; cleanup deletes neither.
        self.assertTrue(sh(self.origin, "git", "rev-parse", "-q", "--verify", "refs/heads/v0.2.0"))

    def test_missing_branch_and_bad_version(self) -> None:
        self.assertEqual(release(self.work, "rc", "0.9.0").returncode, 2)
        self.assertEqual(release(self.work, "rc", "1.2").returncode, 2)


class WorkflowLink(unittest.TestCase):
    """The link printed after a push names deploy.yml unless release.pin names another workflow."""

    def setUp(self) -> None:
        spec = importlib.util.spec_from_file_location("release", SCRIPT)
        self.release = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.release)
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.pin = self.root / "release.pin"

    def test_default_without_a_pin_or_a_workflow_line(self) -> None:
        self.assertEqual(self.release.workflow_name(self.pin), "deploy.yml")
        self.pin.write_text("source o/r@abc\n0123  scripts/release.py\n")
        self.assertEqual(self.release.workflow_name(self.pin), "deploy.yml")

    def test_pin_names_the_workflow(self) -> None:
        self.pin.write_text("source o/r@abc\n# workflow: android-release.yml\n0123  scripts/release.py\n")
        self.assertEqual(self.release.workflow_name(self.pin), "android-release.yml")

    def test_link_uses_the_pinned_workflow(self) -> None:
        sh(self.root, "git", "init", "-q")
        sh(self.root, "git", "remote", "add", "origin", "git@github.com:owner/app.git")
        self.pin.write_text("# workflow: android-release.yml\n")
        self.release.PIN = self.pin
        cwd = os.getcwd()
        os.chdir(self.root)
        self.addCleanup(os.chdir, cwd)
        self.assertEqual(
            self.release.deploy_link(),
            "https://github.com/owner/app/actions/workflows/android-release.yml",
        )


if __name__ == "__main__":
    unittest.main()
