import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ───────────────────────── أنواع المفاتيح ─────────────────────────
/// مواصفات نوع مفتاح: عدد القطع (الدبابيس) ومدى أرقام العمق.
/// لإضافة نوع جديد أضف سطرًا في [kKeyTypes] فقط.
class KeyType {
  const KeyType({
    required this.id,
    required this.brand,
    required this.pins,
    required this.minDepth,
    required this.maxDepth,
    this.custom = false,
  });

  final String id; // مثل KW1
  final String brand; // مثل Kwikset
  final int pins;
  final int minDepth;
  final int maxDepth;
  final bool custom; // النوع المخصص: يعدّل المستخدم عدد القطع والعمق

  int get levels => maxDepth - minDepth + 1;
  int get defaultDepth => ((minDepth + maxDepth) / 2).round();

  String get label => brand.isEmpty ? id : '$id · $brand';

  KeyType copyWith({int? pins, int? maxDepth}) => KeyType(
        id: id,
        brand: brand,
        pins: pins ?? this.pins,
        minDepth: minDepth,
        maxDepth: maxDepth ?? this.maxDepth,
        custom: custom,
      );
}

const List<KeyType> kKeyTypes = [
  // Kwikset KW1: 5 قطع، أعماق 1–7 (العمق 7 يُستخدم نادرًا)
  KeyType(id: 'KW1', brand: 'Kwikset', pins: 5, minDepth: 1, maxDepth: 7),
  // Schlage SC1: 5 قطع، أعماق 0–9
  KeyType(id: 'SC1', brand: 'Schlage', pins: 5, minDepth: 0, maxDepth: 9),
  // نوع حر: عدد القطع ومدى العمق يحددهما المستخدم
  KeyType(
    id: 'مخصص',
    brand: '',
    pins: 5,
    minDepth: 1,
    maxDepth: 7,
    custom: true,
  ),
];

const int kMinCuts = 3;
const int kMaxCuts = 10;
const int kMinCustomMaxDepth = 3;
const int kMaxCustomMaxDepth = 9;

// ألوان شاشة الجهاز (برتقالي كما في الصورة)
const Color kLcdColor = Color(0xFFF5A623);
const Color kLcdInk = Color(0xFF2A1A00);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const KeyCopyApp());
}

class KeyCopyApp extends StatelessWidget {
  const KeyCopyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نسخ المفاتيح',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.amber,
      ),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const KeyCopyScreen(),
    );
  }
}

// ───────────────────────── الشاشة الرئيسية ─────────────────────────
class KeyCopyScreen extends StatefulWidget {
  const KeyCopyScreen({super.key});

  @override
  State<KeyCopyScreen> createState() => _KeyCopyScreenState();
}

