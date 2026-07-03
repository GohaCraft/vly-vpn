// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unnecessary_to_list_in_spreads, unused_local_variable, dead_code, unnecessary_null_comparison, avoid_print, unused_field, unnecessary_statements, duplicate_ignore, unnecessary_brace_in_string_interp, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unnecessary_string_escapes, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, unnecessary_import, depend_on_referenced_packages, unnecessary_overrides, avoid_unnecessary_containers, sized_box_for_whitespace, sort_child_properties_last, prefer_final_locals, omit_local_variable_types, always_use_package_imports, curly_braces_in_flow_control_structures, argument_type_not_assignable, invalid_assignment, body_might_complete_normally
part of 'main.dart';

// ═══════════════════════════════════════════════════════════════
//  GLASSMORPHISM 2.0
// ═══════════════════════════════════════════════════════════════

class _Blob { double x, y, vx, vy, r; Color color; _Blob(this.x,this.y,this.vx,this.vy,this.r,this.color); }

// ═══════════════════════════════════════════════════════════════════════════════
//  FPS MONITOR — Production Performance Guard
//  Если FPS < 45 → отключаем BackdropFilter и анимацию блобов
//  Слабые телефоны работают плавно, сильные — красиво
// ═══════════════════════════════════════════════════════════════════════════════

// ── AppProvider singleton ref для VlyBlobBg ─────────────────────────────────
// VlyBlobBg не имеет доступа к Provider — используем глобальную ссылку
class _AppProviderRef {
  static AppProvider? instance;
  static void register(AppProvider app) { instance = app; }
}

// ── Media Background Widget ───────────────────────────────────────────────────
// Рендерит фото или GIF как фон с оптимизацией
class _MediaBackground extends StatefulWidget {
  final String path, type;
  final double opacity;
  const _MediaBackground({required this.path, required this.type, this.opacity = 0.35});
  @override State<_MediaBackground> createState() => _MediaBackgroundState();
}

class _MediaBackgroundState extends State<_MediaBackground> {
  // GIF: frames decoded via dart:ui codec
  List<ui.Image>? _gifImages;
  List<int>?      _gifDurations;
  int             _frameIdx = 0;
  Timer?          _gifTimer;

  @override
  void initState() {
    super.initState();
    if (widget.type == 'gif') _loadGif();
    // video: rendered natively via TextureView in VlyVpnService
    // We simply show a static poster frame for video type
  }

