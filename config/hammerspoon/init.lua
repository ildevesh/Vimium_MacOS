--------------------------------------------------
-- Vimium macOS - Hammerspoon
--------------------------------------------------

--------------------------------------------------
-- TAB + Q → Move Tab to New Window
--------------------------------------------------

local function moveTabToNewWindow()
    local app = hs.application.frontmostApplication()

    if not app then
        return
    end

    local bundleID = app:bundleID()

    -- Safari
    if bundleID == "com.apple.Safari" then
        local ok = app:selectMenuItem({
            "Window",
            "Move Tab to New Window"
        })

        if not ok then
            hs.alert.show("Safari: Move Tab command not found")
        end

        return
    end

    -- Google Chrome
    if bundleID == "com.google.Chrome" then
        local labels = {
            "Move Tab to New Window",
            "Move tab to new window"
        }

        for _, label in ipairs(labels) do
            if app:selectMenuItem(label) then
                return
            end
        end

        hs.alert.show("Chrome: Move Tab command not found")
        return
    end

    -- Dia
    if bundleID == "company.thebrowser.dia" then
        hs.alert.show("Dia: not implemented")
        return
    end

    hs.alert.show("Unsupported: " .. app:name())
end

hs.hotkey.bind({}, "f18", moveTabToNewWindow)


--------------------------------------------------
-- F4 → Shottr
--------------------------------------------------

hs.hotkey.bind({}, "f4", function()
    hs.application.launchOrFocus("Shottr")
end)


--------------------------------------------------
-- COMMAND PALETTE
-- Super + Space → F16
--------------------------------------------------

local commandPalette = nil
local activeApp = nil
local baseChoices = {}
local finderFileChoices = {}


--------------------------------------------------
-- Common commands
--------------------------------------------------

local function getCommonCommands(app)

    local commands = {}

    local function add(title, subtitle, modifiers, key)
        table.insert(commands, {
            text = title,
            subText = subtitle,
            kind = "key",
            modifiers = modifiers,
            key = key
        })
    end

    --------------------------------------------------
    -- Universal macOS commands
    --------------------------------------------------

    add("New Window", "Common  •  Command + N",
        {"cmd"}, "n")

    add("Close Window / Tab", "Common  •  Command + W",
        {"cmd"}, "w")

    add("Save", "Common  •  Command + S",
        {"cmd"}, "s")

    add("Copy", "Common  •  Command + C",
        {"cmd"}, "c")

    add("Paste", "Common  •  Command + V",
        {"cmd"}, "v")

    add("Cut", "Common  •  Command + X",
        {"cmd"}, "x")

    add("Select All", "Common  •  Command + A",
        {"cmd"}, "a")

    add("Undo", "Common  •  Command + Z",
        {"cmd"}, "z")

    add("Redo", "Common  •  Command + Shift + Z",
        {"cmd", "shift"}, "z")

    add("Find", "Common  •  Command + F",
        {"cmd"}, "f")

    add("Hide Application", "Common  •  Command + H",
        {"cmd"}, "h")

    add("Quit Application", "Common  •  Command + Q",
        {"cmd"}, "q")


    --------------------------------------------------
    -- Browser commands
    --------------------------------------------------

    local browserBundles = {
        ["com.apple.Safari"] = true,
        ["com.google.Chrome"] = true,
        ["org.chromium.Chromium"] = true,
        ["company.thebrowser.dia"] = true
    }

    if browserBundles[app:bundleID()] then

        add("New Tab",
            "Browser  •  Command + T",
            {"cmd"}, "t")

        add("Reload",
            "Browser  •  Command + R",
            {"cmd"}, "r")

        add("Back",
            "Browser  •  Command + [",
            {"cmd"}, "[")

        add("Forward",
            "Browser  •  Command + ]",
            {"cmd"}, "]")

        add("Focus Address Bar",
            "Browser  •  Command + L",
            {"cmd"}, "l")

        add("Zoom In",
            "Browser  •  Command + +",
            {"cmd"}, "=")

        add("Zoom Out",
            "Browser  •  Command + -",
            {"cmd"}, "-")

        add("Reset Zoom",
            "Browser  •  Command + 0",
            {"cmd"}, "0")
    end

    return commands
end


--------------------------------------------------
-- Native application menu parser
--------------------------------------------------

