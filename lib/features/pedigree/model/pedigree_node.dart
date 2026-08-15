import '../../birds/model/bird.dart';

/// Un nodo del árbol genealógico — `RF-PED-01`.
///
/// El árbol es de ascendencia: cada nodo apunta a su padre y a su madre. Un
/// hueco (`null`) es un progenitor desconocido y se dibuja como **casilla
/// vacía**, nunca como error (`RF-PED-05`): que el criador no sepa quién fue el
/// abuelo es lo normal, no un fallo.
class PedigreeNode {
  const PedigreeNode({required this.bird, this.father, this.mother, this.isCycle = false});

  /// Nodo que ya aparecía en su propia línea de ascendencia — `RF-PED-06`.
  ///
  /// Se marca y **se corta ahí**: seguir bajando daría un árbol infinito. El
  /// resto de las ramas se dibuja con normalidad, porque una inconsistencia en
  /// una rama no invalida las demás.
  const PedigreeNode.cycle(this.bird) : father = null, mother = null, isCycle = true;

  final Bird bird;
  final PedigreeNode? father;
  final PedigreeNode? mother;
  final bool isCycle;

  /// Generaciones ascendentes que cuelgan de este nodo. Cero si no tiene
  /// progenitores registrados.
  int get depth {
    if (isCycle) return 0;
    final left = father?.depth ?? -1;
    final right = mother?.depth ?? -1;
    final deeper = left > right ? left : right;
    return deeper + 1;
  }

  /// Total de ejemplares del árbol, el propio nodo incluido.
  int get size => 1 + (father?.size ?? 0) + (mother?.size ?? 0);

  /// `true` si alguna rama quedó cortada por ciclo. Lo usa la vista para avisar
  /// una sola vez, en lugar de repetir el aviso en cada nodo afectado.
  bool get hasCycle => isCycle || (father?.hasCycle ?? false) || (mother?.hasCycle ?? false);
}
