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
local browserBookmarkChoices = {}
local browserHistoryChoices = {}


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
-- Browser history / bookmarks
--------------------------------------------------

local function getSupportedBrowserBundleID(app)
    if not app then
        return nil
    end

    local bundleID = app:bundleID()

    local supported = {
        ["com.apple.Safari"] = true,
        ["com.google.Chrome"] = true,
        ["org.chromium.Chromium"] = true,
        ["company.thebrowser.dia"] = true
    }

    if supported[bundleID] then
        return bundleID
    end

    return nil
end


local function getBrowserName(bundleID)
    local names = {
        ["com.apple.Safari"] = "Safari",
        ["com.google.Chrome"] = "Chrome",
        ["org.chromium.Chromium"] = "Chromium",
        ["company.thebrowser.dia"] = "Dia"
    }

    return names[bundleID] or "Browser"
end


local function getBrowserProfileFiles(bundleID)
    local profiles = {}

    --------------------------------------------------
    -- Safari
    --------------------------------------------------

    if bundleID == "com.apple.Safari" then
        table.insert(
            profiles,
            {
                name = "Safari",
                bookmarks =
                    (os.getenv("HOME") or "") ..
                    "/Library/Safari/Bookmarks.plist",
                history =
                    (os.getenv("HOME") or "") ..
                    "/Library/Safari/History.db"
            }
        )

        return profiles
    end


    --------------------------------------------------
    -- Chromium-based browsers
    --------------------------------------------------

    local basePaths = {
        ["com.google.Chrome"] =
            (os.getenv("HOME") or "") ..
            "/Library/Application Support/Google/Chrome",

        ["org.chromium.Chromium"] =
            (os.getenv("HOME") or "") ..
            "/Library/Application Support/Chromium",

        ["company.thebrowser.dia"] =
            (os.getenv("HOME") or "") ..
            "/Library/Application Support/Dia/User Data"
    }

    local basePath = basePaths[bundleID]

    if not basePath then
        return profiles
    end


    --------------------------------------------------
    -- Discover Default / Profile N directories.
    -- This avoids assuming that the user only has
    -- one browser profile.
    --------------------------------------------------

    local output =
        hs.execute(
            "/usr/bin/find "
            .. shellQuote(basePath)
            .. " -maxdepth 2 -type f "
            .. "\\( -name Bookmarks -o -name History \\) "
            .. "-print 2>/dev/null"
        )


    local byProfile = {}

    for path in tostring(output or ""):gmatch("[^\r\n]+") do
        local profileName =
            path:match("/([^/]+)/Bookmarks$")
            or path:match("/([^/]+)/History$")

        if profileName then
            if not byProfile[profileName] then
                byProfile[profileName] = {
                    name = profileName
                }
            end

            if path:match("/Bookmarks$") then
                byProfile[profileName].bookmarks = path
            elseif path:match("/History$") then
                byProfile[profileName].history = path
            end
        end
    end


    for profileName, profile in pairs(byProfile) do
        table.insert(profiles, profile)
    end


    table.sort(
        profiles,
        function(a, b)
            return a.name:lower() < b.name:lower()
        end
    )


    return profiles
end


local function decodeBrowserJSON(path, plistMode)
    if not path then
        return nil
    end

    local command

    if plistMode then
        command =
            "/usr/bin/plutil -convert json -o - -- "
            .. shellQuote(path)
            .. " 2>/dev/null"
    else
        command =
            "/bin/cat "
            .. shellQuote(path)
            .. " 2>/dev/null"
    end

    local output =
        hs.execute(command)

    if not output or output == "" then
        return nil
    end

    local ok, decoded =
        pcall(
            hs.json.decode,
            output
        )

    if ok and type(decoded) == "table" then
        return decoded
    end

    return nil
end


local function addBrowserBookmark(
    results,
    bundleID,
    profileName,
    title,
    url,
    folderPath
)

    if type(url) ~= "string"
        or url == ""
    then
        return
    end

    title =
        tostring(title or ""):gsub(
            "[\r\n\t]+",
            " "
        )

    if title == "" then
        title = url
    end

    local browserName =
        getBrowserName(bundleID)

    local location = folderPath

    if location == nil
        or location == ""
    then
        location = profileName
    elseif profileName
        and profileName ~= ""
    then
        location =
            profileName
            .. "  •  "
            .. location
    end

    local subText =
        browserName
        .. "  •  Bookmark"

    if location and location ~= "" then
        subText =
            subText
            .. "  •  "
            .. location
    end

    subText =
        subText
        .. "  •  "
        .. url

    table.insert(
        results,
        {
            text = title,
            subText = subText,
            kind = "browser_link",
            target = url,
            browserBundleID = bundleID
        }
    )
