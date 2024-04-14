--Import of JSON library, skip to line 525 for the deck importer

-- From https://github.com/rxi/json.lua/blob/master/json.lua
--
--
-- json.lua
--
-- Copyright (c) 2020 rxi
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--

local json = { _version = "0.1.2" }

-------------------------------------------------------------------------------
-- Encode
-------------------------------------------------------------------------------

local encode

local escape_char_map = {
  [ "\\" ] = "\\",
  [ "\"" ] = "\"",
  [ "\b" ] = "b",
  [ "\f" ] = "f",
  [ "\n" ] = "n",
  [ "\r" ] = "r",
  [ "\t" ] = "t",
}

local escape_char_map_inv = { [ "/" ] = "/" }
for k, v in pairs(escape_char_map) do
  escape_char_map_inv[v] = k
end


local function escape_char(c)
  return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
end


local function encode_nil(val)
  return "null"
end


local function encode_table(val, stack)
  local res = {}
  stack = stack or {}

  -- Circular reference?
  if stack[val] then error("circular reference") end

  stack[val] = true

  if rawget(val, 1) ~= nil or next(val) == nil then
    -- Treat as array -- check keys are valid and it is not sparse
    local n = 0
    for k in pairs(val) do
      if type(k) ~= "number" then
        error("invalid table: mixed or invalid key types")
      end
      n = n + 1
    end
    if n ~= #val then
      error("invalid table: sparse array")
    end
    -- Encode
    for i, v in ipairs(val) do
      table.insert(res, encode(v, stack))
    end
    stack[val] = nil
    return "[" .. table.concat(res, ",") .. "]"

  else
    -- Treat as an object
    for k, v in pairs(val) do
      if type(k) ~= "string" then
        error("invalid table: mixed or invalid key types")
      end
      table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
    end
    stack[val] = nil
    return "{" .. table.concat(res, ",") .. "}"
  end
end


-- -*- coding: utf-8 -*-
--
-- Simple JSON encoding and decoding in pure Lua.
--
-- Copyright 2010-2017 Jeffrey Friedl
-- http://regex.info/blog/
-- Latest version: http://regex.info/blog/lua/json
--
-- This code is released under a Creative Commons CC-BY "Attribution" License:
-- http://creativecommons.org/licenses/by/3.0/deed.en_US
--
-- It can be used for any purpose so long as:
--    1) the copyright notice above is maintained
--    2) the web-page links above are maintained
--    3) the 'AUTHOR_NOTE' string below is maintained
--
-- local VERSION = '20170927.26' -- version history at end of file
-- local AUTHOR_NOTE = "-[ JSON.lua package by Jeffrey Friedl (http://regex.info/blog/lua/json) version 20170927.26 ]-"

--
-- The 'AUTHOR_NOTE' variable exists so that information about the source
-- of the package is maintained even in compiled versions. It's also
-- included in OBJDEF below mostly to quiet warnings about unused variables.
--
-- local OBJDEF = {
--    VERSION      = VERSION,
--    AUTHOR_NOTE  = AUTHOR_NOTE,
-- }

local function object_or_array(T)
   --
   -- We need to inspect all the keys... if there are any strings, we'll convert to a JSON
   -- object. If there are only numbers, it's a JSON array.
   --
   -- If we'll be converting to a JSON object, we'll want to sort the keys so that the
   -- end result is deterministic.
   --
   local string_keys = { }
   local number_keys = { }
   local number_keys_must_be_strings = false
   local maximum_number_key

   for key in pairs(T) do
      if type(key) == 'string' then
         table.insert(string_keys, key)
      elseif type(key) == 'number' then
         table.insert(number_keys, key)
         if key <= 0 or key >= math.huge then
            number_keys_must_be_strings = true
         elseif not maximum_number_key or key > maximum_number_key then
            maximum_number_key = key
         end
      elseif type(key) == 'boolean' then
         table.insert(string_keys, tostring(key))
      else
         error("can't encode table with a key of type " .. type(key))
      end
   end

   if #string_keys == 0 and not number_keys_must_be_strings then
      --
      -- An empty table, or a numeric-only array
      --
      if #number_keys > 0 then
         return nil, maximum_number_key -- an array
      elseif tostring(T) == "JSON array" then
         return nil
      elseif tostring(T) == "JSON object" then
         return { }
      else
         -- have to guess, so we'll pick array, since empty arrays are likely more common than empty objects
         return nil
      end
   end

   local map
   if #number_keys > 0 then

      --
      -- Have to make a shallow copy of the source table so we can remap the numeric keys to be strings
      --
      map = { }
      for key, val in pairs(T) do
         map[key] = val
      end

      --
      -- Throw numeric keys in there as strings
      --
      for _, number_key in ipairs(number_keys) do
         local string_key = tostring(number_key)
         if map[string_key] == nil then
            table.insert(string_keys , string_key)
            map[string_key] = T[number_key]
         else
            error("conflict converting table with mixed-type keys into a JSON object: key " .. number_key .. " exists both as a string and a number.")
         end
      end
   end

   return string_keys, nil, map
