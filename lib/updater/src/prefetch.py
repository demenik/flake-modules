import json
from typing import Optional, Dict, Any, List
from git_utils import run_cmd, resolve_git_url


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


def prefetch_git_only(
    url: str,
    new_rev: str,
    leave_dot_git: bool = False,
    deep_clone: bool = False,
    fetch_submodules: bool = False,
    sparse_checkout: Optional[List[str]] = None,
) -> Optional[str]:
    cmd = [
        "nix",
        "run",
        "nixpkgs#nix-prefetch-git",
        "--",
        "--url",
        url,
        "--rev",
        new_rev,
        "--quiet",
    ]
    if leave_dot_git:
        cmd.append("--leave-dotGit")
    if deep_clone:
        cmd.append("--deepClone")
    if fetch_submodules:
        cmd.append("--fetch-submodules")
    if sparse_checkout:
        sparse_str = "\n".join(sparse_checkout)
        cmd.extend(["--sparse-checkout", sparse_str])

    out = run_cmd(cmd)
    if out:
        try:
            return json.loads(out).get("hash")
        except Exception:
            return None
    return None


def prefetch_dynamic_url(
    url: str, current_rev: str, new_rev: str, unpack: bool
) -> Optional[str]:
    new_url = url.replace(current_rev, new_rev)
    cmd = ["nix", "store", "prefetch-file", "--json"]
    if unpack:
        cmd.append("--unpack")
    cmd.append(new_url)

    out = run_cmd(cmd)
    if out:
        return json.loads(out).get("hash")
    return None


def prefetch_package(pkg: Dict[str, Any], new_rev: str) -> Optional[str]:
    owner: Optional[str] = pkg.get("owner")
    repo: Optional[str] = pkg.get("repo")
    url: Optional[str] = pkg.get("url")
    script: Optional[str] = pkg.get("script")
    unpack: bool = pkg.get("unpack", False)

    leave_dot_git = pkg.get("leaveDotGit", False)
    deep_clone = pkg.get("deepClone", False)
    fetch_submodules = pkg.get("fetchSubmodules", False)
    sparse_checkout = pkg.get("sparseCheckout", None)

    is_git_only = leave_dot_git or deep_clone or fetch_submodules or sparse_checkout

    if script and url:
        current_rev = pkg.get("rev")
        if current_rev:
            return prefetch_dynamic_url(url, current_rev, new_rev, unpack)

    if is_git_only:
        git_url = resolve_git_url(pkg)
        if git_url:
            return prefetch_git_only(
                git_url,
                new_rev,
                leave_dot_git=bool(leave_dot_git),
                deep_clone=bool(deep_clone),
                fetch_submodules=bool(fetch_submodules),
                sparse_checkout=sparse_checkout,
            )

    if owner and repo and (not url or "github.com" in url):
        return prefetch_github(owner, repo, new_rev)
    elif (owner and repo and url and "gitlab.com" in url) or (
        url and "gitlab.com" in url
    ):
        return prefetch_gitlab(owner, repo, new_rev, url)
    elif url:
        return prefetch_generic_git(url, new_rev)

    return None