  Future<void> _loadGif() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 800);
      final imgs = <ui.Image>[];
      final durs = <int>[];
      for (int i = 0; i < codec.frameCount; i++) {
        final f = await codec.getNextFrame();
        imgs.add(f.image);
        durs.add(f.duration.inMilliseconds.clamp(16, 1000));
      }
      if (!mounted || imgs.isEmpty) return;
      setState(() { _gifImages = imgs; _gifDurations = durs; });
      _scheduleGifFrame(0);
    } catch (_) {}
  }

  void _scheduleGifFrame(int idx) {
    if (!mounted || _gifImages == null) return;
    final dur = _gifDurations![idx % _gifDurations!.length];
    _gifTimer = Timer(Duration(milliseconds: dur), () {
      if (!mounted) return;
      setState(() => _frameIdx = (idx + 1) % _gifImages!.length);
      _scheduleGifFrame(_frameIdx);
    });
  }

  @override
  void dispose() {
    _gifTimer?.cancel();
    for (final img in _gifImages ?? []) img.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (widget.type == 'gif' && _gifImages != null) {
      child = RawImage(
        image:  _gifImages![_frameIdx],
        fit:    BoxFit.cover,
        width:  double.infinity,
        height: double.infinity,
      );
    } else if (widget.type == 'video') {
      // Video background rendered via platform view
      // Show photo thumbnail if available, otherwise dark overlay
      child = Container(
        color: Colors.black,
        child: const Center(child: Icon(Icons.play_circle_fill_rounded,
            color: Colors.white24, size: 64)),
      );
    } else {
      child = Image.file(
        File(widget.path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: (MediaQuery.of(context).size.width *
            MediaQuery.of(context).devicePixelRatio).round().clamp(0, 2160),
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return SizedBox.expand(child: Opacity(opacity: widget.opacity, child: child));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  CUSTOM THEME EDITOR  —  Редактор пользовательской темы
// ═══════════════════════════════════════════════════════════════════════════════

// ── Colour picker row ────────────────────────────────────────────────────────

// ── Hex color picker bottom sheet ─────────────────────────────────────────────

class _HexColorPicker extends StatefulWidget {
  final Color initial;
  final ValueChanged<Color> onPicked;
  const _HexColorPicker({required this.initial, required this.onPicked});
  @override State<_HexColorPicker> createState() => _HexColorPickerState();
}

class _HexColorPickerState extends State<_HexColorPicker> {
  late double _h, _s, _v, _a;
  late TextEditingController _hexCtrl;
  bool _hexError = false;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initial);
    _h = hsv.hue; _s = hsv.saturation; _v = hsv.value; _a = hsv.alpha;
    _hexCtrl = TextEditingController(text: _toHex(widget.initial));
  }

  @override void dispose() { _hexCtrl.dispose(); super.dispose(); }

  Color get _current => HSVColor.fromAHSV(_a, _h, _s, _v).toColor();

  String _toHex(Color c) =>
      '#${c.red.toRadixString(16).padLeft(2,'0')}${c.green.toRadixString(16).padLeft(2,'0')}${c.blue.toRadixString(16).padLeft(2,'0')}'.toUpperCase();

  void _fromHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length != 6) throw Exception();
      final v = int.parse('FF$clean', radix: 16);
      final c = Color(v);
      final hsv = HSVColor.fromColor(c);
      setState(() {
        _h = hsv.hue; _s = hsv.saturation; _v = hsv.value;
        _hexError = false;
      });
    } catch (_) { setState(() => _hexError = true); }
  }

  @override
  Widget build(BuildContext context) {
    final c = _current;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1226),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.08))),
      padding: EdgeInsets.fromLTRB(20, 16, 20,
          20 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        // Превью цвета
        Container(height: 52, decoration: BoxDecoration(
            color: c, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
            boxShadow: [BoxShadow(color: c.withOpacity(0.5), blurRadius: 20)])),
        const SizedBox(height: 16),
        // HUE slider
        _SliderRow('H', _h / 360, (v) => setState(() { _h = v * 360; _hexCtrl.text = _toHex(_current); }),
            gradient: LinearGradient(colors: List.generate(7, (i) =>
                HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor()))),
        const SizedBox(height: 8),
        // SATURATION slider
        _SliderRow('S', _s, (v) => setState(() { _s = v; _hexCtrl.text = _toHex(_current); }),
            gradient: LinearGradient(colors: [
                HSVColor.fromAHSV(1, _h, 0, _v).toColor(),
                HSVColor.fromAHSV(1, _h, 1, _v).toColor()])),
        const SizedBox(height: 8),
        // VALUE slider
        _SliderRow('V', _v, (v) => setState(() { _v = v; _hexCtrl.text = _toHex(_current); }),
            gradient: LinearGradient(colors: [Colors.black,
                HSVColor.fromAHSV(1, _h, _s, 1).toColor()])),
        const SizedBox(height: 8),
        // ALPHA slider
        _SliderRow('A', _a, (v) => setState(() { _a = v; _hexCtrl.text = _toHex(_current); }),
            gradient: LinearGradient(colors: [Colors.transparent, c.withOpacity(1)])),
        const SizedBox(height: 14),
        // HEX input
        Row(children: [
          const Text('HEX', style: TextStyle(fontSize: 11, color: Colors.white38, letterSpacing: 1)),
          const SizedBox(width: 12),
          Expanded(child: TextField(
            controller: _hexCtrl,
            style: TextStyle(fontSize: 13, color: _hexError ? Colors.redAccent : Colors.white, fontFamily: 'monospace'),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              filled: true, fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _hexError ? Colors.redAccent : Colors.white24)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _hexError ? Colors.redAccent.withOpacity(0.5) : Colors.white12)),
              hintText: '#RRGGBB', hintStyle: const TextStyle(color: Colors.white24, fontSize: 12)),
            onChanged: _fromHex,
            inputFormatters: [LengthLimitingTextInputFormatter(7)],
          )),
        ]),
        const SizedBox(height: 14),
        // Кнопки
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(height: 44, decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24)),
              child: Center(child: Text(S.t('cancel'),
                  style: const TextStyle(color: Colors.white54, fontSize: 13)))))),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: () { widget.onPicked(_current); Navigator.pop(context); },
            child: Container(height: 44, decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(colors: [c, c.withOpacity(0.7)])),
              child: Center(child: Text(S.t('apply'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)))))),
        ]),
      ]));
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final Gradient gradient;
  const _SliderRow(this.label, this.value, this.onChanged, {required this.gradient});
  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 16, child: Text(label,
        style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w700))),
    const SizedBox(width: 8),
    Expanded(child: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(children: [
        Container(height: 20, decoration: BoxDecoration(gradient: gradient)),
        // Checkerboard для alpha
        if (label == 'A') _Checkerboard(size: 10),
        if (label == 'A') Container(height: 20, decoration: BoxDecoration(gradient: gradient)),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 20, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
            trackShape: const RectangularSliderTrackShape(),
            thumbColor: Colors.white, activeTrackColor: Colors.transparent,
            inactiveTrackColor: Colors.transparent),
          child: Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged)),
      ]))),
  ]);
}

