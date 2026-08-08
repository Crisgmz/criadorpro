import 'package:flutter/material.dart';

/// Marca de Criador Pro.
///
/// El símbolo es un ejemplar, no una huella: `Icons.pets` de Material dibuja
/// una pata de perro y no tiene nada que ver con el oficio. Cualquier sitio que
/// necesite representar «ejemplar» usa estos widgets.
///
/// Se sirven como mapa de bits y no como SVG para no arrastrar `flutter_svg`
/// por cuatro imágenes; a 256 px el símbolo escala de sobra hasta los 3× de una
/// pantalla de alta densidad.
abstract final class BrandAsset {
  static const String symbolNavy = 'assets/transparente/simbolo-navy-256.png';
  static const String symbolWhite = 'assets/transparente/simbolo-white-256.png';
  static const String lockupVerticalWhite = 'assets/transparente/lockup-vertical-white-1024.png';
  static const String lockupHorizontalNavy = 'assets/transparente/lockup-horizontal-navy-1024.png';
}

/// Elige la variante de marca que contrasta con el fondo.
///
/// El símbolo es sólido y viene en dos colores fijos, así que no se puede
/// teñir: hay que servir el archivo correcto. Por omisión se deduce del tema
/// —en oscuro, la variante blanca—, y solo se fuerza donde el fondo no sigue al
/// tema, como las tarjetas navy, que son navy en claro y en oscuro.
bool _resolveOnDark(BuildContext context, {bool? forced}) =>
    forced ?? Theme.of(context).brightness == Brightness.dark;

/// Símbolo suelto, para usar donde iría un icono.
class BrandSymbol extends StatelessWidget {
  const BrandSymbol({super.key, this.size = 24, this.onDark, this.opacity = 1});

  final double size;

  /// `null` sigue al tema. Se fuerza a `true` sobre superficies navy fijas.
  final bool? onDark;

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      _resolveOnDark(context, forced: onDark) ? BrandAsset.symbolWhite : BrandAsset.symbolNavy,
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Decorativo: quien nombra el elemento es el texto que lo acompaña.
      excludeFromSemantics: true,
    );
    return opacity == 1 ? image : Opacity(opacity: opacity, child: image);
  }
}

/// El símbolo **como icono**: hereda tamaño y color del `IconTheme`, igual que
/// un `Icon` de Material.
///
/// Es lo que hay que usar dentro de barras de navegación, `ListTile` y botones,
/// donde Material tiñe los iconos según el estado (activo, inactivo,
/// deshabilitado). `BrandSymbol` no sirve ahí: al ser una imagen de color fijo
/// se queda apagada junto a sus vecinos y no reacciona a la selección.
///
/// El tinte usa `srcIn`, que conserva el alfa del PNG: pinta la silueta del
/// color pedido y deja transparente lo que ya lo era.
class BrandIcon extends StatelessWidget {
  const BrandIcon({super.key, this.size, this.color});

  /// `null` toma el del `IconTheme` — 24 en la retícula de Material.
  final double? size;

  /// `null` toma el del `IconTheme`, que es lo que hace que el destino activo
  /// de la barra se distinga del inactivo.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedSize = size ?? iconTheme.size ?? 24;
    final resolvedColor = color ?? iconTheme.color;
    final opacity = iconTheme.opacity ?? 1;

    // Sin color que aplicar, no hay tinte posible: se cae a elegir el archivo
    // que contraste con el fondo.
    final Widget image = resolvedColor == null
        ? BrandSymbol(size: resolvedSize)
        : Image.asset(
            BrandAsset.symbolNavy,
            width: resolvedSize,
            height: resolvedSize,
            fit: BoxFit.contain,
            color: resolvedColor,
            colorBlendMode: BlendMode.srcIn,
            excludeFromSemantics: true,
          );

    return opacity == 1 ? image : Opacity(opacity: opacity, child: image);
  }
}

/// Logotipo completo, con el nombre del producto incluido.
///
/// Solo se empaquetan las dos composiciones que el producto usa: la vertical
/// blanca para fondos oscuros —donde el logo es el protagonista— y la
/// horizontal navy para los claros, donde comparte espacio con el contenido.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.width = 220, this.onDark});

  final double width;

  /// `null` sigue al tema.
  final bool? onDark;

  @override
  Widget build(BuildContext context) => Image.asset(
    _resolveOnDark(context, forced: onDark)
        ? BrandAsset.lockupVerticalWhite
        : BrandAsset.lockupHorizontalNavy,
    width: width,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}
