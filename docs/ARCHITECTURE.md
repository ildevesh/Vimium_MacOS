# Architecture

```text
Keyboard
   |
   v
Karabiner-Elements
   |
   +-- text input focused? --> normal typing
   |
   +-- Vim mode -----------> global keyboard layer
   |
   +-- Super+Space --------> F16
   |
   +-- Tab+Q --------------> F18
                               |
                               v
                           Hammerspoon
                               |
                    +----------+----------+
                    |                     |
               Command palette       Tab actions
                    |
          Application menus / Finder
```

## Karabiner

- Global keyboard interception.
- Master Vim-mode state.
- Text-field protection.
- Scroll events.
- Browser/application mappings.
- Routes special actions to Hammerspoon through F16/F18.

## Hammerspoon

- Move-tab actions for supported apps.
- Shottr launcher.
- Native application menu discovery.
- Command palette.
- Generic keyboard fallback commands.
- Finder current-folder search/open.

## Palette ranking

Empty query: commands only.

Typed query: matching commands first, then Finder file/folder results when Finder
is frontmost.

Future bookmark/history providers can be added as additional result sources.


## Direct URL/path opening

When a typed query is not resolved by a command or Finder result, the palette
first checks existing local paths. When a typed query is not resolved by a
command, Finder result, or existing local path, non-local input is treated as a
web target and passed to macOS `/usr/bin/open` using the default browser.
Explicit URL schemes such as `http://` and `https://` are preserved.