class _Checkerboard extends StatelessWidget {
  final double size;
  const _Checkerboard({required this.size});
  @override
  Widget build(BuildContext context) => SizedBox(height: 20, child: CustomPaint(
    painter: _CheckerPainter(size)));
}

class _CheckerPainter extends CustomPainter {
  final double size;
  _CheckerPainter(this.size);
  @override void paint(Canvas canvas, Size s) {
    final p1 = Paint()..color = const Color(0xFFCCCCCC);
    final p2 = Paint()..color = Colors.white;
    for (double x = 0; x < s.width; x += size) {
      for (double y = 0; y < s.height; y += size) {
        canvas.drawRect(Rect.fromLTWH(x, y, size, size),
            ((x / size + y / size).toInt() % 2 == 0) ? p1 : p2);
      }
    }
  }
  @override bool shouldRepaint(_) => false;
}


// ── Preview blob painter ───────────────────────────────────────────────────────
class _PreviewBlobPainter extends CustomPainter {
  final List<Color> colors;
  const _PreviewBlobPainter(this.colors);
  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < colors.length; i++) {
      final x = size.width  * (0.3 + i * 0.25);
      final y = size.height * (0.4 + (i % 2) * 0.3);
      final r = size.width  * 0.35;
      canvas.drawCircle(Offset(x, y), r, Paint()
        ..shader = RadialGradient(
          colors: [colors[i].withOpacity(0.5), Colors.transparent],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: r)));
    }
  }
  @override bool shouldRepaint(_) => true;
}

// ── Preset chip ───────────────────────────────────────────────────────────────
class _PresetChip extends StatelessWidget {
  final String name;
  final Color a, a2, bg;
  final void Function(Color, Color, Color) onTap;
  const _PresetChip(this.name, this.a, this.a2, this.bg, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onTap(a, a2, bg),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [a.withOpacity(0.2), a2.withOpacity(0.1)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: a.withOpacity(0.4))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: a, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(name, style: TextStyle(fontSize: 11, color: a, fontWeight: FontWeight.w600)),
      ])));
}

class FpsMonitor {
  static bool _lowPerfMode = false;
  static double _fps       = 60.0;
  static DateTime? _lastFrame;
  static int _frameCount   = 0;
  static double _sum       = 0;

  static bool get lowPerfMode => _lowPerfMode;
  static double get currentFps => _fps;

  // Вызывается каждый кадр из SchedulerBinding
  static void onFrame(Duration ts) {
    final now = DateTime.now();
    if (_lastFrame != null) {
      final delta = now.difference(_lastFrame!).inMilliseconds;
      if (delta > 0 && delta < 200) { // игнорируем аномальные кадры
        _sum += 1000.0 / delta;
        _frameCount++;
      }
    }
    _lastFrame = now;

    // Пересчитываем каждые 60 кадров (~1 секунда)
    if (_frameCount >= 60) {
      _fps = _sum / _frameCount;
      _sum = 0; _frameCount = 0;

      // Гистерезис: включаем Low Perf при < 45 fps, выключаем при > 55 fps
      if (!_lowPerfMode && _fps < 45) {
        _lowPerfMode = true;
        _notifyListeners();
      } else if (_lowPerfMode && _fps > 55) {
        _lowPerfMode = false;
        _notifyListeners();
      }
    }
  }

  static final List<VoidCallback> _listeners = [];
  static void addListener(VoidCallback cb)    { _listeners.add(cb); }
  static void removeListener(VoidCallback cb) { _listeners.remove(cb); }
  static void _notifyListeners()              { for (final cb in _listeners) cb(); }
}

// Глобальный экземпляр — регистрируем frame callback в main()
bool _fpsMonitorStarted = false;
void startFpsMonitor() {
  if (_fpsMonitorStarted) return;
  _fpsMonitorStarted = true;
  SchedulerBinding.instance.addPersistentFrameCallback(FpsMonitor.onFrame);
}

class VlyBlobBg extends StatefulWidget {
  final Widget child;
  final bool connected;
  final bool isLight;
  const VlyBlobBg({super.key, required this.child, this.connected = false, this.isLight = false});
  @override State<VlyBlobBg> createState() => _VlyBlobBgState();
}

