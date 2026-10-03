# The engine: MicropolisCore

Metrobits runs on the C++ engine from [MicropolisCore](https://github.com/SimHacker/MicropolisCore), the open-source line of Micropolis. Two of its folders are copied here:

| Folder here | Copied from MicropolisCore | What it holds |
|---|---|---|
| `engine/` | `packages/micropolis-engine/src` | the simulation |
| `content/` | `content/micropolis` | the game's cities, pictures, sounds and text |

We use MicropolisCore as it was at commit `2bfe12a`, from 18 September 2026. MicropolisCore builds the engine for web browsers; we build it for the Mac, leaving out its two browser-only files, `emscripten.cpp` and `callback.cpp`.

## Licence

Micropolis is free software under the GNU General Public License, version 3 (`LICENSE`), with additional terms from Electronic Arts (`MicropolisGPLLicenseNotice.md`). The name Micropolis is a trademark of Micropolis GmbH, used under `MicropolisPublicNameLicense.md`. Every picture, sound and city the app carries is traced back to Electronic Arts' 2008 open-source release in `CONTENT-PROVENANCE.md`.

## What we changed

We changed the engine in 13 places. In the code, each change is marked with a comment that starts "Metrobits local edit" and its number:

| # | File | What changed |
|---|---|---|
| 1 | `fileio.cpp` | Loading a scenario no longer builds text from an empty pointer, which crashed the game outside a web browser. |
| 2 | `sprite.cpp` | Moving things, such as planes and ships, are set up properly before they're used, which stops a crash on some systems. |
| 3 | `evaluate.cpp` | The yearly poll on the city's worst problems no longer reads past the end of its list, a bug from 1989. |
| 4 | `micropolis.cpp` | New memory starts out empty, so saved cities never pick up stray data. |
| 5 | `random.cpp`, `micropolis.h` | The random numbers can start from a fixed value, so a game can be replayed exactly. The tests use this. |
| 6 | `message.cpp` | Each message plays its sound again and, with Auto Goto on, moves the map to the trouble, as the 1989 game did. |
| 7 | `message.cpp`, `micropolis.h`, `initialize.cpp` | A repeated warning, such as pollution or traffic, shows once until a different one arrives, as in 1989. |
| 8 | `budget.cpp`, `micropolis.h` | A change to the money for roads, police or fire takes effect straight away, as the 1989 budget did. |
| 9 | `sprite.cpp`, `micropolis.h` | The Air Crash disaster is back, for the Disasters menu. |
| 10 | `initialize.cpp` | Loading a city clears what the previous city left behind, so a city plays the same however it's loaded. |
| 11 | `fileio.cpp` | Saved cities store their 32-bit numbers as 32 bits on every system, so saving on a Mac no longer damages two of the city's history values. |
| 12 | `sprite.cpp` | The monster appears where it did in 1989: in the middle of the map, and only when the map has river water. |
| 13 | `micropolis.cpp` | Closing the engine frees its moving things, so it no longer leaks memory. |
