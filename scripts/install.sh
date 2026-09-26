#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
KARABINER_DIR="$HOME/.config/karabiner/assets/complex_modifications"
HAMMERSPOON_DIR="$HOME/.hammerspoon"

mkdir -p "$KARABINER_DIR" "$HAMMERSPOON_DIR"

cp "$ROOT/config/karabiner/assets/complex_modifications/vimium-macos.json" \
   "$KARABINER_DIR/vimium-macos.json"

if [[ -f "$HAMMERSPOON_DIR/init.lua" ]]; then
  cp "$HAMMERSPOON_DIR/init.lua" \
     "$HAMMERSPOON_DIR/init.lua.backup-$TIMESTAMP"
  echo "Backed up existing Hammerspoon config."
fi

cp "$ROOT/config/hammerspoon/init.lua" "$HAMMERSPOON_DIR/init.lua"

echo
echo "Installed Vimium for macOS configuration."
echo "Enable the Karabiner rule under:"
echo "  Karabiner-Elements → Complex Modifications"
echo "Then reload Hammerspoon."