class _VlyBlobBgState extends State<VlyBlobBg> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  late final List<_Blob> _blobs;
  bool _lowPerf = false;

  @override
  void initState() {
    super.initState();
    _lowPerf = FpsMonitor.lowPerfMode;
    FpsMonitor.addListener(_onFpsChange);

    final bc = widget.isLight ? _lightBlobs : _darkBlobs;
    _blobs = [
      _Blob(0.15, 0.20,  0.00022,  0.00015, 0.55, bc[0]),
      _Blob(0.80, 0.15, -0.00018,  0.00020, 0.45, bc[1]),
      _Blob(0.50, 0.65,  0.00015, -0.00018, 0.60, bc[2]),
      _Blob(0.20, 0.80,  0.00020, -0.00012, 0.40, bc[3]),
      _Blob(0.85, 0.75, -0.00016, -0.00014, 0.42, bc[4]),
      _Blob(0.50, 0.30, -0.00012,  0.00016, 0.35, bc[5]),
    ];
    // FIX: используем Ticker напрямую вместо AnimationController+setState
    // AnimationController вызывал setState на каждый кадр → BLASTBufferQueue overflow
    // Ticker обновляет только CustomPainter через repaint notifier
    _ticker = createTicker(_step)..start();
  }

  void _onFpsChange() {
    if (!mounted) return;
    final lp = FpsMonitor.lowPerfMode;
    if (lp != _lowPerf) {
      setState(() => _lowPerf = lp);
      if (lp) { _ticker.stop(); }
      else    { _ticker.start(); }
    }
  }

  void _step(Duration _) {
    if (_lowPerf || !mounted) return;
    for (final b in _blobs) {
      b.x += b.vx; b.y += b.vy;
      if (b.x < -0.2 || b.x > 1.2) b.vx = -b.vx;
      if (b.y < -0.2 || b.y > 1.2) b.vy = -b.vy;
    }
    _blobPainterKey.currentState?._repaint();
  }

  final _blobPainterKey = GlobalKey<_BlobPainterWidgetState>();

  @override void dispose() {
    FpsMonitor.removeListener(_onFpsChange);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FIX тем: слушаем AppProvider (listen:true) — иначе при смене темы фон не
    // пересобирался (HomeScreen в IndexedStack — const, не ребилдился на AppProvider).
    final app     = Provider.of<AppProvider>(context);
    // app.skin корректно отдаёт кастомную тему (раньше VlySkin.byId(custom)
    // возвращал Midnight — фон не соответствовал выбранной теме).
    final activeSkin = app.skin;
    final skinBg  = activeSkin.bgDark;
    final skinMid = activeSkin.bgGradientMid;
    final bg = widget.isLight
        ? (widget.connected ? const Color(0xFFEDF4FC) : const Color(0xFFF5F6FC))
        : (widget.connected
            ? Color.lerp(skinBg, Colors.black, 0.12)!
            : skinBg);

    // FIX тем: перекрашиваем анимированные блобы под АКТИВНУЮ тему. Раньше брался
    // фиксированный _darkBlobs → фон не менял цвет при смене темы (главная «кривизна»).
    final palette = widget.isLight ? _lightBlobs : activeSkin.blobs;
    if (palette.isNotEmpty) {
      for (int i = 0; i < _blobs.length; i++) {
        _blobs[i].color = palette[i % palette.length];
      }
    }

    final hasMedia = app.hasCustomMedia;
    final mediaOpacity = app.customMediaType == 'video' ? 0.45 : 0.40;

    return Stack(children: [
      Container(color: bg),
      // Радиальный градиент поверх (глубина)
      if (!widget.isLight)
        Positioned.fill(child: IgnorePointer(child: Container(
          decoration: BoxDecoration(gradient: RadialGradient(
            center: const Alignment(-0.3, -0.6),
            radius: 1.3,
            colors: [skinMid.withOpacity(0.55), Colors.transparent],
          ))))),
      // Узор скина
      if (!widget.isLight && activeSkin.pattern != SkinPattern.none)
        Positioned.fill(child: RepaintBoundary(child: CustomPaint(
          painter: _PatternPainter(
            pattern: activeSkin.pattern,
            color: activeSkin.accent,
            opacity: activeSkin.patternOpacity,
          )))),
      // Медиа-фон
      if (hasMedia)
        Positioned.fill(child: _MediaBackground(
          path: app.customMediaPath,
          type: app.customMediaType,
          opacity: mediaOpacity,
        )),
      // Блобы
      if (!_lowPerf)
        RepaintBoundary(
          child: Opacity(
            opacity: hasMedia ? 0.25 : 1.0,
            child: _BlobPainterWidget(
              key: _blobPainterKey,
              blobs: _blobs,
              connected: widget.connected,
              isLight: widget.isLight,
            ),
          ),
        ),
      if (_lowPerf)
        Opacity(
          opacity: hasMedia ? 0.20 : 1.0,
          child: CustomPaint(
            painter: _BlobPainter(_blobs, widget.connected, widget.isLight),
            child: const SizedBox.expand(),
          ),
        ),
      widget.child,
    ]);
  }
}

