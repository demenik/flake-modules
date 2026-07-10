#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
from typing import List, Dict, Any, Optional, Set

from git_utils import run_cmd, get_flake_store_path, resolve_git_url, update_file
from prefetch import prefetch_package


def run_update(metadata: List[Dict[str, Any]], flake_path: Optional[str]) -> None:
    if not metadata:
        print("No overlay packages found to update.")
        return

    metadata_sorted = sorted(metadata, key=lambda x: x.get("name", ""))
    max_name_len = max(len(pkg.get("name", "")) for pkg in metadata_sorted)

    use_color = sys.stdout.isatty()
    GREEN = "\033[92m" if use_color else ""
    RED = "\033[91m" if use_color else ""
    RESET = "\033[0m" if use_color else ""
    GRAY = "\033[90m" if use_color else ""

    print("\nUpdating overlays...")

    for pkg in metadata_sorted:
        name = pkg.get("name", "unknown")
        file_path = pkg.get("file")
        line_raw = pkg.get("line")
        line = (line_raw - 1) if line_raw is not None else 0
        current_rev = pkg.get("rev")
        current_hash = pkg.get("hash")

        has_rev_hash = bool(current_rev and current_hash)
        git_url = resolve_git_url(pkg) if has_rev_hash else None
        is_supported = bool(git_url)

        if not is_supported:
            status = f"{RED} Not supported   {RESET}"
            if not has_rev_hash:
                details = "Missing 'rev' or 'hash' attribute"
            else:
                details = "Could not resolve Git repository URL"
            print(f"  {name:<{max_name_len}}  {status}  {GRAY}{details}{RESET}")
            continue

        if flake_path and file_path and file_path.startswith(flake_path):
            file_path = file_path.replace(flake_path, ".", 1)

        if not file_path or not os.path.exists(file_path):
            status = f"{RED} Update failed   {RESET}"
            details = f"File {file_path or 'unknown'} not found"
            print(f"  {name:<{max_name_len}}  {status}  {GRAY}{details}{RESET}")
            continue

        head_rev = run_cmd(["git", "ls-remote", git_url, "HEAD"])
        if not head_rev:
            status = f"{RED} Check failed    {RESET}"
            details = f"Failed to fetch HEAD for {git_url}"
            print(f"  {name:<{max_name_len}}  {status}  {GRAY}{details}{RESET}")
            continue

        new_rev = head_rev.split()[0]

        curr_short = (
            current_rev[:7]
            if current_rev and len(current_rev) > 20
            else (current_rev or "")
        )
        new_short = new_rev[:7] if len(new_rev) > 20 else new_rev

        if new_rev == current_rev:
            status = f"{GREEN} Up to date      {RESET}"
            details = f"{git_url} ({curr_short})"
            print(f"  {name:<{max_name_len}}  {status}  {GRAY}{details}{RESET}")
        else:
            new_hash = prefetch_package(pkg, new_rev)
            if not new_hash:
                status = f"{RED} Update failed   {RESET}"
                details = f"Failed to prefetch new hash for {git_url}"
                print(f"  {name:<{max_name_len}}  {status}  {GRAY}{details}{RESET}")
                continue

            try:
                update_file(
                    file_path, line, current_rev, current_hash, new_rev, new_hash
                )
                status = f"{GREEN} Updated         {RESET}"
                details = f"{git_url} ({curr_short} -> {new_short})"
                print(f"  {name:<{max_name_len}}  {status}  {GRAY}{details}{RESET}")
            except Exception as e:
                status = f"{RED} Update failed   {RESET}"
                details = f"Failed to write changes to {file_path}: {e}"
                print(f"  {name:<{max_name_len}}  {status}  {GRAY}{details}{RESET}")

    print()


