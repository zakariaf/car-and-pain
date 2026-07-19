# Debounced autosave drafts & optimistic soft-delete / Trash / Undo

Two never-lose-data mechanisms that protect hand-entered records against process death and mistaken deletes. Both live in `packages/data`; the UI touches them through Riverpod Notifiers.

## Debounced autosave drafts

In-progress form state persists to a `drafts` table so an OEM background-kill mid-entry loses nothing. On reopen, offer to restore.

### Rules

- Persist on a **500ms-1s debounce** after the last keystroke — **never write the encrypted DB per keystroke** (SQLCipher re-encrypt + WAL write on every character drains battery and thrashes the disk).
- Drive the debounce off an injected `Clock` (`package:clock`) + a cancelable timer so `fake_async` can prove: no write before the window, exactly one write after it.
- Key a draft by `(entityType, entityId?)` so editing an existing record and creating a new one each have at most one live draft.
- On form open, check for a matching draft: if present and newer than the committed row, show a non-destructive "Restore unsaved changes?" prompt. Restoring loads the draft; discarding deletes it.
- On successful commit (the real transactional write), **delete the draft in the same logical step** so a stale draft never shadows a saved record.
- Drafts may live in a lighter store than the fully-encrypted main tables if profiling shows SQLCipher overhead — but if they hold PII (notes, odometer), keep them encrypted.

```dart
class DraftAutosaver {
  DraftAutosaver(this._store, {Clock clock = const Clock(),
      Duration debounce = const Duration(milliseconds: 750)})
      : _clock = clock, _debounce = debounce;

  final DraftStore _store;
  final Clock _clock;
  final Duration _debounce;
  Timer? _timer;

  void onChanged(DraftKey key, Map<String, Object?> snapshot) {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      // fire-and-forget; failure logs but never blocks typing
      _store.upsert(key, snapshot, at: _clock.now());
    });
  }

  Future<void> commitClears(DraftKey key) async {
    _timer?.cancel();
    await _store.delete(key); // saved record supersedes the draft
  }
}
```

### Test recipe

```dart
fakeAsync((async) {
  saver.onChanged(key, snap);
  async.elapse(const Duration(milliseconds: 500));
  expect(store.writes, 0);                 // nothing before the window
  async.elapse(const Duration(milliseconds: 300));
  expect(store.writes, 1);                 // exactly one after
});
```

## Optimistic soft-delete + Trash + Undo

Deletes are optimistic and reversible. A row is never hard-deleted on the user's tap.

### The columns and the ONE filter

- Every user-owned table has `is_deleted INTEGER NOT NULL DEFAULT 0` and `deleted_at INTEGER` (UTC epoch millis, nullable).
- **A single shared query layer or DB view filters `is_deleted = 0` out of EVERY read.** This is the load-bearing invariant: records lists, search, analytics, TCO, projections, AND CustomPainter chart data all read through the **same** `deleted_filter` view / query builder. A hand-written analytics query that hits the base table directly will silently count deleted rows and corrupt every report and chart.

```sql
-- packages/data — the ONE view every read goes through.
CREATE VIEW fills_active AS SELECT * FROM fills WHERE is_deleted = 0;
```

```dart
// Or a shared builder — every DAO composes this, none rolls its own WHERE.
SimpleSelectStatement<T, R> activeOnly<T extends Table, R>(
        SimpleSelectStatement<T, R> q) =>
    q..where((t) => (t as dynamic).isDeleted.equals(false));
```

### Optimistic delete with SnackBar Undo

```dart
Future<void> delete(FillId id) async {
  await _repo.softDelete(id, at: _clock.now());   // set is_deleted=1, deleted_at=now
  ref.invalidate(fillsProvider);                   // list updates immediately (optimistic)
  _messenger.showSnackBar(SnackBar(
    content: Text(l10n.recordDeleted),
    action: SnackBarAction(
      label: l10n.undo,
      onPressed: () => _repo.restore(id),          // clears is_deleted / deleted_at
    ),
  ));
}
```

- **Optimistic**: the row leaves the visible list at once (it now fails the `is_deleted = 0` filter); Undo simply reverts the flag.
- Undo restores by clearing `is_deleted`/`deleted_at` — the row was never gone, so restore is exact and cheap.

### Trash screen + auto-purge

- A Trash screen lists rows where `is_deleted = 1`, ordered by `deleted_at`, and offers **Restore** (clear flags) or **Delete permanently** (hard delete + attachment cleanup).
- **Auto-purge after N days**: a maintenance pass hard-deletes rows whose `deleted_at` is older than N days. Drive the cutoff off the injected `Clock` so `fake_async` can verify purge timing deterministically.
- Purge is a real destructive delete — run it inside a transaction and clean up SHA-256-addressed attachment files whose last referencing row is gone.

### Parity guarantee (the thing that breaks silently)

| Read surface | Must go through `deleted_filter`? |
| --- | --- |
| Records / history lists | YES |
| Search | YES |
| Analytics & consumption stats | YES |
| TCO engine | YES |
| CustomPainter chart datasets | YES |
| Reminder/projection inputs | YES |
| Trash screen | NO — it is the ONLY surface that reads `is_deleted = 1` |
| Export/backup | Policy: exclude soft-deleted from CSV/portable export; the archive may retain them for full-fidelity restore — decide per manifest |

`scripts/check-softdelete-parity.sh` greps analytics/TCO/chart builders for base-table reads that bypass the shared view and lists offenders.

### Test recipe

- Soft-delete a fill → assert it disappears from the records list **and** from analytics/TCO/chart query results (not just the list).
- Undo → assert it reappears everywhere.
- `fake_async`: advance the clock past N days → assert the maintenance pass hard-deletes it and frees its attachment; advance to N-1 days → assert it survives.
