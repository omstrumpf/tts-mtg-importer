"""
Builds the TTS mod JSON by inlining #include directives in loader.lua
and writing the result into the Workshop save file.
"""
import json, os, re

repo = os.path.dirname(os.path.abspath(__file__))
workshop = r"C:\Users\austin\Documents\My Games\Tabletop Simulator\Mods\Workshop"
json_path = os.path.join(workshop, "2163084841.json")

def resolve_includes(lua_text, base_dir):
    def replacer(match):
        filename = match.group(1).strip() + ".lua"
        path = os.path.join(base_dir, filename)
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    return re.sub(r"^#include\s+(.+)$", replacer, lua_text, flags=re.MULTILINE)

with open(os.path.join(repo, "loader.lua"), "r", encoding="utf-8") as f:
    lua = f.read()

lua = resolve_includes(lua, repo)

with open(json_path, "r", encoding="utf-8") as f:
    data = json.load(f)

data["ObjectStates"][0]["LuaScript"] = lua

with open(json_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("Done — built and written to", json_path)
