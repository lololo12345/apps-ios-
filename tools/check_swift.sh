#!/usr/bin/env bash
# Checks one or more apps on Linux in seconds (no Mac needed):
#   1. syntax of EVERY Swift file of the app (SwiftUI screens, tests, widget…): unbalanced braces, typos in
#      keywords, broken string interpolation… are caught here instead of after a 15-minute CI run;
#   2. full type-check of the plain-Swift logic in <App>Kit.
#
#   tools/check_swift.sh Chispa            # checks Chispa/ (syntax) and Chispa/ChispaKit (types)
#   tools/check_swift.sh Chispa Isla       # several apps
#   tools/check_swift.sh --all             # every <App>/<App>Kit in the repo
#   tools/check_swift.sh --run Chispa extra.swift   # also compile and run a scratch script against the Kit
#
# Only Foundation code can be checked here (SwiftUI, UIKit, WidgetKit… exist only on Apple platforms),
# which is why each app keeps its logic in <App>Kit. The toolchain is downloaded once to ~/.cache.
set -euo pipefail
VERSION="6.1.2"
ROOT="${CHECK_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
TOOLCHAIN="${SWIFT_TOOLCHAIN:-$HOME/.cache/swift-$VERSION}"
SWIFTC="$TOOLCHAIN/usr/bin/swiftc"

if [ ! -x "$SWIFTC" ]; then
  . /etc/os-release
  distro="${ID}${VERSION_ID//./}"          # ubuntu2404
  label="${ID}${VERSION_ID}"               # ubuntu24.04
  url="https://download.swift.org/swift-$VERSION-release/$distro/swift-$VERSION-RELEASE/swift-$VERSION-RELEASE-$label.tar.gz"
  echo "Descargando Swift $VERSION para $label (una sola vez)…" >&2
  mkdir -p "$TOOLCHAIN"
  curl -sSfL "$url" | tar xz --strip-components=1 -C "$TOOLCHAIN"
fi

run_script=""
apps=()
while [ $# -gt 0 ]; do
  case "$1" in
    --all) for d in "$ROOT"/*/; do n=$(basename "$d"); [ -d "$d/$n.xcodeproj" ] && apps+=("$n"); done ;;
    --run) run_script="yes" ;;
    *.swift) script="$1" ;;
    *) apps+=("$1") ;;
  esac
  shift
done
[ ${#apps[@]} -gt 0 ] || { echo "Uso: tools/check_swift.sh <App>… | --all" >&2; exit 2; }

status=0
for app in "${apps[@]}"; do
  [ -d "$ROOT/$app" ] || { echo "✘ $app: no existe $ROOT/$app" >&2; status=1; continue; }
  plist="$ROOT/$app/Config/$app-Info.plist"
  if [ -f "$plist" ] && ! tr -d ' \t\n' < "$plist" | grep -q '<key>CADisableMinimumFrameDurationOnPhone</key><true/>'; then
    echo "✘ $app: falta 120 Hz (CADisableMinimumFrameDurationOnPhone en $plist)" >&2; status=1
  fi
  mapfile -t every < <(find "$ROOT/$app" -name '*.swift' -not -path '*/.build/*' | sort)
  if [ ${#every[@]} -gt 0 ]; then
    if "$SWIFTC" -parse -swift-version 6 "${every[@]}" 2>&1; then
      echo "✔ $app: sintaxis correcta en ${#every[@]} archivos Swift"
    else
      echo "✘ $app: errores de sintaxis arriba" >&2; status=1; continue
    fi
  fi
  kit="$ROOT/$app/${app}Kit"
  [ -d "$kit" ] || continue
  # Files that import Apple-only frameworks cannot be compiled on Linux: skip them and say so.
  apple='^import (SwiftUI|UIKit|WidgetKit|ActivityKit|AppIntents|SwiftData|MapKit|CoreLocation|EventKit|GameKit|Charts|AVFoundation|UserNotifications|CoreData)$'
  mapfile -t files < <(find "$kit" -name '*.swift' | sort | while read -r f; do grep -Eq "$apple" "$f" || echo "$f"; done)
  skipped=$(( $(find "$kit" -name '*.swift' | wc -l) - ${#files[@]} ))
  [ "$skipped" -gt 0 ] && echo "· $app: $skipped archivo(s) usan frameworks de Apple y solo se comprueban en CI"
  [ ${#files[@]} -gt 0 ] || continue
  if [ -n "$run_script" ] && [ -n "${script:-}" ]; then
    out="$(mktemp -d)/run"
    "$SWIFTC" -swift-version 6 -O "${files[@]}" "$script" -o "$out" && "$out" || status=1
  elif "$SWIFTC" -typecheck -swift-version 6 "${files[@]}"; then
    echo "✔ $app: ${#files[@]} archivos de ${app}Kit compilan con Swift 6"
  else
    echo "✘ $app: errores arriba" >&2; status=1
  fi
done
exit $status