end


local function new_encode_table(val, stack)
    local res = {}
    stack = stack or {}

    local object_keys, maximum_number_key, map = object_or_array(val)
    if maximum_number_key then
       -- An array
       local ITEMS = { }
       for i = 1, maximum_number_key do
          table.insert(res, encode(val[i], stack))
       end
       stack[val] = nil
       return "["  .. table.concat(res, ",")  .. "]"
    elseif object_keys then
       -- An object
      local TT = map or val
      local PARTS = { }
      for _, key in ipairs(object_keys) do
         table.insert(res, encode(key, stack) .. ":" .. encode(TT[key], stack))
      end
      stack[val] = nil
      return "{" .. table.concat(res, ",") .. "}"
    else
       -- An empty array/object... we'll treat it as an array, though it should really be an option
       stack[val] = nil
       return "[]"
    end
end


local function encode_string(val)
  return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end


local function encode_number(val)
  -- Check for NaN, -inf and inf
  if val ~= val or val <= -math.huge or val >= math.huge then
    error("unexpected number value '" .. tostring(val) .. "'")
  end
  return string.format("%.14g", val)
end


local type_func_map = {
  [ "nil"     ] = encode_nil,
  [ "table"   ] = new_encode_table,
  [ "string"  ] = encode_string,
  [ "number"  ] = encode_number,
  [ "boolean" ] = tostring,
}


encode = function(val, stack)
  local t = type(val)
  local f = type_func_map[t]
  if f then
    return f(val, stack)
  end
  error("unexpected type '" .. t .. "'")
end


function jsonencode(val)
  return ( encode(val) )
end


-------------------------------------------------------------------------------
-- Decode
-------------------------------------------------------------------------------

local parse

local function create_set(...)
  local res = {}
  for i = 1, select("#", ...) do
    res[ select(i, ...) ] = true
  end
  return res
end

local space_chars   = create_set(" ", "\t", "\r", "\n")
local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars  = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals      = create_set("true", "false", "null")

local literal_map = {
  [ "true"  ] = true,
  [ "false" ] = false,
  [ "null"  ] = nil,
}


local function next_char(str, idx, set, negate)
  for i = idx, #str do
    if set[str:sub(i, i)] ~= negate then
      return i
    end
  end
  return #str + 1
end


local function decode_error(str, idx, msg)
  local line_count = 1
  local col_count = 1
  for i = 1, idx - 1 do
    col_count = col_count + 1
    if str:sub(i, i) == "\n" then
      line_count = line_count + 1
      col_count = 1
    end
  end
  error( string.format("%s at line %d col %d", msg, line_count, col_count) )
end


local function codepoint_to_utf8(n)
  -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
  local f = math.floor
  if n <= 0x7f then
    return string.char(n)
  elseif n <= 0x7ff then
    return string.char(f(n / 64) + 192, n % 64 + 128)
  elseif n <= 0xffff then
    return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
  elseif n <= 0x10ffff then
    return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
                       f(n % 4096 / 64) + 128, n % 64 + 128)
  end
  error( string.format("invalid unicode codepoint '%x'", n) )
end


local function parse_unicode_escape(s)
  local n1 = tonumber( s:sub(1, 4),  16 )
  local n2 = tonumber( s:sub(7, 10), 16 )
   -- Surrogate pair?
  if n2 then
    return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
  else
    return codepoint_to_utf8(n1)
  end
end


