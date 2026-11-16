# Art, audio and control references

## Included source art — CC0

**Ninja Adventure**, Pixel-boy & AAA / Pixel Archipel.

- https://pixel-boy.itch.io/ninja-adventure-asset-pack
- https://www.patreon.com/pixelarchipel
- License: **CC0 1.0 Universal**, complete text in `assets/ninja/LICENSE.txt`.
- Selected from the user's verified archive (source MD5 and selected file SHA256s:
  `assets/intake.json`). Only 19 source files are retained; unrelated packs are not used.
- Source tiles were assembled into the village/forest; one roof was palette-adjusted.
- Expanded green hero, five tool layers, traveller/portrait, flowers and water ripples
  come from this same pack. No Undertale art, characters, music or dialogue is included.

## Original work

Map layout/assembly, continuous farm fence/corner posts, wooden crates, shore platform,
lantern posts, counter details, live projected shadows, sunlight shader, fountain,
fox/rabbit pixel sheets, synthesised woodland audio,
action tones, interface, lighting/leaf effects, code and Russian story were created
for this project. Wildlife sheets and fountain follow the source palette; they are
not claimed to be original Ninja Adventure assets. Procedural world images are reproducible
with `tools/build_lantern_map.py` from the parent repository. The replacement 0.1.6
wildlife sheets (32px, four directions, idle/walk/bound, twelve phases per cycle)
are original CC0-1.0 work, reproducible independently with
`tools/build_lantern_wildlife.py`; layout metadata is `assets/world/wildlife.json`.
Inspected external wildlife references were NOT incorporated into these sheets. Audio is simple original
noise/chirp synthesis, not a field recording or licensed soundtrack.

## Dialogue controls research

GameFAQs, *Undertale — Controls*, accessed for this implementation:
https://gamefaqs.gamespot.com/pc/180989-undertale/faqs/81196/controls

Reference mapping: arrows = movement, Z = confirm/interact, X = cancel/skip text,
C = menu. This game's additions: WASD, tool actions, lantern pulse, Esc pause and
clickable interaction button. The dialogue is inspired by portrait/typewriter
presentation, not a reproduction of Undertale content.

## Foundation 0.2.0

All original procedural environment details and wildlife were redrawn for this
revision in `tools/lantern_original_art.py` and `tools/build_lantern_wildlife.py`;
Ninja Adventure source PNGs remain unmodified. Original sprite work is CC0-1.0.
The prologue/menu illustration `assets/story/valley-memory.png` is AI-generated
imagery made for this project; it is not a Ninja Adventure or Undertale asset,
and is not reproducible by the procedural sprite builders. Prologue text is
original. No Undertale story, sprites, soundtrack or fonts were copied.

Implementation references: Godot documentation (data paths, saving games, 2D
lighting), Pixelbook/Pixnote pixel-animation guides; research and specific
engineering decisions are recorded in `docs/evidence/lantern-foundation/AUDIT.md`.
