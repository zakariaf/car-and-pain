# ♿ Accessibility & Inclusive Design

> The pain of a "feature-complete" car app that a low-vision, motor-impaired, colour-blind, or screen-reader user simply cannot operate — where the richest data in the world is locked behind unlabelled buttons, clipped text, and colour-only charts.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Localization, RTL & Calendars](./19-localization-rtl.md) · [Dashboard, Statistics & Reports](./17-dashboard-statistics-reports.md) · [Settings & Preferences](./21-settings-preferences.md)

## The pain

Most car-ownership apps treat accessibility as a checkbox for the app-store listing, not as something anyone actually tests. The result is familiar: charts that convey MPG trends purely through red-vs-green lines a colour-blind owner can't tell apart; odometer and cost fields with no screen-reader labels, so a blind driver logging a fill-up hears "button, button, button"; layouts that clip the moment someone bumps up their system font size, hiding the very numbers they came to check; and forms that fail validation silently, leaving a low-vision user staring at a screen that "just won't save." For an app that promises to hold years of a person's financial and legal vehicle history, being unusable to part of the population isn't a cosmetic gap — it's a data-ownership failure. This module makes accessibility a first-class, tested peer of localization, so the "most complete" car app is genuinely usable by everyone.

## What it does

The Accessibility layer is shared infrastructure, not a per-screen afterthought. It provides screen-reader labels and correct reading order (including in mirrored RTL layouts), dynamic-type reflow that survives Arabic elongation and German/Russian word expansion, high-contrast and colour-blind-safe palettes with non-colour encodings, reduced-motion handling, guaranteed minimum touch targets, and disciplined focus management — all applied uniformly across screens, charts, notifications, help, pickers, and exports.

Crucially, accessibility and internationalisation are treated as peers that interact rather than as separate silos. A single QA harness mirrors the RTL/pseudolocale harness used by [Localization, RTL & Calendars](./19-localization-rtl.md), so every accessibility guarantee is re-validated in every supported language, calendar, and numeral system. That pairing is what prevents the classic regression where a layout that reads perfectly in English screen-reader order becomes nonsense once mirrored for Persian or Arabic.

## Features

### ✅ Must-have

- **Screen-reader labelling on everything interactive and data-bearing** — Every button, toggle, list row, and displayed value carries a meaningful VoiceOver (iOS) and TalkBack (Android) label, so no control is ever announced as a bare "button" and every logged number is spoken with its meaning and unit.
- **Accessible RTL reading order** — In mirrored right-to-left layouts, the screen reader announces elements in *logical* order (the order a Persian or Arabic reader expects), never in the raw visual left-to-right sequence the mirror produces on screen.
- **Dynamic type / font scaling without clipping** — Text reflows cleanly as the user scales system font size up, and this is tested specifically against the hardest cases: Arabic elongation (kashida), long German compound words, and Russian expansion — so bigger text never truncates or overlaps.
- **Colour-blind-safe chart palettes with non-colour encodings** — Charts and series are distinguishable without relying on colour alone, using labels, patterns, markers, and direct value annotations, so trends remain readable to deuteranopia/protanopia/tritanopia users and in greyscale.
- **High-contrast mode and WCAG AA contrast** — A high-contrast option plus baseline colour choices that meet WCAG AA contrast ratios for text and essential UI, keeping the app legible in bright sunlight at the pump and for low-vision users alike.
- **Minimum touch-target sizes on all controls** — Every tappable control meets a minimum target size, so buttons stay reliably hittable — including for users with tremor or reduced dexterity, and including dense list and fleet views.
- **Reduced-motion honouring the OS preference** — When the operating system's "reduce motion" setting is on, non-essential animations and transitions are suppressed automatically, protecting users with vestibular sensitivity from motion-triggered discomfort.
- **Meaningful focus order and visible focus indicators** — Keyboard, switch, and screen-reader focus moves through the interface in a logical sequence with a clearly visible focus indicator, so users always know where they are.

### 🔵 Should-have