// FIX: отдельный StatefulWidget для CustomPainter — перерисовка только блобов,
// не всего дерева виджетов
class _BlobPainterWidget extends StatefulWidget {
  final List<_Blob> blobs;
  final bool connected, isLight;
  const _BlobPainterWidget({super.key, required this.blobs,
      required this.connected, required this.isLight});
  @override State<_BlobPainterWidget> createState() => _BlobPainterWidgetState();
}

class _BlobPainterWidgetState extends State<_BlobPainterWidget> {
  void _repaint() { if (mounted) setState(() {}); }
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _BlobPainter(widget.blobs, widget.connected, widget.isLight),
    child: const SizedBox.expand(),
  );
}

class _BlobPainter extends CustomPainter {
  final List<_Blob> blobs; final bool connected, isLight;
  _BlobPainter(this.blobs, this.connected, this.isLight);
  @override
  void paint(Canvas canvas, Size size) {
    for (final b in blobs) {
      final cx = b.x * size.width; final cy = b.y * size.height;
      final r  = b.r * (size.width > size.height ? size.width : size.height) * 0.65;
      final op = isLight ? (connected ? 0.35 : 0.25) : (connected ? 0.72 : 0.58);
      canvas.drawCircle(Offset(cx, cy), r, Paint()
        ..shader = RadialGradient(
          colors: [b.color.withOpacity(op), b.color.withOpacity(op * 0.38), Colors.transparent],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)));
    }
  }
  // FIX бага смены темы: раньше сравнивались только connected/isLight/length,
  // но НЕ цвета блобов — при смене тёмной темы на тёмную (Океан→Сакура) холст
  // блобов не перерисовывался, оставляя старые цвета поверх нового фона =
  // «смешивание». Это painter, управляемый тикером-анимацией, поэтому корректно
  // перерисовывать всегда: и позиции блобов (анимация), и их цвета (смена темы)
  // обновляются мгновенно. FPS-гейт (_lowPerf) уже останавливает тикер на
  // слабых устройствах, так что лишних перерисовок нет.
  @override bool shouldRepaint(_BlobPainter o) => true;
}

// iOS 26 Liquid Glass material — specular highlights, refraction, blur
class GlassBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding, margin;
  final double radius, blur, tintOpacity;
  final Color? borderColor, tint;
  const GlassBox({super.key, required this.child, this.padding, this.margin,
    this.radius = 28, this.borderColor, this.blur = 40, this.tint, this.tintOpacity = 0.12});

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final bc = borderColor ?? (light ? Colors.white.withOpacity(0.70) : Colors.white.withOpacity(0.22));
    final grad = light
        ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
            Colors.white.withOpacity(0.55), Colors.white.withOpacity(0.30),
            (tint ?? const Color(0xFF90CAF9)).withOpacity(tintOpacity)], stops: const [0,0.5,1])
        : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
            Colors.white.withOpacity(0.14), Colors.white.withOpacity(0.05),
            (tint ?? const Color(0xFF1565C0)).withOpacity(tintOpacity)], stops: const [0,0.5,1]);
    return Container(margin: margin, child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(filter: ui.ImageFilter.blur(
          sigmaX: FpsMonitor.lowPerfMode ? 0 : blur,
          sigmaY: FpsMonitor.lowPerfMode ? 0 : blur),
        child: Container(padding: padding,
          decoration: BoxDecoration(gradient: grad, borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: bc, width: 0.9),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(light ? 0.12 : 0.40), blurRadius: 24, spreadRadius: -6, offset: const Offset(0,4)),
              BoxShadow(color: Colors.white.withOpacity(light ? 0.30 : 0.04), blurRadius: 1, spreadRadius: 0, offset: const Offset(0,-1)),
            ]),
          child: child))));
  }
}

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title; final List<Widget>? actions;
  const GlassAppBar({super.key, required this.title, this.actions});

  // preferredSize должен включать высоту статус-бара — иначе AppBar перекрывает контент
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final mq    = MediaQuery.of(context);
    final top   = mq.padding.top;   // высота статус-бара / челки / Dynamic Island
    final light = Theme.of(context).brightness == Brightness.light;

    // FIX: preferredSize = kToolbarHeight, Flutter добавляет top padding сам
    // через Scaffold.appBar механизм. Нам нужно только добавить внутренний отступ.
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: FpsMonitor.lowPerfMode ? 0 : 30,
          sigmaY: FpsMonitor.lowPerfMode ? 0 : 30),
        child: Container(
          // Scaffold.appBar уже получает top padding от системы
          // Наш Container занимает ровно kToolbarHeight
          height: kToolbarHeight + top,
          padding: EdgeInsets.only(top: top, left: 16, right: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: light
                  ? [Colors.white.withOpacity(0.70), Colors.white.withOpacity(0.40)]
                  : [Colors.white.withOpacity(0.12), Colors.white.withOpacity(0.05)]),
            border: Border(bottom: BorderSide(
                color: light
                    ? Colors.black.withOpacity(0.08)
                    : Colors.white.withOpacity(0.10),
                width: 0.6))),
          child: Row(
            children: [Expanded(child: title), if (actions != null) ...actions!]))));
  }

  // preferredSize с учётом статус-бара вычисляется динамически в build,
  // поэтому передаём увеличенный размер через static helper
  static double totalHeight(BuildContext context) =>
      kToolbarHeight + MediaQuery.of(context).padding.top;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  VLY SCAFFOLD  —  Универсальная обёртка для ВСЕХ экранов