local function parse_string(str, i)
  local res = ""
  local j = i + 1
  local k = j

  while j <= #str do
    local x = str:byte(j)

    if x < 32 then
      decode_error(str, j, "control character in string")

    elseif x == 92 then -- `\`: Escape
      res = res .. str:sub(k, j - 1)
      j = j + 1
      local c = str:sub(j, j)
      if c == "u" then
        local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1)
                 or str:match("^%x%x%x%x", j + 1)
                 or decode_error(str, j - 1, "invalid unicode escape in string")
        res = res .. parse_unicode_escape(hex)
        j = j + #hex
      else
        if not escape_chars[c] then
          decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")
        end
        res = res .. escape_char_map_inv[c]
      end
      k = j + 1

    elseif x == 34 then -- `"`: End of string
      res = res .. str:sub(k, j - 1)
      return res, j + 1
    end

    j = j + 1
  end

  decode_error(str, i, "expected closing quote for string")
end


local function parse_number(str, i)
  local x = next_char(str, i, delim_chars)
  local s = str:sub(i, x - 1)
  local n = tonumber(s)
  if not n then
    decode_error(str, i, "invalid number '" .. s .. "'")
  end
  return n, x
end


local function parse_literal(str, i)
  local x = next_char(str, i, delim_chars)
  local word = str:sub(i, x - 1)
  if not literals[word] then
    decode_error(str, i, "invalid literal '" .. word .. "'")
  end
  return literal_map[word], x
end


local function parse_array(str, i)
  local res = {}
  local n = 1
  i = i + 1
  while 1 do
    local x
    i = next_char(str, i, space_chars, true)
    -- Empty / end of array?
    if str:sub(i, i) == "]" then
      i = i + 1
      break
    end
    -- Read token
    x, i = parse(str, i)
    res[n] = x
    n = n + 1
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "]" then break end
    if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
  end
  return res, i
end


local function parse_object(str, i)
  local res = {}
  i = i + 1
  while 1 do
    local key, val
    i = next_char(str, i, space_chars, true)
    -- Empty / end of object?
    if str:sub(i, i) == "}" then
      i = i + 1
      break
    end
    -- Read key
    if str:sub(i, i) ~= '"' then
      decode_error(str, i, "expected string for key")
    end
    key, i = parse(str, i)
    -- Read ':' delimiter
    i = next_char(str, i, space_chars, true)
    if str:sub(i, i) ~= ":" then
      decode_error(str, i, "expected ':' after key")
    end
    i = next_char(str, i + 1, space_chars, true)
    -- Read value
    val, i = parse(str, i)
    -- Set
    res[key] = val
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "}" then break end
    if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
  end
  return res, i
end


local char_func_map = {
  [ '"' ] = parse_string,
  [ "0" ] = parse_number,
  [ "1" ] = parse_number,
  [ "2" ] = parse_number,
  [ "3" ] = parse_number,
  [ "4" ] = parse_number,
  [ "5" ] = parse_number,
  [ "6" ] = parse_number,
  [ "7" ] = parse_number,
  [ "8" ] = parse_number,
  [ "9" ] = parse_number,
  [ "-" ] = parse_number,
  [ "t" ] = parse_literal,
  [ "f" ] = parse_literal,
  [ "n" ] = parse_literal,
  [ "[" ] = parse_array,
  [ "{" ] = parse_object,
}


parse = function(str, idx)
  local chr = str:sub(idx, idx)
  local f = char_func_map[chr]
  if f then
    return f(str, idx)
  end
  decode_error(str, idx, "unexpected character '" .. chr .. "'")
end


function jsondecode(str)
  if type(str) ~= "string" then
    error("expected argument of type string, got " .. type(str))
  end
  local res, idx = parse(str, next_char(str, 1, space_chars, true))
  idx = next_char(str, idx, space_chars, true)
  if idx <= #str then
    decode_error(str, idx, "trailing garbage")
  end
  return res
end

-------------------------------------------
-- Here begins the code for the importer --
-------------------------------------------

------ CONSTANTS
TAPPEDOUT_BASE_URL = "https://tappedout.net/mtg-decks/"
TAPPEDOUT_URL_SUFFIX = "/"
TAPPEDOUT_URL_MATCH = "tappedout%.net"

ARCHIDEKT_BASE_URL = "https://archidekt.com/api/decks/"
ARCHIDEKT_URL_SUFFIX = "/small/?format=json"
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
MAYBEBOARD_POSITION_OFFSET = {1.47, 0.2, 0.1286}
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
enableTokenButtons = false
blowCache = false
pngGraphics = true

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

