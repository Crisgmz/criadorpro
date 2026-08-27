/// Puente entre pruebas de campo y el historial de pesos — `RF-PRU-07`.
///
/// Una prueba anota el peso del ejemplar ese día, y ese peso **es** una pesada:
/// tenerlo solo dentro de la prueba lo dejaría fuera de la curva, que es donde
/// sirve de algo.
///
/// Vive en `core/` y no en ninguno de los dos features porque un feature nunca
/// importa de otro. Pruebas de campo depende de esta interfaz; registros la
/// implementa — el mismo patrón que `PayrollExpenseSink`.
abstract interface class WeightLog {
  /// Anota —o corrige— la pesada que corresponde a una prueba.
  ///
  /// Es **idempotente por prueba**: si esa prueba ya generó una pesada, la
  /// actualiza en vez de añadir otra. Editar una prueba tres veces no puede
  /// dejar tres pesadas que nadie hizo.
  ///
  /// Se llama desde dentro de la transacción de la prueba: si la prueba no se
  /// guarda, la pesada tampoco.
  Future<void> recordFromEvaluation({
    required String ownerId,
    required String birdId,
    required String evaluationId,
    required int weightG,
    required DateTime date,
    required DateTime now,
  });

  /// Retira la pesada de una prueba que se elimina o que se quedó sin peso.
  Future<void> removeFromEvaluation({required String evaluationId, required DateTime now});
}