//
//  Решает сразу все проблемы с insets на любом устройстве:
//  - Челки (Dynamic Island, punch-hole)
//  - Навигационная полоска жестов Android
//  - Складные экраны (Z Fold)
//  - Landscape orientation
//  - Планшеты с разным соотношением сторон
//
//  Используется в _SubPage и QrScanScreen.
//  MainShell имеет свой SafeArea(bottom: false) + BottomNav со своим padding.
// ═══════════════════════════════════════════════════════════════════════════════

class VlyScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? trailing;
  final bool extendBehindAppBar;

  const VlyScaffold({
    super.key,
    required this.title,
    required this.body,
    this.trailing,
    this.extendBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final mq    = MediaQuery.of(context);

    return VlyBlobBg(isLight: light, child: Scaffold(
      backgroundColor: Colors.transparent,
      // Scaffold сам применяет padding.top к AppBar — не дублируем
      extendBodyBehindAppBar: extendBehindAppBar,
      appBar: GlassAppBar(
        title: Text(title, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800,
            letterSpacing: 1, color: _textColor(context))),
        actions: [
          if (trailing != null)
            Padding(padding: const EdgeInsets.only(right: 16), child: trailing),
        ],
      ),
      body: SafeArea(
        // top: false — AppBar уже обрабатывает верхний inset
        // left/right: true — боковые вырезы (Galaxy Z Fold, landscape)
        // bottom: true — навигационная полоска жестов
        top:    false,
        left:   true,
        right:  true,
        bottom: true,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.contentMaxW),
            child: body,
          ),
        ),
      ),
    ));
  }
}



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await S.init();
  await _autoConnect.load();
  startFpsMonitor(); // FPS мониторинг — авто-деградация на слабых устройствах
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (_) => AppProvider()),
    ChangeNotifierProvider(create: (_) => VpnProvider()),
    ChangeNotifierProvider.value(value: _autoConnect),
  ], child: const VlyApp()));
}

class VlyApp extends StatelessWidget {
  const VlyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppProvider>(context);
    // Регистрируем singleton для VlyBlobBg (не имеет доступа к Provider)
    _AppProviderRef.register(app);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vly',
      themeMode: app.themeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(app.skin.bgDark),
      home: const MainShell(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  HOME SCREEN
// ═══════════════════════════════════════════════════════════════

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOnboard());
  }

  // Первый запуск: если конфигов ещё нет — показываем онбординг один раз.
  Future<void> _maybeOnboard() async {
    final p = await SharedPreferences.getInstance();
    if ((p.getBool('onboarded_v1') ?? false) || !mounted) return;
    final vpn = Provider.of<VpnProvider>(context, listen: false);
    if (vpn.configs.isNotEmpty) { await p.setBool('onboarded_v1', true); return; }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const OnboardingScreen(), fullscreenDialog: true));
  }

  // Публичный метод для переключения таба из дочерних виджетов
  void switchTab(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: Colors.transparent,
      // SafeArea НЕ нужен здесь — каждый дочерний Scaffold сам управляет insets:
      // - GlassAppBar добавляет padding.top вручную (учитывает челку/Dynamic Island)
      // - _VlyBottomNav добавляет padding.bottom (навигационная полоска)
      // - Добавление SafeArea сюда вызовет двойной отступ сверху
      body: IndexedStack(index: _tab, children: const [
        HomeScreen(),
        ServersScreen(),
        SettingsScreen(),
      ]),
      bottomNavigationBar: _VlyBottomNav(
        current: _tab,
        onTap: (i) => setState(() => _tab = i),
        light: light,
      ),
    );
  }
}

