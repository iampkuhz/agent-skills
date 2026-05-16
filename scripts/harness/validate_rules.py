#!/usr/bin/env python3
"""Validate rules directory structure and content."""
import os
import sys
import re


def find_repo_root():
    """Find repository root directory."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.normpath(os.path.join(script_dir, "..", ".."))


def check_rules_readme(root):
    """Check that rules/README.md exists."""
    path = os.path.join(root, "rules", "README.md")
    if os.path.isfile(path):
        print(f"  [PASS] rules/README.md exists")
        return True
    else:
        print(f"  [FAIL] rules/README.md not found")
        return False


def check_linked_files_exist(root):
    """Check that all paths linked in README actually exist."""
    readme_path = os.path.join(root, "rules", "README.md")
    if not os.path.isfile(readme_path):
        print(f"  [SKIP] Cannot check linked files: README missing")
        return True

    with open(readme_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Extract relative paths from markdown links: [text](path)
    links = re.findall(r'\[([^\]]*)\]\(([^)]+)\)', content)
    all_ok = True
    checked = 0

    for text, path in links:
        # Skip http/https and pure anchors
        if path.startswith("http://") or path.startswith("https://") or path.startswith("#"):
            continue
        # Resolve relative to rules/ directory
        full_path = os.path.join(root, "rules", path)
        if os.path.exists(full_path):
            print(f"  [PASS] {path} exists")
            checked += 1
        else:
            print(f"  [FAIL] {path} does not exist (linked in README)")
            all_ok = False

    if checked == 0:
        print(f"  [INFO] No file links found in rules/README.md")

    return all_ok


def check_language_md(root):
    """Check rules/global/language.md exists and contains required sections."""
    path = os.path.join(root, "rules", "global", "language.md")
    if not os.path.isfile(path):
        print(f"  [FAIL] rules/global/language.md not found")
        return False

    print(f"  [PASS] rules/global/language.md exists")

    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    required_sections = ["适用场景", "强制规则", "禁止事项", "验证方式"]
    all_ok = True

    for section in required_sections:
        if section in content:
            print(f"  [PASS] language.md contains '{section}' section")
        else:
            print(f"  [FAIL] language.md missing '{section}' section")
            all_ok = False

    return all_ok


def main():
    root = find_repo_root()
    print("=== Rules Validation ===")

    results = []
    results.append(check_rules_readme(root))
    results.append(check_linked_files_exist(root))
    results.append(check_language_md(root))

    if all(results):
        print("Rules validation: PASS")
        return 0
    else:
        print("Rules validation: FAIL")
        return 1


if __name__ == "__main__":
    sys.exit(main())