local function stringToBool(s)
    -- It is truly ridiculous that this needs to exist.
    return (string.lower(s) == "true")
end

------ CARD SPAWNING
local function jsonForCardFace(face, position)
    local rotation = self.getRotation()

    local json = {
        Name = "Card",
        Transform = {
            posX = position.x,
            posY = position.y,
            posZ = position.z,
            rotX = rotation.x,
            rotY = rotation.y,
            rotZ = rotation.z,
            scaleX = 1,
            scaleY = 1,
            scaleZ = 1
        },
        Nickname = face.name,
        Description = face.oracleText,
        Locked = false,
        Grid = true,
        Snap = true,
        IgnoreFoW = false,
        MeasureMovement = false,
        DragSelectable = true,
        Autoraise = true,
        Sticky = true,
        Tooltip = true,
        GridProjection = false,
        HideWhenFaceDown = true,
        Hands = true,
        CardID = 2440000,
        SidewaysCard = false,
        CustomDeck = {},
        LuaScript = "",
        LuaScriptState = "",
     }

     json.CustomDeck["24400"] = {
         FaceURL = face.imageURI,
         BackURL = getCardBack(),
         NumWidth = 1,
         NumHeight = 1,
         BackIsHidden = true,
         UniqueBack = false,
         Type = 0
     }

     if enableTokenButtons and face.tokenData and face.tokenData[1] and face.tokenData[1].name and string.len(face.tokenData[1].name) > 0 then
         json.LuaScript =
            [[function onLoad(saved_data)
                if saved_data ~= "" then
                    tokens = JSON.decode(saved_data)
                else
                    tokens = {}
                end

                local pZ = -1.04
                for i, token in ipairs(tokens) do
                    self.createButton({label = token.name,
                        tooltip = "Create " .. token.name .. "\n" .. token.oracleText,
                        click_function = "gt" .. i,
                        function_owner = self,
                        width = math.max(400, 40 * string.len(token.name) + 40),
                        height = 100,
                        color = {1, 1, 1, 0.5},
                        hover_color = {1, 1, 1, .7},
                        font_color = {0, 0, 0, 2},
                        position = {.5, 0.5, pZ},
                        font_size = 75})
                    pZ = pZ + 0.28
                end
            end

            function onSave()
                return JSON.encode(tokens)
            end

            function gt1() getToken(1) end
            function gt2() getToken(2) end
            function gt3() getToken(3) end
            function gt4() getToken(4) end

            function getToken(i)
                token = tokens[i]
                spawnObject({
                    type = "Card",
                    sound = false,
                    rotation = self.getRotation(),
                    position = self.positionToWorld({-2.2,0.1,0}),
                    scale = self.getScale(),
                    callback_function = (function(obj)
                        obj.memo = ""
                        obj.setName(token.name)
                        obj.setDescription(token.oracleText)
                        obj.setCustomObject({
                            face = token.front,
                            back = token.back
                        })
                        if (parent) then
                          parent.call("CAddButtons",{obj, self})
                        end
                    end)
                })
            end
        ]]

        json.LuaScriptState=JSON.encode(face.tokenData)
     end

     return json
end

