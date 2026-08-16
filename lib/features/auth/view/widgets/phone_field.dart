import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_l10n.dart';
import '../../model/country.dart';
import 'country_names.dart';

/// País y teléfono en una sola fila — pantalla 4.
///
/// Se guardan juntos porque el número no significa nada sin su prefijo: lo que
/// acaba en `profiles.phone` es el E.164 que compone [Country.toE164].
class PhoneField extends StatelessWidget {
  const PhoneField({
    required this.country,
    required this.controller,
    required this.onCountryChanged,
    required this.onChanged,
    super.key,
    this.errorText,
    this.enabled = true,
    this.onEditingComplete,
    this.focusNode,
  });

  final Country country;
  final TextEditingController controller;
  final ValueChanged<Country> onCountryChanged;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final bool enabled;
  final VoidCallback? onEditingComplete;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          // 132 y no 116: con Inter, «DO +1» más el padding del campo y la
          // flecha del desplegable no caben en 116, y el texto desbordaba trece
          // píxeles. Cabía antes solo porque el tema aplicaba por error la
          // fuente del sistema a este campo.
          width: 132,
          child: DropdownButtonFormField<Country>(
            initialValue: country,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.authCountry,
              // El error se pinta bajo el número, no bajo el país: es el número
              // lo que se valida.
              errorText: errorText == null ? null : '',
              errorStyle: const TextStyle(height: 0, fontSize: 0),
            ),
            // El menú desplegado muestra el nombre del país; el campo cerrado,
            // solo el código y el prefijo, que es lo que cabe.
            items: [
              for (final option in Country.values)
                DropdownMenuItem<Country>(
                  value: option,
                  child: Text(
                    '${countryName(l10n, option)} +${option.dialCode}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            selectedItemBuilder: (context) => [
              for (final option in Country.values)
                Align(
                  alignment: Alignment.centerLeft,
                  // Un prefijo de tres dígitos no puede romper la fila: se
                  // recorta antes de desbordar.
                  child: Text(
                    '${option.code} +${option.dialCode}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: enabled
                ? (value) {
                    if (value != null) onCountryChanged(value);
                  }
                : null,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d\s()-]')),
              LengthLimitingTextInputFormatter(20),
            ],
            decoration: InputDecoration(
              labelText: l10n.authPhone,
              helperText: l10n.commonOptional,
              errorText: errorText,
            ),
            onChanged: onChanged,
            onEditingComplete: onEditingComplete,
          ),
        ),
      ],
    );
  }
}