// ── Онбординг первого запуска ──────────────────────────────────────────────────
// Основа: объясняет, что нужен конфиг, и ведёт в существующий поток добавления.
// (Встроенных серверов пока нет — бэкенд позже; здесь честно направляем юзера.)
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static Future<void> _markSeen() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('onboarded_v1', true);
  }

  Widget _step(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Container(width: 40, height: 40,
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: _accent.withOpacity(0.12),
          border: Border.all(color: _accent.withOpacity(0.3))),
        child: Icon(icon, color: _accent, size: 20)),
      const SizedBox(width: 14),
      Expanded(child: Text(text, style: TextStyle(
          fontSize: 13.5, height: 1.35, color: Colors.white.withOpacity(0.85)))),
    ]));

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context, listen: false);
    return VlyBlobBg(child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(children: [
          const Spacer(flex: 2),
          Image.asset('assets/images/vly_icon.png', width: 92, height: 92,
              fit: BoxFit.contain),
          const SizedBox(height: 18),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(colors: [
              Color(0xFFFF2D55), Color(0xFFFF6B35), Color(0xFFFFAA60)]).createShader(b),
            child: const Text('VLY', style: TextStyle(fontSize: 30,
                fontWeight: FontWeight.w900, letterSpacing: 6, color: Colors.white))),
          const SizedBox(height: 8),
          Text(S.t('onb_tagline'), textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.55))),
          const Spacer(),
          _step(Icons.vpn_key_rounded, S.t('onb_step1')),
          _step(Icons.bolt_rounded,    S.t('onb_step2')),
          _step(Icons.lock_rounded,    S.t('onb_step3')),
          const Spacer(flex: 2),
          GestureDetector(
            onTap: () { _markSeen(); Navigator.pop(context); _showAddMenu(context, vpn); },
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(colors: [_accent, _accent.withOpacity(0.7)]),
                boxShadow: [BoxShadow(color: _accent.withOpacity(0.3), blurRadius: 16)]),
              child: Text(S.t('onb_add_config'), textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w800)))),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () { _markSeen(); Navigator.pop(context); },
            child: Text(S.t('onb_later'),
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13))),
        ]),
      )),
    ));
  }
}

// ── Bottom Navigation ─────────────────────────────────────────────────────────

class _VlyBottomNav extends StatelessWidget {
  final int current; final ValueChanged<int> onTap; final bool light;
  const _VlyBottomNav({required this.current, required this.onTap, required this.light});

  // Третий элемент — ключ локализации (метка резолвится в build через S.t).
  static const _items = [
    (Icons.vpn_key_rounded,       Icons.vpn_key_outlined,       'nav_vpn'),
    (Icons.dns_rounded,           Icons.dns_outlined,            'servers_title'),
    (Icons.settings_rounded,      Icons.settings_outlined,       'settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRect(child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
      child: Container(
        height: 60 + MediaQuery.of(context).padding.bottom,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: light
              ? Colors.white.withOpacity(0.80)
              : const Color(0xFF0A0814).withOpacity(0.90),
          border: Border(top: BorderSide(
              color: light
                  ? Colors.black.withOpacity(0.08)
                  : Colors.white.withOpacity(0.08),
              width: 0.5))),
        child: Row(children: _items.asMap().entries.map((e) {
          final sel = current == e.key;
          final item = e.value;
          return Expanded(child: GestureDetector(
            onTap: () => onTap(e.key),
            behavior: HitTestBehavior.opaque,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                decoration: BoxDecoration(
                  color: sel ? _accent.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: sel ? Border.all(
                      color: _accent.withOpacity(0.25), width: 0.8) : null),
                child: Icon(sel ? item.$1 : item.$2,
                  size: 20,
                  color: sel ? _accent : (light ? Colors.black38 : Colors.white30))),
              const SizedBox(height: 2),
              Text(S.t(item.$3), style: TextStyle(
                fontSize: 9,
                color: sel ? _accent : (light ? Colors.black38 : Colors.white30),
                fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                letterSpacing: 0.3)),
            ])));
        }).toList()),
      )));
  }
}

// ── Servers Screen (вкладка серверов) ─────────────────────────────────────────

