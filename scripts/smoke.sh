#!/usr/bin/env bash
# End-to-end check of an installed rex-annotate, in a throwaway Rex session it removes after.
#
# Each action runs through the server the way a key press does, against a stand-in agent:
# `cat -v` started as `claude`, in raw mode, so every byte it receives shows on its screen.
set -euo pipefail

work="$(mktemp -d)"
printf '# Plan\n\nStep one: build the thing.\n\nStep two: ship it.\n' >"$work/plan.md"
session=""
cleanup() {
  [ -n "$session" ] && rex kill "$session" >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT

failures=0
pass() { printf '  ok    %s\n' "$*"; }
fail() {
  printf '  FAIL  %s\n' "$*"
  failures=$((failures + 1))
}
check() {
  local name="$1"
  shift
  if "$@"; then pass "$name"; else fail "$name"; fi
}

blocks_labelled() {
  rex block ls -s "$session" --json | jq -r --arg l "$1" '[.. | objects | select(.label? == $l) | .block_id] | unique | .[]'
}
latest_review() { blocks_labelled Annotate | tail -1; }
close_reviews() {
  for block in $(blocks_labelled Annotate); do rex send -s "$session" -b "$block" q 2>/dev/null || true; done
  sleep 0.4
}
run_action() {
  local action="$1" block="$2" args="${3:-{\}}"
  jq -n --arg a "$action" --arg b "$block" --argjson args "$args" \
    '{action: $a, origin: "key", block_id: $b, args: $args}' |
    rex api call -s "$session" client.action - >/dev/null
  sleep 1.5
}
stand_in() {
  rex run -s "$session" -c "$work" --shell=none --json -- \
    /bin/bash -c 'stty raw -echo; exec -a claude /bin/cat -v' | jq -r '.block_ids[0]'
}

echo "rex-annotate smoke test"
check "the actions are loaded" sh -c 'rex actions | grep -q annotate_terminal'

created="$(rex new rex-annotate-smoke -c "$work" --json -- sh -c 'echo "error: smoke marker 42"; sleep 600')"
session="$(jq -r .session_id <<<"$created")"
shell_block="$(jq -r '.initial_windows[0].block_ids[0]' <<<"$created")"
sleep 0.5

run_action annotate_terminal "$shell_block"
review="$(latest_review)"
check "a terminal review shows the pane's output" \
  sh -c "rex capture -s '$session' -b '$review' | grep -q 'smoke marker 42'"
check "a pane without an agent copies to the clipboard" \
  sh -c "rex capture -s '$session' -b '$review' | head -1 | grep -q Copy"
close_reviews

agent="$(stand_in)"
sleep 0.8
run_action annotate_open "$agent"
review="$(latest_review)"
check "a review beside an agent sends to it" \
  sh -c "rex capture -s '$session' -b '$review' | head -1 | grep -q 'claude in'"
close_reviews

# Send the same note in each mode. A send ends with one Enter (^M) more than a paste.
endings=()
for paste in true false; do
  agent="$(stand_in)"
  sleep 0.8
  run_action annotate_open "$agent" "{\"paste\": $paste}"
  review="$(latest_review)"
  # A folder with one file opens on that file, with the document focused.
  rex send -s "$session" -b "$review" j
  sleep 0.2
  rex send -s "$session" -b "$review" c
  sleep 0.4
  rex send -s "$session" -b "$review" 'smoke note'
  rex send-key -s "$session" -b "$review" enter
  sleep 0.3
  rex send -s "$session" -b "$review" E
  sleep 1
  received="$(rex capture -s "$session" -b "$agent" | tr -d '\n')"
  [[ "$received" == *"smoke note"* ]] || fail "paste=$paste: the note reached the agent"
  trailing="${received##*[!^M]}"
  endings+=("$(printf '%s' "$trailing" | tr -cd 'M' | wc -c | tr -d ' ')")
  close_reviews
done
check "paste mode leaves Enter to you" test "$((endings[1] - endings[0]))" -eq 1

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
