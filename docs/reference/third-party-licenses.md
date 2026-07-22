# Third-party licenses & store-compliance manifest

Car and Pain ships **no runtime network tier and no telemetry**; this manifest
records the redistributable third-party *assets* bundled into the app binary.
Runtime Dart/Flutter package licenses are surfaced automatically by Flutter's
`showLicensePage`; bundled **fonts** are registered into that same page by
`registerFontLicenses()` (see `packages/design_system/lib/src/theme/font_licenses.dart`,
called from `bootstrap()`).

## Bundled fonts (F4-T6)

Two variable font families cover all six launch locales. Both are under the
**SIL Open Font License 1.1 (OFL)**, which permits bundling and redistribution
inside an application.

| Family | Script coverage | Locales | License | Source | File | Size |
|---|---|---|---|---|---|---|
| **Hanken Grotesk** | Latin | en, de, fr | OFL 1.1 | google/fonts `ofl/hankengrotesk` | `packages/design_system/fonts/HankenGrotesk-VF.ttf` | ~130 KB |
| **Vazirmatn** | Arabic (incl. Persian & Sorani letterforms; Eastern-Arabic/Persian digits) | fa, ar, ckb | OFL 1.1 | google/fonts `ofl/vazirmatn` (rastikerdar/vazirmatn) | `packages/design_system/fonts/Vazirmatn-VF.ttf` | ~236 KB |

- **Total added binary weight:** ~373 KB (variable fonts, all weights in one
  file each). The full OFL texts live beside the fonts as
  `*-OFL.txt` and are bundled as assets so the licenses page shows them verbatim.
- **Fallback chain:** the theme sets `fontFamily = Hanken Grotesk` with
  `fontFamilyFallback = [Vazirmatn]`, so Latin runs render in Hanken Grotesk and
  any Arabic-script codepoint it lacks falls back per-glyph to Vazirmatn.
  F4-T2 additionally makes Vazirmatn the *primary* family under an Arabic-script
  locale (fa/ar/ckb) for consistent metrics.
- **Subsetting:** not applied — no `pyftsubset`/fonttools in the toolchain at
  build time, and the variable fonts are already compact (~373 KB combined).
  Glyph-range subsetting remains an available size optimization (tracked as a
  follow-up); it does not change coverage or licensing.

### Why these fonts
- **Hanken Grotesk** — a humanist grotesque that reads as calm and modern for the
  Latin locales, matching the PULSE tone.
- **Vazirmatn** — a comprehensive, actively-maintained Arabic-script family with
  proper Persian (ی ک گ) and Sorani Kurdish (ڕ ڵ ۆ ێ) letterforms and native
  Eastern-Arabic/Persian digit glyphs, so numeral shaping (F4-T4) renders
  correctly without tofu.

## Policy

Any new bundled asset (font, icon set, sound, dataset) must be added to this
table with its license, source, and redistribution terms **before** merge, and
its license text must be registered so it appears on the in-app licenses page.
Copyleft or non-redistributable assets are not permitted in the binary.
