#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 -m json.tool "$ROOT/config/karabiner/assets/complex_modifications/vimium-macos.json" >/dev/null
echo "Karabiner JSON: valid"
