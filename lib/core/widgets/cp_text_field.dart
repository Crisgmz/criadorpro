import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo de texto de la app.
///
/// Para contraseñas usa [CpTextField.password], que añade el ojo de mostrar/
/// ocultar sin que la View tenga que gestionar ese estado.
class CpTextField extends StatefulWidget {
  const CpTextField({
    required this.label,
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.helper,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.autofocus = false,
    this.prefixIcon,
    this.suffix,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
  }) : isPassword = false;

  const CpTextField.password({
    required this.label,
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.helper,
    this.errorText,
    this.textInputAction,
    this.enabled = true,
    this.autofocus = false,
    this.prefixIcon = Icons.lock_outline,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
  }) : isPassword = true,
       keyboardType = TextInputType.visiblePassword,
       textCapitalization = TextCapitalization.none,
       inputFormatters = null,
       maxLines = 1,
       maxLength = null,
       suffix = null;

  final String label;
  final TextEditingController? controller;

  /// Necesario para validar al perder el foco — `RF-AUT-05`.
  final FocusNode? focusNode;

  final String? hint;
  final String? helper;

  /// Mensaje de error ya traducido. Lo decide la View a partir del ViewModel.
  final String? errorText;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final bool autofocus;
  final IconData? prefixIcon;
  final Widget? suffix;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool isPassword;

  @override
  State<CpTextField> createState() => _CpTextFieldState();
}

class _CpTextFieldState extends State<CpTextField> {
  late bool _obscured = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscured,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      maxLines: _obscured ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helper,
        errorText: widget.errorText,
        prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : widget.suffix,
      ),
    );
  }
}
