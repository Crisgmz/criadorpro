import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/sex.dart';
import '../../../core/error/failure_messages.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cp_button.dart';
import '../../../core/widgets/cp_segmented.dart';
import '../../../core/widgets/cp_text_field.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/navy_surface.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../model/clutch.dart';
import '../viewmodel/clutch_form_viewmodel.dart';
import 'widgets/form_fields.dart';
import 'widgets/marking_fields.dart';

/// Registro de camada — pantalla 21, `RF-REG-08` a `RF-REG-10`.
///
/// Es la función que hace rentable la app: ocho crías registradas en menos de
/// un minuto. De ahí el orden de la pantalla — primero lo que decide el número
/// de placas, después lo accesorio— y de ahí que el contador sea un par de
/// botones grandes y no un campo de texto: se pulsa con el pulgar, sin mirar,
/// con un ave en la otra mano.
class ClutchFormView extends ConsumerStatefulWidget {
  const ClutchFormView({super.key});

  @override
  ConsumerState<ClutchFormView> createState() => _ClutchFormViewState();
}

class _ClutchFormViewState extends ConsumerState<ClutchFormView> {
  final _eggsController = TextEditingController();
  final _lineController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _viewModel.load());
  }

  @override
  void dispose() {
    _eggsController.dispose();
    _lineController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  ClutchFormViewModel get _viewModel => ref.read(clutchFormViewModelProvider);

  Future<void> _pickDate() async {
    final viewModel = _viewModel;
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: viewModel.date,
      // `RV-09`: ni futura ni de hace más de veinte años. El calendario ya no
      // deja elegir fuera de rango, así que el error casi nunca llega a verse.
      firstDate: DateTime(now.year - 20),
      lastDate: now,
    );

    if (picked != null) viewModel.setDate(picked);
  }

  Future<void> _submit() async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final viewModel = _viewModel;

    final registration = await viewModel.submit();

    if (!mounted) return;

    if (registration != null) {
      await _celebrate(registration);
      return;
    }

    // CU-02 alterno B antes que el error genérico: hay una salida concreta que
    // ofrecerle al criador.
    if (viewModel.planLimit != null) {
      await _offerWhatFits();
      return;
    }

    final failure = viewModel.failure;
    if (failure != null) {
      messenger.showSnackBar(SnackBar(content: Text(failureMessage(l10n, failure))));
      viewModel.clearFailure();
    }
  }

  /// CU-02 alterno B — «solo caben N, ¿registro N?».
  ///
  /// Decir «no se pudo» y dejar al criador contando a mano cuántas plazas le
  /// quedan sería trasladarle un cálculo que la app ya tiene hecho.
  Future<void> _offerWhatFits() async {
    final l10n = AppL10n.of(context);
    final viewModel = _viewModel;
    final limit = viewModel.planLimit!;
    final fits = viewModel.planLimitFits;

    final accepted = await showCpDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.info_outline, size: 40),
        title: Text(l10n.clutchPlanLimitTitle),
        content: Text(l10n.clutchPlanLimitBody(fits, limit.limit)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.dashboardSeePlans),
          ),
          // Con cero plazas libres no hay nada que ofrecer: `RS-03` deja
          // consultar y exportar, pero no crear.
          if (fits > 0)
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.clutchPlanLimitAccept(fits)),
            ),
        ],
      ),
    );

    if (!mounted) return;
    viewModel.clearPlanLimit();
    if (accepted ?? false) {
      viewModel.setHatched(fits);
      await _submit();
    }
  }

  /// `RF-REG-10` — confirmar el resultado con las placas asignadas.
  ///
  /// El criador necesita ver el rango exacto: es lo que va a escribir en las
  /// anillas físicas, y sin ese dato la pantalla no le ha resuelto el problema.
  Future<void> _celebrate(ClutchRegistration registration) async {
    final l10n = AppL10n.of(context);

    final again = await showCpDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.egg_outlined, size: 48),
        title: Text(l10n.clutchDoneTitle),
        content: Text(
          l10n.clutchDoneBody(
            registration.chicks.length,
            registration.firstPlate,
            registration.lastPlate,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.clutchRegisterAnother),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.clutchViewChicks),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (again ?? false) {
      // Registrar otra es lo normal en temporada de cría: se limpia el
      // formulario y se recalcula la placa siguiente, sin salir de la pantalla.
      _eggsController.clear();
      _notesController.clear();
      await _viewModel.load();
      return;
    }

    context.go(Routes.birds);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final viewModel = ref.watch(clutchFormViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.clutchTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // El rango de placas va arriba del todo y no al final: es la pregunta
          // que el criador trae al abrir la pantalla, y cambia en vivo al tocar
          // el contador.
          _PlatePreview(
            first: viewModel.firstPlate,
            last: viewModel.lastPlate,
            count: viewModel.hatched,
          ),
          const SizedBox(height: AppSpacing.lg),

          SectionLabel(l10n.clutchSectionBirth),
          DateField(
            label: l10n.fieldBirthDate,
            value: viewModel.date,
            formatted: Formatters.date(viewModel.date, locale),
            onTap: _pickDate,
            errorText: viewModel.isDateInFuture ? l10n.clutchDateFuture : null,
          ),
          const SizedBox(height: AppSpacing.md),

          _HatchedStepper(
            value: viewModel.hatched,
            canDecrement: viewModel.canDecrement,
            canIncrement: viewModel.canIncrement,
            onDecrement: viewModel.decrement,
            onIncrement: viewModel.increment,
          ),
          const SizedBox(height: AppSpacing.md),

          CpTextField(
            label: l10n.clutchEggs,
            controller: _eggsController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            prefixIcon: Icons.egg_outlined,
            helper: l10n.commonOptional,
            errorText: viewModel.isHatchedOverEggs ? l10n.clutchHatchedOverEggs : null,
            onChanged: viewModel.setEggs,
          ),
          InlineWarning(message: l10n.clutchSexNote),

          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.clutchSectionParents),
          ParentField(
            label: l10n.fieldFather,
            sex: Sex.male,
            value: viewModel.father,
            onChanged: viewModel.setFather,
          ),
          const SizedBox(height: AppSpacing.md),
          ParentField(
            label: l10n.fieldMother,
            sex: Sex.female,
            value: viewModel.mother,
            onChanged: viewModel.setMother,
          ),

          // El estado del cruce va junto a los reproductores, que es de lo que
          // habla: si fue una prueba, si ya está hecho, o si se repitió.
          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.crossStatus),
          CpSegmented<CrossStatus>(
            segments: [
              CpSegment(value: CrossStatus.test, label: l10n.crossStatusTest),
              CpSegment(value: CrossStatus.done, label: l10n.crossStatusDone),
              CpSegment(value: CrossStatus.repeated, label: l10n.crossStatusRepeated),
            ],
            selected: viewModel.crossStatus,
            onChanged: viewModel.setCrossStatus,
          ),

          // Marca y cintas **para toda la camada**: las crías de un mismo
          // cruce se marcan igual, y pedirlo quince veces —una por cría— es lo
          // que hace que no se marque ninguna. Cada una lo corrige en su ficha.
          const SizedBox(height: AppSpacing.lg),
          BirthMarkPicker(value: viewModel.birthMark, onChanged: viewModel.setBirthMark),
          const SizedBox(height: AppSpacing.lg),
          WingBandPicker(
            left: viewModel.wingLeft,
            right: viewModel.wingRight,
            onLeftChanged: viewModel.setWingLeft,
            onRightChanged: viewModel.setWingRight,
          ),

          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.clutchSectionExtra),
          CpTextField(
            label: l10n.fieldLine,
            controller: _lineController,
            textInputAction: TextInputAction.next,
            onChanged: viewModel.setLine,
          ),
          const SizedBox(height: AppSpacing.md),
          CpTextField(
            label: l10n.clutchGoalNotes,
            controller: _notesController,
            maxLines: 3,
            onChanged: viewModel.setNotes,
          ),

          const SizedBox(height: AppSpacing.xl),
          CpButton(
            label: l10n.clutchNew,
            isLoading: viewModel.isLoading,
            onPressed: viewModel.canSubmit ? _submit : null,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// Rango de placas que se reservará, antes de confirmar — `RF-REG-09`.
class _PlatePreview extends StatelessWidget {
  const _PlatePreview({required this.first, required this.last, required this.count});

  final int first;
  final int last;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return NavySurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.clutchRegistered(count),
            style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            // Con una sola cría, «#40 a #40» sonaría a error del programa.
            count == 1 ? '#$first' : '#$first – #$last',
            style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            count == 1
                ? l10n.clutchPlatePreviewSingle(first)
                : l10n.clutchPlatePreview(first, last),
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

/// Contador de crías: dos botones grandes y el número en medio.
///
/// Es el control principal de la pantalla. Un campo de texto obligaría a abrir
/// el teclado numérico para escribir un dígito, y son ocho toques contra uno.
class _HatchedStepper extends StatelessWidget {
  const _HatchedStepper({
    required this.value,
    required this.canDecrement,
    required this.canIncrement,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int value;
  final bool canDecrement;
  final bool canIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return Semantics(
      // El lector de pantalla anuncia el conjunto como un solo control con su
      // valor, en vez de tres elementos sueltos sin relación aparente.
      label: l10n.clutchHatched,
      value: '$value',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(child: Text(l10n.clutchHatched, style: theme.textTheme.bodyLarge)),
            _StepperButton(
              icon: Icons.remove,
              tooltip: l10n.clutchDecrement,
              onPressed: canDecrement ? onDecrement : null,
            ),
            SizedBox(
              width: 56,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
            ),
            _StepperButton(
              icon: Icons.add,
              tooltip: l10n.clutchIncrement,
              onPressed: canIncrement ? onIncrement : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    icon: Icon(icon),
    tooltip: tooltip,
    onPressed: onPressed,
    // 44 × 44 es el área táctil mínima de `RNF-23`; este control se pulsa
    // muchas veces seguidas, así que va holgado.
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
  );
}
