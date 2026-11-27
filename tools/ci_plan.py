#!/usr/bin/env python3
"""Decide which apps CI must build and test, so a push to one app does not rebuild all of them.

Prints GitHub Actions outputs:
  apps=["Chispa"]            iOS apps to build (folders with <Dir>/<Dir>.xcodeproj)
  android=["RondaAndroid"]   Android apps to build (folders ending in Android with a gradlew)
  scaffold=true|false        whether tools/new_ios_app.py was checked (adds the generated app "Plantilla")

Rules:
  - workflow_dispatch, a new branch or an unknown base → everything.
  - A change to the platform's workflow → every app of that platform, plus the scaffold check.
  - A change to the generators or other tools → only the scaffold check ("Plantilla"): apps already made do not
    use the generator to build, so rebuilding all of them on a Mac would only burn time.
  - Otherwise only the apps whose folder changed; README.md and docs/ changes alone do not count.

Environment: EVENT (github.event_name), BASE (commit to diff against).
"""
import json
import os
import subprocess
import sys

TEMPLATE = "Plantilla"
ANDROID_TEMPLATE = "PlantillaAndroid"
ANDROID_TOOLS = ("tools/new_android_app.py", "tools/android/")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def ios_apps() -> list[str]:
    return sorted(d for d in os.listdir(ROOT) if os.path.isdir(os.path.join(ROOT, d, f"{d}.xcodeproj")))


def android_apps() -> list[str]:
    return sorted(d for d in os.listdir(ROOT) if d.endswith("Android") and os.path.exists(os.path.join(ROOT, d, "gradlew")))


def missing_promotion() -> list[str]:
    """Every iPhone app must run at 120 Hz (ProMotion): its Info.plist needs CADisableMinimumFrameDurationOnPhone = true.
    Without it iOS caps the app at 60 Hz. Checked on every push, for old and new apps alike."""
    missing = []
    for app in ios_apps():
        plist = os.path.join(ROOT, app, "Config", f"{app}-Info.plist")
        text = open(plist).read() if os.path.exists(plist) else ""
        compact = "".join(text.split())
        if "<key>CADisableMinimumFrameDurationOnPhone</key><true/>" not in compact:
            missing.append(app)
    return missing


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
        return {"apps": ios + [TEMPLATE], "android": android + [ANDROID_TEMPLATE], "scaffold": True}
    workflow = ".github/workflows/ios.yml" in files
    tooling = workflow or any(f.startswith("tools/") and not f.startswith(ANDROID_TOOLS) for f in files)
    android_workflow = ".github/workflows/android.yml" in files
    android_tooling = android_workflow or any(f.startswith(ANDROID_TOOLS) or f in ("tools/make_icon.py", "tools/ci_plan.py")
                                              for f in files)
    touched = {f.split("/")[0] for f in files if "/" in f and counts(f)}
    ios_apps_to_test = ios if workflow else [a for a in ios if a in touched]
    android_apps_to_test = android if android_workflow else [a for a in android if a in touched]
    return {
        # "Plantilla" is generated in CI by tools/new_ios_app.py to prove the template builds and passes its tests.
        "apps": ios_apps_to_test + ([TEMPLATE] if tooling else []),
        # "PlantillaAndroid" is generated in CI by tools/new_android_app.py in the same way.
        "android": android_apps_to_test + ([ANDROID_TEMPLATE] if android_tooling else []),
        "scaffold": tooling,
    }


if __name__ == "__main__":
    if missing := missing_promotion():
        print(f"Sin 120 Hz (falta CADisableMinimumFrameDurationOnPhone en el Info.plist): {', '.join(missing)}", file=sys.stderr)
        sys.exit(1)
    result = plan(os.environ.get("EVENT", ""), changed_files(os.environ.get("BASE", "")))
    lines = [f"apps={json.dumps(result['apps'])}", f"android={json.dumps(result['android'])}",
             f"scaffold={'true' if result['scaffold'] else 'false'}"]
    print("\n".join(lines))
    print("Plan: " + "; ".join(lines), file=sys.stderr)
