# Where the game's content comes from

Metrobits carries only the cities, pictures, sounds and text the game uses. Each file is listed below with the file it comes from in `micropolis-activity`, Electronic Arts' 2008 open-source release of Micropolis. That release's README puts all of its non-text files under the GNU General Public License, version 3, with Electronic Arts' additional terms (`MicropolisGPLLicenseNotice.md`).

How to read the second column:

- **The same pixels:** the picture is identical to the original.
- **A shade off:** one or two pixels differ by a single step of colour, from converting the file.
- **The same bytes, or a percentage:** a city file that matches the original exactly, or almost exactly.
- **MicropolisCore's own:** a text file MicropolisCore wrote to hold the original game's text.

The table is written by `packaging/trace_content.py`. The original game files that the game reads directly are listed in `olpc/PROVENANCE.md`.

