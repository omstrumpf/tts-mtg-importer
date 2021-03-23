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
--    if flipped then
--        rotation = vecSum(self.getRotation(), {0, 0, 180})
--    else
        rotation = self.getRotation()
--    end
    
    json = {GUID="111111", Name="Card", Transform={posX=position.x, posY=position.y, posZ=position.z, 
            rotX=rotation.x, rotY=rotation.y, rotZ=rotation.z, scaleX=1, scaleY=1, scaleZ=1},
            Nickname=face.name, Description=face.oracleText, GMNotes="", ColorDiffuse={r=0.713235259, g=0.713235259, b=0.713235259},
            LayoutGroupSourtIndex=0, Locked=false, Grid=true, Snap=true, IgnoreFoW=false, MeasureMovement=false, DragSelectable=true,
            Autoraise=true, Sticky=true, Tooltip=true, GridProjection=false, HideWhenFaceDown=true, Hands=true, CardID=2440000,
            SidewaysCard=false, CustomDeck={}, LuaScript="", LuaScriptState="", XmlUI=""}
    json.CustomDeck["24400"]={FaceURL=face.imageURI, BackURL=getCardBack(), NumWidth=1, NumHeight=1, BackIsHidden=true, UniqueBack=false, Type=0}

    if face.savedata and face.savedata[1] and face.savedata[1].name and string.len(face.savedata[1].name) > 0 then
            json.LuaScript="\nfunction onLoad(saved_data)\n    if saved_data ~= \"\" then\n        tokens = JSON.decode(saved_data)\n    else\n        tokens = {}\n    end\n\n    local pZ = -1\n    for i, token in ipairs(tokens) do\n        self.createButton({label = token.name,\n                            click_function = \"gt\" .. i,\n                            function_owner = self,\n                            width = math.max(400,40 * string.len(token.name) + 40),\n                            height = 100,\n                            color = {1,1,1},\n                            position = {1, 0.5, pZ},\n                            font_size = 75})\n        pZ = pZ + 0.25\n    end\n\nend\n\nfunction onSave()\n    return JSON.encode(tokens)\nend\n\nfunction gt1() getToken(1) end\nfunction gt2() getToken(2) end\nfunction gt3() getToken(3) end\nfunction gt4() getToken(4) end\n\nfunction getToken(i)\n    token = tokens[i]\n    position = self.getPosition()\n    position.y =     position.y + 0.1\n    position.x =     position.x + 2.5\r\n    spawnObject({\r\n        type = \"Card\",\r\n        sound = false,\r\n        rotation = self.getRotation(),\r\n        position = position,\r\n        scale = self.getScale(),\r\n        callback_function = (function(obj)\r\n            obj.memo = \"\"\r\n            obj.setName(token.name)\r\n            obj.setDescription(token.desc)\r\n            obj.setCustomObject({\r\n                face = token.front,\r\n                back = token.back\r\n            })\r\r\n        end)})\nend"
            json.LuaScriptState=JSON.encode(face.savedata) --[]
    end
    
    local cardObj = spawnObjectJSON({json = JSON.encode(json)})
    onFullySpawned(cardObj)
    return cardObj
end

-- Spawns the given card [face] at [position].
-- Card will be face down if [flipped].
-- Calls [onFullySpawned] when the object is spawned.
local function spawnCard2Face(oracleID, face1, face2, position, flipped, onFullySpawned)
    local rotation
--    if flipped then
--        rotation = vecSum(self.getRotation(), {0, 0, 180})
--    else
        rotation = self.getRotation()
