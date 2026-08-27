import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/bird_traits.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/cp_button.dart';
import '../../../../core/widgets/cp_empty_state.dart';
import '../../../../core/widgets/cp_text_field.dart';
import '../../../../core/widgets/motion.dart';
import '../../../../l10n/generated/app_l10n.dart';

/// Campo de color de plumaje o de cresta.
///
/// Abre una hoja en lugar de desplegar una lista: el catálogo es **abierto** y
/// crece con el criadero, así que puede llegar a treinta valores. Un
/// desplegable de treinta entradas no se recorre con el pulgar.
class TraitField extends StatelessWidget {
  const TraitField({required this.trait, required this.value, required this.onChanged, super.key});

  final BirdTrait trait;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final label = trait == BirdTrait.plumage ? l10n.fieldColor : l10n.fieldComb;

    return InkWell(
      onTap: () async {
        final selection = await showModalBottomSheet<_TraitSelection>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => _TraitSheet(trait: trait, selected: value),
        );
        if (selection != null) onChanged(selection.value);
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.chevron_right)),
        child: Text(
          (value ?? '').isEmpty ? l10n.commonNone : value!,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Resultado de la hoja. Envuelto en una clase para distinguir «elegí ninguno»
/// —un `value` nulo— de «cerré sin elegir», que es un `null` a secas.
class _TraitSelection {
  const _TraitSelection(this.value);

  final String? value;
}

class _TraitSheet extends ConsumerStatefulWidget {
  const _TraitSheet({required this.trait, this.selected});

  final BirdTrait trait;
  final String? selected;

  @override
  ConsumerState<_TraitSheet> createState() => _TraitSheetState();
}

class _TraitSheetState extends ConsumerState<_TraitSheet> {
  late String? _selected = widget.selected;

  /// Valor recién escrito por el criador. Todavía no lo usa ningún ejemplar, así
  /// que no vendría en la lista: se añade a mano hasta que se guarde.
  String? _created;

  Future<void> _createNew() async {
    final l10n = AppL10n.of(context);
    final controller = TextEditingController();

    final name = await showCpDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.trait == BirdTrait.plumage ? l10n.traitNewPlumage : l10n.traitNewComb),
        content: CpTextField(
          label: l10n.traitName,
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();

    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    setState(() {
      _created = trimmed;
      _selected = trimmed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final ownerId = ref.watch(currentOwnerIdProvider);
    final options = ref.watch(traitOptionsProvider((ownerId: ownerId, trait: widget.trait)));

    final title = widget.trait == BirdTrait.plumage
        ? l10n.traitSelectPlumage
        : l10n.traitSelectComb;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      expand: false,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.commonClose,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(title, style: theme.textTheme.titleLarge),
              ],
            ),
          ),

          Expanded(
            child: options.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              // Nunca en blanco: una hoja vacía sin explicación se lee como
              // «no hay nada» cuando en realidad la consulta falló.
              error: (error, _) => CpEmptyState(
                icon: Icons.error_outline,
                title: l10n.errorUnknown,
                message: '$error',
              ),
              data: (values) {
                // El recién creado aún no lo usa ningún ejemplar, así que no
                // llega en la consulta: se antepone a mano.
                final all = [
                  if (_created != null &&
                      !values.any((o) => o.value.toLowerCase() == _created!.toLowerCase()))
                    TraitOption(value: _created!, count: 0),
                  ...values,
                ];

                return RadioGroup<String?>(
                  groupValue: _selected,
                  onChanged: (value) => setState(() => _selected = value),
                  child: ListView(
                    controller: controller,
                    children: [
                      ListTile(
                        leading: const _DashedPlus(),
                        title: Text(
                          widget.trait == BirdTrait.plumage
                              ? l10n.traitNewPlumage
                              : l10n.traitNewComb,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onTap: _createNew,
                      ),
                      const Divider(height: 1),

                      // «Ninguno» explícito: el color es opcional y sin esta
                      // entrada no habría forma de retirarlo.
                      RadioListTile<String?>(value: null, title: Text(l10n.commonNone)),
                      const Divider(height: 1),

                      for (final option in all) ...[
                        RadioListTile<String?>(
                          value: option.value,
                          title: Row(
                            children: [
                              Expanded(child: Text(option.value)),
                              // Cuántos ejemplares lo usan: distingue el nombre
                              // real del criadero de un error de tecleo.
                              Text(
                                '(${option.count})',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: CpButton(
              label: l10n.traitContinue,
              onPressed: () => Navigator.of(context).pop(_TraitSelection(_selected)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Círculo punteado del «crear nuevo», como en la referencia.
class _DashedPlus extends StatelessWidget {
  const _DashedPlus();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Icon(Icons.add, size: 20, color: theme.colorScheme.onSurfaceVariant),
    );
  }
}