local function collectMenuItems(items, parentPath, results)

    if type(items) ~= "table" then
        return
    end

    for _, item in ipairs(items) do

        if type(item) ~= "table" then
            goto continue
        end

        local title = item.AXTitle
        local role = item.AXRole
        local enabled = item.AXEnabled

        local currentPath = {}

        for _, parent in ipairs(parentPath) do
            table.insert(currentPath, parent)
        end

        if title and title ~= "" then
            table.insert(currentPath, title)
        end

        local rootMenu = currentPath[1]

        -- Don't put bookmark/history entries in the initial list.
        local ignored =
            rootMenu == "Bookmarks"
            or rootMenu == "History"

        if not ignored then

            -- Submenu
            if type(item.AXChildren) == "table"
                and type(item.AXChildren[1]) == "table"
            then

                collectMenuItems(
                    item.AXChildren[1],
                    currentPath,
                    results
                )

            -- Actual executable menu item
            elseif role == "AXMenuItem"
                and title
                and title ~= ""
                and enabled ~= false
                and enabled ~= 0
            then

                table.insert(results, {
                    text = title,
                    subText = table.concat(
                        currentPath,
                        "  ›  "
                    ),
                    kind = "menu",
                    path = currentPath
                })
            end
        end

        ::continue::
    end
end


--------------------------------------------------
-- Finder: current folder
--------------------------------------------------

local function getFinderCurrentFolder()

    local ok, result =
        hs.osascript.applescript([[
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
]])

    if ok
        and type(result) == "string"
        and result ~= ""
    then
        return result
    end

    return nil
end


--------------------------------------------------
-- Finder: enumerate ALL items
--
-- Uses the exact AppleScript operation that we
-- already confirmed returns all 650 items.
--------------------------------------------------

local function getFinderFileChoices()

    local results = {}

    local folder =
        getFinderCurrentFolder()

    if not folder then
        return results
    end


    local ok, names =
        hs.osascript.applescript([[
tell application "Finder"
    set theFolder to target of front Finder window
    return name of every item of theFolder
end tell
]])


    if not ok
        or type(names) ~= "table"
    then
        return results
    end


    --------------------------------------------------
    -- Create a palette item for every Finder item.
    --------------------------------------------------

    for _, name in ipairs(names) do

        if type(name) == "string"
            and name ~= ""
            and name:sub(1, 1) ~= "."
        then

            table.insert(
                results,
                {
                    text = name,

                    subText =
                        "Finder  •  "
                        .. folder,

                    kind = "finder_file",

                    path =
                        folder .. name
                }
            )
        end
    end


    table.sort(
        results,
        function(a, b)
            return a.text:lower()
                < b.text:lower()
        end
    )


    return results
end


--------------------------------------------------
-- Deduplicate choices
--------------------------------------------------

local function deduplicateChoices(choices)

    local seen = {}
    local result = {}

    for _, choice in ipairs(choices) do

        local key =
            tostring(choice.text or "")
            .. "\0"
            .. tostring(choice.subText or "")

        if not seen[key] then

            seen[key] = true

            table.insert(
                result,
                choice
            )
        end
    end

    return result
end


--------------------------------------------------
-- Safely quote a shell path
--------------------------------------------------

local function shellQuote(path)

    return "'"
        .. path:gsub(
            "'",
            "'\\''"
        )
        .. "'"
end


--------------------------------------------------
-- Direct URL / File / Folder input
--------------------------------------------------

