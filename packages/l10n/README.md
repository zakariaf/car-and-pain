# l10n

Internationalization for Car and Pain. **Every user-facing string resolves here
— never hardcoded.** Six shipping locales: en/de/fr (LTR) + fa/ar/ckb (RTL).

## F1 scope

- The **gen-l10n ARB pipeline** (`lib/l10n/*.arb`, `l10n.yaml`) with the
  bootstrap/splash/error/home strings across all six locales.
- The **localization delegates** (`carAndPainLocalizationsDelegates`),
  **supported locales**, and an **RTL check** (`isRtlLocale`).
- The **ckb fallback**: Flutter's `GlobalMaterialLocalizations` has no Sorani
  Kurdish data, so `ckb` falls back to Arabic for framework strings while our
  own `AppLocalizations` supplies real ckb copy.

## Regenerating

Generated output lives in `lib/src/generated/` and is **gitignored**. Regenerate
with:

```bash
melos run l10n        # → flutter gen-l10n (runs before analyze in CI)
```

If an import of `AppLocalizations` fails to resolve, you haven't generated yet —
run the command above; don't chase the symptom.

## Adding a string

1. Add the key + `@`metadata to the template `lib/l10n/app_en.arb` **first**.
2. Mirror the message into `app_de/fr/fa/ar/ckb.arb` with identical placeholder
   names and ICU structure (plurals via `{count, plural, ...}`, never string
   concatenation; Arabic needs the six CLDR forms).
3. Run `melos run l10n`, then analyze.

## Arriving later (F4)

Own Gregorian/Jalali/Hijri conversion math, Western/Eastern-Arabic/Persian
numeral shaping with Indian grouping, `٫`/`٬` normalization to ASCII before math,
bidi-isolation helpers, and bundled Vazirmatn/Noto fonts.
