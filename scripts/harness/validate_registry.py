#!/usr/bin/env python3
"""Validate skill registry (skills/registry.yaml)."""
import os
import sys
import re


def find_repo_root():
    """Find repository root directory."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.normpath(os.path.join(script_dir, "..", ".."))


def try_parse_yaml_simple(text):
    """Minimal YAML-like parser for the registry structure.
    Handles the specific flat list format of skills/registry.yaml.
    """
    skills = []
    current = {}

    for line in text.splitlines():
        stripped = line.strip()

        # Skip comments and empty lines
        if not stripped or stripped.startswith("#"):
            # If we hit a new list item marker on the next non-comment line, save current
            continue

        # New list item: "- name: ..."
        if stripped.startswith("- "):
            if current:
                skills.append(current)
            current = {}
            stripped = stripped[2:].strip()

        # Key-value pair
        if ":" in stripped:
            key, _, value = stripped.partition(":")
            key = key.strip()
            value = value.strip().strip('"').strip("'")

            if key in ("name", "path", "layer", "description", "entry", "status"):
                current[key] = value
            elif key == "validation" and value in ("null", "none", ""):
                current["validation"] = None
            elif key == "type":
                current["validation_type"] = value
            elif key == "command":
                current["validation_command"] = value

    if current:
        skills.append(current)

    return skills


def parse_registry(root):
    """Parse skills/registry.yaml, trying PyYAML first, fallback to simple parser."""
    reg_path = os.path.join(root, "skills", "registry.yaml")

    skills = None

    # Try PyYAML
    try:
        import yaml
        with open(reg_path, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        skills = data.get("skills", [])
    except ImportError:
        pass
    except Exception:
        pass

    if skills is None:
        # Fallback to simple parser
        with open(reg_path, "r", encoding="utf-8") as f:
            text = f.read()
        skills = try_parse_yaml_simple(text)

    return skills


def check_registry_exists(root):
    """Check that skills/registry.yaml exists."""
    path = os.path.join(root, "skills", "registry.yaml")
    if os.path.isfile(path):
        print(f"  [PASS] skills/registry.yaml exists")
        return True
    else:
        print(f"  [FAIL] skills/registry.yaml not found")
        return False


def check_skill_paths(root, skills):
    """Check each skill's path directory and SKILL.md entry exist."""
    all_ok = True

    for skill in skills:
        name = skill.get("name", "<unknown>")
        path = skill.get("path", "")
        entry = skill.get("entry", "SKILL.md")

        if not path:
            print(f"  [FAIL] Skill '{name}' has no path")
            all_ok = False
            continue

        full_dir = os.path.join(root, path)
        if os.path.isdir(full_dir):
            print(f"  [PASS] Skill '{name}' directory exists: {path}")
        else:
            print(f"  [FAIL] Skill '{name}' directory missing: {path}")
            all_ok = False
            continue

        # Check entry file
        entry_path = os.path.join(full_dir, entry)
        if os.path.isfile(entry_path):
            print(f"  [PASS] Skill '{name}' entry exists: {path}/{entry}")
        else:
            print(f"  [FAIL] Skill '{name}' entry missing: {path}/{entry}")
            all_ok = False

    return all_ok


def check_validation_scripts(root, skills):
    """If validation.type is 'script', check the script path exists.

    Handles both:
      - Nested dict from PyYAML: skill["validation"]["type"] / ["command"]
      - Flat keys from fallback parser: skill["validation_type"] / ["validation_command"]
    """
    all_ok = True

    for skill in skills:
        name = skill.get("name", "<unknown>")

        # Extract validation info from nested dict (PyYAML) or flat keys (fallback)
        val = skill.get("validation")
        if isinstance(val, dict):
            val_type = val.get("type", "")
            val_cmd = val.get("command", "")
        else:
            val_type = skill.get("validation_type", "")
            val_cmd = skill.get("validation_command", "")

        if not val_type or val_type != "script":
            continue

        if not val_cmd:
            print(f"  [WARN] Skill '{name}' has validation type 'script' but no command")
            continue

        # Extract the script path from the command (e.g., "bash path/to/script.sh" -> path/to/script.sh)
        parts = val_cmd.split()
        script_path = parts[-1] if parts else ""

        full_script = os.path.join(root, script_path)
        if os.path.isfile(full_script):
            print(f"  [PASS] Skill '{name}' validation script exists: {script_path}")
        else:
            print(f"  [FAIL] Skill '{name}' validation script missing: {script_path}")
            all_ok = False

    return all_ok


def main():
    root = find_repo_root()
    print("=== Registry Validation ===")

    results = []
    results.append(check_registry_exists(root))

    reg_path = os.path.join(root, "skills", "registry.yaml")
    if not os.path.isfile(reg_path):
        print("Registry validation: FAIL (registry file missing)")
        return 1

    skills = parse_registry(root)

    if not skills:
        print(f"  [WARN] No skills found in registry")
        print("Registry validation: PASS (empty but valid)")
        return 0

    print(f"  [INFO] Found {len(skills)} skill(s) in registry")
    results.append(check_skill_paths(root, skills))
    results.append(check_validation_scripts(root, skills))

    if all(results):
        print("Registry validation: PASS")
        return 0
    else:
        print("Registry validation: FAIL")
        return 1


if __name__ == "__main__":
    sys.exit(main())
