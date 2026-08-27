import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Movimiento del producto, tal como lo define el prototipo.
///
/// No son adornos sueltos: son cuatro gestos con un significado cada uno, y
/// repetirlos siempre igual es lo que hace que la app se sienta de una pieza.
///
/// | Gesto | Qué dice | Dónde |
/// |---|---|---|
/// | `slideIn` | «vienes de otra pantalla» | cambio de ruta |
/// | `fadeUp` | «esto acaba de aparecer» | contenido que entra en su sitio |
/// | `pop` | «ha salido bien» | confirmaciones |
/// | `floatY` | «esto está vivo, no es un icono muerto» | ilustraciones |
///
/// Todos respetan «reducir movimiento» del sistema: quien lo activa tiene un
/// motivo —mareo, vértigo— y la animación se salta, no se acorta.
abstract final class CpMotion {
  /// Entrada de pantalla: 28 px desde la derecha, 350 ms.
  static const Duration page = Duration(milliseconds: 350);

  /// Contenido que aparece en su sitio: 10 px desde abajo, 250 ms.
  static const Duration content = Duration(milliseconds: 250);

  /// Confirmación: 400 ms con un rebote corto.
  static const Duration confirm = Duration(milliseconds: 400);

  /// Respiración de una ilustración: 4 s de ida y vuelta.
  static const Duration breathe = Duration(seconds: 4);

  static const Curve easeOut = Curves.easeOutCubic;

  /// `true` cuando el sistema pide no animar.
  static bool isReduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Transición de ruta del prototipo: entra desplazándose desde la derecha
/// mientras aparece.
///
/// Se usa en go_router para que todas las pantallas entren igual. La que sale
/// no se mueve: el prototipo la deja quieta debajo, y así el desplazamiento se
/// lee como «encima», no como «al lado».
class CpPageTransition extends CustomTransitionPage<void> {
  CpPageTransition({required super.child, super.key, super.name})
    : super(
        transitionDuration: CpMotion.page,
        reverseTransitionDuration: CpMotion.page,
        transitionsBuilder: (context, animation, secondary, child) {
          if (CpMotion.isReduced(context)) return child;

          final curved = CurvedAnimation(parent: animation, curve: CpMotion.easeOut);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              // 28 px sobre un ancho de teléfono ≈ 0,07: se define en fracción
              // para que no dé un salto mayor en tableta.
              position: Tween(begin: const Offset(0.07, 0), end: Offset.zero).animate(curved),
              child: child,
            ),
          );
        },
      );
}

/// Contenido que entra en su sitio: sube 10 px mientras aparece.
///
/// Para lo que cambia **dentro** de una pantalla —una pestaña, una lista que
/// termina de cargar—, no para la pantalla entera.
class CpFadeUp extends StatefulWidget {
  const CpFadeUp({
    required this.child,
    super.key,
    this.duration = CpMotion.content,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration duration;

  /// Escalonar una lista con retardos crecientes hace que se lea de arriba
  /// abajo. Pasados unos pocos elementos deja de ayudar y empieza a estorbar,
  /// así que conviene limitarlo a los primeros.
  final Duration delay;

  @override
  State<CpFadeUp> createState() => _CpFadeUpState();
}

class _CpFadeUpState extends State<CpFadeUp> with SingleTickerProviderStateMixin {
  // El controlador se crea aquí y no en un `late final` perezoso: con «reducir
  // movimiento» activo `build` no lo toca, y entonces `dispose` sería quien lo
  // construyera —ya fuera del árbol— y reventaría al buscar el `TickerMode`.
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // Con el movimiento apagado no se programa nada: un temporizador pendiente
    // que ya no va a servir para nada deja el árbol sin quedarse quieto.
    if (CpMotion.isReduced(context)) return;
    if (widget.delay == Duration.zero) {
      _controller.forward();
      return;
    }
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (CpMotion.isReduced(context)) return widget.child;

    final curved = CurvedAnimation(parent: _controller, curve: CpMotion.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
        child: widget.child,
      ),
    );
  }
}

/// Confirmación: crece de golpe, se pasa un poco y se asienta.
///
/// Solo para lo que confirma que algo salió bien. Usarlo en cualquier icono
/// convertiría el gesto en ruido y dejaría de significar nada.
class CpPop extends StatefulWidget {
  const CpPop({required this.child, super.key});

  final Widget child;

  @override
  State<CpPop> createState() => _CpPopState();
}

class _CpPopState extends State<CpPop> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: CpMotion.confirm)..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (CpMotion.isReduced(context)) return widget.child;

    // `easeOutBack` es el rebote del prototipo: 0,4 → 1,12 → 1.
    final scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    return FadeTransition(
      opacity: _controller,
      child: ScaleTransition(scale: scale, child: widget.child),
    );
  }
}