--    end
    
    json = {GUID="111111", Name="Card", Transform={posX=position.x, posY=position.y, posZ=position.z, 
            rotX=rotation.x, rotY=rotation.y, rotZ=rotation.z, scaleX=1, scaleY=1, scaleZ=1},
            Nickname=face1.name, Description=face1.oracleText, GMNotes="", ColorDiffuse={r=0.713235259, g=0.713235259, b=0.713235259},
            LayoutGroupSourtIndex=0, Locked=false, Grid=true, Snap=true, IgnoreFoW=false, MeasureMovement=false, DragSelectable=true,
            Autoraise=true, Sticky=true, Tooltip=true, GridProjection=false, HideWhenFaceDown=true, Hands=true, CardID=2440000,
            SidewaysCard=false, CustomDeck={}, LuaScript="", LuaScriptState="", XmlUI=""}
    json.CustomDeck["24400"]={FaceURL=face1.imageURI, BackURL=getCardBack(), NumWidth=1, NumHeight=1, BackIsHidden=true, UniqueBack=false, Type=0}

    if face1.savedata and face1.savedata[1] and face1.savedata[1].name and string.len(face1.savedata[1].name) > 0 then
            json.LuaScript="\nfunction onLoad(saved_data)\n    if saved_data ~= \"\" then\n        tokens = JSON.decode(saved_data)\n    else\n        tokens = {}\n    end\n\n    local pZ = -1\n    for i, token in ipairs(tokens) do\n        self.createButton({label = token.name,\n                            click_function = \"gt\" .. i,\n                            function_owner = self,\n                            width = math.max(400,40 * string.len(token.name) + 40),\n                            height = 100,\n                            color = {1,1,1},\n                            position = {1, 0.5, pZ},\n                            font_size = 75})\n        pZ = pZ + 0.25\n    end\n\nend\n\nfunction onSave()\n    return JSON.encode(tokens)\nend\n\nfunction gt1() getToken(1) end\nfunction gt2() getToken(2) end\nfunction gt3() getToken(3) end\nfunction gt4() getToken(4) end\n\nfunction getToken(i)\n    token = tokens[i]\n    position = self.getPosition()\n    position.y =     position.y + 0.1\n    position.x =     position.x + 2.5\r\n    spawnObject({\r\n        type = \"Card\",\r\n        sound = false,\r\n        rotation = self.getRotation(),\r\n        position = position,\r\n        scale = self.getScale(),\r\n        callback_function = (function(obj)\r\n            obj.memo = \"\"\r\n            obj.setName(token.name)\r\n            obj.setDescription(token.desc)\r\n            obj.setCustomObject({\r\n                face = token.front,\r\n                back = token.back\r\n            })\r\r\n        end)})\nend"
            json.LuaScriptState="[".. JSON.encode(face1.savedata[1]) .. "]"
    end
    
    json2 = {GUID="111112", Name="Card", Transform={posX=position.x, posY=position.y, posZ=position.z, 
            rotX=rotation.x, rotY=rotation.y, rotZ=rotation.z, scaleX=1, scaleY=1, scaleZ=1},
            Nickname=face2.name, Description=face2.oracleText, GMNotes="", ColorDiffuse={r=0.713235259, g=0.713235259, b=0.713235259},
            LayoutGroupSourtIndex=0, Locked=false, Grid=true, Snap=true, IgnoreFoW=false, MeasureMovement=false, DragSelectable=true,
            Autoraise=true, Sticky=true, Tooltip=true, GridProjection=false, HideWhenFaceDown=true, Hands=true, CardID=2440100,
            SidewaysCard=false, CustomDeck={}, LuaScript="", LuaScriptState="", XmlUI=""}
    json2.CustomDeck["24401"]={FaceURL=face2.imageURI, BackURL=getCardBack(), NumWidth=1, NumHeight=1, BackIsHidden=true, UniqueBack=false, Type=0}

    if face2.savedata and face2.savedata[1] and face2.savedata[1].name and string.len(face2.savedata[1].name) > 0 then
            json2.LuaScript="\nfunction onLoad(saved_data)\n    if saved_data ~= \"\" then\n        tokens = JSON.decode(saved_data)\n    else\n        tokens = {}\n    end\n\n    local pZ = -1\n    for i, token in ipairs(tokens) do\n        self.createButton({label = token.name,\n                            click_function = \"gt\" .. i,\n                            function_owner = self,\n                            width = math.max(400,40 * string.len(token.name) + 40),\n                            height = 100,\n                            color = {1,1,1},\n                            position = {1, 0.5, pZ},\n                            font_size = 75})\n        pZ = pZ + 0.25\n    end\n\nend\n\nfunction onSave()\n    return JSON.encode(tokens)\nend\n\nfunction gt1() getToken(1) end\nfunction gt2() getToken(2) end\nfunction gt3() getToken(3) end\nfunction gt4() getToken(4) end\n\nfunction getToken(i)\n    token = tokens[i]\n    position = self.getPosition()\n    position.y =     position.y + 0.1\n    position.x =     position.x + 2.5\r\n    spawnObject({\r\n        type = \"Card\",\r\n        sound = false,\r\n        rotation = self.getRotation(),\r\n        position = position,\r\n        scale = self.getScale(),\r\n        callback_function = (function(obj)\r\n            obj.memo = \"\"\r\n            obj.setName(token.name)\r\n            obj.setDescription(token.desc)\r\n            obj.setCustomObject({\r\n                face = token.front,\r\n                back = token.back\r\n            })\r\r\n        end)})\nend"
            json2.LuaScriptState=JSON.encode(face2.savedata)--[]
    end

    json.States = {}
    json.States["2"] = json2

    local cardObj = spawnObjectJSON({json = JSON.encode(json)})
    onFullySpawned(cardObj)
    return cardObj
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

