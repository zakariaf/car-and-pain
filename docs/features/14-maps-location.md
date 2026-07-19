# 🗺️ Offline Maps & Location

> The pain: your car app shows a trip or a parked-car pin as a naked "48.8566, 2.3522" the moment you lose signal — useless when you actually need it.

📍 Part of **[Car and Pain](../overview.md)** · Related: [Trips & Mileage Logbook](./06-trips-mileage.md) · [Safety, Incidents & Roadside](./22-safety-incidents-roadside.md) · [Data, Offline, Backup & Portability](./18-data-offline-backup.md)

## The pain

Every other car app quietly assumes a network. The instant you drive into an underground garage, a mountain tunnel, a border town, or airplane mode, the "map" collapses into raw latitude/longitude numbers — and a string of coordinates has never once helped anyone find their car in a ten-story parking structure or reconstruct where an accident happened. Owners record a GPS trip, a parking spot, or an incident location expecting to *see* it later, and instead get a blank tile grid or a dead pin. This is the single biggest hole in any "100% offline" promise: location is exactly the moment connectivity fails you, and it is exactly the moment you need it most.

## What it does

Offline Maps & Location is the shared, bundled map layer that every location-aware module draws on. It renders real pins and route polylines from bundled or cached vector tiles — no online routing engine, no live reverse-geocoding service, no account — so trips, the parking saver, find-my-car, saved stations, and incident locations all show a genuine map even in airplane mode. It manages how much map data lives on the device, lets you cache the regions you actually drive, and degrades honestly: where a region isn't cached it never shows a blank screen, falling back to coordinates plus a live compass bearing and distance so you can still walk to the spot.

Because it is a layer and not a destination, it does one job well and hands the results to the modules that own the data. Trips give it track points; the parking saver and incident wizard give it pins; it gives back a rendered, pannable, localized map and the geometry math (bearing, distance, nearest place) that make those pins useful with zero connectivity.

## Features

### ✅ Must-have