class _KeyCopyScreenState extends State<KeyCopyScreen> {
  late KeyType _type;
  late List<int> _depths;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _type = kKeyTypes.first;
    _depths = List<int>.filled(_type.pins, _type.defaultDepth);
  }

  String get _code => _depths.join(' ');

  // اختيار نوع مفتاح: يعيد ضبط القطع على عمق ابتدائي مناسب لذلك النوع
  void _selectType(KeyType t) {
    if (t.id == _type.id) return;
    HapticFeedback.selectionClick();
    setState(() {
      _type = t;
      _depths = List<int>.filled(t.pins, t.defaultDepth);
      _selected = 0;
    });
  }

  // أعلى/أسفل: تحريك الخط للأعلى (أقل عمقًا) أو للأسفل (أكثر عمقًا)
  void _changeDepth(int delta) {
    final next =
        (_depths[_selected] + delta).clamp(_type.minDepth, _type.maxDepth);
    if (next == _depths[_selected]) return;
    HapticFeedback.selectionClick();
    setState(() => _depths[_selected] = next);
  }

  // يمين/يسار: الانتقال بين مواضع القطع
  void _moveSelection(int delta) {
    final next = (_selected + delta).clamp(0, _type.pins - 1);
    if (next == _selected) return;
    HapticFeedback.selectionClick();
    setState(() => _selected = next);
  }

  void _resetSelected() {
    HapticFeedback.mediumImpact();
    setState(() => _depths[_selected] = _type.defaultDepth);
  }

  void _resetAll() {
    HapticFeedback.mediumImpact();
    setState(() {
      _depths = List<int>.filled(_type.pins, _type.defaultDepth);
      _selected = 0;
    });
  }

  // تعديل عدد القطع (للنوع المخصص فقط)
  void _setPins(int count) {
    final n = count.clamp(kMinCuts, kMaxCuts);
    if (n == _type.pins) return;
    setState(() {
      if (n > _type.pins) {
        _depths = [
          ..._depths,
          ...List<int>.filled(n - _type.pins, _type.defaultDepth),
        ];
      } else {
        _depths = _depths.sublist(0, n);
      }
      _type = _type.copyWith(pins: n);
      if (_selected > n - 1) _selected = n - 1;
    });
  }

  // تعديل أعلى رقم عمق (للنوع المخصص فقط)
  void _setMaxDepth(int value) {
    final m = value.clamp(kMinCustomMaxDepth, kMaxCustomMaxDepth);
    if (m == _type.maxDepth) return;
    setState(() {
      _type = _type.copyWith(maxDepth: m);
      _depths = _depths.map((d) => d > m ? m : d).toList();
    });
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _depths.join('')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ الكود'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Widget _stepperRow(
    String label,
    int value,
    VoidCallback? onMinus,
    VoidCallback? onPlus,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: onMinus,
        ),
        Text('$value', style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: onPlus,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('نسخ المفاتيح'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'مسح الكل',
            icon: const Icon(Icons.restart_alt),
            onPressed: _resetAll,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            children: [
              // اختيار نوع المفتاح
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kKeyTypes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final t = kKeyTypes[i];
                    return Center(
                      child: ChoiceChip(
                        label: Text(t.label),
                        selected: t.id == _type.id,
                        onSelected: (_) => _selectType(t),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              // المربع العلوي ثابت الأبعاد
              Center(
                child: KeyDisplay(
                  depths: _depths,
                  selected: _selected,
                  minDepth: _type.minDepth,
                  maxDepth: _type.maxDepth,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'الموضع ${_selected + 1} من ${_type.pins}  •  '
                'العمق ${_depths[_selected]}  '
                '(${_type.minDepth}–${_type.maxDepth})',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('الكود: '),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      _code,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'نسخ الكود',
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: _copyCode,
                  ),
                ],
              ),
              // خيارات النوع المخصص فقط
              if (_type.custom) ...[
                _stepperRow(
                  'عدد القطع',
                  _type.pins,
                  _type.pins > kMinCuts ? () => _setPins(_type.pins - 1) : null,
                  _type.pins < kMaxCuts ? () => _setPins(_type.pins + 1) : null,
                ),
                _stepperRow(
                  'أعلى عمق',
                  _type.maxDepth,
                  _type.maxDepth > kMinCustomMaxDepth
                      ? () => _setMaxDepth(_type.maxDepth - 1)
                      : null,
                  _type.maxDepth < kMaxCustomMaxDepth
                      ? () => _setMaxDepth(_type.maxDepth + 1)
                      : null,
                ),
              ],
              // دائرة الأزرار في الأسفل
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: DPad(
                      onUp: () => _changeDepth(-1),
                      onDown: () => _changeDepth(1),
                      onLeft: () => _moveSelection(-1),
                      onRight: () => _moveSelection(1),
                      onCenter: _resetSelected,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── مربع العرض (أبعاد ثابتة) ─────────────────────────
class KeyDisplay extends StatelessWidget {
  const KeyDisplay({
    super.key,
    required this.depths,
    required this.selected,
    required this.minDepth,
    required this.maxDepth,
  });

  final List<int> depths;
  final int selected;
  final int minDepth;
  final int maxDepth;

  static const double boxWidth = 340;
  static const double boxHeight = 190;

  @override
  Widget build(BuildContext context) {
    // الأبعاد ثابتة؛ على الشاشات الضيقة يُصغَّر المربع بنفس النسبة فقط
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        width: boxWidth,
        height: boxHeight,
        decoration: BoxDecoration(
          color: kLcdColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF111111), width: 4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: CustomPaint(
            painter: KeyPainter(
              depths: depths,
              selected: selected,
              minDepth: minDepth,
              maxDepth: maxDepth,
            ),
          ),
        ),
      ),
    );
  }
}

class KeyPainter extends CustomPainter {
  KeyPainter({
    required this.depths,
    required this.selected,
    required this.minDepth,
    required this.maxDepth,
  });

  final List<int> depths;
  final int selected;
  final int minDepth;
  final int maxDepth;

  static const double pad = 14;
  static const double shoulderY = 76;
  static const double firstY = 92;
  static const double step = 9.5;

  // ميل جانبي الهرم (1 = 45 درجة)
  static const double ridgeSlope = 1.0;

  double _yOf(int depth) => firstY + (depth - minDepth) * step;

  /// يضيف الجزء الواقع بين نهاية قطعة (xe, ye) وبداية القطعة التالية (xs, ys).
  /// الخطان الصاعدان من الجانبين يلتقيان في قمة (هرم) إن كان التقاؤهما داخل
  /// المسافة بين القطعتين، وإلا يُوصل الخط مباشرة (كالانتقال من 4 إلى 2 البعيدة).
  /// القمة لا ترتفع فوق مستوى الكتف.
  void _addRidge(Path path, double xe, double ye, double xs, double ys) {
    const m = ridgeSlope;
    final xStar = (xe + xs) / 2 + (ye - ys) / (2 * m);
    if (xStar <= xe || xStar >= xs) return; // وصلة مباشرة بلا قمة

    final yStar = ye - m * (xStar - xe);
    if (yStar >= shoulderY) {
      path.lineTo(xStar, yStar);
    } else {
      // القمة تتجاوز الكتف: نقطعها بخط أفقي عند مستوى الكتف
      path.lineTo(xe + (ye - shoulderY) / m, shoulderY);
      path.lineTo(xs - (ys - shoulderY) / m, shoulderY);
    }
  }

  void _text(Canvas canvas, String s, Offset center, double size,
      FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          fontWeight: weight,
          color: kLcdInk,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final n = depths.length;
    final slotW = (w - 2 * pad) / n;
    final half = slotW * 0.28;

    // خطوط إرشادية خفيفة لمستويات العمق
    final guide = Paint()
      ..color = kLcdInk.withOpacity(0.12)
      ..strokeWidth = 1;
    for (var d = minDepth; d <= maxDepth; d++) {
      canvas.drawLine(Offset(pad, _yOf(d)), Offset(w - pad, _yOf(d)), guide);
    }

    // الخط الرئيسي
    final line = Paint()
      ..color = kLcdInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.miter;

    final path = Path()..moveTo(pad, shoulderY);
    for (var i = 0; i < n; i++) {
      final cx = pad + slotW * (i + 0.5);
      final y = _yOf(depths[i]);
      if (i == 0) {
        path.lineTo(cx - half - slotW * 0.2, shoulderY);
      }
      path.lineTo(cx - half, y);
      path.lineTo(cx + half, y);

      if (i < n - 1) {
        // الحافة (الهرم) بين هذه القطعة والتي بعدها
        final nextCx = pad + slotW * (i + 1.5);
        final nextY = _yOf(depths[i + 1]);
        _addRidge(path, cx + half, y, nextCx - half, nextY);
      } else {
        path.lineTo(cx + half + slotW * 0.2, shoulderY);
      }
    }
    path.lineTo(w - pad, shoulderY);
    canvas.drawPath(path, line);

    // الأرقام والعلامات
    final tick = Paint()
      ..color = kLcdInk
      ..strokeWidth = 2;
    for (var i = 0; i < n; i++) {
      final cx = pad + slotW * (i + 0.5);
      final isSel = i == selected;
      _text(canvas, '${depths[i]}', Offset(cx, 36), isSel ? 30 : 24,
          isSel ? FontWeight.bold : FontWeight.normal);
      canvas.drawLine(Offset(cx, 54), Offset(cx, 66), tick);

      if (isSel) {
        // قطعة الخط المحددة أسمك
        final y = _yOf(depths[i]);
        canvas.drawLine(
          Offset(cx - half, y),
          Offset(cx + half, y),
          Paint()
            ..color = kLcdInk
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
        // سهم لأسفل فوق الرقم المحدد
        final arrow = Path()
          ..moveTo(cx, 20)
          ..lineTo(cx - 6, 11)
          ..lineTo(cx + 6, 11)
          ..close();
        canvas.drawLine(Offset(cx, 4), Offset(cx, 12), tick);
        canvas.drawPath(arrow, Paint()..color = kLcdInk);
      }
    }
  }

  @override
  bool shouldRepaint(covariant KeyPainter oldDelegate) => true;
}

// ───────────────────────── دائرة الأزرار ─────────────────────────
class DPad extends StatelessWidget {
  const DPad({
    super.key,
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
    required this.onCenter,
  });

  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onCenter;

  static const double size = 240;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // اتجاهات الأسهم فيزيائية دائمًا (يمين/يسار حقيقيان)
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surfaceContainerHighest,
                border: Border.all(color: cs.outline, width: 2),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: _padButton(Icons.keyboard_arrow_up, onUp),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _padButton(Icons.keyboard_arrow_down, onDown),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: _padButton(Icons.keyboard_arrow_left, onLeft),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: _padButton(Icons.keyboard_arrow_right, onRight),
            ),
            Center(
              child: RepeatButton(
                onPressed: onCenter,
                repeat: false,
                size: 64,
                color: cs.primary,
                child: Icon(Icons.refresh, color: cs.onPrimary, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _padButton(IconData icon, VoidCallback onPressed) {
    return RepeatButton(
      onPressed: onPressed,
      size: 76,
      color: Colors.transparent,
      child: Icon(icon, size: 52),
    );
  }
}

/// زر دائري يكرر الأمر عند الضغط المطوّل.
class RepeatButton extends StatefulWidget {
  const RepeatButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.size = 72,
    this.color = Colors.transparent,
    this.repeat = true,
  });

  final VoidCallback onPressed;
  final Widget child;
  final double size;
  final Color color;
  final bool repeat;

  @override
  State<RepeatButton> createState() => _RepeatButtonState();
}

class _RepeatButtonState extends State<RepeatButton> {
  Timer? _delay;
  Timer? _repeat;
  bool _down = false;

  void _start() {
    setState(() => _down = true);
    widget.onPressed();
    if (!widget.repeat) return;
    _delay = Timer(const Duration(milliseconds: 350), () {
      _repeat = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => widget.onPressed(),
      );
    });
  }

  void _stop() {
    _delay?.cancel();
    _repeat?.cancel();
    if (mounted) setState(() => _down = false);
  }

  @override
  void dispose() {
    _delay?.cancel();
    _repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _start(),
      onPointerUp: (_) => _stop(),
      onPointerCancel: (_) => _stop(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _down ? cs.primary.withOpacity(0.35) : widget.color,
        ),
        alignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}
