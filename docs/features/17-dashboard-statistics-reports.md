# 📊 Dashboard, Statistics & Reports

> The pain: your car's numbers live in a dozen paper receipts and half-remembered fill-ups, so you never actually know what the car costs, whether it's getting thirstier, or what to hand a buyer, tax office, or insurer — this module turns your own on-device history into a glance, a chart, and a report.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Fuel & Energy](./02-fuel-energy.md) · [Expenses & Cost of Ownership](./05-expenses-cost-ownership.md) · [Data, Offline, Backup & Portability](./18-data-offline-backup.md)

## The pain

Owners log fuel and repairs faithfully for years and still can't answer the simple questions: *What does this car actually cost me per month? Is my fuel economy slipping? When is the next big bill?* Competing apps either bury the answer behind a subscription, compute the wrong MPG because they mishandle partial fills, or lock the numbers inside an account you can't export. Worse, most charts are colour-only (useless to colour-blind users), assume Gregorian months and Latin numerals, and break the layout entirely in Arabic or Persian. Car and Pain treats the dashboard as the daily home screen and the report suite as a first-class deliverable — everything computed on-device, correct by construction, readable in your language and calendar, and yours to export.

## What it does

The dashboard is the glanceable front door to the whole garage: an active-vehicle header, a customizable row of KPI tiles, upcoming-reminder and cost-breakdown cards, and quick-add buttons — all scoped to one vehicle or the whole fleet. Below it sits a unified charts and statistics layer: fuel-economy trends with moving averages, cost and distance over time, spend-by-category, CO₂ footprint, forecasts, and anomaly detection, every series drawn from a fuel-economy engine that correctly understands full, partial, missed, and first fills.

The reports layer turns that same canonical data into shareable artifacts — a KPI-and-charts PDF, a printable service-history report for resale/warranty/insurance, full CSV (UTF-8 + BOM) and JSON exports, and a custom report builder. Nothing here needs connectivity: all aggregation, charting, forecasting, and rendering happen locally, and every number is stored canonically (SI units, UTC/ISO dates, base currency) and converted only for display, so switching units, currency, calendar, or language never rewrites your history.

## Features

### ✅ Must-have

- **Active vehicle summary header** — a persistent top card showing the vehicle name, photo, current odometer, and next-due item, with tap-to-switch between vehicles so the dashboard always states which car you're looking at.
- **Customizable KPI tile row** — a glanceable row of key numbers (total spend, cost per distance, average economy, distance covered, fill count) that the user can pick and arrange.
- **Upcoming reminders card** — surfaces the next maintenance and document items, showing both the calendar date and the projected-mileage due point so date- and distance-based reminders read at a glance.
- **Fuel economy at-a-glance card** — last computed economy plus rolling average, best, and worst, so a slipping trend is visible without opening a chart.
- **Cost breakdown mini card** — a compact split of spend across fuel, service, and other for the selected period.
- **Fuel economy trend chart** — economy over time with a moving-average overlay that smooths pump-to-pump noise into a readable direction.
- **Cost trend chart** — spend per month or per bucket so seasonal and creeping costs stand out.
- **Spend-by-category pie/donut** — proportional view of where the money goes, with non-colour encodings so it is not colour-only.
- **Distance-over-time chart** — per-period bars for distance driven plus a cumulative odometer line.
- **Large-dataset chart performance** — automatic aggregation and downsampling so multi-year histories render smoothly instead of choking on thousands of points.
- **Period filter presets + custom range** — quick presets (this month, year, all time) plus a custom range that is calendar-aware, so ranges align to Jalali/Hijri/Hebrew month and year boundaries where chosen.
- **Per-vehicle vs all-vehicles/fleet toggle** — every dashboard, stat, and chart can scope to one vehicle or aggregate across the garage/fleet.
- **Fuel-economy computation engine** — a correct engine that is full/partial/missed aware, so partial fills are never charted as a tank's economy and missed fills don't produce phantom numbers.
- **Multi-unit economy display** — the same canonical economy shown as L/100km, mpg (US/UK), km/L, or Wh/km per user preference without corrupting stored values.
- **Best/worst/average economy stats** — headline economy statistics over the selected period and scope.
- **Cost-per-distance metrics** — both fuel-only and all-in (fuel + service + other + financing/depreciation) cost per km/mile.
- **Missed/inconsistent-entry detection** — flags odometer gaps, decreasing readings, and duplicates before they distort statistics, prompting review rather than silently producing negative distance.
- **PDF report generator** — a formatted report bundling KPIs, totals, and embedded charts for sharing or archiving.
- **Full CSV export** — UTF-8 with BOM so Excel opens non-Latin text and chosen numerals correctly.
- **Full JSON backup export** — a complete machine-readable export of the underlying records.
- **Printable service/maintenance history report** — a clean history document sized for resale, warranty proof, and insurance.
- **Report share & save** — export via the OS share sheet or Files entirely offline; nothing is uploaded.
- **Localized report formatting** — every report honours language, RTL direction, numeral system, currency, and calendar.
- **Quick-add** — a home-screen widget / app shortcut plus on-dashboard quick-add buttons so a fill-up or expense is one tap away.
- **Multi-currency handling in stats** — values in different currencies are never silently summed; mixed-currency scopes are shown safely with clear labelling.
- **Unit conversion layer** — canonical SI storage converted to display units on the fly, shared across all charts and reports.
- **Calendar-system support in charts/reports** — period buckets computed for Gregorian, Jalali, Hijri, and Hebrew calendars.
- **RTL chart & dashboard layout** — chrome (legends, tooltips, axes) mirrors for right-to-left while the plotted data orientation is preserved.
- **Colour-blind-safe chart palettes** — accessible palettes by default, paired with pattern/label encodings so meaning never depends on colour alone.
- **Unified stats & charts dashboard** — one coherent surface tying the KPIs, cards, and charts together rather than scattered screens.

