# Clean-ZIP edge-case review — before final save-position correction

The published 0.2.0 ZIP imports and passes 11,990 game checks + 50 writer/27 independent-reader checks from a fresh isolated user-data directory; 137 source files match exactly. Additional source review found one edge case not covered by those tests:

- `safe_position()` uses an expanded rectangle margin of 5px, whereas the real collision shape is a circle of radius 4px at actor Y-3. A physically valid save immediately beside a wall can therefore incorrectly fall back to the square. Expanded rectangles also falsely reject space near their outer corners.

Correct with exact point-to-AABB nearest-distance for the actual 4px foot circle. Add regression checks for valid wall contact and a clear corner, while preserving the inside-solid fallback. This requires a fresh evidence digest/release (0.2.1), not relabelling the 0.2.0 validation. No map or collision geometry changes.

The first corner regression fixture at X448 was itself occupied by the nearby pot
(rect 440,387,9,6), so rejecting it was correct. Moved the clear-corner fixture to
the opposite facade corner X512. Kept all three regression assertions. Premature
CI attempts 43936864925/43936864434 were cancelled; no 0.2.1 release from those runs.