- **Accessible form errors and validation announcements** — When a field is invalid or a save fails, the error is announced to the screen reader and tied to the offending field, so the reason is spoken rather than shown only as a silent colour change.
- **Alt-text and labels for photos, charts, and diagrams** — Receipt photos, chart images, the odometer illustration, and the wheel/tire diagram all carry descriptive alternative text, so their meaning is available to users who can't see the image.
- **Screen-reader-friendly data tables and reports** — Statistics tables and report structures expose proper row/column semantics and header associations, so a screen-reader user can navigate a cost or economy table cell-by-cell with context, not as an undifferentiated wall of numbers.
- **Voice quick-actions and Watch/Wear one-tap entry** — Low-friction alternatives to the full form: voice quick-actions and a Watch/Wear one-tap capture let users log a fill-up or reading without navigating the whole app — valuable for motor-impaired users and hands-busy moments alike.
- **Haptic and audio feedback options** — Optional haptic and audio cues confirm actions (save, error, reminder) through non-visual channels, reinforcing what happened for users who can't rely on on-screen confirmation.
- **Scalable icons and layouts free of fixed widths** — Icons scale with text and layouts avoid hard-coded widths, so nothing breaks when type is enlarged or a translated string runs long.
- **Accessible date and number pickers across all calendars and numeral systems** — The pickers used to enter dates and numbers stay fully accessible whether the user is on Gregorian, Jalali/Shamsi, Hijri, or Hebrew calendars, and whether numerals are Western, Eastern-Arabic, Persian, or Devanagari.

### ⚪ Nice-to-have

- **Switch-control and external-keyboard navigation** — Full operability via iOS/Android switch control and a paired external keyboard, so users who navigate without touch can reach every function.
- **Screen-reader tutorial / accessibility onboarding** — A guided introduction that orients screen-reader and assistive-tech users to the app's gestures and layout, lowering the first-run learning curve.
- **Simplified / large-text mode** — An optional stripped-down, large-text presentation for users who want maximum legibility and minimum visual complexity.
- **Read-aloud of key summaries** — On-demand read-aloud of the important summaries — reminder details and red/amber/green compliance status — so critical information can be heard rather than read.
- **Dyslexia-friendly font option** — An optional typeface tuned for dyslexic readers, giving users who benefit from it a more comfortable reading experience.

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `a11y_prefs.high_contrast` | bool | Whether high-contrast mode is enabled. |
| `a11y_prefs.reduced_motion` | bool | App-level reduced-motion, layered over the OS preference. |
| `a11y_prefs.text_scale` | number (factor) | User's chosen text-scaling factor driving reflow constraints. |
| `a11y_prefs.bold_text` | bool | Bold-text preference for improved legibility. |
| `a11y_prefs.haptics` | bool | Whether haptic/audio feedback is enabled. |
| `semantic_label` | text | Localized screen-reader label for an element or value. |
| `accessibility_role` | enum | Role exposed to assistive tech (button, header, image, adjustable, etc.). |
| `focus_order` | number | Logical focus/reading-order index, resolved per layout direction. |
| `alt_text` | text | Localized alternative text for photos, charts, and diagrams. |
| `palette_mode` | enum | Chart/colour palette mode, including the `colorblind_safe` option. |
| `min_touch_target` | number+unit | Enforced minimum hit-target dimension for controls. |

## Calculations & formulas

- **Contrast-ratio validation against WCAG thresholds** — Foreground/background pairs are checked so their computed ratio meets the AA target, e.g. `contrast_ratio(fg, bg) >= 4.5` for normal text (`>= 3.0` for large text/essential UI); failures are flagged in the QA harness.
- **Text-scale reflow constraints** — Layout budgets are derived from the active scale factor to avoid truncation, e.g. `max_lines(scale, container)` and a rule enforcing `rendered_text_width <= container_width` after wrapping, so enlarged or expanded strings reflow instead of clipping.
- **Palette selection for distinguishable series** — The chart palette is chosen so every series remains separable without colour reliance: `perceptual_distance(series_i, series_j) >= min_delta` across colour-blind simulations, with pattern/label fallbacks applied when the distance budget can't be met by colour alone.