### 🔵 Should-have

- **Period-over-period delta badges** — up/down badges with *semantic* direction, so lower spend reads as good (green) and lower economy reads as bad.
- **Recent activity feed** — a chronological feed of the latest fills, services, and expenses.
- **Odometer & annualized-mileage card** — current reading plus projected annual distance from average daily use.
- **Budget vs actual card** — planned versus actual spend for the period, tying into budgets.
- **All-vehicles / fleet overview card** — an aggregate summary across the garage for households and small fleets.
- **Customizable dashboard layout** — show/hide and reorder cards, saved locally on the device.
- **Dashboard empty & onboarding states** — helpful first-run states that guide new users, linking into onboarding rather than showing blank charts.
- **Fuel price history and consumption-volume charts** — price paid over time and volume consumed per period.
- **Cost-per-distance trend chart** — the all-in and fuel-only cost per distance plotted over time.
- **Vehicle comparison chart** — side-by-side comparison of economy or cost across vehicles.
- **Interactive chart controls** — tap-for-detail, zoom, and series toggling.
- **Economy by season/month breakdown** — seasonal patterns (e.g. winter economy loss) surfaced by month or season.
- **Cost-per-day and average monthly spend** — normalized spend metrics for budgeting.
- **Spend forecast/projection** — projected future spend with a minimum-data threshold so it won't guess from too little history.
- **Predicted next-service due date** — a projected service date from average daily distance and interval.
- **Fuel economy drop alert; spend spike detection** — proactive flags when economy falls below baseline or spend spikes above the historical norm.
- **Personalized insights feed** — plain-language insights derived from the user's own data.
- **Per-module CSV export** — export any single entity (fuel, service, expenses, trips…) as its own CSV.
- **Tax/business mileage & expense report** — a compliant business-use report, linking into Fleet/Business.
- **Custom report builder** — choose sections, period, vehicles, categories, and whether to include receipts.
- **Home-screen + lock-screen KPI widget; Watch/Wear complication** — key numbers surfaced outside the app.
- **Eco/efficiency score** — a score measured against the user's *own* baseline, not a leaderboard.
- **CO₂ & environmental footprint stats** — emissions estimated from fuel volume and grid factors.

### ⚪ Nice-to-have

- **Period comparison overlay** — this year vs last year drawn on the same axes.
- **Spend-by-station/vendor chart** — where you fuel and shop, ranked by spend.
- **EV & plug-in energy charts** — kWh consumed, efficiency, and charging cost for EV/PHEV.
- **Trip-computer vs actual economy comparison** — the dashboard's computed economy against the car's own trip-computer reading.
- **Unusual fuel price alert** — flags a price paid that is out of line with your history.
- **Milestone & anniversary insights** — celebratory notes (odometer milestones, ownership anniversaries).
- **Cheapest-station / best-value insight** — where you have historically paid least.
- **Receipt/photo inclusion in reports** — embed attached receipts and photos in generated reports.
- **Offline report reminder** — an optional local notification prompting a periodic report (e.g. month-end).
- **Assistant/voice quick actions** — voice shortcuts for quick-add and quick-glance.
- **Achievements, badges & streaks** — local, self-competitive gamification with no server or social layer.
- **Savings tracker vs baseline; personal goals & challenges** — track savings against a baseline and set personal efficiency goals.

## Data captured

