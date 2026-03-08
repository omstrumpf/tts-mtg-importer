"""
Builds the TTS mod JSON by inlining #include directives in loader.lua
and writing the result into the Workshop save file.

Usage: python build.py <workshop_dir>
  workshop_dir: path to the TTS Workshop folder containing 2163084841.json
"""
import json, os, re, sys

if len(sys.argv) != 2:
    print("Usage: python build.py <workshop_dir>")
    sys.exit(1)

repo = os.path.dirname(os.path.abspath(__file__))
workshop = sys.argv[1]
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
