import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_spacing.dart';

/// Las seis casillas del código de verificación — pantallas 5 y 8.
///
/// Debajo hay **un solo campo de texto**, transparente y estirado sobre toda la
/// fila; las seis cajas solo pintan. Con seis campos reales habría que
/// reimplementar a mano el avance, el retroceso y el reparto del pegado, y cada
/// uno se rompe en algún caso (corregir un dígito sin borrarlo, pegar desde la
/// casilla del medio). Así `RF-AUT-07` —avance automático y pegado que llena
/// las seis— sale del comportamiento nativo del campo.
class OtpInput extends StatefulWidget {
  const OtpInput({
    required this.controller,
    required this.onChanged,
    required this.semanticsLabel,
    super.key,
    this.onCompleted,
    this.enabled = true,
    this.hasError = false,
    this.autofocus = true,
  });

  /// Contiene el código completo. La View lo vacía tras un reenvío.
  final TextEditingController controller;

  final ValueChanged<String> onChanged;

  /// Etiqueta para el lector de pantalla — `RNF-26`. Llega traducida porque el
  /// widget no conoce las traducciones.
  final String semanticsLabel;

  /// Se dispara al llenarse la sexta casilla.
  final ValueChanged<String>? onCompleted;

  final bool enabled;
  final bool hasError;
  final bool autofocus;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  static const int _length = AppConfig.verificationCodeLength;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _focusNode.addListener(_repaint);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _focusNode
      ..removeListener(_repaint)
      ..dispose();
    super.dispose();
  }

  void _repaint() {
    if (mounted) setState(() {});
  }

  void _onControllerChanged() {
    _repaint();
    final code = widget.controller.text;
    widget.onChanged(code);
    if (code.length == _length) {
      _focusNode.unfocus();
      widget.onCompleted?.call(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;

    return Semantics(
      label: widget.semanticsLabel,
      textField: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = AppSpacing.sm;
          final available = constraints.maxWidth - gap * (_length - 1);
          final boxWidth = (available / _length).clamp(40.0, 56.0);
          const boxHeight = AppSizes.control + 4;

          return SizedBox(
            height: boxHeight,
            child: Stack(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var index = 0; index < _length; index++) ...[
                      if (index > 0) const SizedBox(width: gap),
                      _Box(
                        width: boxWidth,
                        height: boxHeight,
                        digit: index < code.length ? code[index] : null,
                        // El cursor se dibuja en la primera casilla libre.
                        isActive: _focusNode.hasFocus && index == code.length,
                        hasError: widget.hasError,
                        enabled: widget.enabled,
                      ),
                    ],
                  ],
                ),
                // El campo real: invisible, encima de todo para recibir los
                // toques, y con el teclado numérico y el autorrelleno del SMS.
                Positioned.fill(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    autofocus: widget.autofocus,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(_length),
                    ],
                    showCursor: false,
                    enableInteractiveSelection: false,
                    style: const TextStyle(color: Colors.transparent, height: 0.01),
                    cursorColor: Colors.transparent,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      filled: false,
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                    ),
                    // Escribir siempre continúa por el final, aunque el toque
                    // haya caído sobre una casilla ya escrita.
                    onTap: () => widget.controller.selection = TextSelection.collapsed(
                      offset: widget.controller.text.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.width,
    required this.height,
    required this.digit,
    required this.isActive,
    required this.hasError,
    required this.enabled,
  });

  final double width;
  final double height;
  final String? digit;
  final bool isActive;
  final bool hasError;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final borderColor = switch ((hasError, isActive)) {
      (true, _) => scheme.error,
      (false, true) => scheme.secondary,
      (false, false) => scheme.outlineVariant,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled ? scheme.surface : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor, width: isActive || hasError ? 2 : 1.5),
      ),
      child: Text(
        digit ?? '',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}