- **Offline map rendering:** Draws the base map from bundled or cached vector tiles (or the device's own offline-map integration where available), so pins and routes appear on a real map surface with no network call.
- **Map pins for every saved location:** Displays typed pins for saved places, fuel/charging stations, parking spots, and incident locations, each tappable back to the record it belongs to.
- **Route polylines for GPS trips:** Renders the polyline of a recorded GPS trip directly from its stored track points, drawing the path you actually drove without any online routing service.
- **Graceful coordinate + compass degradation:** When the surrounding region isn't cached, the screen never goes blank — it falls back to exact coordinates plus a live compass bearing and straight-line distance to the target.
- **Granular location permissions with manual fallback:** Handles precise, approximate, while-in-use, and denied location states cleanly, and keeps a fully-manual path (type or pick a location, no GPS required) so denying location never blocks logging.

### 🔵 Should-have

- **On-device region download & management:** Choose the geographic areas you want available offline and cache them on demand, with clear size accounting so you decide what map data lives on the device.
- **Find-my-car compass + distance pointer:** From a saved parking pin, show a directional arrow and a live updating distance so you can walk straight to the car even underground where the base tiles are missing.
- **Offline reverse-geocoding where possible:** Resolve a coordinate to a human place name from bundled or cached place data when it's available, and fall back to a manual label the user types when it isn't — never a spinning "resolving address".
- **Embedded map previews in cards:** Show a small static map thumbnail inside trip, parking, and incident cards so you recognize a location at a glance without opening the full map.
- **Layer toggles:** Turn individual layers — route, stops, stations, parking, incidents — on and off so a busy map stays readable and you see only what you care about.

### ⚪ Nice-to-have

- **Offline place search:** Search across your saved and cached places with locale-aware collation, so a search in German, Persian, or Arabic sorts and matches correctly without a server.
- **Elevation / route profile:** For road-trips, derive an elevation profile from the recorded track points to show climbs and descents along the route.
- **Frequent-location heatmap:** Visualize your most-visited locations as an on-device heatmap built entirely from your own history.
- **Shareable static map image:** Export a rendered static map image into reports and handover packs (for example, an incident location in a claim pack or a trip map in a fleet report).

## Data captured

| Field | Type | Notes |
| --- | --- | --- |
| `map_region_id` | uuid | Identifier for a downloaded offline region. |
| `cached_bounds` | array (bbox) | Geographic bounding box (min/max lat-lon) covered by the cached region. |
| `cache_size` | number+unit (MB/GB) | On-device storage consumed by this region's tiles, for size-aware management. |
| `tile_source` | enum | Origin of the tiles (bundled base map, downloaded region, or device offline-map provider). |
| `pin_id` | uuid | Identifier for a rendered map pin. |
| `pin_type` | enum | Kind of pin — saved place, station, parking, or incident — driving icon and layer. |
| `latitude` | number (deg) | Canonical WGS84 latitude, stored raw and formatted only for display. |
| `longitude` | number (deg) | Canonical WGS84 longitude, stored raw and formatted only for display. |
| `label` | text | Human-readable name for the pin — reverse-geocoded or manually entered. |
| `linked_record_id` | ref | The owning record (trip, parking event, station, incident) this pin represents. |
| `route_id` | ref | The trip/route whose polyline is rendered. |
| `track_points[]` | array | Ordered GPS points (lat, lon, timestamp, optional elevation) forming the route polyline. |
| `layer_visibility{}` | object (map) | Per-layer on/off state (route, stops, stations, parking, incidents) for the current view. |

## Calculations & formulas

- **Find-my-car bearing & distance:** compute the initial great-circle bearing from the device's current position to the saved parking pin and combine it with the device compass heading to rotate the pointer arrow: `bearing = atan2(sin(Δlon)·cos(lat₂), cos(lat₁)·sin(lat₂) − sin(lat₁)·cos(lat₂)·cos(Δlon))`, and `distance = haversine(lat₁, lon₁, lat₂, lon₂)`.
- **GPS trip distance from track points:** sum straight-line segment distances between consecutive track points — `distance = Σ haversine(pᵢ, pᵢ₊₁)` — so trip length comes purely from on-device geometry with no online routing.
- **Cache size estimate vs free storage:** estimate a region's tile footprint before download and compare against available device storage — `will_fit = (estimated_tile_bytes ≤ free_storage − safety_margin)` — to warn before you run out of space.
- **Nearest saved place (offline):** find the closest saved/cached place to a coordinate by minimizing distance — `nearest = argmin_p haversine(current, p)` — used to auto-suggest a label with no network.

## Offline & data

This module is the offline layer, so "works with zero connectivity" is its entire reason to exist. The base map ships bundled; additional regions are cached on-device by explicit user choice; pins, routes, and labels are stored locally in the same canonical database as everything else. Coordinates are held raw as WGS84 and formatted only for display, matching the app-wide rule that canonical values are stored once and converted at render time. Nothing here calls out to the network to function — reverse-geocoding and any optional map-data refresh are strictly opt-in extras, never prerequisites.

In the backup and portability story, location data round-trips like any other entity. Saved pins, route track points, region metadata, and per-record labels are included in the single-file full backup and in the per-entity CSV/JSON exports, so migrating to a new phone brings your parked-car pins, trip paths, and incident locations intact. Bulky tile caches are treated as *regenerable* rather than precious payload: a restore re-links records and you re-download regions on the new device, keeping backups small while losing none of your actual data. Static map images exported into reports/handover packs travel as ordinary attachments through the media pipeline.

## Localization & RTL

Per `i18n_notes`, the map UI chrome — panels, buttons, layer toggles, back/next controls — mirrors fully for right-to-left languages (Persian/Farsi, Arabic, Sorani Kurdish), while the map canvas itself stays geographically correct. Map labels use bundled localized place names where available; where they aren't, they render in the canonical local script with bidi isolation so a Latin, Arabic, or mixed-script name never scrambles its neighbors. Distances and bearings display in the user's preferred units (km/mi, meters/feet) and numeral system (Western, Eastern-Arabic, or Persian digits). Crucially, the compass and find-my-car directional arrows are **direction-absolute** — north is north and the pointer points where the car physically is; they are never mirrored — even though the surrounding back/next navigation chrome does mirror. Coordinate strings, when shown, stay LTR and bidi-isolated like other IDs.

## Edge cases

- **No offline routing engine:** distances come from summing recorded track points, not from turn-by-turn routing — the app renders the path you drove, it does not compute new routes.
- **Region not cached:** falls back to coordinates plus a compass bearing and straight-line distance, and never shows a blank screen.
- **Limited offline reverse-geocoding:** where a coordinate can't be resolved to a place name from bundled/cached data, it falls back to a saved label or a manually typed name.
- **Large tile caches consume storage:** surfaces size warnings and per-region management so map data can't silently eat the device.
- **GPS drift and tunnels:** smoothing and gap-handling live upstream in [Trips](./06-trips-mileage.md); this layer simply renders the points it is given.
- **Map data goes stale:** cached regions and place data are timestamped and can be refreshed when online — always strictly optional, never forced.

## Related features

- **[Trips & Mileage Logbook](./06-trips-mileage.md):** supplies the GPS track points this layer renders as route polylines and elevation profiles.
- **[Safety, Incidents & Roadside](./22-safety-incidents-roadside.md):** pins incident locations and can export a static map image into an at-scene or claim pack.
- **[Fuel & Energy](./02-fuel-energy.md):** provides saved fuel and charging station locations shown as station pins on the map.
- **[Data, Offline, Backup & Portability](./18-data-offline-backup.md):** carries pins, routes, and region metadata through the single-file backup and CSV/JSON export/import.
- **[Localization, RTL & Calendars](./19-localization-rtl.md):** drives the mirrored chrome, localized place names, direction-absolute compass, and preferred numerals/units on the map.
- **[Accessibility & Inclusive Design](./20-accessibility.md):** ensures the map, compass pointer, and layer controls are screen-reader labeled, high-contrast, and reachable without relying on color alone.
