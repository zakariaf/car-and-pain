# ARB workflow — adding & translating string keys

The `packages/l10n/lib/l10n/` directory holds the gen-l10n inputs. `app_en.arb` is the
**template** (`template-arb-file: app_en.arb` in `l10n.yaml`); all keys and placeholder
metadata are declared there first, then mirrored into the other five files.

## The six ARB files (all must contain every key)

| File | Locale | Direction | Notes |
| --- | --- | --- | --- |
| `app_en.arb` | English | LTR | **Template** — source of truth for keys + `@` metadata |
| `app_de.arb` | German | LTR | Compound words expand; leave room, never fixed widths |
| `app_fr.arb` | French | LTR | |
| `app_fa.arb` | Persian/Farsi | RTL | |
| `app_ar.arb` | Arabic | RTL | Six plural forms: zero/one/two/few/many/other |
| `app_ckb.arb` | Sorani Kurdish | RTL | Material widget strings borrow `ar` via `CkbMaterialLocalizations` |

## Step-by-step

1. **Add to `app_en.arb` first.** The key, plus a `@key` object declaring every
   placeholder and its `type`. Only the template needs the `@` metadata block; the
   other locales carry only the translated message string.
2. **Mirror the key into the other five files** with a real translation, keeping the
   **exact placeholder names** and the **same ICU structure** (same plural/select
   branches, though branch bodies differ per language).
3. **Run parity check:** `scripts/check_arb_parity.sh` — reports any key present in the
   template but missing in a locale, any extra key, and any placeholder-name mismatch.
4. **Regenerate + analyze:** `scripts/run_gen_l10n.sh` (runs `flutter gen-l10n` /
   build_runner) then `flutter analyze`. A missing key is a compile error thanks to
   gen-l10n codegen — that is the safety net.
5. **Missing-key test:** before release, instantiate every `supportedLocale` and assert
   all keys resolve (no `MissingResource`).

## ICU — always, never concatenation

Plurals and word order differ across de/fa/ar/ckb; Arabic has all six CLDR plural
categories. Build them with ICU placeholders, never by gluing strings.

```json
{
  "reminderDueDays": "{count, plural, =0{Due today} =1{Due in 1 day} other{Due in {count} days}}",
  "@reminderDueDays": { "placeholders": { "count": { "type": "num" } } },

  "attachmentCount": "{n, plural, =0{No photos} =1{1 photo} other{{n} photos}}",
  "@attachmentCount": { "placeholders": { "n": { "type": "int" } } },

  "vehicleGreeting": "{vehicle}",
  "@vehicleGreeting": { "placeholders": { "vehicle": { "type": "String" } } }
}
```

- `select`/gender keys are **case-sensitive** — pass canonical lowercase keys.
- For Arabic, provide `zero`/`one`/`two`/`few`/`many`/`other` branches where the noun's
  grammar needs them, not just `=0/=1/other`.

## Placeholder typing

| ICU intent | `type` | Notes |
| --- | --- | --- |
| Plural / cardinal count | `num` or `int` | `int` for whole counts (photos), `num` for measured counts |
| Interpolated free text | `String` | e.g. vehicle nickname (UGC) — preserved verbatim |
| Formatted date | `DateTime` + `format` | Prefer projecting via the calendar formatter in `core`/`l10n`, not raw ARB date format, so calendar preference is honored |
| Formatted number/currency | `num` + `format` | Compose with the numeral formatter / ISO-4217 minor-unit model; render number and unit as separate isolated runs, never hand-concatenated |

## Money & units in strings

Money is integer minor units keyed to the ISO-4217 exponent (see the money doc) — never
a float. Render the amount and the currency symbol/unit as **separate isolated runs**
(or via `NumberFormat`'s currency pattern), never hand-glued into one placeholder.
Odometer/volume/pressure values are converted from canonical SI in `core` before they
reach the string.

## Pitfalls

- Adding a key to `app_en.arb` only — the other five silently fall back and ship English.
  `check_arb_parity.sh` catches this.
- Renaming a placeholder in one locale — breaks that translation at runtime. Keep names identical.
- Hand-building "1 day"/"2 days" — use ICU `plural`.
- Forgetting iOS `CFBundleLocalizations` for all six locales — the locale is not offered
  on iOS even though Android works.
