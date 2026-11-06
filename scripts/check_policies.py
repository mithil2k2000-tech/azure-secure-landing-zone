"""Static checks for custom Azure Policy definitions.

Fails if a definition is not valid JSON, lacks required fields, has no parameterised
effect, or defaults to a weaker effect than its category allows.
"""
import json
import sys
from pathlib import Path

REQUIRED = ["displayName", "description", "mode", "metadata", "parameters", "policyRule"]
VALID_MODES = {"All", "Indexed"}


def check(path: Path) -> list[str]:
    errors = []
    try:
        d = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        return [f"{path.name}: invalid JSON ({e})"]
    for key in REQUIRED:
        if key not in d:
            errors.append(f"{path.name}: missing '{key}'")
    if d.get("mode") not in VALID_MODES:
        errors.append(f"{path.name}: mode must be one of {sorted(VALID_MODES)}")
    if not d.get("displayName", "").startswith("LZ: "):
        errors.append(f"{path.name}: displayName must start with 'LZ: '")
    eff = d.get("parameters", {}).get("effect")
    if not eff:
        errors.append(f"{path.name}: effect must be a parameter so it can be relaxed to Audit")
    elif "Disabled" not in eff.get("allowedValues", []):
        errors.append(f"{path.name}: effect must allow 'Disabled' for break-glass")
    then = d.get("policyRule", {}).get("then", {})
    if then.get("effect") != "[parameters('effect')]":
        errors.append(f"{path.name}: policyRule.then.effect must reference the effect parameter")
    if "version" not in d.get("metadata", {}):
        errors.append(f"{path.name}: metadata.version is required")
    return errors


def main(folder: str) -> int:
    files = sorted(Path(folder).glob("*.json"))
    if not files:
        print("no policy definitions found")
        return 1
    errors = [e for f in files for e in check(f)]
    for e in errors:
        print(f"ERROR {e}")
    print(f"checked {len(files)} definitions, {len(errors)} errors")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "policies/definitions"))
