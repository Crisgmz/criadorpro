/// Sexo del ejemplar.
///
/// Vive en `core` y no en el feature `birds` porque lo usan también camadas,
/// pedigrí y evaluaciones, y porque su código de color es una convención de
/// producto que debe ser idéntica en toda la app.
enum Sex {
  male('male'),
  female('female'),
  unknown('unknown');

  const Sex(this.id);

  /// Valor persistido en Drift y en Supabase.
  final String id;

  static Sex fromId(String? id) =>
      values.firstWhere((sex) => sex.id == id, orElse: () => Sex.unknown);
}