local function trim(value)
    return tostring(value or "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
end


local function isWebTarget(query)

    local q = trim(query)

    if q == "" then
        return false
    end

    -- Explicit URL with a scheme, e.g.:
    -- https://example.com
    -- http://example.com
    -- ftp://example.com
    if q:match("^[%a][%w+%-%.]*://") then
        return true
    end

    -- Everything that is not an explicitly local filesystem target
    -- is treated as a website and opened with the default browser.
    -- This means there is NO domain/TLD whitelist.
    return not q:match("^/")
        and not q:match("^~/")
        and not q:match("^file://")
end


local function normalizeWebTarget(query)
    local q = trim(query)

    if q:match("^[%a][%w+%-%.]*://") then
        return q
    end

    return "https://" .. q
end


local function pathExists(path)
    if not path then
        return false
    end

    local ok, attrs =
        pcall(hs.fs.attributes, path)

    return ok and attrs ~= nil
end


local function getDirectPathTarget(query)

    local q = trim(query)

    if q == "" then
        return nil
    end

    -- file:///...
    if q:match("^file://") then
        return q:sub(8)
    end

    -- ~/...
    if q:sub(1, 2) == "~/" then
        q = (os.getenv("HOME") or "~") .. q:sub(2)
    end

    -- Absolute path
    if q:sub(1, 1) == "/" then
        return q
    end

    -- Finder-relative path:
    -- e.g. MHRM/report.pdf
    if activeApp
        and activeApp:bundleID() == "com.apple.finder"
    then

        local folder =
            getFinderCurrentFolder()

        if folder and q:find("/", 1, true) then
            return folder .. q
        end
    end

    return nil
end


local function getOpenTargetChoice(query)

    local q = trim(query)

    if q == "" then
        return nil
    end

    --------------------------------------------------
    -- File / folder path gets priority over web input.
    --------------------------------------------------

    local path =
        getDirectPathTarget(q)

    if path and pathExists(path) then
        return {
            text = "Open " .. q,
            subText = "File / Folder  •  " .. path,
            kind = "open_target",
            target = path
        }
    end

    -- Explicit local path that does not exist:
    -- don't turn it into https://...
    if q:match("^/")
        or q:match("^~/")
        or q:match("^file://")
    then
        return nil
    end

    --------------------------------------------------
    -- Website fallback.
    -- There is intentionally NO domain/TLD whitelist.
    -- Any non-empty non-local input is treated as a web
    -- target and opened by the default browser.
    --------------------------------------------------

    if isWebTarget(q) then
        return {
            text = "Open " .. q,
            subText = "Web  •  Open in default browser",
            kind = "open_target",
            target = normalizeWebTarget(q)
        }
    end

    return nil
end

local function executeChoice(choice)

    if not choice then
        return
    end


    --------------------------------------------------
    -- Native menu command
    --------------------------------------------------

    if choice.kind == "menu" then

        local success =
            activeApp:selectMenuItem(
                choice.path
            )

        if not success then

            hs.alert.show(
                "Could not execute: "
                .. choice.text
            )
        end

        return
    end


    --------------------------------------------------
    -- Direct URL / file / folder
    --------------------------------------------------

    if choice.kind == "open_target" then

        local target = choice.target

        local command =
            "/usr/bin/open "
            .. shellQuote(target)

        hs.timer.doAfter(
            0.05,
            function()
                hs.execute(command)
            end
        )

        return
    end


    --------------------------------------------------
    -- Generic keyboard command
    --------------------------------------------------

    if choice.kind == "key" then

        hs.timer.doAfter(
            0.05,
            function()

                hs.eventtap.keyStroke(
                    choice.modifiers,
                    choice.key
                )
            end
        )

        return
    end


    --------------------------------------------------
    -- Finder file/folder
    --------------------------------------------------

    if choice.kind == "finder_file" then

        local path =
            choice.path

        local command =
            "/usr/bin/open "
            .. shellQuote(path)


        hs.timer.doAfter(
            0.05,
            function()
                hs.execute(command)
            end
        )

        return
    end
end


--------------------------------------------------
-- COMMAND PALETTE
--------------------------------------------------

local function showCommandPalette()

    --------------------------------------------------
    -- Toggle off
    --------------------------------------------------

    if commandPalette
        and commandPalette:isVisible()
    then

        commandPalette:cancel()
        commandPalette = nil

        return
    end


    --------------------------------------------------
    -- Get the TRUE frontmost application
    --------------------------------------------------

    local app =
        hs.application.frontmostApplication()

    if not app then
        return
    end


    activeApp = app


    --------------------------------------------------
    -- Finder items
    --------------------------------------------------

    finderFileChoices = {}

    if app:bundleID()
        == "com.apple.finder"
    then

        finderFileChoices =
            getFinderFileChoices()
    end


    --------------------------------------------------
    -- Generic commands
    --------------------------------------------------

    local commonCommands =
        getCommonCommands(app)


    --------------------------------------------------
    -- Native application commands
    --------------------------------------------------

    app:getMenuItems(
        function(menuItems)

            local nativeChoices = {}


            if menuItems then

                collectMenuItems(
                    menuItems,
                    {},
                    nativeChoices
                )
            end


            --------------------------------------------------
            -- Existing native commands
            --------------------------------------------------

            local existing = {}

            for _, choice in
                ipairs(nativeChoices)
            do

                existing[
                    choice.text:lower()
                ] = true
            end


            --------------------------------------------------
            -- Add common fallback commands
            --------------------------------------------------

            for _, choice in
                ipairs(commonCommands)
            do

                if not existing[
                    choice.text:lower()
                ] then

                    table.insert(
                        nativeChoices,
                        choice
                    )
                end
            end


            if #nativeChoices == 0 then
                nativeChoices =
                    commonCommands
            end


            --------------------------------------------------
            -- Sort commands
            --------------------------------------------------

            baseChoices =
                deduplicateChoices(
                    nativeChoices
                )


            table.sort(
                baseChoices,
                function(a, b)

                    return
                        a.text:lower()
                        <
                        b.text:lower()

                end
            )


            --------------------------------------------------
            -- Create chooser
            --------------------------------------------------

            commandPalette =
                hs.chooser.new(
                    function(choice)

                        if not choice then

                            commandPalette =
                                nil

                            return
                        end


                        executeChoice(
                            choice
                        )


                        commandPalette =
                            nil
                    end
                )


            --------------------------------------------------
            -- Dynamic search
            --------------------------------------------------

            commandPalette:
                queryChangedCallback(
                    function(query)

                        query =
                            tostring(
                                query or ""
                            )


                        --------------------------------------------------
                        -- No query:
                        -- show commands only
                        --------------------------------------------------

                        if query == "" then
                            commandPalette:
                                choices(
                                    baseChoices
                                )

                            return
                        end


                        local search =
                            query:lower()

                        local filtered = {}


                        --------------------------------------------------
                        -- Search commands
                        --------------------------------------------------

                        for _, choice in
                            ipairs(baseChoices)
                        do

                            local title =
                                tostring(
                                    choice.text or ""
                                ):lower()

                            local subtitle =
                                tostring(
                                    choice.subText or ""
                                ):lower()


                            if title:find(
                                search,
                                1,
                                true
                            )
                            or subtitle:find(
                                search,
                                1,
                                true
                            )
                            then

                                table.insert(
                                    filtered,
                                    choice
                                )
                            end
                        end


                   --------------------------------------------------
-- Search Finder items
--
-- IMPORTANT:
-- Commands remain FIRST.
-- Finder files/folders are appended AFTER commands.
--------------------------------------------------

if activeApp
    and activeApp:bundleID()
        == "com.apple.finder"
then

    local finderMatches = {}

    for _, item in
        ipairs(finderFileChoices)
    do

        local name =
            item.text:lower()

        if name:find(
            search,
            1,
            true
        )
        then

            table.insert(
                finderMatches,
                item
            )
        end
    end


    --------------------------------------------------
    -- Append Finder results AFTER command results
    --------------------------------------------------

    for _, item in
        ipairs(finderMatches)
    do

        table.insert(
            filtered,
            item
        )
    end
end

                        --------------------------------------------------
                        -- Direct URL / file / folder fallback
                        --
                        -- Priority:
                        -- 1. Matching commands
                        -- 2. Matching Finder items
                        -- 3. Direct URL / path fallback
                        --------------------------------------------------

                        local openTarget =
                            getOpenTargetChoice(query)

                        if openTarget then
                            table.insert(
                                filtered,
                                openTarget
                            )
                        end

                        commandPalette:
                            choices(
                                deduplicateChoices(
                                    filtered
                                )
                            )
                    end
                )


            --------------------------------------------------
            -- UI
            --------------------------------------------------

            commandPalette
                :bgDark(true)

                :fgColor({
                    red = 0.96,
                    green = 0.96,
                    blue = 0.98,
                    alpha = 1
                })

                :subTextColor({
                    red = 0.55,
                    green = 0.56,
                    blue = 0.60,
                    alpha = 1
                })

                :placeholderText(
                    "Search Commands"
                )

                :rows(8)

                :width(40)

                :searchSubText(true)

                :choices(
                    baseChoices
                )


            commandPalette:show()
        end
    )
end


--------------------------------------------------
-- Super + Space → F16
--------------------------------------------------

hs.hotkey.bind(
    {},
    "f16",
    showCommandPalette
)