---------------Change for double faced cards-----------------
            if card.faces[2] then
                incSem()
                spawnCard2Face(card.oracleID, card.faces[1], card.faces[2], position, flipped, function(obj)
                    table.insert(cardObjects, obj)
                    decSem()
                end)
            else
                incSem()
                spawnCard(card.oracleID, card.faces[1], position, flipped, function(obj)
                    table.insert(cardObjects, obj)
                    decSem()
                end)
            end

--            for _, face in ipairs(card.faces) do
--                incSem()
--                spawnCard(card.oracleID, face, position, flipped, function(obj)
--                    table.insert(cardObjects, obj)
--                    decSem()
--                end)
--            end
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
    local savedata = {}
    local function onQueryS(card, r_tokens)
        log(card)
        table.insert(savedata, {name=card.name, desc=card.oracleText, front=card.faces[1].imageURI, back=getCardBack()})
    end
    local function onQueryE(error)
        log(error)
    end
    if data.all_parts and not (data.layout == "token") then
        for _, part in ipairs(data.all_parts) do
            if part.component and part.component == "token" then
                tmp = {name = part.name, scryfallID = part.id,}
                table.insert(tokens, tmp)
                WebRequest.get(part.uri, function(webReturn)
                    if webReturn.is_error or webReturn.error or string.len(webReturn.text) == 0 then
                        log("Error: " ..webReturn.error or "unknown")
                        return
                    end
                    
                    local success, data = pcall(function() return JSON.decode(webReturn.text) end)
                    if not success or not data or data.object == "error" then
                        log("Error: JSON Parse")
                        return
                    end
                    table.insert(savedata, {name=data.name, desc=collectOracleText(data), front=stripScryfallImageURI(data.image_uris.large), back=getCardBack()})
                end)
--                table.insert(savedata, {name=part.name, desc="", front=part.uri, back=getCardBack()})
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
                oracleText = card.oracleText,
                savedata = savedata
            }
        end
        card['doubleface'] = true
    elseif data.layout == "double_faced_token" then
        for i, face in ipairs(data.card_faces) do
            card['faces'][i] = {
                imageURI = stripScryfallImageURI(face.image_uris.large),
                name = getAugmentedName(face),
                oracleText = card.oracleText,
                savedata = savedata
            }
        end
        card['doubleface'] = false -- Not putting double-face tokens in double-face cards pile
    else
        card['faces'][1] = {
            imageURI = stripScryfallImageURI(data.image_uris.large),
            name = card.name,
            oracleText = card.oracleText,
            savedata = savedata
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

        -- TODO JSON.decode hangs the UI. Pull in a different JSON parser
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

        local card, tokens = parseCardData(cardID, data)

        onSuccess(card, tokens)
    end)
end

-- Queries card data for all cards.
-- TODO use the bulk api
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
