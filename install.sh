#!/usr/bin/env bash
# Install rex-annotate: plannotator-tui, the annotate.lua module, and one line in init.lua.
#
#   ./install.sh                 install or upgrade
#   ./install.sh --with-skill    also teach Claude Code to request reviews itself
#   ./install.sh --no-build      keep the plannotator-tui you have
#   ./install.sh --uninstall     remove the module and its line from init.lua
#
# PLANNOTATOR_TUI_GIT and PLANNOTATOR_TUI_REF choose the plannotator-tui source to build.
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
git_url="${PLANNOTATOR_TUI_GIT:-https://github.com/kwigley/plannotator-tui}"
git_ref="${PLANNOTATOR_TUI_REF:-feat/rex-integration}"
require_line='require("annotate").setup{}'

build=1
skill=0
uninstall=0
for arg in "$@"; do
  case "$arg" in
    --with-skill) skill=1 ;;
    --no-build) build=0 ;;
    --uninstall) uninstall=1 ;;
    -h | --help)
      sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "install.sh: unknown option $arg" >&2
      exit 2
      ;;
  esac
done

say() { printf '  %s\n' "$*"; }
die() {
  printf 'install.sh: %s\n' "$*" >&2
  exit 1
}

command -v rex >/dev/null || die "rex is not on PATH; run this from a Rex terminal"

# The server reads REX_CONFIG when it is set, else the XDG location.
if [ -n "${REX_CONFIG:-}" ]; then
  init="$REX_CONFIG"
else
  init="${XDG_CONFIG_HOME:-$HOME/.config}/rex/init.lua"
fi
config_dir="$(dirname "$init")"
module="$config_dir/annotate.lua"
skills="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/rex-annotate"

if [ "$uninstall" = 1 ]; then
  rm -f "$module"
  say "removed $module"
  if [ -d "$skills" ]; then
    rm -rf "$skills"
    say "removed $skills"
  fi
  if [ -f "$init" ] && grep -qF 'require("annotate")' "$init"; then
    cp "$init" "$init.bak"
    grep -vF 'require("annotate")' "$init.bak" >"$init" || true
    say "removed the require line from $init (backup: $init.bak)"
  fi
  rex config reload >/dev/null && say "reloaded Rex"
  exit 0
fi

echo "plannotator-tui"
if [ "$build" = 1 ]; then
  command -v cargo >/dev/null || die "cargo is not on PATH; install Rust from https://rustup.rs or pass --no-build"
  cargo install --locked --git "$git_url" --branch "$git_ref" plannotator-tui
fi
bin="$HOME/.cargo/bin/plannotator-tui"
[ -x "$bin" ] || bin="$(command -v plannotator-tui || true)"
[ -n "$bin" ] || die "plannotator-tui is not installed"
# `rex` alone prints the usage and fails. A build without Rex support never names `rex pane`.
usage="$("$bin" rex 2>&1 || true)"
[[ "$usage" == *"rex pane"* ]] || die "$bin has no Rex support; rerun without --no-build"
say "using $bin"

echo "Rex"
mkdir -p "$config_dir"
cp "$repo/annotate.lua" "$module"
say "installed $module"
if [ -f "$init" ] && grep -qF 'require("annotate")' "$init"; then
  say "$init already loads it"
else
  [ -f "$init" ] && cp "$init" "$init.bak" && say "backed up $init to $init.bak"
  printf '\n%s\n' "$require_line" >>"$init"
  say "added $require_line to $init"
fi
rex config check "$init" >/dev/null || die "rex config check failed; see: rex config check"
rex config reload >/dev/null
say "reloaded Rex"

if [ "$skill" = 1 ]; then
  echo "Claude Code skill"
  mkdir -p "$skills"
  cp "$repo/skills/rex-annotate/SKILL.md" "$skills/SKILL.md"
  say "installed $skills/SKILL.md"
fi

cat <<'EOF'

Done. In a pane running Claude Code:
  cmd+shift+o   annotate one of its recent replies
  cmd+alt+o     annotate its newest reply
  cmd+shift+e   review the Markdown in its folder
  cmd+alt+t     annotate the pane's terminal output
Press ? in the review for every key.
EOF
