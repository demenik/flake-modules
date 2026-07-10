import subprocess
import sys
from typing import List, Optional, Dict, Any


def run_cmd(cmd: List[str]) -> Optional[str]:
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.PIPE).strip()
    except subprocess.CalledProcessError as e:
        print(f"Error running command '{' '.join(cmd)}': {e.stderr.strip()}", file=sys.stderr)
        return None


def get_flake_store_path() -> Optional[str]:
    try:
        out = subprocess.check_output(
            ["nix", "flake", "metadata", "--json", "."],
            text=True,
            stderr=subprocess.PIPE,
        )
        import json

        return json.loads(out).get("path")
    except Exception:
        return None


def update_file(
    file_path: str,
    line_idx: int,
    current_rev: str,
    current_hash: str,
    new_rev: str,
    new_hash: str,
) -> None:
    with open(file_path, "r") as f:
        lines = f.readlines()

    rev_replaced = False
    hash_replaced = False

    for i in range(line_idx, min(line_idx + 50, len(lines))):
        if current_rev and not rev_replaced and current_rev in lines[i]:
            lines[i] = lines[i].replace(current_rev, new_rev)
            rev_replaced = True

        if current_hash and not hash_replaced and current_hash in lines[i]:
            lines[i] = lines[i].replace(current_hash, new_hash)
            hash_replaced = True

        if (not current_rev or rev_replaced) and (not current_hash or hash_replaced):
            break

    with open(file_path, "w") as f:
        f.writelines(lines)


def resolve_git_url(pkg: Dict[str, Any]) -> Optional[str]:
    owner: Optional[str] = pkg.get("owner")
    repo: Optional[str] = pkg.get("repo")
    url: Optional[str] = pkg.get("url")

    # GitHub
    if owner and repo and (not url or "github.com" in url):
        return f"https://github.com/{owner}/{repo}.git"

    # GitLab
    if url and "gitlab.com" in url:
        if owner and repo:
            return f"https://gitlab.com/{owner}/{repo}.git"
        return url

    # Generic URL
    if url:
        if url.endswith(".git"):
            return url
        if "github.com" in url:
            parts = url.split("/")
            if len(parts) >= 5:
                return (
                    f"https://github.com/{parts[3]}/{parts[4].replace('.git', '')}.git"
                )
        return url

    return None
