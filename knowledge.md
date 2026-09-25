# Knowledge Base / Development History

This file is the project's **engineering memory**. It is intentionally different from the README and other user-facing documentation.

The README explains how to use the project. The docs describe the current architecture, keymap, roadmap, and compatibility. This file preserves the reasoning, experiments, failures, workarounds, decisions, and implementation history that led to the current configuration, including things that are no longer present in the shipped feature set.

It should be updated when an experiment changes the design or when a future contributor needs to understand why a seemingly obvious implementation was avoided.

---

## 1. Original project goal

The original idea was a **system-wide Vimium-style interaction layer for macOS**, not merely a browser extension.

The initial concept included:

- Keyboard-first interaction with the macOS GUI.
- Keyboard-driven scrolling and navigation.
- Keyboard-driven mouse movement and clicking.
- Accessibility-based discovery of interactive UI elements.
- A Vimium-like hint mode across applications.
- Context-sensitive remapping so normal typing remains normal inside text fields.
- A global enable/disable mechanism.
- Application-specific compatibility handling.

The implementation direction was:

- **Karabiner-Elements** for low-level, global keyboard interception and stateful remapping.
- **Hammerspoon** for higher-level macOS automation, application menus, Finder integration, and operations that are cumbersome or unreliable in Karabiner alone.

The current project is intentionally narrower than the original concept. The system-wide hint/mouse-control portion was explored but is not part of the current shipped configuration.

---

## 2. Current architecture

### Karabiner-Elements

Karabiner currently handles:

- The master Vim-mode variable.
- Text-input protection.
- Vertical and horizontal scrolling.
- Full-page scrolling.
- Browser/application navigation mappings.
- Application-specific tab switching.
- The `Tab+Q` internal Hammerspoon trigger.
- The `Super+Space` internal Hammerspoon trigger.

### Hammerspoon

Hammerspoon currently handles:

- `Tab+Q` → move the current tab to a new window in supported browsers.
- F4 → launch/focus Shottr.
- Native application menu discovery.
- The command palette.
- Generic fallback keyboard commands.
- Finder current-folder enumeration.
- Finder file/folder opening.
- Direct web target opening.
- Direct local path opening.

### Internal event bridge

The project uses otherwise-unused function keys as internal event signals:

```text
Super+Space → F16 → Hammerspoon command palette
Tab+Q      → F18 → Hammerspoon tab action
```

This keeps the low-level keyboard detection in Karabiner while leaving higher-level application logic in Hammerspoon.

---

## 3. Master toggle history

### First approach: F8

The original design used **F8** as the master toggle.

This did not work with the user's Bluetooth keyboard because the physical F8 key was being interpreted as:

```text
Command + Control + Space
```

That combination opens the macOS emoji/symbol picker, so F8 was not a reliable physical control for this setup.

### Current approach: Super+V

The project therefore changed to:

```text
Super = Command + Control + Option + Shift
Super+V = toggle `vim_mode`
```

This was tested and works.

The Karabiner variable is:

```text
vim_mode = 0 → normal keyboard behavior
vim_mode = 1 → Vim-style layer active
```

This also makes the project safer because the entire layer can be disabled without removing the configuration.

---

## 4. Text-input protection

Text-input safety is a central design requirement.

Karabiner checks the Accessibility role string of the focused UI element and avoids applying the Vim layer when the focused element is a text input.

The effective condition used by the current configuration is based on:

```text
accessibility.focused_ui_element.role_string like 'AXText*'
```

### Verification experiment

A temporary F7 test rule was used to verify whether macOS Accessibility information correctly identified a text field.

The test was performed in a ChatGPT text field and correctly detected that the field was a text-input context.

The temporary test rule was then removed; it is **not** part of the repository.

This experiment established that text-field protection could be implemented at the Karabiner layer rather than requiring application-specific code for every editor.

---

## 5. Scrolling implementation

Current mappings:

```text
w → scroll up
s → scroll down
a → scroll left
d → scroll right
W → page up
S → page down
```

