# design_system (PULSE)

The PULSE design system — *"a vitals chart for your car"*. Warm-paper (day) / ink
(night) dual theme over a Persian-miniature palette. Centralizes RTL geometry and
the redundant-encoding status rule so features never reimplement them.

## F1 scope

- **Tokens** (`PulseTokens`, `PulseColors`, `PulseColorsExt`) — the temperature
  ramp (u0..u4, halo capped at u2), neutrals, spacing (8px grid), radii, motion.
- **Dual theme** (`pulseLightTheme` / `pulseDarkTheme`) — Material 3 `ColorScheme`
  + the PULSE `TextTheme`; extended neutrals ride the tree via `PulseColorsExt`.
- **`StatusBadge`** — the reference implementation of the redundant-encoding rule.

## The non-negotiable: status is NEVER colour alone

Every status is encoded **redundantly** in at least two of {icon, text label,
shape/position}, so the app is fully operable in greyscale and for colour-blind
users. `StatusBadge` pairs a distinct **icon** (check / triangle-alert / bell)
with the **text label**; the temperature tint is decoration behind an AA-safe
foreground. Warmth is mood, never signal.

## Directional-only geometry

Use `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`,
`TextAlign.start/end`, `Icons.adaptive.*` — **never** `EdgeInsets.left/right`,
`Alignment.centerLeft`, `Positioned(left:)`, or `TextAlign.left/right`. A CI grep
rejects the banned forms in this package and feature code.

## Arriving later

- **F3** — Rooms scaffolding, the single breathing vitals hero (CustomPainter),
  the capped ambient halo + concentrated ache card, the exhale interaction,
  `PulseScaffold`, and `Semantics`-annotated charts (no chart library).
- **F4** — bundled Vazirmatn/Noto fonts + the fa/ar/ckb type overrides.