-- Spawns the given card [faces] at [position].
-- Card will be face down if [flipped].
-- Calls [onFullySpawned] when the object is spawned.
local function spawnCard(faces, position, flipped, onFullySpawned)
    if not faces or not faces[1] then
        faces = {{
            name = card.name,
            oracleText = "Card not found",
            imageURI = "https://vignette.wikia.nocookie.net/yugioh/images/9/94/Back-Anime-2.png/revision/latest?cb=20110624090942",
        }}
    end

    local jsonFace1 = jsonForCardFace(faces[1], position, flipped)

    if #faces > 1 then
        jsonFace1.States = {}
        for i=2,(#(faces)) do
            local jsonFaceI = jsonForCardFace(faces[i], position, flipped)

            jsonFace1.States[tostring(i)] = jsonFaceI
        end
    end

    local cardObj = spawnObjectJSON({json = JSON.encode(jsonFace1)})

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

            incSem()
            spawnCard(card.faces, position, flipped, function(obj)
                table.insert(cardObjects, obj)
                decSem()
            end)
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

local function pickImageURI(cardData, highres_image, image_status)
    if not cardData or not cardData.image_uris then
        return ""
    end

    local highres_image
    if highres_image == nil then
        highres_image = cardData.highres_image
    end

    local image_status
    if image_status == nil then
        image_status = cardData.image_status
    end

    if pngGraphics and cardData.image_uris.png then
        uri = stripScryfallImageURI(cardData.image_uris.png)
    else
        uri = stripScryfallImageURI(cardData.image_uris.large)
    end

    local sep
    if uri:find("?") then
        sep = "&"
    else
        sep = "?"
    end

    if blowCache then
        local cachebuster = string.gsub(tostring(Time.time), "%.", "-")

        uri = uri .. sep .. "CACHEBUSTER_" .. cachebuster
    elseif (not highres_image) or image_status != "highres_scan" then
        uri = uri .. sep .. "LOWRES_CACHEBUSTER"
    end

    return uri
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

local function parseCardData(cardID, data)
    local card = shallowCopyTable(cardID)

    card.name = getAugmentedName(data)
    card.oracleText = collectOracleText(data)
    card.faces = {}
    card.scryfallID = data.id
    card.oracleID = data.oracle_id
    card.language = data.lang
    card.setCode = data.set
    card.collectorNum = data.collector_number

    if data.layout == "transform" or data.layout == "art_series" or data.layout == "double_sided" or data.layout == "modal_dfc" or data.layout == "double_faced_token" then
        for i, face in ipairs(data.card_faces) do
            card.faces[i] = {
                imageURI = pickImageURI(face, data.highres_image, data.image_status),
                name = getAugmentedName(face),
                oracleText = card.oracleText
            }
        end
    else
        card.faces[1] = {
            imageURI = pickImageURI(data),
            name = card.name,
            oracleText = card.oracleText
        }
    end

    return card
end

-- Parses scryfall response data for a card.
-- Queries for tokens and associated cards.
-- onSuccess is called with a populated card table, and list of tokens.
local function handleCardResponse(cardID, data, onSuccess, onError)
    local sem = 0
    local function incSem() sem = sem + 1 end
    local function decSem() sem = sem - 1 end

    local tokens = {}
    local tokenDataForButtons = {}

    local function addToken(name, uri)
        incSem()

        WebRequest.get(uri, function(webReturn)
            if webReturn.is_error or webReturn.error or string.len(webReturn.text) == 0 then
                log("Error fetching token: " ..webReturn.error or "unknown")
                decSem()
                return
            end

            local success, data = pcall(function() return jsondecode(webReturn.text) end)
            if not success or not data or data.object == "error" then
                log("Error fetching token: JSON Parse")
                decSem()
                return
            end

            local token = parseCardData({}, data)

            token.name = name

            table.insert(tokens, token)

            -- Store pared down token data for token buttons
            local front
            local back
            if token.faces[1] then
                front = token.faces[1].imageURI
            end
            if token.faces[2] then
                back = token.faces[2].imageURI
            else
                back = getCardBack()
            end

            table.insert(tokenDataForButtons, {
                name = token.name,
                oracleText = token.oracleText,
                front = front,
                back = back,
            })

            decSem()
        end)
    end

    -- On normal cards, check for tokens or related effects (i.e. city's blessing)
    if data.all_parts and not (data.layout == "token" or data.type_line == "Card") then
        for _, part in ipairs(data.all_parts) do
            if part.component and (part.type_line == "Card" or part.component == "token") then
                addToken(part.name, part.uri)
            -- shorten name on emblems
            elseif part.component and (string.sub(part.type_line,1,6) == "Emblem" and not (string.sub(data.type_line,1,6) == "Emblem")) then
                addToken("Emblem", part.uri)
            end
        end
    end

    local card = parseCardData(cardID, data)

    -- Store token data on each face
    for _, face in ipairs(card.faces) do
        face.tokenData = tokenDataForButtons
    end

    Wait.condition(
        function() onSuccess(card, tokens) end,
        function() return (sem == 0) end,
        30,
        function() onError("Error loading card data... timed out.") end
    )
end

-- Queries scryfall by the [cardID].
-- cardID must define at least one of scryfallID, multiverseID, or name.
-- if forceNameQuery is true, will query scryfall by card name ignoring other data.
-- if forceSetNumLangQuery is true, will query scryfall by set/num/lang ignoring other data.
-- onSuccess is called with a populated card table, and a table of associated tokens.
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

        local success, data = pcall(function() return jsondecode(webReturn.text) end)

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

        handleCardResponse(cardID, data, onSuccess, onError)
    end)
end

-- Queries card data for all cards.
-- TODO use the bulk api (blocked by JSON decode issue)
local function fetchCardData(cards, onComplete, onError)
    local sem = 0
    local function incSem() sem = sem + 1 end
    local function decSem() sem = sem - 1 end

    local cardData = {}
    local tokensData = {}

    local function onQuerySuccess(card, tokens)
        table.insert(cardData, card)
        for _, token in ipairs(tokens) do
            table.insert(tokensData, token)
        end
        decSem()
    end

    local function onQueryFailed(e)
        log("Error querying scryfall: " .. e)
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
                    end)
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
            end)
    end

    Wait.condition(
        function() onComplete(cardData, tokensData) end,
        function() return (sem == 0) end,
        30,
        function() onError("Error loading card images... timed out.") end
    )