These are the computed and configuration fields the dashboard/report layer works with. Most are *derived* at read-time from canonical source records rather than stored, but a few (layout, palette, report definitions) are persisted preferences.

| Field | Type | Notes |
| --- | --- | --- |
| `period` | enum / date-range | Selected preset or custom range; calendar-aware boundaries. |
| `vehicle_scope` | enum / ref | One vehicle, all-vehicles, or fleet. |
| `sumFuelCost` | number+currency | Aggregated fuel spend for period/scope. |
| `sumServiceCost` | number+currency | Aggregated service/maintenance spend. |
| `sumOtherExpense` | number+currency | Aggregated other expenses. |
| `sumDistance` | number+unit | Distance covered, canonical SI (metres) → display km/mi. |
| `avgFuelEconomy` | number+unit | Average economy over valid tanks; display L/100km, mpg, km/L, Wh/km. |
| `fillupCount` | number | Count of qualifying fills in period. |
| `economyUnit` | enum | Display economy unit per preference. |
| `distanceUnit` | enum | Display distance unit per preference. |
| `currency` | enum | Display/base currency for the scope. |
| `metricValueCurrent` | number | Current-period value for a KPI/delta. |
| `metricValuePrevious` | number | Prior-period value for period-over-period comparison. |
| `deltaPercent` | number (%) | Signed change with semantic direction. |
| `movingAverageWindow` | number | N points in the moving-average smoothing window. |
| `rollingBaseline` | number | Rolling mean used as anomaly baseline. |
| `stdDev` | number | Rolling standard deviation for spike/drop thresholds. |
| `forecastValue` | number | Projected future value from trend. |
| `confidenceRange` | number range | Uncertainty band around the forecast. |
| `projectedAnnualDistance` | number+unit | `avg_daily_distance × 365`. |
| `co2_factor` | number | Emission factor per unit of fuel volume. |
| `grid_co2_per_kwh` | number | Grid carbon intensity for EV charging. |
| `gCO2PerKm` | number | Emissions per distance. |
| `chart_type` | enum | Line, bar, pie/donut, etc. |
| `aggregationBucket` | enum | Time bucket (day/week/month/quarter/year). |
| `downsampleThreshold` | number | Point count above which downsampling applies. |
| `layoutDirection` | enum | `ltr` / `rtl` for chart chrome and dashboard. |
| `numeralSystem` | enum | Western / Eastern-Arabic / Persian / Devanagari. |
| `calendarSystem` | enum | Gregorian / Jalali / Hijri / Hebrew. |
| `palette_mode` | enum | Colour-blind-safe / high-contrast palette selection. |
| `report_sections[]` | array | Sections chosen for a custom/PDF report. |
| `export_format` | enum | PDF / CSV / JSON. |
| `include_charts` | bool | Whether to embed charts in a report. |
| `include_receipts` | bool | Whether to embed receipt/photo attachments. |

## Calculations & formulas

- **KPI aggregations** — sum and average of source records (`sum`/`avg`) over the selected period and vehicle scope.
- **Semantic delta** — `delta_percent = (current − previous) / previous × 100`, then coloured by meaning: lower spend is good, lower economy is bad.
- **Moving average & baseline** — a moving average over the last `N` points for smoothing, plus a `rolling baseline mean` and `stddev` used as the reference for anomaly detection.
- **Economy-drop alert** — fires when `recent_economy < baseline − drop_threshold_pct`.
- **Spend spike** — fires when `period_spend > historical_mean + k × stddev`.
- **Forecast** — a `linear` or `moving-average` trend projection guarded by a minimum-data threshold so sparse history produces an estimate/empty state, not a confident-looking wrong number.
- **Projected annual distance** — `projected_annual_distance = avg_daily_distance × 365`.
- **CO₂ footprint** — `CO2 = fuel_volume × emission_factor + kWh × grid_factor`, expressed as `gCO2/km`.
- **Downsampling** — bucket large histories into time buckets (`aggregationBucket`) before plotting so rendering stays fast.

## Reminders & notifications

This module mostly *consumes* reminders rather than producing them: the **upcoming reminders card** reads the shared [local notification engine](./04-reminders-notifications.md), showing the next items by both calendar date and projected-mileage due point (date / distance / engine-hour / whichever-comes-first), with early-warning lead times (e.g. "1 week before" or "1000 km before") reflected in what surfaces first.

It also *produces* two optional notifications:

- **Anomaly alerts** — a fuel-economy drop alert or spend-spike alert can be delivered as a local notification when the analytics layer detects the condition.
- **Offline report reminder** — an optional periodic nudge (e.g. month-end) to generate and save a report, delivered entirely offline and naming the vehicle.

