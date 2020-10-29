------ CONSTANTS
TAPPEDOUT_BASE_URL = "https://tappedout.net/mtg-decks/"
TAPPEDOUT_URL_SUFFIX = "/"
TAPPEDOUT_URL_MATCH = "tappedout%.net"

ARCHIDEKT_BASE_URL = "https://archidekt.com/api/decks/"
ARCHIDEKT_URL_SUFFIX = "/small/"
ARCHIDEKT_URL_MATCH = "archidekt%.com"

GOLDFISH_URL_MATCH = "mtggoldfish%.com"

MOXFIELD_BASE_URL = "https://api.moxfield.com/v2/decks/all/"
MOXFIELD_URL_SUFFIX = "/"
MOXFIELD_URL_MATCH = "moxfield%.com"

SCRYFALL_ID_BASE_URL = "https://api.scryfall.com/cards/"
SCRYFALL_MULTIVERSE_BASE_URL = "https://api.scryfall.com/cards/multiverse/"
SCRYFALL_SET_NUM_BASE_URL = "https://api.scryfall.com/cards/"
SCRYFALL_SEARCH_BASE_URL = "https://api.scryfall.com/cards/search/?q="
SCRYFALL_NAME_BASE_URL = "https://api.scryfall.com/cards/named/?exact="

DECK_SOURCE_URL = "url"
DECK_SOURCE_NOTEBOOK = "notebook"

MAINDECK_POSITION_OFFSET = {0.0, 0.2, 0.1286}
DOUBLEFACE_POSITION_OFFSET = {1.47, 0.2, 0.1286}
SIDEBOARD_POSITION_OFFSET = {-1.47, 0.2, 0.1286}
COMMANDER_POSITION_OFFSET = {0.7286, 0.2, -0.8257}
TOKENS_POSITION_OFFSET = {-0.7286, 0.2, -0.8257}

DEFAULT_CARDBACK = "https://gamepedia.cursecdn.com/mtgsalvation_gamepedia/f/f8/Magic_card_back.jpg?version=0ddc8d41c3b69c2c3c4bb5d72669ffd7"

------ GLOBAL STATE
lock = false
playerColor = nil
deckSource = nil

------ UTILITY
local function trim(s)
    local n = s:find"%S"
    return n and s:match(".*%S", n) or ""
end

local function iterateLines(s)
    if not s or string.len(s) == 0 then
        return ipairs({})
    end

    if string.sub(s, -1) ~= '\n' then
        s = s .. '\n'
    end

    local success, line = pcall(function() return string.gmatch(s, "(.-)\n") end)

    if success then
        return line
    else
        return ipairs({})
    end
end

local function readNotebookForColor(playerColor)
    for i, tab in ipairs(Notes.getNotebookTabs()) do
        if tab.title == playerColor and tab.color == playerColor then
            return tab.body
        end
    end

    return nil
end

local function vecSum(v1, v2)
    return {v1[1] + v2[1], v1[2] + v2[2], v1[3] + v2[3]}
end

local function vecMult(v, s)
    return {v[1] * s, v[2] * s, v[3] * s}
end

local function valInTable(table, v)
    for _, value in ipairs(table) do
        if value == v then
            return true
        end
    end

    return false
end

local function printErr(s)
    printToColor(s, playerColor, {r=1, g=0, b=0})
end

local function printInfo(s)
    printToColor(s, playerColor)
end

------ CARD SPAWNING

-- Spawns the given card [face] at [position].
-- Card will be face down if [flipped].
-- Calls [onFullySpawned] when the object is spawned.
local function spawnCard(face, position, flipped, onFullySpawned)
    local rotation
    if flipped then
        rotation = vecSum(self.getRotation(), {0, 0, 180})
    else
        rotation = self.getRotation()
    end

    return spawnObject({
        type = "Card",
        sound = false,
        rotation = rotation,
        position = position,
        scale = vecMult(self.getScale(), (1 / 3.5)),
        callback_function = (function(obj)
            obj.setName(face.name)
            obj.setDescription(face.oracleText)
            obj.setCustomObject({
                face = face.imageURI,
                back = getCardBackInputValue()
            })
            onFullySpawned(obj)
        end)
    })
end

