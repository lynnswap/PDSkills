#!/usr/bin/env bash
set -euo pipefail

# Runs `codex exec -o <tmp> review ...` with stdout/stderr redirected to a temp log.
# Success: prints only the final review message (the `-o` file contents).
# Failure: prints a short error + the temp file paths so the caller can inspect.

repo_dir=""
rest=()

# Support `-C <DIR>` / `--cd <DIR>` at the wrapper level so callers can run
# the review against a repo without manually `cd`-ing first.
while (($#)); do
  case "$1" in
    -C|--cd)
      shift
      repo_dir="${1:-}"
      if [[ -z "$repo_dir" ]]; then
        echo "missing directory after -C/--cd" >&2
        exit 2
      fi
      shift
      ;;
    *)
      rest+=("$1")
      shift
      ;;
  esac
done

if [[ -n "$repo_dir" ]]; then
  cd "$repo_dir"
fi

out="$(mktemp -t codex-review.last.XXXXXX)"
log="$(mktemp -t codex-review.log.XXXXXX)"

hide_reasoning_config=()
default_review_config=()
found_hide_reasoning=false
found_review_model=false
found_reasoning_effort=false

# If the caller already provided `-c hide_agent_reasoning=...`, don't add another.
args=("${rest[@]}")
for ((i = 0; i < ${#args[@]}; i++)); do
  if [[ "${args[$i]}" == "-c" || "${args[$i]}" == "--config" ]]; then
    if (( i + 1 < ${#args[@]} )); then
      if [[ "${args[$i+1]}" == hide_agent_reasoning=* ]]; then
        found_hide_reasoning=true
      elif [[ "${args[$i+1]}" == review_model=* ]]; then
        found_review_model=true
      elif [[ "${args[$i+1]}" == model_reasoning_effort=* ]]; then
        found_reasoning_effort=true
      fi
    fi
  fi
done

if [[ "$found_hide_reasoning" != "true" ]]; then
  hide_reasoning_config=(-c hide_agent_reasoning=true)
fi

if [[ "$found_review_model" != "true" ]]; then
  default_review_config+=(-c review_model=gpt-5.1-codex-mini)
fi

if [[ "$found_reasoning_effort" != "true" ]]; then
  default_review_config+=(-c model_reasoning_effort=high)
fi

set +e
codex exec -o "$out" review "${hide_reasoning_config[@]}" "${default_review_config[@]}" "${rest[@]}" >"$log" 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  cat "$out"
  rm -f "$out" "$log"
  exit 0
fi

echo "codex review failed (exit=$status)"
echo "log: $log"
echo "last_message: $out"
exit "$status"
