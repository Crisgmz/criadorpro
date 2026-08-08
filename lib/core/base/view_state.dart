/// Estado de carga de un ViewModel. La View elige qué pintar en cada caso.
enum ViewState {
  /// Aún no se ha pedido nada.
  idle,

  /// Operación en curso.
  loading,

  /// Datos listos.
  ready,

  /// La última operación falló; mira `BaseViewModel.failure`.
  error,
}