-- Spawns a deck named [name] containing the given [cards] at [position].
-- Deck will be face down if [flipped].
-- Calls [onFullySpawned] when the object is spawned.
local function spawnDeck(cards, name, position, flipped, onFullySpawned, onError)
    local cardObjects = {}

    local sem = 0
    local function incSem() sem = sem + 1 end
    local function decSem() sem = sem - 1 end

    for _, card in ipairs(cards) do
        for i=1,(card.count or 1) do
            if not card.faces or not card.faces[1] then
                card.faces = {{
                    name = card.name,
                    oracleText = "Card not found",
                    imageURI = "https://vignette.wikia.nocookie.net/yugioh/images/9/94/Back-Anime-2.png/revision/latest?cb=20110624090942",
                }}
            end

            for _, face in ipairs(card.faces) do
                incSem()
                spawnCard(face, position, flipped, function(obj)
                    table.insert(cardObjects, obj)
                    decSem()
                end)
            end
        end
    end

    Wait.condition(
        function()
            local deckObject

            if cardObjects[1] and cardObjects[2] then
                deckObject = cardObjects[1].putObject(cardObjects[2])
                if success and deckObject then
                    deckObject.setPosition(position)
                    deckObject.setName(name)
                else
                    deckObject = cardObjects[1]
                end
            else
                deckObject = cardObjects[1]
            end

            onFullySpawned(deckObject)
        end,
        function() return (sem == 0) end,
        5,
        function() onError("Error collating deck... timed out.") end
    )
end

------ SCRYFALL
local function stripScryfallImageURI(uri)
    if not uri or string.len(uri) == 0 then
        return ""
    end

    return uri:match("(.*)%?") or ""
end

-- Parses scryfall reseponse data for a card.
-- Returns a populated card table, a list of tokens, and an error if occured.
local function parseCardData(cardID, data)
    local tokens = {}
    if data.all_parts and not (data.layout == "token") then
        for _, part in ipairs(data.all_parts) do
            if part.component and part.component == "token" then
                table.insert(tokens, {
                    name = part.name,
                    scryfallID = part.id,
                })
            end
        end
    end

    local card = cardID
    card.name = data.name
    card.faces = {}
    card.scryfallID = data.id

    if data.layout == "transform" or data.layout == "art_series" or data.layout == "double_sided" or data.layout == "modal_dfc" then
        for i, face in ipairs(data.card_faces) do
            card['faces'][i] = {
                name = face.name,
                imageURI = stripScryfallImageURI(face.image_uris.normal),
                oracleText = face.oracle_text,
            }
        end
        card['doubleface'] = true
    elseif data.layout == "double_faced_token" then
        for i, face in ipairs(data.card_faces) do
            card['faces'][i] = {
                name = face.name,
                imageURI = stripScryfallImageURI(face.image_uris.normal),
                oracleText = face.oracle_text,
            }
        end
        card['doubleface'] = false -- Not putting double-face tokens in double-face cards pile
    else
        card['faces'][1] = {
            name = data.name,
            imageURI = stripScryfallImageURI(data.image_uris.normal),
            oracleText = data.oracle_text,
        }
        card['doubleface'] = false
    end

    return card, tokens, nil
end

-- Queries scryfall by the [cardID].
-- cardID must define at least one of scryfallID, multiverseID, or name.
-- if forceNameQuery is true, will query scryfall by card name ignoring other data.
-- onSuccess is called with a populated card table, and a table of associated token cardIDs.
local function queryCard(cardID, forceNameQuery, onSuccess, onError)
    local query_url

    if forceNameQuery then
        query_url = SCRYFALL_NAME_BASE_URL .. cardID.name
    elseif cardID.scryfallID and string.len(cardID.scryfallID) > 0 then
        query_url = SCRYFALL_ID_BASE_URL .. cardID.scryfallID
    elseif cardID.multiverseID and string.len(cardID.multiverseID) > 0 then
        query_url = SCRYFALL_MULTIVERSE_BASE_URL .. cardID.multiverseID
    elseif cardID.setCode and string.len(cardID.setCode) > 0 and cardID.collectorNum and string.len(cardID.collectorNum) > 0 then
        query_url = SCRYFALL_SET_NUM_BASE_URL .. string.lower(cardID.setCode) .. "/" .. cardID.collectorNum
    elseif cardID.setCode and string.len(cardID.setCode) > 0 then
        query_string = "order:released s:" .. string.lower(cardID.setCode) .. " " .. cardID.name
        query_url = SCRYFALL_SEARCH_BASE_URL .. query_string
    else
        query_url = SCRYFALL_NAME_BASE_URL .. cardID.name
    end

    webRequest = WebRequest.get(query_url, function(webReturn)
        if webReturn.is_error or webReturn.error then
            onError("Web request error: " .. webReturn.error or "unknown")
            return
        elseif string.len(webReturn.text) == 0 then
            onError("empty response")
            return
        end

        local success, data = pcall(function() return JSON.decode(webReturn.text) end)

        if not success then
            onError("failed to parse JSON response")
            return
        elseif not data then
            onError("empty JSON response")
            return
        elseif data.object == "error" then
            onError("failed to find card")
            return
        end

        -- Grab the first card if response is a list
        if data.object == "list" then
            if data.total_cards == 0 or not data.data or not data.data[1] then
                onError("failed to find card")
                return
            end

            data = data.data[1]
        end

        local card, tokens, err = parseCardData(cardID, data)

        if err then
            onError(err)
            return
        end

        onSuccess(card, tokens)
    end)
