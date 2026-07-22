import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../domain/attachment.dart';
import 'base_repository.dart';

/// Polymorphic attachment metadata repository (F8-T1). Emits [Attachment] domain
/// models (never Drift rows), exposes soft-delete-filtered `.watch()` streams by
/// owner, and returns `Result<T, DbFailure>` — never throwing across the
/// boundary. The physical blob is content-addressed by `sha256`, so multiple
/// rows can share one on-disk file; `refCount` is maintained transactionally as
/// the number of live rows sharing a blob, so blob GC (F8-T5) knows when the
/// last reference is gone.
class AttachmentsRepository extends BaseRepository {
  AttachmentsRepository(super.db, {super.clock});

  Attachment _toDomain(AttachmentRow r) => Attachment(
        id: r.id,
        linkedEntityType: r.linkedEntityType,
        linkedEntityId: r.linkedEntityId,
        sha256: r.sha256,
        relativePath: r.relativePath,
        thumbnailRelativePath: r.thumbnailRelativePath,
        mimeType: r.mimeType,
        originalFilename: r.originalFilename,
        size: ByteSize(r.sizeBytes),
        refCount: r.refCount,
        isEncrypted: r.isEncrypted,
        createdAt: r.createdAt,
      );

  /// Live attachments for a record, oldest first — push-updated on every write.
  Stream<List<Attachment>> watchByOwner(String type, String id) {
    final query = db.select(db.attachments)
      ..where((t) =>
          t.linkedEntityType.equals(type) &
          t.linkedEntityId.equals(id) &
          t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query
        .watch()
        .map((rows) => rows.map<Attachment>(_toDomain).toList());
  }

  Future<Result<List<Attachment>, DbFailure>> listByOwner(
    String type,
    String id,
  ) async {
    try {
      final rows = await (db.select(db.attachments)
            ..where((t) =>
                t.linkedEntityType.equals(type) &
                t.linkedEntityId.equals(id) &
                t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();
      return Ok(rows.map(_toDomain).toList());
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'attachments'));
    }
  }

  Future<Result<Attachment?, DbFailure>> getById(String id) async {
    try {
      final row = await (db.select(db.attachments)
            ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
          .getSingleOrNull();
      return Ok(row == null ? null : _toDomain(row));
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'attachments'));
    }
  }

