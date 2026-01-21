#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: copy-ios-dev-docs.sh [--xcode <Xcode.app>] [--source <AdditionalDocumentation dir>] [--dest <dir>] [--interactive] [--list]

Copies Xcode IDEIntelligenceChat AdditionalDocumentation into this repo's
`skills/common/ios-dev-docs/references` folder (which is git-ignored).
Defaults to the active Xcode selected by `xcode-select -p`.

Options:
  --xcode, --xcode-app  Path to Xcode.app (or Contents/Developer).
  --source              Path to AdditionalDocumentation directory.
  --dest                Destination directory (default: skills/common/ios-dev-docs/references).
  --interactive          Always prompt when auto-detecting Xcode apps.
  --list                 List detected Xcode apps and exit.
  -h, --help             Show this help.
EOF
}

collect_candidates() {
  local -a found=()
  local -a unique=()
  local -a filtered=()
  local dev_dir app_dir app existing docs_dir seen

  if dev_dir="$(xcode-select -p 2>/dev/null)"; then
    if [[ "$dev_dir" == *.app/Contents/Developer ]]; then
      app_dir="${dev_dir%/Contents/Developer}"
      [[ -d "$app_dir" ]] && found+=("$app_dir")
    fi
  fi

  for app in /Applications/Xcode*.app /Applications/Developer/Xcode*.app; do
    [[ -d "$app" ]] && found+=("$app")
  done

  if ((${#found[@]})); then
    for app in "${found[@]}"; do
      seen=false
      if ((${#unique[@]})); then
        for existing in "${unique[@]}"; do
          if [[ "$app" == "$existing" ]]; then
            seen=true
            break
          fi
        done
      fi
      if [[ "$seen" == "false" ]]; then
        unique+=("$app")
      fi
    done
  fi

  if ((${#unique[@]})); then
    for app in "${unique[@]}"; do
      docs_dir="$app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation"
      if [[ -d "$docs_dir" ]]; then
        filtered+=("$app")
      fi
    done
  fi

  candidates=()
  if ((${#filtered[@]})); then
    candidates=("${filtered[@]}")
  fi
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
dest_dir="$repo_root/skills/common/ios-dev-docs/references"

xcode_app="${XCODE_APP:-}"
xcode_app_explicit=false
source_dir=""
force_prompt=false
list_only=false
candidates=()

if [[ -n "$xcode_app" ]]; then
  xcode_app_explicit=true
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --xcode|--xcode-app)
      if [[ -z "${2:-}" ]]; then
        echo "Missing value for $1" >&2
        usage
        exit 1
      fi
      xcode_app="$2"
      xcode_app_explicit=true
      shift 2
      ;;
    --source)
      if [[ -z "${2:-}" ]]; then
        echo "Missing value for $1" >&2
        usage
        exit 1
      fi
      source_dir="$2"
      shift 2
      ;;
    --dest)
      if [[ -z "${2:-}" ]]; then
        echo "Missing value for $1" >&2
        usage
        exit 1
      fi
      dest_dir="$2"
      shift 2
      ;;
    --interactive)
      force_prompt=true
      shift
      ;;
    --list)
      list_only=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -n "$source_dir" && -n "$xcode_app" ]]; then
  echo "Use either --source or --xcode, not both." >&2
  exit 1
fi

if [[ -n "$xcode_app" ]]; then
  xcode_app="${xcode_app%/}"
  if [[ "$xcode_app" == */Contents/Developer ]]; then
    xcode_app="${xcode_app%/Contents/Developer}"
  fi
fi

if [[ "$list_only" == "true" ]]; then
  collect_candidates
  if [[ ${#candidates[@]} -eq 0 ]]; then
    echo "No Xcode app found. Use --xcode to specify the path." >&2
    exit 1
  fi
  printf "%s\n" "${candidates[@]}"
  exit 0
fi

if [[ -z "$source_dir" ]]; then
  if [[ -z "$xcode_app" && "$force_prompt" != "true" && "$xcode_app_explicit" == "false" ]]; then
    if dev_dir="$(xcode-select -p 2>/dev/null)"; then
      if [[ "$dev_dir" == *.app/Contents/Developer ]]; then
        app_dir="${dev_dir%/Contents/Developer}"
        [[ -d "$app_dir" ]] && xcode_app="$app_dir"
      fi
    fi
  fi

  if [[ -n "$xcode_app" ]]; then
    source_dir="$xcode_app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation"
  fi

  if [[ "$force_prompt" == "true" || -z "$source_dir" || ! -d "$source_dir" ]]; then
    if [[ "$xcode_app_explicit" == "true" && "$force_prompt" != "true" ]]; then
      :
    else
      collect_candidates
      if [[ ${#candidates[@]} -eq 0 ]]; then
        echo "No Xcode app found. Use --xcode to specify the path." >&2
        exit 1
      fi

      if [[ ${#candidates[@]} -eq 1 && "$force_prompt" != "true" ]]; then
        echo "Found Xcode app:"
        printf "  %s\n" "${candidates[0]}"
        xcode_app="${candidates[0]}"
      else
        echo "Available Xcode apps:"
        for i in "${!candidates[@]}"; do
          printf "  %d) %s\n" "$((i + 1))" "${candidates[$i]}"
        done
        while true; do
          printf "Select an Xcode app [1-%d]: " "${#candidates[@]}"
          read -r selection
          if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#candidates[@]} )); then
            xcode_app="${candidates[$((selection - 1))]}"
            break
          fi
        done
      fi
      source_dir="$xcode_app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation"
    fi
  fi
fi

if [[ ! -d "$source_dir" ]]; then
  echo "AdditionalDocumentation not found at: $source_dir" >&2
  exit 1
fi

mkdir -p "$dest_dir"

if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete --exclude ".gitkeep" "$source_dir"/ "$dest_dir"/
else
  find "$dest_dir" -mindepth 1 -maxdepth 1 -not -name ".gitkeep" -exec rm -rf {} +
  cp -R "$source_dir"/. "$dest_dir"/
fi

echo "Copied AdditionalDocumentation from:"
echo "  $source_dir"
echo "Into:"
echo "  $dest_dir"