/// Flotación suave y continua, para ilustraciones.
///
/// Cuatro segundos de ida y vuelta: lo bastante lento como para que no llame la
/// atención mientras se lee lo que hay al lado.
class CpFloat extends StatefulWidget {
  const CpFloat({required this.child, super.key, this.distance = 8});

  final Widget child;
  final double distance;

  @override
  State<CpFloat> createState() => _CpFloatState();
}

class _CpFloatState extends State<CpFloat> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: CpMotion.breathe);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El ciclo no se arranca cuando el sistema pide no animar: no basta con
    // ignorarlo al pintar, porque un `Ticker` infinito deja el árbol sin
    // quedarse quieto nunca —el aparato no duerme y `pumpAndSettle` no vuelve.
    if (CpMotion.isReduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Una animación infinita con «reducir movimiento» activo es lo peor que se
    // puede dejar puesto: no termina nunca.
    if (CpMotion.isReduced(context)) return widget.child;

    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) =>
          Transform.translate(offset: Offset(0, -widget.distance * curved.value), child: child),
      child: widget.child,
    );
  }
}

/// Palomita que se dibuja sola, como en el prototipo: el trazo avanza en medio
/// segundo tras una pausa corta.
///
/// La pausa es lo que hace que se lea como una secuencia —primero aparece el
/// círculo, después se marca— en lugar de como dos cosas a la vez.
class CpDrawCheck extends StatefulWidget {
  const CpDrawCheck({
    required this.color,
    super.key,
    this.size = 30,
    this.strokeWidth = 3,
    this.delay = const Duration(milliseconds: 200),
  });

  final Color color;
  final double size;
  final double strokeWidth;
  final Duration delay;

  @override
  State<CpDrawCheck> createState() => _CpDrawCheckState();
}

class _CpDrawCheckState extends State<CpDrawCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || CpMotion.isReduced(context)) return;
    _started = true;

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = CpMotion.isReduced(context);
    final progress = reduced
        ? const AlwaysStoppedAnimation(1.0)
        : CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    return CustomPaint(
      size: Size.square(widget.size),
      painter: _CheckPainter(
        progress: progress,
        color: widget.color,
        strokeWidth: widget.strokeWidth,
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress, required this.color, required this.strokeWidth})
    : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    // Mismo trazo del prototipo (`m5 12 5 6L20 6`) reescalado al lienzo.
    final s = size.width / 24;
    final path = Path()
      ..moveTo(5 * s, 12 * s)
      ..lineTo(10 * s, 18 * s)
      ..lineTo(20 * s, 6 * s);

    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress.value);

    canvas.drawPath(
      drawn,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth || old.progress != progress;
}

/// `showDialog` con la entrada del prototipo: el fondo aparece y la tarjeta
/// crece con un rebote corto (`fadeUp .2s` + `pop .4s`).
///
/// Se usa en lugar de `showDialog` para que todos los diálogos del producto
/// entren igual; la versión de Material entra con una escala sin rebote y se
/// nota al lado de los demás gestos.
Future<T?> showCpDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final theme = Theme.of(context);
  final l10n = MaterialLocalizations.of(context);

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: l10n.modalBarrierDismissLabel,
    // Navy al 50 %, como el prototipo: el velo negro de Material deja la
    // tarjeta flotando sobre un gris sucio.
    barrierColor: const Color(0x800E2A47),
    transitionDuration: CpMotion.confirm,
    pageBuilder: (context, animation, secondary) => builder(context),
    transitionBuilder: (context, animation, secondary, child) {
      if (CpMotion.isReduced(context)) return child;

      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.5)),
        child: ScaleTransition(
          scale: Tween(
            begin: 0.4,
            end: 1.0,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
          child: Theme(data: theme, child: child),
        ),
      );
    },
  );
}

/// Retardo escalonado para el elemento `index` de una lista.
///
/// Escalonar hace que la lista se lea de arriba abajo, pero solo mientras son
/// pocos: pasado el décimo el retardo ya se percibe como lentitud, y al
/// desplazarse una fila que aparece con retraso se lee como un tirón. Por eso
/// se corta.
Duration cpStagger(int index, {int limit = 10}) =>
    index >= limit ? Duration.zero : Duration(milliseconds: 40 * index);

/// Hunde ligeramente lo que envuelve mientras el dedo está encima.
///
/// La tinta de Material responde al soltar; esto responde al **tocar**, que es
/// lo que hace que un botón se sienta pulsado y no solo pintado. En un galpón,
/// con el teléfono a un brazo de distancia y guantes puestos, esa confirmación
/// inmediata es la diferencia entre pulsar una vez o tres.
///
/// Va sobre un `Listener` y no sobre un `GestureDetector`: el segundo entraría
/// en la puja por el gesto y podría robarle el toque al botón que envuelve.
class CpPressable extends StatefulWidget {
  const CpPressable({required this.child, super.key, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<CpPressable> createState() => _CpPressableState();
}

class _CpPressableState extends State<CpPressable> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    if (CpMotion.isReduced(context)) return widget.child;

    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