The normal scroll mappings use Karabiner mouse-wheel events.

These were tested successfully in browsers and Finder.

### Why scroll-to-top/bottom was not implemented

An earlier plan considered using modified versions of the scroll keys for top/bottom behavior. That was deliberately abandoned because the natural macOS shortcuts under consideration were already important global shortcuts, especially:

```text
⌘W → close window/tab
⌘S → save
```

The project therefore does **not** repurpose `⌘W` or `⌘S` for Vim-style scrolling. Scroll-to-top and scroll-to-bottom are intentionally omitted rather than risking global macOS behavior.

---

## 6. History/navigation implementation

Current mappings:

```text
h   → Command + [
l   → Command + ]
⌘⇧A → Command + [
⌘⇧D → Command + ]
```

These were chosen because the bracket shortcuts are the established macOS/browser back/forward mechanism and therefore require no application-level automation for the basic case.

---

## 7. Tab navigation decisions

### Why Super+Q / Super+E

The project initially considered several alternatives for next/previous tab, including shortcuts that would conflict with common macOS application behavior.

The final decision was:

```text
Super+Q → next tab
Super+E → previous tab
```

The reason is conflict avoidance: the project should not globally steal common shortcuts such as `Command+D`, `Command+A`, or `Control+A`.

### Application-specific implementations

Safari:

```text
Super+Q → Control+Tab
Super+E → Control+Shift+Tab
```

Google Chrome / Chromium:

```text
Super+Q → Command+Option+Right
Super+E → Command+Option+Left
```

Dia:

```text
Super+Q → Command+Shift+]
Super+E → Command+Shift+[
```

These are separated in Karabiner because the same logical operation has different reliable shortcuts in the target applications.

---

## 8. Tab+Q → new window

`Tab+Q` is used as an internal trigger.

Karabiner emits:

```text
F18
```

Hammerspoon listens for F18 and attempts the application's native:

```text
Window → Move Tab to New Window
```

### Confirmed support

- Safari — works.
- Google Chrome — works.

Chrome accepts more than one menu-label spelling, so the current code checks both:

```text
Move Tab to New Window
Move tab to new window
```

### Dia

Dia was intentionally **not** implemented for Tab+Q yet. The current behavior is an explicit "not implemented" message rather than pretending the action is supported.

This is a deliberate compatibility boundary.

---

## 9. Browser URL controls

Current mappings in supported browsers:

```text
o → Command+L
O → Command+T
~ → Command+L
```

The supported browser bundle IDs include:

- Safari
- Google Chrome
- Chromium
- Dia

Dia's bundle ID was discovered/confirmed as:

```text
company.thebrowser.dia
```

The Dia-specific bundle was added to the browser conditions after testing showed the generic browser rules did not include it.

---

## 10. Shottr

F4 is reserved for:

```text
launch or focus Shottr
```

Hammerspoon handles this with `hs.application.launchOrFocus("Shottr")`.

Shottr is optional; the rest of the project does not depend on it.

---

## 11. Command palette: design evolution

The command palette became the main higher-level interface for application commands.

### First palette attempt: custom Hammerspoon webview

A custom Hammerspoon webview-based palette was tried.

It was rejected because it introduced practical problems:

- It stole application focus in undesirable ways.
- It could become stuck.
- It interfered with browser keyboard shortcuts such as `Command+1` / `Command+2`.
- It displayed an unwanted square/black border.

The project was therefore rolled back to the more stable native Hammerspoon:

```lua
hs.chooser
```

The current palette intentionally uses `hs.chooser` even though it is visually less customizable than a custom webview.

### Current palette UI

Current behavior includes:

- Dark chooser.
- Approximately 40% width.
- Eight visible rows.
- `Search Commands` placeholder.
- Automatic positioning handled by Hammerspoon.

Reliability and focus behavior were prioritized over cosmetic customization.

---

## 12. Native menu discovery

The palette can expose commands from the current application's native macOS menu hierarchy.

### Problem encountered

The first native-menu parser returned no useful commands because the Accessibility menu hierarchy was being traversed incorrectly.

