# tts-mtg-importer
Tabletop Simulator script to import MTG decks

## Features
* Imports MTG decks from various deckbuilder websites into Tabletop Simulator
* Also supports importing from the in-game notebook
* Grabs related tokens
* Splits out sideboard, commander, etc. into separate piles

## Workshop Mod
Mod available on [steam workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=2163084841).

## Contributing
Load up the mod in tabletop simulator, and replace the existing script with your changes.

I recommend using [this atom plugin](https://atom.io/packages/tabletopsimulator-lua) that interfaces directly with the game - it makes script editing much more usable. Some shenanigans are required to get the #import statement to work properly - or, if you're lazy, simply inline `json_parser.lua` manually when saving to TTS.
