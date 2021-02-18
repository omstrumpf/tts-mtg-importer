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

DECKSTATS_URL_SUFFIX = "?include_comments=1&export_mtgarena=1"
DECKSTATS_URL_MATCH = "deckstats%.net"

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
DEFAULT_LANGUAGE = "en"

LANGUAGES = {
    ["en"] = "en",
    ["es"] = "es",
    ["sp"] = "sp",
    ["fr"] = "fr",
    ["de"] = "de",
    ["it"] = "it",
    ["pt"] = "pt",
    ["ja"] = "ja",
    ["jp"] = "ja",
    ["ko"] = "ko",
    ["kr"] = "ko",
    ["ru"] = "ru",
    ["zcs"] = "zcs",
    ["cs"] = "zcs",
    ["zht"] = "zht",
    ["ph"] = "ph",
    ["english"] = "en",
    ["spanish"] = "es",
    ["french"] = "fr",
    ["german"] = "de",
    ["italian"] = "it",
    ["portugese"] = "pt",
    ["japanese"] = "ja",
    ["korean"] = "ko",
    ["russian"] = "ru",
    ["chinese"] = "zhs",
    ["simplified chinese"] = "zhs",
    ["traditional chinese"] = "zht",
    ["phyrexian"] = "ph"
}

------ UI IDs
UI_ADVANCED_PANEL = "MTGDeckLoaderAdvancedPanel"
UI_CARD_BACK_INPUT = "MTGDeckLoaderCardBackInput"
UI_LANGUAGE_INPUT = "MTGDeckLoaderLanguageInput"
UI_FORCE_LANGUAGE_TOGGLE = "MTGDeckLoaderForceLanguageToggleID"

------ GLOBAL STATE
lock = false
playerColor = nil
deckSource = nil
advanced = false
cardBackInput = ""
languageInput = ""
forceLanguage = false

------ UTILITY
local function trim(s)
    if not s then return "" end

    local n = s:find"%S"
    return n and s:match(".*%S", n) or ""
end

local function iterateLines(s)
    if not s or string.len(s) == 0 then
        return ipairs({})
    end

    if s:sub(-1) ~= '\n' then
        s = s .. '\n'
    end

    local pos = 1
    return function ()
        if not pos then return nil end

        local p1, p2 = s:find("\r?\n", pos)

        local line
        if p1 then
            line = s:sub(pos, p1 - 1)
            pos = p2 + 1
        else
            line = s:sub(pos)
            pos = nil
        end

        return line
    end
end

local function underline(s)
    if not s or string.len(s) == 0 then
        return ""
    end

    return s .. '\n' .. string.rep('-', string.len(s)) .. '\n'
end