### Fix

The working parser recursively follows the menu object's children through:

```text
item.AXChildren[1]
```

The implementation treats those nested children as submenu collections and records executable `AXMenuItem` entries.

Bookmark and History menu roots are intentionally excluded from the initial command list to avoid flooding the palette with browsing data.

### Fallback behavior

Some applications expose too little menu information to make native discovery useful.

The palette therefore adds a generic fallback set of common commands, including operations such as:

```text
New Window
Close Window / Tab
Save
Copy
Paste
Cut
Select All
Undo
Redo
Find
Hide Application
Quit Application
```

Browser-specific fallback commands are added for supported browsers.

This means the command palette remains useful even when Accessibility menu information is incomplete.

---

## 13. Finder integration

Finder has two separate pieces of command-palette logic:

1. Determine the current Finder folder.
2. Enumerate the items inside that folder.

### Current Finder folder

AppleScript was used because it reliably exposes the front Finder window's target folder.

The effective logic is equivalent to:

```applescript
tell application "Finder"
  if (count of Finder windows) > 0 then
    try
      return POSIX path of (target of front Finder window as alias)
    on error
      return POSIX path of (path to desktop folder)
    end try
  else
    return POSIX path of (path to desktop folder)
  end if
end tell
```

This was tested successfully. For example, the current folder could be returned as:

```text
/Users/<user>/Downloads/
```

### Failed approach: `hs.fs.dir()`

An attempt was made to enumerate Finder directory contents using Hammerspoon's filesystem iterator.

It failed with an error equivalent to:

```text
bad argument #1 to 'for iterator'
(directory metatable expected, got nil)
```

Because the approach was unreliable in the current configuration, it was abandoned.

### Failed approach: AppleScript type detection

A more elaborate AppleScript attempt tried to inspect Finder items and determine whether each item was a folder by navigating item relationships.

That AppleScript was malformed and failed.

The project did **not** need type detection to deliver the required behavior, so the implementation was simplified.

### Current working approach

Finder is asked only for the names of every item in the current folder:

```applescript
tell application "Finder"
    set theFolder to target of front Finder window
    return name of every item of theFolder
end tell
```

This was tested successfully and returned approximately 650 items from the Downloads folder, including files and folders.

The palette therefore uses the names plus the current folder path to construct openable paths.

Dotfiles are hidden from the Finder result list.

---

## 14. Finder result ordering

A query in Finder can match both a command and a file/folder.

The required priority is:

```text
1. Matching commands
2. Matching Finder files/folders
3. Direct URL/path fallback
```

This was deliberately implemented so a file named something like `MHRM` does not hide or displace an application command named `MHRM`.

Deduplication is performed after the combined result list is built.

---

## 15. Direct URL / file / folder opening

The command palette was extended so typed input can directly open either a web target or a local target.

### Required behavior

Examples of intended input include:

```text
google.com
www.example.com
https://example.com/docs
/Users/<user>/Documents/report.pdf
~/Downloads/report.pdf
file:///Users/<user>/Documents/report.pdf
```

In Finder, a relative path such as:

```text
MHRM/report.pdf
```

can resolve relative to the current Finder folder.

### First implementation problem

The first version attempted to recognize domains with a Lua pattern containing alternation (`|`).

Lua patterns do not implement regular-expression alternation in that form, so a bare domain such as:

```text
google.com
```

was not consistently recognized as a web target, while explicit `https://...` input worked.

### Second implementation

The logic was changed to avoid a TLD/domain whitelist.

The current behavior is intentionally generic:

- Existing local paths are checked first.
- Explicit local-path syntax that does not exist is not silently converted into a website.
- Explicit URL schemes are preserved.
- Other non-local text is treated as a web target and passed to the default browser.

Therefore the implementation does **not** contain a hard-coded list such as `google.com`, `github.com`, etc.

### Why this behavior was chosen

The desired command-bar behavior is launcher-like rather than validator-like: the user should be able to type a site without first specifying `https://` and without maintaining a domain database.

