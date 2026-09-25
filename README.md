# Vimium for macOS

System-wide, Vimium-inspired keyboard interaction for macOS using **Karabiner-Elements + Hammerspoon**.

**Author:** Devesh Raghuwanshi (`ildevesh`)  
**Status:** Experimental / active development  
**License:** MIT

## What this is

This project extends the keyboard-first interaction model of Vimium beyond the browser and into the macOS GUI.

- **Karabiner-Elements** handles global keyboard interception, text-input protection, scrolling, navigation, application-specific shortcuts, and the master mode.
- **Hammerspoon** handles higher-level macOS automation, application menu commands, the command palette, Finder file launching, and actions that are awkward to implement purely in Karabiner.

A core requirement is that **normal typing must keep working when a text input is focused**.

## Current features

| Feature | Status |
|---|---|
| Super+V master toggle | Implemented |
| Text-field protection | Implemented |
| `w/s` vertical scrolling | Implemented |
| `a/d` horizontal scrolling | Implemented |
| `W/S` full-page scrolling | Implemented |
| `h/l` back/forward | Implemented |
| `⌘⇧A / ⌘⇧D` back/forward | Implemented |
| Super+Q / Super+E tab navigation | Implemented |
| Safari/Chrome/Chromium/Dia tab switching | Implemented |
| `Tab+Q` move tab to new window | Implemented for Safari/Chrome |
| Browser `o/O/~` navigation | Implemented |
| Super+Space command palette | Implemented |
| Native application menu discovery | Implemented |
| Generic fallback commands | Implemented |
| Finder current-folder file/folder search | Implemented |
| Direct URL/file/folder opening from command palette | Implemented |
| Browser bookmark/history search | Planned |
| Dia-specific Tab+Q handling | Planned |
| Vim-style hint mode | Intentionally removed |
| Scroll-to-top/bottom remaps | Intentionally omitted |
| `⌘W` / `⌘S` remapping | Intentionally avoided |

## Super / Hyper key

In this project, **Super** means the keyboard's Hyper key:

```text
⌘ + Control + Option + Shift
```

Main controls:

```text
Super+V      → toggle Vim mode
Super+Q      → next tab
Super+E      → previous tab
Super+Space  → command palette
```

## Keymap

### Scrolling

```text
w → scroll up
s → scroll down
a → scroll left
d → scroll right
W → full-page up
S → full-page down
```

### History

```text
h     → back
l     → forward
⌘⇧A   → back
⌘⇧D   → forward
```

### Tabs

```text
Super+Q → next tab
Super+E → previous tab
Tab+Q   → move current tab to a new window (supported browsers)
```

### Browser navigation

```text
o → address/search bar
O → new tab
~ → edit current URL
```

### Other

```text
F4 → launch/focus Shottr
```

Important macOS shortcuts such as `⌘W`, `⌘S`, `⌘V`, `⌘C`, and `⌘A` are intentionally not replaced globally.

## Command palette

```text
Super+Space
```

The command palette combines:

1. Native commands exposed by the current application's menu hierarchy.
2. Common macOS fallback commands.
3. Finder items from the current Finder folder when Finder is frontmost.

When searching in Finder, **command matches always appear before file/folder matches**.

Example:

```text
Search: MHRM

[matching commands]
MHRM
MHRM.pdf
MHRM Notes
```

Browser bookmark/history search is intentionally not implemented yet.

## Installation

### Requirements

- [Karabiner-Elements](https://karabiner-elements.pqrs.org/)
- [Hammerspoon](https://www.hammerspoon.org/)
- Optional: [Shottr](https://shottr.cc/)

### Manual

Copy:

```text
config/karabiner/assets/complex_modifications/vimium-macos.json
```

to:

```text
~/.config/karabiner/assets/complex_modifications/
```

Then enable **Vimium macOS - core keyboard layer** under:

```text
Karabiner-Elements → Complex Modifications
```

Copy:

```text
config/hammerspoon/init.lua
```

to:

```text
~/.hammerspoon/init.lua
```

Then reload Hammerspoon.

### Automated

```bash
./scripts/install.sh
```

The installer backs up an existing Hammerspoon configuration before replacement. It does not automatically enable the Karabiner rule.

## Text-input protection

Karabiner checks the focused Accessibility element. When a text input is focused, Vim mappings such as `w/s/a/d/h/l` are not applied.

This is a central design requirement of the project.

## Application compatibility

### Safari

Core scrolling, navigation, tab switching, command palette, and Tab+Q are supported.

### Google Chrome

Core scrolling, navigation, tab switching, command palette, and Tab+Q are supported.

### Chromium

Generic Chromium tab/navigation mappings are included. Individual Chromium-based browsers may need their own application-specific rules.

### Dia

Dia requires custom handling for some operations. Tab switching has dedicated rules; the Hammerspoon Tab+Q action is intentionally not implemented yet.

### Other apps

Applications with useful native menus can expose those commands through the palette. Apps that expose little menu information still receive the common fallback command set.

## Project structure

```text
vimium-macos/
├── README.md
├── knowledge.md
├── LICENSE
├── NOTICE.md
├── CONTRIBUTING.md
├── SECURITY.md
├── CHANGELOG.md
├── .gitignore
│
├── config/
│   ├── karabiner/
│   │   └── assets/complex_modifications/
│   │       └── vimium-macos.json
│   └── hammerspoon/
│       └── init.lua
│
├── docs/
│   ├── KEYMAP.md
│   ├── ARCHITECTURE.md
│   ├── COMPATIBILITY.md
│   └── ROADMAP.md
│
├── scripts/
│   ├── install.sh
│   └── validate.sh
│
└── .github/ISSUE_TEMPLATE/
    ├── bug_report.md
    └── feature_request.md
```

## Limitations

- Browser bookmark/history search is not yet implemented.
- Finder search covers the immediate contents of the current folder.
- Dia-specific move-tab handling remains unfinished.
- Application menu availability depends on what each app exposes to macOS Accessibility.
- This project is in active development and is not a drop-in replacement for Vimium.

## Copyright and free use

Copyright © 2026 **Devesh Raghuwanshi (ildevesh)**.

This repository is released under the **MIT License**. Subject to that license, it may be used, modified, copied, redistributed, and incorporated into personal, educational, research, non-commercial, or commercial projects without a fee.

The software is provided **as-is, without warranty**. See `LICENSE` for the complete legal terms.

This project is independent and is not affiliated with or endorsed by Apple, Vimium, Karabiner-Elements, Hammerspoon, Google, Chromium, Safari, Dia, or Shottr.

## Direct opening from the command palette

The command palette can open direct web and local targets when typed into the search field. Examples:

```text
google.com
https://example.com/docs
www.example.com
~/Downloads/report.pdf
/Users/devesh/Documents/report.pdf
```

Press Enter on an `Open ...` result. Existing local files and folders are passed to macOS `/usr/bin/open`. Non-local input is treated as a web target, so a domain does not need to be prefixed with `https://`.

Search priority remains:

1. Matching commands
2. Finder file/folder matches
3. Existing local path
4. Web fallback

This keeps commands above files or URLs when names overlap.

For implementation history and failed experiments, see `knowledge.md`.
