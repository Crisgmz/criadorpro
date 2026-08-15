import '../../../core/db/daos/birds_dao.dart';
import '../../../core/error/failure.dart';
import '../../../core/utils/result.dart';
import '../../birds/model/bird.dart';
import '../model/pedigree_node.dart';

/// Construcción del pedigrí — `RF-PED-01`, algoritmo del DDT §7.
///
/// Todo se resuelve **contra la base local** (`RF-PED-09`): el pedigrí es lo
/// que el criador consulta de pie en el galpón, delante del ave, sin señal.
class PedigreeRepository {
  PedigreeRepository({required BirdsDao birdsDao}) : _birdsDao = birdsDao;

  final BirdsDao _birdsDao;

  /// Profundidad máxima que admite el producto, sea cual sea el plan.
  static const int maxDepth = 4;

  /// Construye el árbol de [rootId] hasta [depth] generaciones ascendentes.
  ///
  /// Dos fases, y ese es todo el truco del rendimiento: primero se recogen los
  /// identificadores **nivel a nivel** —una consulta por generación, no una por
  /// nodo—, luego se leen todos los ejemplares de una vez y el árbol se arma en
  /// memoria. Un pedigrí de cuatro generaciones son 5 consultas en lugar de 31,
  /// que es lo que sostiene el umbral de 300 ms de `RNF-03`.
  Future<Result<PedigreeNode>> build({required String rootId, required int depth}) => guard(
    () async {
      final maxLevels = depth.clamp(1, maxDepth);

      // 1. Identificadores por nivel.
      final visited = <String>{rootId};
      final ids = <String>{rootId};
      var frontier = <String>[rootId];

      for (var level = 0; level < maxLevels; level++) {
        final parents = await _birdsDao.parentsOf(frontier);
        // `visited.add` devuelve false si ya estaba: evita releer un ancestro
        // que aparece por dos ramas, algo habitual con la endogamia dirigida.
        final next = parents.where(visited.add).toList();
        if (next.isEmpty) break;
        ids.addAll(next);
        frontier = next;
      }

      // 2. Una sola lectura para todo el árbol.
      final rows = await _birdsDao.byIds(ids);
      final index = {for (final row in rows) row.id: Bird.fromRow(row)};

      final root = _node(index, rootId, 0, maxLevels, <String>{});
      if (root == null) throw const _NotFound();
      return root;
    },
    (error, _) => error is _NotFound
        ? const NotFoundFailure(debugMessage: 'raíz del pedigrí no encontrada')
        : DatabaseFailure(debugMessage: error.toString(), cause: error),
  );

  /// Armado recursivo con corte por ciclo.
  ///
  /// El conjunto [path] es el camino **desde la raíz hasta aquí**, no todo lo
  /// visto: un mismo ancestro puede aparecer por la rama paterna y por la
  /// materna sin que eso sea un ciclo —es endogamia, y es información legítima
  /// del criadero—. Solo es ciclo si el ejemplar es ancestro de sí mismo.
  PedigreeNode? _node(
    Map<String, Bird> index,
    String? id,
    int depth,
    int maxLevels,
    Set<String> path,
  ) {
    if (id == null || depth > maxLevels) return null;

    final bird = index[id];
    // Progenitor desconocido o dado de baja: casilla vacía, nunca error
    // (`RF-PED-05`).
    if (bird == null) return null;

    if (!path.add(id)) return PedigreeNode.cycle(bird);

    return PedigreeNode(
      bird: bird,
      father: _node(index, bird.fatherId, depth + 1, maxLevels, {...path}),
      mother: _node(index, bird.motherId, depth + 1, maxLevels, {...path}),
    );
  }
}

class _NotFound implements Exception {
  const _NotFound();
}
