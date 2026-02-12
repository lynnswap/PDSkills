#!/usr/bin/env bash
set -euo pipefail

# Runs `codex exec review --json ...` with stdout/stderr redirected to temp files.
# Success: prints only the final review message (extracted via `jq` from JSONL events).
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

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required by codex-review-quiet.sh (needed to extract the final review message from --json output)." >&2
  exit 2
fi

events="$(mktemp -t codex-review.events.XXXXXX.jsonl)"
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
  default_review_config+=(-c review_model=gpt-5.3-codex-spark)
fi

if [[ "$found_reasoning_effort" != "true" && "$found_review_model" != "true" ]]; then
  default_review_config+=(-c model_reasoning_effort=xhigh)
fi

set +e
codex exec review --json "${hide_reasoning_config[@]}" "${default_review_config[@]}" "${rest[@]}" >"$events" 2>"$log"
status=$?
set -e

if [[ $status -eq 0 ]]; then
  # Note: review tasks don't populate TurnComplete.last_agent_message, so `-o/--output-last-message`
  # is often empty for `codex exec review`. Instead, extract the final `agent_message` from JSONL.
  jq -rs '
    map(select(.type == "item.completed" and .item.type == "agent_message"))
    | (last // empty)
    | .item.text // ""
  ' "$events"

  rm -f "$events" "$log"
  exit 0
fi

if [[ -s "$events" ]]; then
  # If we got as far as emitting JSONL, surface the last agent message and a compact error summary.
  last_agent_message="$(
    jq -rs '
      map(select(.type == "item.completed" and .item.type == "agent_message"))
      | (last // empty)
      | .item.text // ""
    ' "$events" 2>/dev/null || true
  )"
  if [[ -n "$last_agent_message" ]]; then
    echo "$last_agent_message"
  fi

  error_summary="$(
    jq -rs '
      def parse_error_message:
        if type == "string" then
          . as $raw
          | (try fromjson catch null) as $parsed
          | if ($parsed | type) == "object" then
              (
                $parsed.error.message
                // $parsed.message
                // ($parsed.error | select(type == "string"))
                // $raw
              )
            else
              $raw
            end
        else
          ""
        end;

      (
        map(select(.type == "turn.failed")) | last | .error.message?
      ) // (
        map(select(.type == "error")) | last | .message?
      ) // ""
      | parse_error_message
    ' "$events" 2>/dev/null || true
  )"
  if [[ -n "$error_summary" ]]; then
    echo "$error_summary" >&2
  fi
fi

echo "codex review failed (exit=$status)"
echo "log: $log"
echo "events: $events"
exit "$status"
