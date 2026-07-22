/// Which sensitive fields to strip from a handover / sell-dispose export, keyed
/// by entity (F7-T6). Sensitive modules (driver medical/ICE, documents) register
/// their `entity → field-names` here; redaction runs at the **export boundary**
/// (the serializer), so a shared handover pack never carries a sensitive value —
/// it is never merely hidden in the UI.
final class RedactionSpec {
  const RedactionSpec(this.fieldsByEntity);

  /// Empty = redact nothing (a full-fidelity backup for the owner's own use).
  const RedactionSpec.none() : fieldsByEntity = const {};

  final Map<String, Set<String>> fieldsByEntity;

  bool get isEmpty => fieldsByEntity.isEmpty;
}

/// Return a copy of a canonical export [doc] with every field named in [spec]
/// removed from that entity's rows. Every other field and entity is untouched,
/// so the vehicle record stays intact while medical/ICE/document contents drop
/// out. Redaction removes the key entirely — no masked placeholder leaks the
/// existence or shape of the value.
Map<String, dynamic> redactExport(
  Map<String, dynamic> doc,
  RedactionSpec spec,
) {
  if (spec.isEmpty) return doc;
  final entities = (doc['entities'] as Map?)?.cast<String, dynamic>();
  if (entities == null) return doc;

  final redacted = <String, dynamic>{};
  entities.forEach((name, rows) {
    final fields = spec.fieldsByEntity[name];
    if (fields == null || fields.isEmpty || rows is! List) {
      redacted[name] = rows;
      return;
    }
    redacted[name] = rows.map((row) {
      if (row is! Map) return row;
      final copy = Map<String, dynamic>.from(row);
      for (final field in fields) {
        copy.remove(field);
      }
      return copy;
    }).toList();
  });
  return {...doc, 'entities': redacted};
}