end


local function collectBrowserBookmarkNodes(
    node,
    folderPath,
    results,
    bundleID,
    profileName,
    limit
)

    if #results >= limit
        or type(node) ~= "table"
    then
        return
    end

    --------------------------------------------------
    -- Chromium bookmark format
    -- type = "url", name, url
    --
    -- Safari WebBookmark format
    -- URLString, Title, Children
    --------------------------------------------------

    local url =
        node.url
        or node.URLString

    local title =
        node.name
        or node.Title
        or node.title

    if type(url) == "string"
        and url ~= ""
    then
        addBrowserBookmark(
            results,
            bundleID,
            profileName,
            title,
            url,
            folderPath
        )
    end


    local children =
        node.children
        or node.Children

    if type(children) ~= "table" then
        return
    end


    local nextFolder =
        folderPath

    local folderName =
        node.name
        or node.Title
        or node.title

    local nodeType =
        node.type
        or node.WebBookmarkType


    if folderName
        and folderName ~= ""
        and nodeType ~= "url"
    then
        if nextFolder
            and nextFolder ~= ""
        then
            nextFolder =
                nextFolder
                .. "  ›  "
                .. tostring(folderName)
        else
            nextFolder =
                tostring(folderName)
        end
    end


    for _, child in ipairs(children) do
        collectBrowserBookmarkNodes(
            child,
            nextFolder,
            results,
            bundleID,
            profileName,
            limit
        )

        if #results >= limit then
            return
        end
    end
end


local function loadBrowserBookmarks(
    bundleID,
    profile
)

    local results = {}

    if not profile
        or not profile.bookmarks
    then
        return results
    end


    local plistMode =
        bundleID == "com.apple.Safari"

    local data =
        decodeBrowserJSON(
            profile.bookmarks,
            plistMode
        )

    if not data then
        return results
    end


    local roots =
        data.roots

    if type(roots) == "table" then
        for _, root in pairs(roots) do
            collectBrowserBookmarkNodes(
                root,
                "",
                results,
                bundleID,
                profile.name,
                1000
            )

            if #results >= 1000 then
                break
            end
        end

        return results
    end


    --------------------------------------------------
    -- Safari's plist structure uses Children.
    --------------------------------------------------

    if type(data.Children) == "table" then
        collectBrowserBookmarkNodes(
            data,
            "",
            results,
            bundleID,
            profile.name,
            1000
        )

        return results
    end


    --------------------------------------------------
    -- Generic fallback.
    --------------------------------------------------

    collectBrowserBookmarkNodes(
        data,
        "",
        results,
        bundleID,
        profile.name,
        1000
    )

    return results
end


local function runBrowserSQLiteJSON(
    databasePath,
    query
)

    if not databasePath
        or not query
    then
        return nil
    end

    local command =
        "/usr/bin/sqlite3 -readonly -json "
        .. shellQuote(databasePath)
        .. " "
        .. shellQuote(query)
        .. " 2>/dev/null"

    local output =
        hs.execute(command)

    if not output or output == "" then
        return nil
    end

    local ok, decoded =
        pcall(
            hs.json.decode,
            output
        )

    if ok and type(decoded) == "table" then
        return decoded
    end

    return nil
end


local function addBrowserHistory(
    results,
    bundleID,
    profileName,
    title,
    url
)

    if type(url) ~= "string"
        or url == ""
    then
        return
    end

    title =
        tostring(title or ""):gsub(
            "[\r\n\t]+",
            " "
        )

    if title == "" then
        title = url
    end

    local browserName =
        getBrowserName(bundleID)

    local subText =
        browserName
        .. "  •  History"

    if profileName
        and profileName ~= ""
    then
        subText =
            subText
            .. "  •  "
            .. profileName
    end

    subText =
        subText
        .. "  •  "
        .. url

    table.insert(
        results,
        {
            text = title,
            subText = subText,
            kind = "browser_link",
            target = url,
            browserBundleID = bundleID
        }
    )
end


