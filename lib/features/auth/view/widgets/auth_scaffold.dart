import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// Estructura común de las pantallas de entrada.
///
/// Todas comparten el mismo esqueleto —flecha de vuelta, título, subtítulo y
/// una columna centrada con ancho máximo— y `RNF-24` exige que aguanten el
/// escalado tipográfico del sistema hasta el 200 %: de ahí el scroll siempre
/// disponible en lugar de una columna rígida.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.children,
    super.key,
    this.subtitle,
    this.showBackButton = true,
    this.onBack,
    this.action,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBackButton;
  final VoidCallback? onBack;

  /// Acción al final de la barra superior, como el «Saltar» del onboarding.
  final Widget? action;

  /// Contenido anclado abajo, fuera del scroll.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: showBackButton
            ? BackButton(onPressed: onBack ?? () => Navigator.of(context).maybePop())
            : null,
        automaticallyImplyLeading: false,
        actions: [?action],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(title, style: theme.textTheme.headlineSmall),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        ...children,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: bottom,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Envuelve un campo para validarlo cuando pierde el foco.
///
/// `RF-AUT-05` es explícito: se valida al perder el foco, nunca mientras el
/// usuario escribe. Encapsularlo aquí evita repetir el `FocusNode` y su
/// listener en cada pantalla.
class ValidateOnBlur extends StatefulWidget {
  const ValidateOnBlur({required this.onBlur, required this.builder, super.key});

  final VoidCallback onBlur;
  final Widget Function(BuildContext context, FocusNode focusNode) builder;

  @override
  State<ValidateOnBlur> createState() => _ValidateOnBlurState();
}

class _ValidateOnBlurState extends State<ValidateOnBlur> {
  final FocusNode _focusNode = FocusNode();
  bool _hadFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _hadFocus = true;
      return;
    }
    // Solo valida si el campo llegó a tener el foco: al construir la pantalla
    // nadie ha escrito todavía y marcar todo en rojo sería absurdo.
    if (_hadFocus) widget.onBlur();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _focusNode);
}