end

-- Queries card data for all cards.
local function fetchCardData(cards, onComplete, onError)
    local sem = 0
    local function incSem() sem = sem + 1 end
    local function decSem() sem = sem - 1 end

    local cardData = {}
    local tokenIDs = {}

    local function onQuerySuccess(card, tokens)
        table.insert(cardData, card)
        for _, token in ipairs(tokens) do
            table.insert(tokenIDs, token)
        end
        decSem()
    end

    for _, card in ipairs(cards) do
        incSem()
        queryCard(
            card,
            false,
            onQuerySuccess,
            function(e) -- onError
                -- try again, forcing query-by-name.
                queryCard(
                    card,
                    true,
                    onQuerySuccess,
                    function(e) -- onError
                        printErr("Error querying scryfall for card [" .. card.name .. "]: " .. e)
                        decSem()
                    end
                )
            end
        )
    end

    Wait.condition(
        function() onComplete(cardData, tokenIDs) end,
        function() return (sem == 0) end,
        30,
        function() onError("Error loading card images... timed out.") end
    )
end

-- Queries for the given card IDs, collates deck, and spawns objects.
local function loadDeck(cardIDs, deckName, onComplete, onError)
    local maindeckPosition = self.positionToWorld(MAINDECK_POSITION_OFFSET)
    local doublefacePosition = self.positionToWorld(DOUBLEFACE_POSITION_OFFSET)
    local sideboardPosition = self.positionToWorld(SIDEBOARD_POSITION_OFFSET)
    local commanderPosition = self.positionToWorld(COMMANDER_POSITION_OFFSET)
    local tokensPosition = self.positionToWorld(TOKENS_POSITION_OFFSET)

    printInfo("Querying Scryfall for card data...")

    fetchCardData(cardIDs, function(cards, tokenIDs)
        if tokenIDs and tokenIDs[1] then
            printInfo("Querying Scryfall for tokens...")
        end

        fetchCardData(tokenIDs, function(tokens, _)
            local maindeck = {}
            local sideboard = {}
            local commander = {}
            local doubleface = {}

            for _, card in ipairs(cards) do
                if card.sideboard then
                    table.insert(sideboard, card)
                elseif card.commander then
                    table.insert(commander, card)
                elseif card.doubleface then
                    table.insert(doubleface, card)
                else
                    table.insert(maindeck, card)
                end
            end

            printInfo("Spawning deck...")

            local sem = 5
            local function decSem() sem = sem - 1 end

            spawnDeck(maindeck, deckName, maindeckPosition, true,
                function() -- onSuccess
                    decSem()
                end,
                function(e) -- onError
                    printErr(e)
                    decSem()
                end
            )

            spawnDeck(doubleface, deckName .. " - double face cards", doublefacePosition, true,
                function(obj) -- onSuccess
                    if obj then
                        obj.setDescription("Combine these into states.")
                    end
                    decSem()
                end,
                function(e) -- onError
                    printErr(e)
                    decSem()
                end
            )

            spawnDeck(sideboard, deckName .. " - sideboard", sideboardPosition, true,
                function() -- onSuccess
                    decSem()
                end,
                function(e) -- onError
                    printErr(e)
                    decSem()
                end
            )

            spawnDeck(commander, deckName .. " - commanders", commanderPosition, false,
                function() -- onSuccess
                    decSem()
                end,
                function(e) -- onError
                    printErr(e)
                    decSem()
                end
            )

            spawnDeck(tokens, deckName .. " - tokens", tokensPosition, true,
                function() -- onSuccess
                    decSem()
                end,
                function(e) -- onError
                    printErr(e)
                    decSem()
                end
            )

            Wait.condition(
                function() onComplete() end,
                function() return (sem == 0) end,
                10,
                function() onError("Error spawning deck objects... timed out.") end
            )
        end, onError)
    end, onError)
