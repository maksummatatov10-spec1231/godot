# Local changes — 2026-11-15

GPLv2 source and notices are retained. Local changes are reviewable in
`tools/plugin-integration.patch` at repository root:

- Offline mode is an explicit project-level policy: prevent helper auto-start,
  settings-signal restart and remote provider HTTP calls in this sandbox.
- Godot 4.7 editor font fallback avoids a missing main_bold theme font.
- Parent hidden status controls and disconnect the gallery node_added hook.
  Replace its self-referential Array/lambda cycle; free the main editor screen
  at shutdown. Full editor smoke now exits without resource/RID leaks.
- Two restricted BlendKit logo SVGs are replaced by newly drawn generic CC0
  symbols, not vendor trademarks. Poly Haven/ambientCG marks retain notices.

No helper executable is bundled (as in the supplied nobin archive). Remote
catalogs and external Sources indexing require network/client configuration
and are not claimed tested or operational in this restricted environment.
