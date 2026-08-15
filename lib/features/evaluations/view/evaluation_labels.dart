import '../../../l10n/generated/app_l10n.dart';
import '../model/evaluation.dart';

/// Traducción del catálogo de resultados — BRD §8.
///
/// Las claves se guardan en inglés y se traducen aquí, en presentación: es la
/// única forma de que el vocabulario visible pueda revisarse en los `.arb` sin
/// tocar la base ni el servidor.
String resultLabel(AppL10n l10n, EvaluationResult result) => switch (result) {
  EvaluationResult.favorable => l10n.testsResultFavorable,
  EvaluationResult.unfavorable => l10n.testsResultUnfavorable,
  EvaluationResult.undefined => l10n.testsResultUndefined,
};