  /// The first live attachment sharing [sha256] — for content de-duplication
  /// (if this content is already stored, reuse its blob instead of re-writing).
  Future<Result<Attachment?, DbFailure>> findBySha(String sha256) async {
    try {
      final row = await (db.select(db.attachments)
            ..where((t) => t.sha256.equals(sha256) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
            ..limit(1))
          .getSingleOrNull();
      return Ok(row == null ? null : _toDomain(row));
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'attachments'));
    }
  }

  /// Attach content to an owner record. `sha256`/`relativePath` are the
  /// content-address the caller already computed + stored; `sizeBytes` is the
  /// plaintext size. Refcounts for the shared blob are re-synced atomically.
  Future<Result<Attachment, DbFailure>> add({
    required String linkedEntityType,
    required String linkedEntityId,
    required String sha256,
    required String relativePath,
    required String mimeType,
    required int sizeBytes,
    String? thumbnailRelativePath,
    String? originalFilename,
    bool isEncrypted = false,
  }) async {
    try {
      final now = nowMillis();
      final id = newId();
      await db.transaction(() async {
        await db.into(db.attachments).insert(
              AttachmentsCompanion.insert(
                id: id,
                createdAt: now,
                updatedAt: now,
                sha256: sha256,
                relativePath: relativePath,
                mimeType: mimeType,
                linkedEntityType: linkedEntityType,
                linkedEntityId: linkedEntityId,
                sizeBytes: Value(sizeBytes),
                thumbnailRelativePath: Value(thumbnailRelativePath),
                originalFilename: Value(originalFilename),
                isEncrypted: Value(isEncrypted),
              ),
            );
        await _syncRefCounts(sha256);
      });
      final row = await (db.select(db.attachments)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      return Ok(_toDomain(row));
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'attachments'));
    }
  }

  /// Optimistic soft-delete: tombstone the row with a retention window and
  /// re-sync the blob's live refcount. The blob file is untouched here — orphan
  /// GC (F8-T5) removes it once no live row references its sha.
  Future<Result<void, DbFailure>> softDelete(
    String id, {
    Duration retention = const Duration(days: 30),
  }) async {
    try {
      final now = nowMillis();
      final found = await db.transaction(() async {
        final cur = await (db.select(db.attachments)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (cur == null) return false;
        await (db.update(db.attachments)..where((t) => t.id.equals(id))).write(
          AttachmentsCompanion(
            isDeleted: const Value(true),
            deletedAt: Value(now),
            trashExpiresAt: Value(now + retention.inMilliseconds),
            updatedAt: Value(now),
            rowRevision: Value(cur.rowRevision + 1),
          ),
        );
        await _syncRefCounts(cur.sha256);
        return true;
      });
      return found ? const Ok(null) : const Err(NotFound('attachment'));
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'attachments'));
    }
  }

  /// Restore a trashed attachment (clears the tombstone, re-syncs refcount).
  Future<Result<void, DbFailure>> restore(String id) async {
    try {
      final now = nowMillis();
      final found = await db.transaction(() async {
        final cur = await (db.select(db.attachments)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (cur == null) return false;
        await (db.update(db.attachments)..where((t) => t.id.equals(id))).write(
          AttachmentsCompanion(
            isDeleted: const Value(false),
            deletedAt: const Value(null),
            trashExpiresAt: const Value(null),
            updatedAt: Value(now),
          ),
        );
        await _syncRefCounts(cur.sha256);
        return true;
      });
      return found ? const Ok(null) : const Err(NotFound('attachment'));
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'attachments'));
    }
  }

  /// Flip the at-rest encryption flag after a blob was (un)sealed in place —
  /// used by the bulk encrypt/decrypt migration (F8-T4).
  Future<Result<void, DbFailure>> markEncrypted(
    String id, {
    required bool encrypted,
  }) async {
    try {
      final n = await (db.update(db.attachments)..where((t) => t.id.equals(id)))
          .write(AttachmentsCompanion(
        isEncrypted: Value(encrypted),
        updatedAt: Value(nowMillis()),
      ));
      return n == 0 ? const Err(NotFound('attachment')) : const Ok(null);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'attachments'));
    }
  }

  /// Every live attachment across all owners — for bulk maintenance passes.
  Future<Result<List<Attachment>, DbFailure>> listAllLive() async {
    try {
      final rows = await (db.select(db.attachments)
            ..where((t) => t.isDeleted.equals(false)))
          .get();
      return Ok(rows.map(_toDomain).toList());
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'attachments'));
    }
  }

  /// Permanently remove the row (post trash-retention). Blob file cleanup is the
  /// GC's job; this only reconciles the metadata + refcount.
  Future<Result<void, DbFailure>> hardDelete(String id) async {
    try {
      final removed = await db.transaction(() async {
        final cur = await (db.select(db.attachments)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (cur == null) return 0;
        final n = await (db.delete(db.attachments)
              ..where((t) => t.id.equals(id)))
            .go();
        await _syncRefCounts(cur.sha256);
        return n;
      });
      return removed == 0 ? const Err(NotFound('attachment')) : const Ok(null);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'attachments'));
    }
  }

  /// Set every live row sharing [sha256] to the current live count — the
  /// authoritative shared-blob refcount. Called inside write transactions.
  Future<void> _syncRefCounts(String sha256) async {
    final live = await (db.select(db.attachments)
          ..where((t) => t.sha256.equals(sha256) & t.isDeleted.equals(false)))
        .get();
    if (live.isEmpty) return; // last reference gone → blob now GC-eligible
    await (db.update(db.attachments)
          ..where((t) => t.sha256.equals(sha256) & t.isDeleted.equals(false)))
        .write(AttachmentsCompanion(refCount: Value(live.length)));
  }
}