end

------ DECK BUILDER SCRAPING
local function queryDeckNotebook(_, onSuccess, onError)
    local bookContents = readNotebookForColor(playerColor)

    if bookContents == nil then
        onError("Notebook not found: " .. playerColor)
        return
    elseif string.len(bookContents) == 0 then
        onError("Notebook is empty. Please paste your decklist into your notebook (" .. playerColor .. ").")
        return
    end

    local cards = {}

    local i = 1
    local mode = "deck"
    for line in iterateLines(bookContents) do
        line = string.gsub(line, "[\n\r]", "")

        if string.len(line) > 0 then
            if line == "Commander" then
                mode = "commander"
            elseif line == "Sideboard" then
                mode = "sideboard"
            elseif line == "Deck" then
                mode = "deck"
            else
                -- Parse out card count if present
                local count, countIndex = string.match(line, "^%s*(%d+)[x%*]?%s+()")
                if count and countIndex then
                    line = string.sub(line, countIndex)
                else
                    count = 1
                end
        
                local name, setCode, collectorNum = string.match(line, "([^%(%)]+) %(([%d%l%u]+)%) ([%d%l%u]+)")

                if not name then
                    name, setCode = string.match(line, "([^%(%)]+) %(([%d%l%u]+)%)")
                end

                if not name then
                   name = string.match(line, "([^%(%)]+)")
                end

                -- MTGA format uses DAR for dominaria for some reason, which scryfall can't find.
                if setCode == "DAR" then
                    setCode = "DOM"
                end

                if name then
                    cards[i] = {
                        count = count,
                        name = name,
                        setCode = setCode,
                        collectorNum = collectorNum,
                        sideboard = (mode == "sideboard"),
                        commander = (mode == "commander")
                    }

                    i = i + 1
                end
            end
        end
    end

    onSuccess(cards, "")
end

local function parseDeckIDTappedout(s)
    -- NOTE: need to do this in multiple parts because TTS uses an old version
    -- of lua with hilariously sad pattern matching
    local urlSuffix = s:match("tappedout%.net/mtg%-decks/(.*)")
    if urlSuffix then
        return urlSuffix:match("([^%s%?/$]*)")
    else
        return nil
    end
end

local function queryDeckTappedout(slug, onSuccess, onError)
    if not slug or string.len(slug) == 0 then
        onError("Invalid tappedout deck slug: " .. slug)
        return
    end

    local url = TAPPEDOUT_BASE_URL .. slug .. TAPPEDOUT_URL_SUFFIX

    printInfo("Fetching decklist from tappedout...")

    WebRequest.get(url .. "?fmt=multiverse", function(webReturn)
        if webReturn.error then
            if string.match(webReturn.error, "(404)") then
                onError("Deck not found. Is it public?")
            else
                onError("Web request error: " .. webReturn.error)
            end
            return
        elseif webReturn.is_error then
            onError("Web request error: unknown")
            return
        elseif string.len(webReturn.text) == 0 then
            onError("Web request error: empty response")
            return
        end

        multiverseData = webReturn.text

        WebRequest.get(url .. "?fmt=txt", function(webReturn)
            if webReturn.error then
                if string.match(webReturn.error, "(404)") then
                    onError("Deck not found. Is it public?")
                else
                    onError("Web request error: " .. webReturn.error)
                end
                return
            elseif webReturn.is_error then
                onError("Web request error: unknown")
                return
            elseif string.len(webReturn.text) == 0 then
                onError("Web request error: empty response")
                return
            end

            txtData = webReturn.text

            local cards = {}

            local i = 1
            local sb = false
            for line in iterateLines(multiverseData) do
                line = string.gsub(line, "[\n\r]", "")

                if string.len(line) > 0 then
                    if line == "SB:" then
                        sb = true
                    else
                        local count, multiverseID = string.match(line, "(%d+) (.*)")

                        cards[i] = {
                            count = count,
                            multiverseID = multiverseID,
                            sideboard = sb,
                        }

                        i = i + 1
                    end
                end
            end

            local i = 1
            local sb = false
            for line in iterateLines(txtData) do
                line = string.gsub(line, "[\n\r]", "")

                if string.len(line) > 0 then
                    if line == "Sideboard:" then
                        sb = true
                    else
                        local _, name = string.match(line, "(%d+) (.+)")

                        cards[i]['name'] = name

                        i = i + 1
                    end
                end
            end

            onSuccess(cards, slug)
        end)
    end)