local function shallowCopyTable(t)
    if type(t) == 'table' then
        local copy = {}
        for key, val in pairs(t) do
            copy[key] = val
        end

        return copy
    end

    return {}
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
local function spawnCard(oracleID, face, position, flipped, onFullySpawned)
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
            obj.memo = oracleID
            obj.setName(face.name)
            obj.setDescription(face.oracleText)
            obj.setCustomObject({
                face = face.imageURI,
                back = getCardBack()
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
                spawnCard(card.oracleID, face, position, flipped, function(obj)
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

-- Returns a nicely formatted card name with type_line and cmc
local function getAugmentedName(cardData)
    local name = cardData.name:gsub('"', '') or ""

    if cardData.type_line then
        name = name .. '\n' .. cardData.type_line
    end

    if cardData.cmc then
        name = name .. '\n' .. cardData.cmc .. ' CMC'
    end

    return name
end

-- Returns a nicely formatted oracle text with power/toughness or loyalty
-- if present
local function getAugmentedOracleText(cardData)
    local oracleText = cardData.oracle_text:gsub('"', "'")

    if cardData.power and cardData.toughness then
        oracleText = oracleText .. '\n[b]' .. cardData.power .. '/' .. cardData.toughness .. '[/b]'
    elseif cardData.loyalty then
        oracleText = oracleText .. '\n[b]' .. tostring(cardData.loyalty) .. '[/b]'
    end

    return oracleText
end

-- Collects oracle text from multiple faces if present
local function collectOracleText(cardData)
    local oracleText = ""

    if cardData.card_faces then
        for i, face in ipairs(cardData.card_faces) do
            oracleText = oracleText .. underline(face.name) .. getAugmentedOracleText(face)

            if i < #cardData.card_faces then
                oracleText = oracleText .. '\n\n'
            end
        end
    else
        oracleText = getAugmentedOracleText(cardData)
    end

    return oracleText
end

-- Parses scryfall reseponse data for a card.
-- Returns a populated card table and a list of tokens.
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

    local card = shallowCopyTable(cardID)
    card.name = getAugmentedName(data)
    card.oracleText = collectOracleText(data)
    card.faces = {}
    card.scryfallID = data.id
    card.oracleID = data.oracle_id
    card.language = data.lang
    card.setCode = data.set
    card.collectorNum = data.collector_number

    if data.layout == "transform" or data.layout == "art_series" or data.layout == "double_sided" or data.layout == "modal_dfc" then
        for i, face in ipairs(data.card_faces) do
            card['faces'][i] = {
                imageURI = stripScryfallImageURI(face.image_uris.large),
                name = getAugmentedName(face),
                oracleText = card.oracleText
            }
        end
        card['doubleface'] = true
    elseif data.layout == "double_faced_token" then
        for i, face in ipairs(data.card_faces) do
            card['faces'][i] = {
                imageURI = stripScryfallImageURI(face.image_uris.large),
                name = getAugmentedName(face),
                oracleText = card.oracleText,
            }
        end
        card['doubleface'] = false -- Not putting double-face tokens in double-face cards pile
    else
        card['faces'][1] = {
            imageURI = stripScryfallImageURI(data.image_uris.large),
            name = card.name,
            oracleText = card.oracleText,
        }
        card['doubleface'] = false
    end

    return card, tokens
end

-- Queries scryfall by the [cardID].
-- cardID must define at least one of scryfallID, multiverseID, or name.
-- if forceNameQuery is true, will query scryfall by card name ignoring other data.
-- if forceSetNumLangQuery is true, will query scryfall by set/num/lang ignoring other data.
-- onSuccess is called with a populated card table, and a table of associated token cardIDs.
local function queryCard(cardID, forceNameQuery, forceSetNumLangQuery, onSuccess, onError)
    local query_url

    local language_code = getLanguageCode()

    if forceNameQuery then
        query_url = SCRYFALL_NAME_BASE_URL .. cardID.name
    elseif forceSetNumLangQuery then
        query_url = SCRYFALL_SET_NUM_BASE_URL .. string.lower(cardID.setCode) .. "/" .. cardID.collectorNum .. "/" .. language_code
    elseif cardID.scryfallID and string.len(cardID.scryfallID) > 0 then
        query_url = SCRYFALL_ID_BASE_URL .. cardID.scryfallID
    elseif cardID.multiverseID and string.len(cardID.multiverseID) > 0 then
        query_url = SCRYFALL_MULTIVERSE_BASE_URL .. cardID.multiverseID
    elseif cardID.setCode and string.len(cardID.setCode) > 0 and cardID.collectorNum and string.len(cardID.collectorNum) > 0 then
        query_url = SCRYFALL_SET_NUM_BASE_URL .. string.lower(cardID.setCode) .. "/" .. cardID.collectorNum .. "/" .. language_code
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

        -- PieHere: it's now possible to just get the very first card (without having to parse the whole list) with the function
        -- getNextCardDatFromList(webReturn.text,1)   -- (1 is the the text index where to start parsing from)
        -- πTODO, try query_url=https://api.scryfall.com/cards/search?q=..cardID(probably the name?)..+lang%3A..language_code

        -- TODO JSONdecode hangs the UI. Pull in a different JSON parser              -- PieHere: done?

        local success,data
        if webReturn.text:sub(1,16)=='{"object":"list"' then

          success,data = pcall(function() return getNextCardDatFromList(webReturn.text,1) end)
          if not success then
            onError('something went wrong with the getNextCardDatFromList')
            return
          end

        elseif webReturn.text:sub(1,16)=='{"object":"card"' then

          success, data = pcall(function() return JSONdecode(webReturn.text) end)
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

        else

          onError('somehow got a webReturn that is not a card or a list')
          return

        end

        local card, tokens = parseCardData(cardID, data)

        onSuccess(card, tokens)
    end)
end

-- Queries card data for all cards.
-- TODO use the bulk api        -- PieHere: bulk API is crazy man, no way TTS's JSON.decode would handle that, parsing it by text would also be kinda nuts O.o... but possible ;-)
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

    local function onQueryFailed(e)
        printErr("Error querying scryfall: " .. e)
        decSem()
    end

    local language = getLanguageCode()

    for _, cardID in ipairs(cards) do
        incSem()
        queryCard(
            cardID,
            false,
            false,
            function (card, tokens) -- onSuccess
                if card.language != language and
                   (forceLanguage or (not cardID.scryfallID and not cardID.multiverseID)) then
                  -- We got the wrong language, and should re-query.
                  -- We requery if forceLanguage is enabled, or if the printing wasn't specified directly

                  -- TODO currently we just hope that the target language is available in the printing
                  -- we found. If it doesn't, we miss other printings that might have the right language.
                  -- This isn't easily solveable, since TTS crashes if we try to do large scryfall queries.

                  cardID.setCode = card.setCode
                  cardID.collectorNum = card.collectorNum
                  queryCard(cardID, false, true, onQuerySuccess,
                    function(e) -- onError, use the original language
                        onQuerySuccess(card, tokens)
                    end
                  )
                else
                    -- We got the right language
                    onQuerySuccess(card, tokens)
                end
            end,
            function(e) -- onError
                -- try again, forcing query-by-name.
                queryCard(
                    cardID,
                    true,
                    false,
                    onQuerySuccess,
                    onQueryFailed
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
local function parseMTGALine(line)
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

    return name, count, setCode, collectorNum
end

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
        if string.len(line) > 0 then
            if line == "Commander" then
                mode = "commander"
            elseif line == "Sideboard" then
                mode = "sideboard"
            elseif line == "Deck" then
                mode = "deck"
            else
                local name, count, setCode, collectorNum = parseMTGALine(line)

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

        local success, data = pcall(function() return JSONdecode(webReturn.text) end)

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

        local success, data = pcall(function() return JSONdecode(webReturn.text) end)

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

local function parseDeckIDDeckstats(s)
    local deckURL = s:match("(deckstats%.net/decks/%d*/[^/]*)")
    return deckURL
end

local function queryDeckDeckstats(deckURL, onSuccess, onError)
    if not deckURL or string.len(deckURL) == 0 then
        onError("Invalid deckstats URL: " .. deckURL)
        return
    end

    local url = deckURL .. DECKSTATS_URL_SUFFIX

    printInfo("Fetching decklist from deckstats...")

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

        local name = deckURL:match("deckstats%.net/decks/%d*/%d*-([^/?]*)")

        local cards = {}

        local i = 1
        local mode = "deck"
        for line in iterateLines(webReturn.text) do
            if string.len(line) == 0 then
                mode = "sideboard"
            else
                local commentPos = line:find("#")
                if commentPos then
                    line = line:sub(1, commentPos)
                end

                local name, count, setCode, collectorNum = parseMTGALine(line)

                if name then
                    cards[i] = {
                      count = count,
                      name = name,
                      setCode = setCode,
                      collectorNum = collectorNum,
                      sideboard = (mode == "sideboard"),
                      commander = false
                    }

                    i = i + 1
                end
            end
        end

        -- This sucks... but the arena export format is the only one that gives
        -- me full data on printings and this is the best way I've found to tell
        -- if its a commander deck.
        if #cards >= 90 then
            cards[1].commander = true
        end

        onSuccess(cards, name)
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
        elseif string.match(deckURL, DECKSTATS_URL_MATCH) then
            queryDeckFunc = queryDeckDeckstats
            deckID = parseDeckIDDeckstats(deckURL)
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
    local _inputs = self.getInputs()
    local deckURL = ""

    if _inputs ~= nil then
        for i, input in pairs(self.getInputs()) do
            if input.label == "Enter deck URL, or load from Notebook." then
                deckURL = input.value
            end
        end
    end
    self.clearInputs()
    self.clearButtons()
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
        value = deckURL,
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

    self.createButton({
        click_function = "onToggleAdvancedButton",
        function_owner = self,
        label          = "...",
        position       = {2.25, 0.1, 1.15},
        rotation       = {0, 0, 0},
        width          = 160,
        height         = 160,
        font_size      = 100,
        color          = {0.5, 0.5, 0.5},
        font_color     = {r=1, b=1, g=1},
        tooltip        = "Click to open advanced menu",
    })

    if advanced then
        self.UI.show("MTGDeckLoaderAdvancedPanel")
    else
        self.UI.hide("MTGDeckLoaderAdvancedPanel")
    end
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

function onToggleAdvancedButton(_, _, _)
    advanced = not advanced
    drawUI()
end

function getCardBack()
    if not cardBackInput or string.len(cardBackInput) == 0 then
        return DEFAULT_CARDBACK
    else
        return cardBackInput
    end
end

function mtgdl__onCardBackInput(_, value, _)
    cardBackInput = value
end

function getLanguageCode()
    if not languageInput or string.len(languageInput) == 0 then
        return DEFAULT_LANGUAGE
    else
        local code = LANGUAGES[string.lower(trim(languageInput))]

        return (code or DEFAULT_LANGUAGE)
    end
end

function mtgdl__onLanguageInput(_, value, _)
    languageInput = value
end

function mtgdl__onForceLanguageInput(_, value, _)
    forceLanguage = value
end

------ TTS CALLBACKS
function onLoad()
    drawUI()
end



--------------------------------------------------------------------------------
-- pie's manual "JSON.decode" for scryfall's api output
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- which fields to extract?
-- these need to be in the order the appear in the json text
normal_card_keys={
  'object',
  'id',
  'oracle_id',
  'name',
  'printed_name',       --for non-EN cards
  'lang',
  'layout',
  'image_uris',
  'mana_cost',
  'cmc',
  'type_line',
  'printed_type_line',  --for non-EN cards
  'oracle_text',
  'printed_text',       --for non-EN cards
  'loyalty',
  'power',
  'toughness',
  'loyalty',
  'set',
  'collector_number'
}

image_uris_keys={       -- "image_uris":{
  'small',
  'normal',
  'large',
}

related_card_keys={     -- "all_parts":[{"object":"related_card",
  'id',
  'component',
  'name',
  'uri',
}

card_face_keys={        -- "card_faces":[{"object":"card_face",
  'name',
  'printed_name',       --for non-EN cards
  'mana_cost',
  'type_line',
  'printed_type_line',  --for non-EN cards
  'oracle_text',
  'printed_text',       --for non-EN cards
  'power',
  'toughness',
  'loyalty',
  'image_uris',
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function JSONdecode(txt)
  local txtBeginning = txt:sub(1,16)
  local jsonType = txtBeginning:match('{"object":"(%w+)"')

  -- not scryfall? use normal JSON.decode
  if not(jsonType=='card' or jsonType=='list') then
    return JSON.decode(txt)
  end

  ------------------------------------------------------------------------------
  -- parse list: extract each card, and parse it separately
  -- used when one wants to decode a whole list
  if jsonType=='list' then
    local txtBeginning = txt:sub(1,80)
    local nCards=txtBeginning:match('"total_cards":(%d+)')
    local cardEnd=0
    local cardDats = {}
    for i=1,nCards do     -- could insert max number cards to parse here
      local cardStart=string.find(txt,'{"object":"card"',cardEnd+1)
      local cardEnd = findClosingBracket(txt,cardStart)
      local cardDat = JSONdecode(txt:sub(cardStart,cardEnd))
      table.insert(cardDats,cardDat)
    end
    local dat = {object="list",total_cards=nCards,data=cardDats}    --ignoring hast_more...
    return dat
  end

  ------------------------------------------------------------------------------
  -- parse card

  txt=txt:gsub('}',',}')    -- comma helps parsing last element in an array

  local cardDat={}
  local all_parts_i=string.find(txt,'"all_parts":')
  local card_faces_i=string.find(txt,'"card_faces":')

  -- if all_parts exist
  if all_parts_i~=nil then
    local st=string.find(txt,'%[',all_parts_i)
    local en=findClosingBracket(txt,st)
    local all_parts_txt = txt:sub(all_parts_i,en)
    local all_parts={}
    -- remove all_parts snip from the main text
    txt=txt:sub(1,all_parts_i-1)..txt:sub(en+2,-1)
    -- parse all_parts_txt for each related_card
    st=1
    local cardN=0
    while st~=nil do
      st=string.find(all_parts_txt,'{"object":"related_card"',st)
      if st~=nil then
        cardN=cardN+1
        en=findClosingBracket(all_parts_txt,st)
        local related_card_txt=all_parts_txt:sub(st,en)
        st=en
        local s,e=1,1
        local related_card={}
        for i,key in ipairs(related_card_keys) do
          val,s=getKeyValue(related_card_txt,key,s)
          related_card[key]=val
        end
        table.insert(all_parts,related_card)
        if cardN>30 then break end   -- avoid inf loop if something goes strange
      end
      cardDat.all_parts=all_parts
    end
  end

  -- if card_faces exist
  if card_faces_i~=nil then
    local st=string.find(txt,'%[',card_faces_i)
    local en=findClosingBracket(txt,st)
    local card_faces_txt = txt:sub(card_faces_i,en)
    local card_faces={}
    -- remove card_faces snip from the main text
    txt=txt:sub(1,card_faces_i-1)..txt:sub(en+2,-1)

    -- parse card_faces_txt for each card_face
    st=1
    local cardN=0
    while st~=nil do
      st=string.find(card_faces_txt,'{"object":"card_face"',st)
      if st~=nil then
        cardN=cardN+1
        en=findClosingBracket(card_faces_txt,st)
        local card_face_txt=card_faces_txt:sub(st,en)
        st=en
        local s,e=1,1
        local card_face={}
        for i,key in ipairs(card_face_keys) do
          val,s=getKeyValue(card_face_txt,key,s)
          card_face[key]=val
        end
        table.insert(card_faces,card_face)
        if cardN>4 then break end   -- avoid inf loop if something goes strange
      end
      cardDat.card_faces=card_faces
    end
  end

  -- normal card (or what's left of it after removing card_faces and all_parts)
  st=1
  for i,key in ipairs(normal_card_keys) do
    val,st=getKeyValue(txt,key,st)
    cardDat[key]=val
  end

  return cardDat
end

--------------------------------------------------------------------------------
-- returns data for one card at a time from a scryfall's "object":"list"
function getNextCardDatFromList(txt,startHere)

  if startHere==nil then
    startHere=1
  end

  local cardStart=string.find(txt,'{"object":"card"',startHere)
  if cardStart==nil then
    print('error: no more cards in list')
    startHere=nil
    return nil,nil,nil
  end

  local cardEnd = findClosingBracket(txt,cardStart)
  if cardEnd==nil then
    print('error: no more cards in list')
    startHere=nil
    return nil,nil,nil
  end

  -- startHere is not a local variable, so it's possible to just do:
  -- getNextCardFromList(txt) and it will keep giving the next card or nil if there's no more
  startHere=cardEnd+1

  local cardDat = JSONdecode(txt:sub(cardStart,cardEnd))

  return cardDat,cardStart,cardEnd
end

--------------------------------------------------------------------------------
function findClosingBracket(txt,st)   -- find paired {} or []
  local ob,cb='{','}'
  local pattern='[{}]'
  if txt:sub(st,st)=='[' then
    ob,cb='[',']'
    pattern='[%[%]]'
  end
  local txti=st
  local nopen=1
  while nopen>0 do
    txti=string.find(txt,pattern,txti+1)
    if txt:sub(txti,txti)==ob then
      nopen=nopen+1
    elseif txt:sub(txti,txti)==cb then
      nopen=nopen-1
    end
  end
  return txti
end

--------------------------------------------------------------------------------
function getKeyValue(txt,key,st)
  local str='"'..key..'":'
  local st=string.find(txt,str,st)
  local en=nil
  local value=nil
  if st~=nil then
    if key=='image_uris' then
      value={}
      local s=st
      for i,k in ipairs(image_uris_keys) do
        local val,s=getKeyValue(txt,k,s)
        value[k]=val
      end
      en=s
    elseif key=='cmc' then      -- cmc the only key that doesn't have quotation marks?
      en=string.find(txt,',"',st+#str+1)
      value=tostring(tonumber(txt:sub(st+#str,en-1)))
    else
      en=string.find(txt,'",',st+#str+1)
      value=txt:sub(st+#str+1,en-1):gsub('\\"','"'):gsub('\\n','\n')
    end
  end
  if type(value)=='string' then
    value=value:gsub(',}','}')    -- get rid of the previously inserted comma
  end
  return value,en
end