## Offline & data

Every KPI, chart, forecast, insight, and report is computed on-device from your local records — no server round-trip, no live data feed, works fully in airplane mode. The module is honest about offline limits: it uses stored/manual fuel prices and bundled emission/grid factors (with "last checked" context where relevant) rather than live prices or live FX, so figures are reproducible and never blocked by a lost connection.

In **export / backup / import**, this layer is both a producer and a passenger. It generates the PDF, CSV (UTF-8 + BOM), and JSON reports on demand, and can embed charts and receipts. Its own persisted preferences — dashboard layout, chosen palette, saved custom-report definitions — travel inside the single-file full backup alongside every module's records and attachments, so your dashboard comes back exactly as you left it after a device migration. See [Data, Offline, Backup & Portability](./18-data-offline-backup.md) for the backup/restore contract.

## Localization & RTL

- **RTL charts** — chart *chrome* mirrors for right-to-left (legends, tooltips, axis placement) and the time axis inverts, but the plotted data orientation is never mirrored, so the meaning of a rising line stays intact.
- **Numerals** — Eastern-Arabic, Persian, and Devanagari numerals render throughout, with LTR numeric runs correctly bidi-isolated inside RTL text, and Indian lakh/crore grouping where the locale calls for it.
- **Calendars** — period grouping respects Jalali, Hijri, and Hebrew month/year boundaries and each locale's first-day-of-week; Gregorian buckets remain the default. Hijri drift versus the solar year is accounted for in seasonal charts.
- **Currency** — per-vehicle currency with safe aggregation: mixed-currency scopes are never silently summed, and high-magnitude/redenominated currencies (e.g. IRR, TRY) are handled without breaking price charts.
- **Reports** — CSV exports are UTF-8 with BOM; PDFs honour language, direction, calendar, and currency, and are screen-reader-tagged where the format allows.
- **Accessible dataviz** — palettes are colour-blind-safe by default (accessibility × dataviz), always paired with non-colour encodings such as patterns and direct labels. See [Localization, RTL & Calendars](./19-localization-rtl.md) and [Accessibility & Inclusive Design](./20-accessibility.md).

## Edge cases

- Partial fills are never charted as a tank's economy; missed fills are excluded; a first fill shows as "pending" until a following full fill closes the interval.
- Odometer resets, cluster swaps, and decreasing or duplicate readings are validated before producing distance, so a swap or rollover never yields negative distance.
- Both trip-distance logging and absolute-odometer logging are handled and reconciled.
- A unit switch mid-history reformats display only; multi-currency values are never silently summed.
- High-inflation / redenominated currencies (IRR, TRY) can skew price charts — large magnitudes are handled gracefully.
- RTL: plotted data is never mirrored; legends and tooltips mirror and the time axis inverts.
- Non-Gregorian calendars change month/year buckets; Hijri drifts against the solar year, which matters for seasonal charts.
- Sparse or new-user data yields estimate/empty states, not misleading forecasts.
- Very large multi-year histories render and export without crashing (aggregation/downsampling).
- EV/PHEV surface dual metrics; bi-fuel vehicles report per-fuel figures.
- Pump rounding: the stored total wins for cost statistics; zero or negative costs are handled.
- Business/personal split feeds tax reports; edited or deleted entries recompute all dependent statistics.
- Export encoding is UTF-8 + BOM so non-Latin text and the chosen numerals survive in CSV and PDF.
- Colour-blind-safe palettes plus non-colour encodings (pattern/label) ensure no chart relies on colour alone.

## Related features

- **[Fuel & Energy](./02-fuel-energy.md)** — the source of every economy, price, and consumption statistic; the full/partial/missed/first-fill state machine defined there is what the economy engine here honours.
- **[Expenses & Cost of Ownership](./05-expenses-cost-ownership.md)** — feeds the cost KPIs, spend-by-category, budget-vs-actual, and all-in cost-per-distance and TCO figures.
- **[Reminders & Notifications](./04-reminders-notifications.md)** — supplies the upcoming-reminders card and delivers anomaly and report reminders through the shared offline scheduler.
- **[Fleet, Business & Company-Car](./10-fleet-business.md)** — consumes the tax/business mileage and expense reports and the all-vehicles/fleet overview.
- **[Data, Offline, Backup & Portability](./18-data-offline-backup.md)** — the CSV/JSON/PDF exports and the backup that carries dashboard layout, palette, and saved report definitions.
- **[Accessibility & Inclusive Design](./20-accessibility.md)** — the colour-blind-safe palettes, non-colour encodings, and screen-reader-tagged reports originate from this shared layer.
