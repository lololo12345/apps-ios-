#!/usr/bin/env python3
"""Decide which apps CI must build and test, so a push to one app does not rebuild all of them.

Prints GitHub Actions outputs:
  apps=["Chispa"]            iOS apps to build (folders with <Dir>/<Dir>.xcodeproj)
  android=["RondaAndroid"]   Android apps to build (folders ending in Android with a gradlew)
  scaffold=true|false        whether tools/new_ios_app.py was checked (adds the generated app "Plantilla")

Rules:
  - workflow_dispatch, a new branch or an unknown base → everything.
  - Changes to tools/ or to a workflow → every app of that platform, plus the scaffold check.
  - Otherwise only the apps whose folder changed; README.md and docs/ changes alone do not count.

Environment: EVENT (github.event_name), BASE (commit to diff against).
"""
import json
import os
import subprocess
import sys

TEMPLATE = "Plantilla"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def ios_apps() -> list[str]:
    return sorted(d for d in os.listdir(ROOT) if os.path.isdir(os.path.join(ROOT, d, f"{d}.xcodeproj")))


def android_apps() -> list[str]:
    return sorted(d for d in os.listdir(ROOT) if d.endswith("Android") and os.path.exists(os.path.join(ROOT, d, "gradlew")))


def changed_files(base: str) -> list[str] | None:
    if not base or set(base) == {"0"}:
        return None
    try:
        out = subprocess.run(["git", "diff", "--name-only", base, "HEAD"], cwd=ROOT, check=True,
                             capture_output=True, text=True).stdout
    except subprocess.CalledProcessError:
        return None
    return [line for line in out.splitlines() if line]


def counts(path: str) -> bool:
    """Documentation-only edits do not need a rebuild."""
    parts = path.split("/")
    return not (path.endswith(".md") or "docs" in parts[1:2])


def plan(event: str, files: list[str] | None) -> dict:
    ios, android = ios_apps(), android_apps()
    if event == "workflow_dispatch" or files is None:
        return {"apps": ios + [TEMPLATE], "android": android, "scaffold": True}
    tooling = any(f.startswith("tools/") or f == ".github/workflows/ios.yml" for f in files)
    android_tooling = any(f == ".github/workflows/android.yml" for f in files)
    touched = {f.split("/")[0] for f in files if "/" in f and counts(f)}
    return {
        # "Plantilla" is generated in CI by tools/new_ios_app.py to prove the template builds and passes its tests.
        "apps": ios + [TEMPLATE] if tooling else [a for a in ios if a in touched],
        "android": android if android_tooling else [a for a in android if a in touched],
        "scaffold": tooling,
    }


if __name__ == "__main__":
    result = plan(os.environ.get("EVENT", ""), changed_files(os.environ.get("BASE", "")))
    lines = [f"apps={json.dumps(result['apps'])}", f"android={json.dumps(result['android'])}",
             f"scaffold={'true' if result['scaffold'] else 'false'}"]
    print("\n".join(lines))
    print("Plan: " + "; ".join(lines), file=sys.stderr)