macOS `/usr/bin/open` is used as the final launcher.

---

## 16. Command priority for direct opening

The final order is important:

```text
Command match
    ↓
Finder item match (Finder only)
    ↓
Direct local path match
    ↓
Web fallback
```

This prevents arbitrary typed text from unexpectedly overriding an actual command or an existing local Finder item.

---

## 17. Important shortcuts intentionally NOT remapped

The project avoids globally stealing common macOS shortcuts whenever possible.

In particular, it does not globally remap:

```text
⌘W
⌘S
⌘C
⌘V
⌘A
```

The command palette can still expose some of these as explicit commands when appropriate because selecting a palette item is different from globally intercepting the physical shortcut.

---

## 18. Hint mode: planned, tested, then removed

The original project concept included a system-wide Vimium-style hint mode.

That would require:

1. Accessibility hierarchy traversal.
2. Identification of clickable/actionable elements.
3. Generating short visual labels.
4. Rendering those labels over arbitrary application UIs.
5. Mapping the selected label back to an Accessibility action or mouse coordinate.

The idea was ultimately removed from the current active configuration because cross-application reliability was not sufficient for a stable first release.

This is **not** an accidentally missing feature. It is an intentional scope decision.

The roadmap may revisit related Accessibility/UI-navigation work later.

---

## 19. Mouse-control mode

The earliest architecture included keyboard-driven pointer movement, clicking, and double-clicking.

Those capabilities are not part of the current shipped implementation.

The current Karabiner configuration uses mouse events only for scrolling, not as a general keyboard mouse-control layer.

A future mouse-control mode remains a roadmap item rather than an undocumented assumption.

---

## 20. Current tested/implemented feature set

As of the current repository state, the practical feature set is:

### Mode control

- Super+V master toggle.
- Text-input protection.

### Scrolling

- `w` / `s` vertical scrolling.
- `a` / `d` horizontal scrolling.
- `W` / `S` full-page scrolling.

### Navigation

- `h` / `l` back/forward.
- `⌘⇧A` / `⌘⇧D` back/forward.

### Tabs

- Super+Q / Super+E application-aware tab switching.
- Safari support.
- Chrome support.
- Chromium support.
- Dia tab-switching shortcuts.
- Tab+Q → new window in Safari and Chrome.
- Dia Tab+Q intentionally unimplemented.

### Browser controls

- `o` address/search bar.
- `O` new tab.
- `~` address/search bar / URL editing behavior.

### Command palette

- Super+Space.
- Native application menu discovery.
- Generic fallback commands.
- Finder current-folder item search.
- Command-first ranking in Finder.
- Open selected Finder files/folders.
- Direct local path opening.
- Direct web opening without requiring `https://`.

### Utility

- F4 → Shottr.

---

## 21. Known limitations

- Browser bookmark search is not implemented.
- Browser history search is not implemented as a dedicated provider.
- Finder search currently covers the immediate contents of the current Finder folder rather than recursively indexing an entire filesystem.
- Dia Tab+Q move-to-new-window handling is not implemented.
- Native menu availability depends on the application's Accessibility exposure.
- Chromium-based applications other than Chrome may require separate bundle/application handling.
- Generic web fallback deliberately favors convenience over domain validation.
- The project remains experimental and is not a drop-in replacement for the Vimium browser extension.

---

## 22. Files and locations

Repository configuration files:

```text
config/karabiner/assets/complex_modifications/vimium-macos.json
config/hammerspoon/init.lua
```

Typical installed locations on macOS:

```text
~/.config/karabiner/assets/complex_modifications/vimium-macos.json
~/.hammerspoon/init.lua
```

The repository intentionally keeps the Karabiner configuration as one JSON ruleset rather than splitting mappings into separate scripts.

---

## 23. Development principle going forward

When a feature is added or rejected, record the decision here with:

1. What was tried.
2. What happened.
3. Why the approach was accepted or rejected.
4. What implementation is now authoritative.
5. What future work remains.

This file is meant to prevent rediscovering old dead ends.
