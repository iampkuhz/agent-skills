#!/usr/bin/env python3
"""Validate commands directory structure and content."""
import os
import sys
import re


def find_repo_root():
    """Find repository root directory."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.normpath(os.path.join(script_dir, "..", ".."))


def check_commands_readme(root):
    """Check that commands/README.md exists."""
    path = os.path.join(root, "commands", "README.md")
    if os.path.isfile(path):
        print(f"  [PASS] commands/README.md exists")
        return True
    else:
        print(f"  [FAIL] commands/README.md not found")
        return False


def check_no_phantom_commands(root):
    """Check that README doesn't list non-existent commands."""
    readme_path = os.path.join(root, "commands", "README.md")
    if not os.path.isfile(readme_path):
        print(f"  [SKIP] Cannot check phantom commands: README missing")
        return True

    with open(readme_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Check for declared "no commands" statement
    has_no_commands = bool(re.search(r'没有.*已启用\s*command|没有.*command|no.*command.*enabled', content, re.IGNORECASE))

    if has_no_commands:
        print(f"  [PASS] README declares no enabled commands")
        return True

    # If commands are claimed to exist, verify they do
    # Look for links to command files/dirs
    links = re.findall(r'\[([^\]]*)\]\(([^)]+)\)', content)
    all_ok = True
    checked = 0

    for text, path in links:
        if path.startswith("http://") or path.startswith("https://") or path.startswith("#"):
            continue
        full_path = os.path.join(root, "commands", path)
        if os.path.exists(full_path):
            print(f"  [PASS] Command path {path} exists")
            checked += 1
        else:
            print(f"  [FAIL] Command path {path} does not exist (linked in README)")
            all_ok = False

    if checked == 0 and not has_no_commands:
        print(f"  [INFO] No command links found and no 'no commands' declaration")

    return all_ok


def check_command_dirs(root):
    """Check that any command directories mentioned actually have content."""
    commands_dir = os.path.join(root, "commands")
    if not os.path.isdir(commands_dir):
        print(f"  [SKIP] commands/ directory does not exist")
        return True

    # Find subdirectories that look like commands (not README or hidden files)
    entries = os.listdir(commands_dir)
    command_dirs = [e for e in entries if os.path.isdir(os.path.join(commands_dir, e)) and not e.startswith(".")]

    if not command_dirs:
        print(f"  [PASS] No command directories found (expected when commands.enabled=false)")
        return True

    all_ok = True
    for cmd_dir in command_dirs:
        cmd_path = os.path.join(commands_dir, cmd_dir)
        has_content = False
        for f in os.listdir(cmd_path):
            if not f.startswith("."):
                has_content = True
                break
        if has_content:
            print(f"  [PASS] commands/{cmd_dir} has content")
        else:
            print(f"  [WARN] commands/{cmd_dir} is empty")

    return all_ok


def main():
    root = find_repo_root()
    print("=== Commands Validation ===")

    results = []
    results.append(check_commands_readme(root))
    results.append(check_no_phantom_commands(root))
    results.append(check_command_dirs(root))

    if all(results):
        print("Commands validation: PASS")
        return 0
    else:
        print("Commands validation: FAIL")
        return 1


if __name__ == "__main__":
    sys.exit(main())