end

-- Queries for the given card IDs, collates deck, and spawns objects.
local function loadDeck(cardIDs, deckName, onComplete, onError)
    local maindeckPosition = self.positionToWorld(MAINDECK_POSITION_OFFSET)
    local sideboardPosition = self.positionToWorld(SIDEBOARD_POSITION_OFFSET)
    local maybeboardPosition = self.positionToWorld(MAYBEBOARD_POSITION_OFFSET)
    local commanderPosition = self.positionToWorld(COMMANDER_POSITION_OFFSET)
    local tokensPosition = self.positionToWorld(TOKENS_POSITION_OFFSET)

    printInfo("Querying Scryfall for card data...")

    fetchCardData(cardIDs, function(cards, tokens)
        local maindeck = {}
        local sideboard = {}
        local maybeboard = {}
        local commander = {}

        for _, card in ipairs(cards) do
            if card.maybeboard then
                table.insert(maybeboard, card)
            elseif card.sideboard then
                table.insert(sideboard, card)
            elseif card.commander then
                table.insert(commander, card)
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

        spawnDeck(sideboard, deckName .. " - sideboard", sideboardPosition, true,
            function() -- onSuccess
                decSem()
            end,
            function(e) -- onError
                printErr(e)
                decSem()
            end
        )

        spawnDeck(maybeboard, deckName .. " - maybeboard", maybeboardPosition, true,
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

        local success, data = pcall(function() return jsondecode(webReturn.text) end)

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

        local function isMaybeboard(card)
            if card.categories and card.categories[1] then
                local firstCategory = card.categories[1]

                for _, category in ipairs(data.categories) do
                    if category.name == firstCategory then
                        if not category.includedInDeck then
                            return true
                        end
                    end
                end

                return false
            end
        end

        local cards = {}

        for i, card in ipairs(data.cards) do

            if card and card.card then
                cards[#cards+1] = {
                    count = card.quantity,
                    sideboard = valInTable(card.categories, "Sideboard"),
                    maybeboard = isMaybeboard(card),
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

        local success, data = pcall(function() return jsondecode(webReturn.text) end)

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

        for name, cardData in pairs(data.maybeboard or {}) do
            if cardData.card and not commanderIDs[cardData.card.id] then
                table.insert(cards, {
                    name = cardData.card.name,
                    count = cardData.quantity,
                    scryfallID = cardData.card.id,
                    sideboard = false,
                    maybeboard = true,
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
        log("Error: Deck import started while importer locked.")
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
        log("Error. Unknown deck source: " .. deckSource or "nil")
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
    forceLanguage = stringToBool(value)
end

function mtgdl__onTokenButtonsInput(_, value, _)
    enableTokenButtons = stringToBool(value)
end

function mtgdl__onBlowCacheInput(_, value, _)
    blowCache = stringToBool(value)
end

function mtgdl__onPNGgraphics(_, value, _)
    pngGraphics = stringToBool(value)
end

------ TTS CALLBACKS
function onLoad()
    self.setName("MTG Deck Loader")

    self.setDescription(
    [[
Enter your deck URL from many online deck builders!

You can also paste a decklist in MTG Arena format into your color's notebook.

Currently supported sites:
 - tappedout.net
 - archidekt.com
 - moxfield.com
 - deckstats.net
]])

    drawUI()
end
