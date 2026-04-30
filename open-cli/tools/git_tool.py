import subprocess
import sys
from pathlib import Path
from typing import Dict, Any, List

class GitError(Exception):
    pass

class GitTool:
    def __init__(self, repo_root: Path = None):
        self.repo_root = repo_root or Path.cwd()

    def _run_git(self, args: List[str]) -> subprocess.CompletedProcess:
        if sys.platform == "win32":
            result = subprocess.run(
                ["git"] + args,
                cwd=self.repo_root,
                capture_output=True,
                timeout=30,
            )
            stdout = result.stdout.decode("gbk", errors="replace") if result.stdout else ""
            stderr = result.stderr.decode("gbk", errors="replace") if result.stderr else ""
            result.stdout = stdout
            result.stderr = stderr
        else:
            result = subprocess.run(
                ["git"] + args,
                cwd=self.repo_root,
                capture_output=True,
                text=True,
                timeout=30,
            )
        return result

    def status(self) -> Dict[str, Any]:
        result = self._run_git(["status", "--porcelain"])
        files = [line.strip() for line in result.stdout.strip().split("\n") if line.strip()]

        branch_result = self._run_git(["branch", "--show-current"])
        branch = branch_result.stdout.strip()

        return {"branch": branch, "files": files}

    def diff(self, file: str = None) -> str:
        args = ["diff", "--stat"]
        if file:
            args.append(file)
        result = self._run_git(args)

        if not result.stdout.strip():
            return "No changes."

        diff_result = self._run_git(args + ["--patch"])
        return diff_result.stdout[:3000] if diff_result.stdout else result.stdout

    def diff_staged(self, file: str = None) -> str:
        args = ["diff", "--cached"]
        if file:
            args.append(file)
        result = self._run_git(args)
        return result.stdout

    def commit(self, message: str) -> Dict[str, Any]:
        result = self._run_git(["commit", "-m", message])
        if result.returncode != 0:
            return {"success": False, "error": result.stderr}
        return {"success": True, "message": result.stdout.strip()}

    def add(self, files: List[str] = None) -> Dict[str, Any]:
        args = ["add"]
        if files:
            args.extend(files)
        else:
            args.append(".")
        result = self._run_git(args)
        if result.returncode != 0:
            return {"success": False, "error": result.stderr}
        return {"success": True}

    def log(self, n: int = 10) -> str:
        result = self._run_git(["log", f"-{n}", "--pretty=format:%h %ad %s (%an)", "--date=iso"])
        stdout = result.stdout or ""
        if not stdout.strip():
            return "No commits found."
        return stdout

    def log_formatted(self, n: int = 10) -> str:
        """Return formatted git log with details."""
        result = self._run_git(["log", f"-{n}", "--pretty=format:%H|%s|%an|%ad", "--date=iso"])
        lines = []
        stdout = result.stdout or ""
        for line in stdout.strip().split("\n"):
            if line:
                parts = line.split("|")
                if len(parts) >= 4:
                    short_hash = parts[0][:7]
                    subject = parts[1]
                    author = parts[2]
                    date = parts[3][:10]
                    lines.append(f"{short_hash} | {date} | {subject} | {author}")
        if not lines:
            return "No commits found."
        return "\n".join(lines)

    def branch_list(self) -> List[str]:
        result = self._run_git(["branch"])
        return [b.strip() for b in result.stdout.strip().split("\n") if b.strip()]

    def create_branch(self, branch_name: str) -> Dict[str, Any]:
        result = self._run_git(["checkout", "-b", branch_name])
        if result.returncode != 0:
            return {"success": False, "error": result.stderr}
        return {"success": True, "branch": branch_name}