// ═══════════════════════════════════════════════════════════════════════════
//  PATTERN PAINTER — узоры поверх фона (звёзды, волны, схемы и т.д.)
// ═══════════════════════════════════════════════════════════════════════════
class _PatternPainter extends CustomPainter {
  final SkinPattern pattern;
  final Color       color;
  final double      opacity;
  const _PatternPainter({required this.pattern, required this.color, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color.withOpacity(opacity);
    final r = Random(42);
    switch (pattern) {
      case SkinPattern.dots:      _dots(canvas, size, p, r);
      case SkinPattern.grid:      _grid(canvas, size, p);
      case SkinPattern.hex:       _hex(canvas, size, p);
      case SkinPattern.circuit:   _circuit(canvas, size, p, r);
      case SkinPattern.stars:     _stars(canvas, size, p, r);
      case SkinPattern.waves:     _waves(canvas, size, p);
      case SkinPattern.particles: _particles(canvas, size, p, r);
      case SkinPattern.none:      break;
    }
  }

  void _dots(Canvas c, Size s, Paint p, Random r) {
    const step = 28.0;
    for (double x = 0; x < s.width; x += step)
      for (double y = 0; y < s.height; y += step) {
        final jx = x + (r.nextDouble()-.5)*6;
        final jy = y + (r.nextDouble()-.5)*6;
        c.drawCircle(Offset(jx, jy), .8 + r.nextDouble()*1.2, p);
      }
  }

  void _grid(Canvas c, Size s, Paint p) {
    final lp = Paint()..color = p.color..strokeWidth = .5;
    const step = 32.0;
    for (double x = 0; x <= s.width;  x += step) c.drawLine(Offset(x, 0), Offset(x, s.height), lp);
    for (double y = 0; y <= s.height; y += step) c.drawLine(Offset(0, y), Offset(s.width, y),  lp);
  }

  void _hex(Canvas c, Size s, Paint p) {
    const r = 18.0, h = r * 1.732, w = r * 2.0;
    final lp = Paint()..color = p.color..strokeWidth = .6..style = PaintingStyle.stroke;
    int row = 0;
    for (double y = 0; y < s.height + h; y += h) {
      final xOff = (row % 2 == 0) ? 0.0 : w * .75;
      for (double x = -w; x < s.width + w; x += w * 1.5) {
        final cx = x + xOff;
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final a = pi / 180 * (60*i - 30);
          final px = cx + r * cos(a), py = y + r * sin(a);
          i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
        }
        path.close(); c.drawPath(path, lp);
      }
      row++;
    }
  }

  void _circuit(Canvas c, Size s, Paint p, Random r) {
    final lp = Paint()..color = p.color..strokeWidth = .7;
    const step = 40.0;
    for (double x = step; x < s.width; x += step)
      for (double y = step; y < s.height; y += step) {
        if (r.nextDouble() > .35) continue;
        final dir = r.nextInt(4);
        final x2 = x + (dir==0?step:dir==1?-step:0);
        final y2 = y + (dir==2?step:dir==3?-step:0);
        c.drawLine(Offset(x,y), Offset(x2,y2), lp);
        if (r.nextDouble() > .6) c.drawCircle(Offset(x,y), 2.0, p);
      }
  }

  void _stars(Canvas c, Size s, Paint p, Random r) {
    final count = (s.width * s.height / 1800).round().clamp(60, 250);
    for (int i = 0; i < count; i++) {
      final x = r.nextDouble()*s.width, y = r.nextDouble()*s.height;
      final rv = r.nextDouble()*1.8 + .3;
      final fade = r.nextDouble();
      c.drawCircle(Offset(x,y), rv, Paint()..color = p.color.withOpacity(p.color.opacity*fade));
      if (rv > 1.4) {
        final bp = Paint()..color = p.color.withOpacity(p.color.opacity*.4)..strokeWidth = .4;
        c.drawLine(Offset(x-rv*3,y), Offset(x+rv*3,y), bp);
        c.drawLine(Offset(x,y-rv*3), Offset(x,y+rv*3), bp);
      }
    }
  }

  void _waves(Canvas c, Size s, Paint p) {
    final lp = Paint()..color = p.color..strokeWidth = 1.0..style = PaintingStyle.stroke;
    for (int w = 0; w < 5; w++) {
      final yBase = s.height*(0.2+w*0.18), amp = 8.0+w*4.0, freq = 0.008-w*0.001;
      final path = Path()..moveTo(0, yBase);
      for (double x = 0; x <= s.width; x += 2)
        path.lineTo(x, yBase + sin(x*freq*pi*2)*amp);
      c.drawPath(path, lp);
    }
  }

  void _particles(Canvas c, Size s, Paint p, Random r) {
    final count = (s.width * s.height / 2500).round().clamp(40, 150);
    for (int i = 0; i < count; i++) {
      final x = r.nextDouble()*s.width, y = r.nextDouble()*s.height;
      final rv = r.nextDouble()*2.5 + .5;
      c.drawCircle(Offset(x,y), rv,
          Paint()..color = p.color.withOpacity(p.color.opacity*(.3+r.nextDouble()*.7)));
    }
  }

  @override
  bool shouldRepaint(_PatternPainter o) =>
      o.pattern != pattern || o.color != color || o.opacity != opacity;
}