def run_dry_run(metadata: List[Dict[str, Any]]) -> None:
    if not metadata:
        print("No overlay packages found.")
        return

    metadata_sorted = sorted(metadata, key=lambda x: x.get("name", ""))
    max_name_len = max(len(pkg.get("name", "")) for pkg in metadata_sorted)

    use_color = sys.stdout.isatty()
    GREEN = "\033[92m" if use_color else ""
    YELLOW = "\033[93m" if use_color else ""
    RED = "\033[91m" if use_color else ""
    RESET = "\033[0m" if use_color else ""
    GRAY = "\033[90m" if use_color else ""

    print("\nChecking for overlay updates...")

    for pkg in metadata_sorted:
        name = pkg.get("name", "unknown")
        current_rev = pkg.get("rev")
        current_hash = pkg.get("hash")

        has_rev_hash = bool(current_rev and current_hash)
        git_url = resolve_git_url(pkg) if has_rev_hash else None
        is_supported = bool(git_url)

        if not is_supported:
            status = f"{RED} Not supported   {RESET}"
            if not has_rev_hash:
                details = "Missing 'rev' or 'hash' attribute"
            else:
                details = "Could not resolve Git repository URL"
            print(f"  {name:<{max_name_len}}  {status}  {GRAY}{details}{RESET}")
            continue

        head_rev = run_cmd(["git", "ls-remote", git_url, "HEAD"])
        if not head_rev:
            status = f"{RED} Check failed    {RESET}"
            details = f"Failed to fetch HEAD for {git_url}"
            print(f"  {name:<{max_name_len}}  {status}  {GRAY}{details}{RESET}")
            continue

        new_rev = head_rev.split()[0]

        curr_short = (
            current_rev[:7]
            if current_rev and len(current_rev) > 20
            else (current_rev or "")
        )
        new_short = new_rev[:7] if len(new_rev) > 20 else new_rev

        if new_rev == current_rev:
            status = f"{GREEN} Up to date      {RESET}"
            details = f"{git_url} ({curr_short})"
        else:
            status = f"{YELLOW}󰚰 Update available{RESET}"
            details = f"{git_url} ({curr_short} -> {new_short})"

        print(f"  {name:<{max_name_len}}  {status}  {GRAY}{details}{RESET}")


def main() -> None:
    app_name = os.environ.get("FM_UPDATE_APP_NAME", "overlay-update")
    system = os.environ.get("FM_UPDATE_SYSTEM")

    parser = argparse.ArgumentParser(
        prog=f"nix run .#{app_name}", description="Update flake-modules overlays"
    )
    parser.add_argument("package", nargs="?", help="Specific package to update")
    parser.add_argument(
        "-d",
        "--dry-run",
        action="store_true",
        help="Check for updates without modifying files",
    )
    args = parser.parse_args()

    if not system:
        print("FM_UPDATE_SYSTEM environment variable not set.", file=sys.stderr)
        sys.exit(1)

    print("Evaluating configuration overlays...")
    flake_url = f"path:{os.getcwd()}"
    expr = f'(builtins.getFlake "{flake_url}").apps.{system}.{app_name}.metadata null'
    cmd = ["nix", "eval", "--json", "--impure", "--expr", expr]
    try:
        res = subprocess.run(
            cmd, stdout=subprocess.PIPE, stderr=sys.stderr, text=True, check=True
        )
        out = res.stdout.strip()
    except subprocess.CalledProcessError:
        print("Error evaluating metadata: Nix execution failed.", file=sys.stderr)
        sys.exit(1)

    try:
        metadata = json.loads(out)
    except Exception as e:
        print(f"Failed to parse metadata JSON: {e}", file=sys.stderr)
        sys.exit(1)

    # Deduplicate metadata by package definition coordinates
    seen: Set[tuple] = set()
    deduped_metadata: List[Dict[str, Any]] = []
    for pkg in metadata:
        pkg_key = (pkg.get("name"), pkg.get("file"), pkg.get("line"), pkg.get("column"))
        if pkg_key not in seen:
            seen.add(pkg_key)
            deduped_metadata.append(pkg)
    metadata = deduped_metadata

    if args.package:
        metadata = [pkg for pkg in metadata if pkg.get("name") == args.package]
        if not metadata:
            print(f"Package '{args.package}' not found in configuration overlays.")
            sys.exit(1)

    if args.dry_run:
        run_dry_run(metadata)
        return

    flake_path = get_flake_store_path()
    run_update(metadata, flake_path)


if __name__ == "__main__":
    main()
