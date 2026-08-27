/// Puente entre empleomanía y contabilidad — `RS-06`.
///
/// Confirmar un pago de nómina tiene que crear, **en la misma transacción**, un
/// gasto de categoría nómina por el neto; anular el pago anula el gasto. Eso
/// acopla los dos módulos por requisito, no por descuido.
///
/// Vive en `core/` y no en ninguno de los dos features porque un feature nunca
/// importa de otro. Empleomanía depende de esta interfaz; contabilidad la
/// implementa. Además hace el acoplamiento explícito y sustituible: una prueba
/// de empleomanía puede comprobar que el gasto se pide sin montar la
/// contabilidad entera.
abstract interface class PayrollExpenseSink {
  /// Registra el gasto de nómina y devuelve su identificador.
  ///
  /// Se llama desde dentro de la transacción del pago: si algo falla después,
  /// el gasto se deshace con él.
  Future<String> recordPayrollExpense({
    required String ownerId,
    required int amountCents,
    required DateTime date,
    required String description,
    required DateTime now,
  });

  /// Anula el gasto de un pago que se anula. Si el gasto ya no existe —lo borró
  /// otro dispositivo— no es un error: el estado final es el mismo.
  Future<void> voidPayrollExpense({required String transactionId, required DateTime now});
}
