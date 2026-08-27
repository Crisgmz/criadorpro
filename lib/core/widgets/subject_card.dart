import 'dart:io';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'brand.dart';

/// Bloque navy que identifica al ejemplar del que trata la pantalla.
///
/// Es el mismo en la cabecera de la ficha y arriba del pedigrí: en las dos, lo
/// primero que hay que resolver es «¿de qué ave estoy hablando?». Repetirlo
/// idéntico es lo que evita que el criador tenga que reorientarse al pasar de
/// una a otra.
///
/// El navy va aquí y no en la barra superior porque el PRD reserva el color de
/// marca a bloques de contenido — y esto **es** contenido.
class CpSubjectCard extends StatelessWidget {
  const CpSubjectCard({
    required this.title,
    required this.subtitle,
    super.key,
    this.photoPath,
    this.badges = const [],
    this.leading,
    this.trailing,
    this.borderRadius = AppRadius.card,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.showWatermark = false,
  });

  final String title;
  final String subtitle;
  final String? photoPath;

  /// Insignias bajo el subtítulo: estado y sexo en la ficha.
  final List<Widget> badges;

  /// Contenido sobre el bloque: la equis de cerrar y las acciones de la ficha.
  final Widget? leading;
  final Widget? trailing;

  final double borderRadius;
  final EdgeInsetsGeometry padding;

  /// Silueta grande y tenue al fondo. Solo en la cabecera de pantalla completa:
  /// en una tarjeta pequeña se convertiría en una mancha.
  final bool showWatermark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ColoredBox(
        color: AppColors.navy,
        child: Stack(
          children: [
            if (showWatermark)
              Positioned(
                right: -20,
                bottom: -30,
                child: const BrandSymbol(size: 190, opacity: 0.06, onDark: true),
              ),
            Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null || trailing != null)
                    Row(children: [?leading, const Spacer(), ?trailing]),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Photo(path: photoPath),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (badges.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xs,
                                children: badges,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Foto del ejemplar sobre el navy, o su hueco punteado.
///
/// El hueco se dibuja punteado y con la palabra «Foto» a propósito: un cuadro
/// liso se leería como una foto que no cargó, y el criador iría a buscar el
/// fallo donde no lo hay.
class _Photo extends StatelessWidget {
  const _Photo({required this.path});

  final String? path;

  static const double _size = 78;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = path == null ? null : File(path!);
    final hasPhoto = file != null && file.existsSync();

    if (hasPhoto) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Image.file(file, width: _size, height: _size, fit: BoxFit.cover),
      );
    }

    return CustomPaint(
      painter: _DashedBorderPainter(color: Colors.white.withValues(alpha: 0.28)),
      child: SizedBox(
        width: _size,
        height: _size,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const BrandSymbol(size: 26, opacity: 0.6, onDark: true),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppL10n.of(context).birdPhotoPlaceholder.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(AppRadius.md));
    final path = Path()..addRRect(rect);

    // Trazo discontinuo a mano: Flutter no lo trae, y recorrer la métrica del
    // contorno es más barato que arrastrar un paquete por una línea punteada.
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 5), paint);
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}
