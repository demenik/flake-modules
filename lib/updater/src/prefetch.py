import json
from typing import Optional, Dict, Any
from git_utils import run_cmd


def prefetch_github(owner: str, repo: str, new_rev: str) -> Optional[str]:
    url = f"https://github.com/{owner}/{repo}/archive/{new_rev}.tar.gz"
    out = run_cmd(["nix", "store", "prefetch-file", "--json", "--unpack", url])
    if out:
        return json.loads(out).get("hash")
    return None


def prefetch_gitlab(
    owner: Optional[str], repo: Optional[str], new_rev: str, url: Optional[str] = None
) -> Optional[str]:
    if owner and repo:
        archive_url = f"https://gitlab.com/{owner}/{repo}/-/archive/{new_rev}/{repo}-{new_rev}.tar.gz"
    elif url:
        clean_url = url.replace(".git", "").rstrip("/")
        parts = clean_url.split("/")
        if len(parts) >= 5:
            o, r = parts[-2], parts[-1]
            archive_url = (
                f"https://gitlab.com/{o}/{r}/-/archive/{new_rev}/{r}-{new_rev}.tar.gz"
            )
        else:
            return None
    else:
        return None

    out = run_cmd(["nix", "store", "prefetch-file", "--json", "--unpack", archive_url])
    if out:
        return json.loads(out).get("hash")
    return None


def prefetch_generic_git(url: str, new_rev: str) -> Optional[str]:
    clean_url = url
    if clean_url.startswith("git+"):
        clean_url = clean_url[4:]

    if clean_url.startswith("http://") or clean_url.startswith("https://"):
        git_url = f"git+{clean_url}"
    else:
        git_url = clean_url

    if "?" in git_url:
        git_url = f"{git_url}&rev={new_rev}"
    else:
        git_url = f"{git_url}?rev={new_rev}"

    out = run_cmd(["nix", "store", "prefetch-file", "--json", git_url])
    if out:
        return json.loads(out).get("hash")
    return None


def prefetch_package(pkg: Dict[str, Any], new_rev: str) -> Optional[str]:
    owner: Optional[str] = pkg.get("owner")
    repo: Optional[str] = pkg.get("repo")
    url: Optional[str] = pkg.get("url")

    if owner and repo and (not url or "github.com" in url):
        return prefetch_github(owner, repo, new_rev)
    elif (owner and repo and url and "gitlab.com" in url) or (
        url and "gitlab.com" in url
    ):
        return prefetch_gitlab(owner, repo, new_rev, url)
    elif url:
        return prefetch_generic_git(url, new_rev)

    return None
