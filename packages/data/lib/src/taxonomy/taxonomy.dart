import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../repositories/base_repository.dart';

/// A taxonomy entry (service type / expense category / trip category / tag /
/// cost-centre). [label] is an l10n key for seeded defaults, or a literal for
/// user rows (`isCustom`). [analyticBucket] keeps reports stable regardless of
/// custom naming. [colorToken] is paired with icon+label — never colour alone.
class Category {
  const Category({
    required this.id,
    required this.kind,
    required this.label,
    required this.analyticBucket,
    this.iconKey = 'tag',
    this.colorToken,
    this.isCustom = false,
    this.defaultIntervalMetres,
  });

  final String id;
  final String kind;
  final String label;
  final String analyticBucket;
  final String iconKey;
  final String? colorToken;
  final bool isCustom;
  final int? defaultIntervalMetres;
}

/// A seed definition for a default taxonomy row.
typedef _Seed = ({
  String kind,
  String labelKey,
  String iconKey,
  String bucket,
});

/// The shared custom taxonomy: seeded localized defaults + user rows, filtered
/// by kind and soft-delete. Seeding is idempotent (re-seed-safe).
class TaxonomyRepository extends BaseRepository {
  TaxonomyRepository(super.db, {super.clock});

  static const List<_Seed> _defaults = [
    (
      kind: 'expense',
      labelKey: 'taxonomy.fuel',
      iconKey: 'fuel',
      bucket: 'fuel'
    ),
    (
      kind: 'expense',
      labelKey: 'taxonomy.insurance',
      iconKey: 'shield',
      bucket: 'insurance'
    ),
    (
      kind: 'expense',
      labelKey: 'taxonomy.tax',
      iconKey: 'receipt',
      bucket: 'tax'
    ),
    (
      kind: 'expense',
      labelKey: 'taxonomy.parking',
      iconKey: 'parking',
      bucket: 'parking'
    ),
    (
      kind: 'service',
      labelKey: 'taxonomy.oil_change',
      iconKey: 'oil',
      bucket: 'service'
    ),
    (
      kind: 'service',
      labelKey: 'taxonomy.brakes',
      iconKey: 'brake',
      bucket: 'service'
    ),
    (
      kind: 'trip',
      labelKey: 'taxonomy.business',
      iconKey: 'briefcase',
      bucket: 'business'
    ),
    (
      kind: 'trip',
      labelKey: 'taxonomy.personal',
      iconKey: 'home',
      bucket: 'personal'
    ),
  ];

  Category _toDomain(CategoryRow r) => Category(
        id: r.id,
        kind: r.kind,
        label: r.label,
        analyticBucket: r.analyticBucket,
        iconKey: r.iconKey,
        colorToken: r.colorToken,
        isCustom: r.isCustom,
        defaultIntervalMetres: r.defaultIntervalMetres,
      );

  Stream<List<Category>> watchByKind(String kind) {
    final query = db.select(db.categories)
      ..where((t) => t.kind.equals(kind) & t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.label)]);
    return query.watch().map((rows) => rows.map<Category>(_toDomain).toList());
  }

  /// Seed the default taxonomy. **Idempotent** — a default row for the same
  /// (kind, label) is never inserted twice, so it is safe to call every launch.
  Future<Result<int, DbFailure>> seedDefaults() async {
    try {
      final now = nowMillis();
      var inserted = 0;
      await db.transaction(() async {
        for (final d in _defaults) {
          final exists = await (db.select(db.categories)
                ..where(
                  (t) =>
                      t.kind.equals(d.kind) &
                      t.label.equals(d.labelKey) &
                      t.isCustom.equals(false),
                ))
              .getSingleOrNull();
          if (exists != null) continue;
          await db.into(db.categories).insert(
                CategoriesCompanion.insert(
                  id: newId(),
                  kind: d.kind,
                  label: d.labelKey,
                  analyticBucket: d.bucket,
                  createdAt: now,
                  updatedAt: now,
                  iconKey: Value(d.iconKey),
                ),
              );
          inserted++;
        }
      });
      return Ok(inserted);
    } on Object catch (e) {
      return Err(mapDbError(e, table: 'categories'));
    }
  }
}