end

local function parseDeckIDArchidekt(s)
    return s:match("archidekt%.com/decks/(%d*)")
end

local function queryDeckArchidekt(deckID, onSuccess, onError)
    if not deckID or string.len(deckID) == 0 then
        onError("Invalid archidekt deck: " .. deckID)
        return
    end

    local url = ARCHIDEKT_BASE_URL .. deckID .. ARCHIDEKT_URL_SUFFIX

    printInfo("Fetching decklist from archidekt...")

    WebRequest.get(url, function(webReturn)
        if webReturn.error then
            if string.match(webReturn.error, "(404)") then
                onError("Deck not found. Is it public?")
            else
                onError("Web request error: " .. webReturn.error)
            end
            return
        elseif webReturn.is_error then
            onError("Web request error: unknown")
            return
        elseif string.len(webReturn.text) == 0 then
            onError("Web request error: empty response")
            return
        end

        local success, data = pcall(function() return JSON.decode(webReturn.text) end)

        if not success then
            onError("Failed to parse JSON response from archidekt.")
            return
        elseif not data then
            onError("Empty response from archidekt.")
            return
        elseif not data.cards then
            onError("Empty response from archidekt. Did you enter a valid deck URL?")
            return
        end

        local deckName = data.name
        local cards = {}

        for i, card in ipairs(data.cards) do
            if card and card.card and not valInTable(card.categories, "Maybeboard") then
                cards[#cards+1] = {
                    count = card.quantity,
                    sideboard = valInTable(card.categories, "Sideboard"),
                    commander = valInTable(card.categories, "Commander"),
                    name = card.card.oracleCard.name,
                    scryfallID = card.card.uid,
                }
            end
        end

        onSuccess(cards, deckName)
    end)
end

local function parseDeckIDMoxfield(s)
    local urlSuffix = s:match("moxfield%.com/decks/(.*)")
    if urlSuffix then
        return urlSuffix:match("([^%s%?/$]*)")
    else
        return nil
    end
end

local function queryDeckMoxfield(deckID, onSuccess, onError)
    if not deckID or string.len(deckID) == 0 then
        onError("Invalid moxfield deck: " .. deckID)
        return
    end

    local url = MOXFIELD_BASE_URL .. deckID .. MOXFIELD_URL_SUFFIX

    printInfo("Fetching decklist from moxfield... this is a slow one please have patience :)")

    WebRequest.get(url, function(webReturn)
        if webReturn.error then
            if string.match(webReturn.error, "(404)") then
                onError("Deck not found. Is it public?")
            else
                onError("Web request error: " .. webReturn.error)
            end
            return
        elseif webReturn.is_error then
            onError("Web request error: unknown")
            return
        elseif string.len(webReturn.text) == 0 then
            onError("Web request error: empty response")
            return
        end

        local success, data = pcall(function() return JSON.decode(webReturn.text) end)

        if not success then
            onError("Failed to parse JSON response from moxfield.")
            return
        elseif not data then
            onError("Empty response from moxfield.")
            return
        elseif not data.name or not data.mainboard then
            onError("Empty response from moxfield. Did you enter a valid deck URL?")
            return
        end

        local deckName = data.name
        local commanderIDs = {}
        local cards = {}

        for name, cardData in pairs(data.commanders or {}) do
            if cardData.card then
                commanderIDs[cardData.card.id] = true

                table.insert(cards, {
                    name = cardData.card.name,
                    count = cardData.quantity,
                    scryfallID = cardData.card.id,
                    sideboard = false,
                    commander = true,
                })
            end
        end

        for name, cardData in pairs(data.mainboard) do
            if cardData.card and not commanderIDs[cardData.card.id] then
                table.insert(cards, {
                    name = cardData.card.name,
                    count = cardData.quantity,
                    scryfallID = cardData.card.id,
                    sideboard = false,
                    commander = false,
                })
            end
        end

        for name, cardData in pairs(data.sideboard or {}) do
            if cardData.card and not commanderIDs[cardData.card.id] then
                table.insert(cards, {
                    name = cardData.card.name,
                    count = cardData.quantity,
                    scryfallID = cardData.card.id,
                    sideboard = true,
                    commander = false,
                })
            end
        end

        onSuccess(cards, deckName)
    end)
end

