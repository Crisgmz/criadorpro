import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/media/photo_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_l10n.dart';

/// Foto del ejemplar en el formulario — `RF-REG-15`, pantalla 19.
///
/// La foto se lee del disco por su ruta: en la base solo viaja el camino, no el
/// binario. Si el archivo desapareció —copia restaurada en otro dispositivo,
/// limpieza del sistema— se cae al marcador vacío en vez de romper la pantalla.
class PhotoField extends StatelessWidget {
  const PhotoField({
    required this.path,
    required this.isBusy,
    required this.onCapture,
    required this.onRemove,
    super.key,
  });

  final String? path;
  final bool isBusy;
  final ValueChanged<PhotoSource> onCapture;
  final VoidCallback onRemove;

  Future<void> _choose(BuildContext context) async {
    final l10n = AppL10n.of(context);

    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.photoFromCamera),
              onTap: () => Navigator.of(context).pop(PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.photoFromGallery),
              onTap: () => Navigator.of(context).pop(PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) onCapture(source);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final file = path == null ? null : File(path!);
    final hasPhoto = file != null && file.existsSync();

    return Row(
      children: [
        GestureDetector(
          onTap: isBusy ? null : () => _choose(context),
          child: Container(
            width: 96,
            height: 96,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: isBusy
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : hasPhoto
                ? Image.file(file, fit: BoxFit.cover)
                : Icon(Icons.add_a_photo_outlined, color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: isBusy ? null : () => _choose(context),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(hasPhoto ? l10n.photoChange : l10n.photoAdd),
              ),
              if (hasPhoto)
                TextButton.icon(
                  onPressed: isBusy ? null : onRemove,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.photoRemove),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Text(
                    l10n.photoHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