local function loadBrowserHistory(
    bundleID,
    profile
)

    local results = {}

    if not profile
        or not profile.history
    then
        return results
    end


    local rows


    --------------------------------------------------
    -- Safari History.db
    --------------------------------------------------

    if bundleID == "com.apple.Safari" then
        rows =
            runBrowserSQLiteJSON(
                profile.history,
                [[
                    SELECT
                        COALESCE(
                            history_visits.title,
                            ''
                        ) AS title,
                        history_items.url AS url,
                        MAX(
                            history_visits.visit_time
                        ) AS last_visit
                    FROM history_items
                    LEFT JOIN history_visits
                        ON history_items.id =
                           history_visits.history_item
                    WHERE history_items.url IS NOT NULL
                    GROUP BY history_items.id
                    ORDER BY last_visit DESC
                    LIMIT 2000;
                ]]
            )

    else
        --------------------------------------------------
        -- Chromium History database.
        --------------------------------------------------

        rows =
            runBrowserSQLiteJSON(
                profile.history,
                [[
                    SELECT
                        COALESCE(title, '') AS title,
                        url,
                        last_visit_time AS last_visit
                    FROM urls
                    WHERE url IS NOT NULL
                      AND url != ''
                    ORDER BY last_visit_time DESC
                    LIMIT 2000;
                ]]
            )
    end


    if type(rows) ~= "table" then
        return results
    end


    for _, row in ipairs(rows) do
        addBrowserHistory(
            results,
            bundleID,
            profile.name,
            row.title,
            row.url
        )
    end


    return results
end


local function loadBrowserSearchChoices(app)
    local bookmarks = {}
    local history = {}

    local bundleID =
        getSupportedBrowserBundleID(app)

    if not bundleID then
        return bookmarks, history
    end


    local profiles =
        getBrowserProfileFiles(bundleID)

    for _, profile in ipairs(profiles) do

        local profileBookmarks =
            loadBrowserBookmarks(
                bundleID,
                profile
            )

        for _, choice in ipairs(profileBookmarks) do
            table.insert(
                bookmarks,
                choice
            )
        end


        local profileHistory =
            loadBrowserHistory(
                bundleID,
                profile
            )

        for _, choice in ipairs(profileHistory) do
            table.insert(
                history,
                choice
            )
        end
    end


    table.sort(
        bookmarks,
        function(a, b)
            return a.text:lower()
                < b.text:lower()
        end
    )


    return bookmarks, history
end


local function browserChoiceMatches(
    choice,
    search
)

    local title =
        tostring(
            choice.text or ""
        ):lower()

    local subtitle =
        tostring(
            choice.subText or ""
        ):lower()

    return title:find(
        search,
        1,
        true
    ) ~= nil

        or subtitle:find(
            search,
            1,
            true
        ) ~= nil
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
    -- Browser history / bookmark
    --------------------------------------------------

    if choice.kind == "browser_link" then

        local target =
            choice.target

        local bundleID =
            choice.browserBundleID

        if target
            and bundleID
        then

            local command =
                "/usr/bin/open -b "
                .. shellQuote(bundleID)
                .. " "
                .. shellQuote(target)

            hs.timer.doAfter(
                0.05,
                function()
                    hs.execute(command)
                end
            )
        end

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
    -- Browser bookmarks / history
    --------------------------------------------------

    browserBookmarkChoices = {}
    browserHistoryChoices = {}

    if getSupportedBrowserBundleID(app) then
        browserBookmarkChoices,
        browserHistoryChoices =
            loadBrowserSearchChoices(app)
    end


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
                        -- Search browser bookmarks/history
                        --
                        -- Commands remain first.
                        -- Browser bookmarks/history come next.
                        -- Finder results are unaffected because
                        -- this block only runs for browser apps.
                        --------------------------------------------------

                        if getSupportedBrowserBundleID(activeApp) then

                            for _, choice in
                                ipairs(browserBookmarkChoices)
                            do

                                if browserChoiceMatches(
                                    choice,
                                    search
                                )
                                then

                                    table.insert(
                                        filtered,
                                        choice
                                    )
                                end
                            end


                            for _, choice in
                                ipairs(browserHistoryChoices)
                            do

                                if browserChoiceMatches(
                                    choice,
                                    search
                                )
                                then

                                    table.insert(
                                        filtered,
                                        choice
                                    )
                                end
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