function importDeck()
    if lock then
        printErr("Error: Deck import started while importer locked.")
    end

    local deckURL = getDeckInputValue()

    local deckID, queryDeckFunc
    if deckSource == DECK_SOURCE_URL then
        if string.len(deckURL) == 0 then
            printInfo("Please enter a deck URL.")
            return 1
        end

        if string.match(deckURL, TAPPEDOUT_URL_MATCH) then
            queryDeckFunc = queryDeckTappedout
            deckID = parseDeckIDTappedout(deckURL)
        elseif string.match(deckURL, ARCHIDEKT_URL_MATCH) then
            queryDeckFunc = queryDeckArchidekt
            deckID = parseDeckIDArchidekt(deckURL)
        elseif string.match(deckURL, GOLDFISH_URL_MATCH) then
            printInfo("MTGGoldfish support is coming soon! In the meantime, please export to MTG Arena, and use notebook import.")
            return 1
        elseif string.match(deckURL, MOXFIELD_URL_MATCH) then
            queryDeckFunc = queryDeckMoxfield
            deckID = parseDeckIDMoxfield(deckURL)
        else
            printInfo("Unknown deck site, sorry! Please export to MTG Arena and use notebook import.")
            return 1
        end
    elseif deckSource == DECK_SOURCE_NOTEBOOK then
        queryDeckFunc = queryDeckNotebook
        deckID = nil
    else
        printErr("Error. Unknown deck source: " .. deckSource or "nil")
        return 1
    end

    lock = true
    printToAll("Starting deck import...")

    local function onError(e)
        printErr(e)
        printToAll("Deck import failed.")
        lock = false
    end

    queryDeckFunc(deckID,
        function(cardIDs, deckName)
            loadDeck(cardIDs, deckName,
                function()
                    printToAll("Deck import complete!")
                    lock = false
                end,
                onError
            )
        end,
        onError
    )

    return 1
end

------ UI
local function drawUI()
    self.createInput({
        input_function = "onLoadDeckInput",
        function_owner = self,
        label          = "Enter deck URL, or load from Notebook.",
        alignment      = 2,
        position       = {x=0, y=0.1, z=0.78},
        width          = 2000,
        height         = 100,
        font_size      = 60,
        validation     = 1,
        value = "",
    })

    self.createInput({
        input_function = "onGetCardBackInput",
        function_owner = self,
        label          = "Enter card back URL",
        alignment      = 2,
        position       = {x=0, y=0.1, z=1.78},
        width          = 2000,
        height         = 100,
        font_size      = 60,
        validation     = 1,
        value = "",
    })

    self.createButton({
        click_function = "onLoadDeckURLButton",
        function_owner = self,
        label          = "Load Deck (URL)",
        position       = {-1, 0.1, 1.15},
        rotation       = {0, 0, 0},
        width          = 850,
        height         = 160,
        font_size      = 80,
        color          = {0.5, 0.5, 0.5},
        font_color     = {r=1, b=1, g=1},
        tooltip        = "Click to load deck from URL",
    })

    self.createButton({
        click_function = "onLoadDeckNotebookButton",
        function_owner = self,
        label          = "Load Deck (Notebook)",
        position       = {1, 0.1, 1.15},
        rotation       = {0, 0, 0},
        width          = 850,
        height         = 160,
        font_size      = 80,
        color          = {0.5, 0.5, 0.5},
        font_color     = {r=1, b=1, g=1},
        tooltip        = "Click to load deck from notebook",
    })

end

function getDeckInputValue()
    for i, input in pairs(self.getInputs()) do
        if input.label == "Enter deck URL, or load from Notebook." then
            return trim(input.value)
        end
    end

    return ""
end

function onLoadDeckInput(_, _, _) end

function getCardBackInputValue()
    for i, input in pairs(self.getInputs()) do
        if input.label == "Enter card back URL" then
            local back = trim(input.value)
            if back ~= "" then return back end
        end
    end

    return DEFAULT_CARDBACK
end

function onGetCardBackInput(_, _, _) end

function onLoadDeckURLButton(_, pc, _)
    if lock then
        printToColor("Another deck is currently being imported. Please wait for that to finish.", pc)
        return
    end

    playerColor = pc
    deckSource = DECK_SOURCE_URL

    startLuaCoroutine(self, "importDeck")
end

function onLoadDeckNotebookButton(_, pc, _)
    if lock then
        printToColor("Another deck is currently being imported. Please wait for that to finish.", pc)
        return
    end

    playerColor = pc
    deckSource = DECK_SOURCE_NOTEBOOK

    startLuaCoroutine(self, "importDeck")
end

------ TTS CALLBACKS
function onLoad()
    drawUI()
end