## Offline & data

Accessibility is entirely on-device and works identically in airplane mode — there is no cloud dependency, no account, and no telemetry involved in rendering labels, computing contrast, or applying palettes. All accessibility preferences (`a11y_prefs`) live in the local settings store and take effect instantly with zero connectivity.

Because these are user preferences, they are included in the single-file full backup and the combined JSON export alongside every other setting, and they are restored by the merge-aware restore — so a user who has carefully tuned high-contrast, text scale, reduced-motion, and colour-blind-safe palettes doesn't have to re-configure everything after migrating to a new device. Semantic labels and alt-text are generated from canonical, localized data at render time rather than stored per-record, so they stay correct after any unit, currency, calendar, or language switch.

## Localization & RTL

Accessibility strings are not an English-only afterthought: every screen-reader label, announcement, error message, and alt-text is fully localized across all supported languages and rendered correctly in RTL. Screen-reader pronunciation is handled for *localized* content — Eastern-Arabic/Persian/Devanagari numerals, per-preference units, dates across all four calendars (Gregorian/Jalali/Hijri/Hebrew), and base/display currency are all spoken correctly rather than as raw glyphs.

Dynamic-type resilience is validated against the specific typographic stress cases that break naive layouts: Arabic elongation, German and Russian word expansion, and Nastaliq line height. RTL introduces the module's sharpest interaction — reading order must follow *logical* sequence, not the visual mirror — which is why this module and [Localization, RTL & Calendars](./19-localization-rtl.md) are treated as peers sharing one QA harness. Identifiers that must stay LTR (VIN, plate, phone, IBAN) remain bidi-isolated so the screen reader announces them coherently even inside an otherwise RTL sentence.

## Edge cases

- **Screen reader in RTL announces logical order** — In mirrored layouts the reading order follows the language's logical sequence, never the on-screen visual mirror, so Persian/Arabic users hear content in the order they expect.
- **Max-scale dynamic type never clips Arabic elongation or German compounds** — At the largest text scale, elongated Arabic and long German compound words still reflow within their containers without truncation or overlap.
- **Charts stay interpretable in greyscale and for colour-blind users** — Every chart remains readable when colour information is removed or perceived differently, thanks to labels, patterns, and non-colour encodings.
- **Reduced-motion disables non-essential animation and chart transitions** — With reduced-motion active, decorative animations and chart entry/transition effects are suppressed while essential feedback remains.
- **Touch targets stay adequate in dense fleet/list views** — Even in tightly packed fleet and multi-vehicle lists, controls preserve their minimum hittable size.
- **Localized accessibility strings exist for every supported language** — No language ships with missing labels or announcements; the harness treats an untranslated accessibility string as a defect.
- **Accessibility and i18n interact and are QA'd together** — The accessibility QA harness mirrors the RTL/pseudolocale harness, so every guarantee is re-checked across languages, calendars, and numeral systems rather than only in English.

## Related features

- **[Localization, RTL & Calendars](./19-localization-rtl.md)** — The peer module and shared QA harness; RTL mirroring, calendars, and numeral shaping are where accessibility is most tightly co-tested.
- **[Dashboard, Statistics & Reports](./17-dashboard-statistics-reports.md)** — The home of colour-blind-safe palettes, chart alt-text, and screen-reader-friendly data tables.
- **[Settings & Preferences](./21-settings-preferences.md)** — Where `a11y_prefs` (high-contrast, reduced-motion, text scale, bold text, haptics, palette mode) are exposed and toggled.
- **[Reminders & Notifications](./04-reminders-notifications.md)** — Consumes accessible announcements and the read-aloud of key reminder summaries and compliance status.
- **[Data, Offline, Backup & Portability](./18-data-offline-backup.md)** — Carries accessibility preferences through backup, export, and merge-aware restore so tuned settings survive a device move.
- **[Onboarding, Help & Education](./25-onboarding-help.md)** — Hosts the screen-reader tutorial and accessibility onboarding for assistive-tech users.
