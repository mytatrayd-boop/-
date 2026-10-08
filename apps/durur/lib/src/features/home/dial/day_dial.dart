import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show CustomSemanticsAction;
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/day_info.dart';
import '../../../domain/local_date.dart';
import '../../../domain/tables.dart';
import '../../../domain/weather_symbol.dart';
import '../../../formatting/digits.dart';
import '../../../theme/app_theme.dart';
import '../../common/weather_icon.dart';
import '../symbol_bubble.dart';
import 'dial_model.dart';
import 'dial_painter.dart';
import 'weather_marks.dart';

/// ما يُفتح من الدائرة: جزء حلقة ليوم معيّن. [DialRing.seasons] ورقة الفصل
/// الفلكي، و[DialRing.zodiac] ورقة البرج، وغيرهما صفحة العنصر.
typedef DialOpen = void Function(DialRing ring, DayInfo day);

/// الدائرة التفاعلية (DESIGN R3.1، D41): **قرص ثابت** وعقرب يدور إلى اليوم
/// المعروض، والزمن يتقدّم عكس عقارب الساعة (21 ديسمبر عند الساعة 6).
///
/// - سحب العقرب أو أي نقطة على القرص يحرّكه يوماً بيوم، ويستقر عند الرفع.
/// - ضغطة على خلية في الإطار ← فقاعة رموز دَرّها أو طالعها (R2.6)؛ على اسم
///   موسم جو ← ورقته؛ على حلقة الأشهر ← أول الشهر؛ على حلقة ← [onOpen]؛
///   على المحور ← العودة لليوم، أو ورقة الفصل إن كان المعروض هو اليوم.
/// - ضغطتان أو قرص بإصبعين ← تكبير 1×–3×؛ في التكبير يحرّك السحب الدائرة.
/// - لقارئ الشاشة عنصر واحد قابل للتعديل (DESIGN 7.7، R3.5).
///
/// القرص يُرسم مرة في صورة مخزّنة، ولا يُعاد مع السحب إلا العقرب والتمييز.
class DayDial extends StatefulWidget {
  const DayDial({
    super.key,
    required this.diameter,
    required this.density,
    required this.model,
    required this.tables,
    required this.selected,
    required this.today,
    required this.semanticsLabel,
    required this.semanticsValue,
    required this.increasedValue,
    required this.decreasedValue,
    required this.onSelect,
    required this.onShift,
    required this.onOpen,
    required this.onBackToToday,
    this.onReadSeasonZodiac,
    this.digits = DigitStyle.arabicIndic,
  });

  /// حجم رمز الجو المرئي: 16 على ≥ 400dp، و14 أقل (R3.1-5).
  double get iconSize => density == DialDensity.full ? 16 : 14;

  static const dialKey = Key('dayDial');
  static const resetZoomKey = Key('dialResetZoom');

  final double diameter;
  final DialDensity density;
  final DialModel model;
  final Tables tables;

  /// التاريخ المعروض (مقرّب) واليوم الحقيقي.
  final DateTime selected;
  final DateTime today;

  /// قارئ الشاشة (DESIGN 7.7): البادئة والقيمة وقيمتا اليوم التالي والسابق
  /// (null عند حدّي 2025/2040).
  final String semanticsLabel;
  final String semanticsValue;
  final String? increasedValue;
  final String? decreasedValue;

  /// اختيار تاريخ جديد (يُحصر في المدى من المزوّد).
  final ValueChanged<DateTime> onSelect;

  /// نقل التاريخ المعروض بعدد أيام.
  final ValueChanged<int> onShift;
  final DialOpen onOpen;
  final VoidCallback onBackToToday;

  /// إجراء قارئ الشاشة «اقرأ الفصل والبرج» (R3.5): يعيد النص المقروء.
  final String Function(DayInfo day)? onReadSeasonZodiac;

  /// شكل الأرقام (DESIGN 8.7).
  final DigitStyle digits;

  /// هامش أعلى الدائرة وأسفلها للتوهج.
  static const double margin = 4;

  @override
  State<DayDial> createState() => DayDialState();
}

/// حالة الدائرة. عامة فقط ليقرأ الاختبار مواضع رموز الجو الظاهرة.
class DayDialState extends State<DayDial> with SingleTickerProviderStateMixin {
  late final ValueNotifier<double> _rotation = ValueNotifier(
    widget.model.dayIndexOf(widget.selected).toDouble(),
  );
  late final AnimationController _anim = AnimationController(vsync: this)
    ..addListener(_onAnimTick);
  double _animFrom = 0;
  double _animTo = 0;

  DialLabels? _labels;
  Object? _labelsKey;
  final DialPictures _pictures = DialPictures();
  FrameLayout _layout = FrameLayout.empty;
  Object? _layoutKey;
  final GlobalKey _areaKey = GlobalKey();

  // التكبير: مقياس وإزاحة (DESIGN 7.4).
  double _scale = 1;
  Offset _offset = Offset.zero;
  double _scaleAtStart = 1;
  Offset? _lastFocal;
  double? _lastAngle;
  bool _dragging = false;
  Offset? _downAt;
  bool _moved = false;
  bool _multi = false;
  final Set<int> _pointers = {};
  Offset? _pendingTap;
  Timer? _tapTimer;
  Offset? _doubleTapAt;

  Size get _box => Size(widget.diameter, widget.diameter + 2 * DayDial.margin);
  double get _radius => widget.diameter / 2;

  @override
  void didUpdateWidget(DayDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.model.year != widget.model.year) {
      // تغيّرت السنة: يُعاد حساب فهرس العقرب بالنسبة لـ 1 يناير الجديد.
      _anim.stop();
      final shift = daysBetween(
        DateTime(old.model.year),
        DateTime(widget.model.year),
      );
      _rotation.value -= shift;
    }
    if (!_dragging) {
      final target = widget.model.dayIndexOf(widget.selected).toDouble();
      if (target != _rotation.value) _animateTo(target);
    }
  }

  void _animateTo(double target) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final distance = (target - _rotation.value).abs();
    if (reduceMotion || distance > 120) {
      _anim.stop();
      _rotation.value = target;
      return;
    }
    _animFrom = _rotation.value;
    _animTo = target;
    _anim.duration = Duration(milliseconds: distance > 1.5 ? 400 : 150);
    _anim.forward(from: 0);
  }

  void _onAnimTick() {
    final t = Curves.easeOut.transform(_anim.value);
    _rotation.value = _animFrom + (_animTo - _animFrom) * t;
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    _anim.dispose();
    _rotation.dispose();
    _labels?.dispose();
    _pictures.dispose();
    super.dispose();
  }

  DialLabels _labelsFor(BuildContext context, DururColors colors) {
    final scaler = MediaQuery.textScalerOf(context);
    final key = (
      widget.model,
      colors,
      scaler.scale(100),
      widget.density,
      widget.digits,
      _radius,
    );
    if (_labels == null || _labelsKey != key) {
      _labels?.dispose();
      _labels = DialLabels.build(
        model: widget.model,
        items: widget.tables.items,
        l10n: AppLocalizations.of(context),
        colors: colors,
        textScaler: scaler,
        density: widget.density,
        digits: widget.digits,
        radius: _radius,
      );
      _labelsKey = key;
    }
    return _labels!;
  }

  DialGeometry get _geo => DialGeometry.of(widget.model, _radius);

  /// أسماء مواسم الجو والرموز الظاهرة لهذا الحجم والتكبير.
  FrameLayout _layoutFor(DialLabels labels) {
    final zoom = (_scale * 10).round() / 10;
    final key = (widget.model, labels, _radius, zoom, widget.iconSize);
    if (_layoutKey != key) {
      final geo = _geo;
      final r = geo.weatherMid;
      final pxPerDay = geo.step * r * zoom;
      _layout = layoutFrame(
        model: widget.model,
        radius: r,
        zoom: zoom,
        nameWidth: (id) => labels.weatherNames[id]?.width,
        blocked: [
          for (final (i, m) in widget.model.months.indexed)
            (
              m.start + (labels.monthNumbers[i].width / 2 + 3) / pxPerDay,
              (labels.monthNumbers[i].width / 2 + widget.iconSize / 2 + 1) /
                  pxPerDay,
            ),
        ],
      );
      _layoutKey = key;
    }
    return _layout;
  }

  // ———— اللمس ————

  /// نقطة في إطار الدائرة غير المكبّرة، بالنسبة لمركزها.
  Offset _toDial(Offset local) {
    final unscaled = (local - _offset) / _scale;
    return unscaled - _box.center(Offset.zero);
  }

  DialHit? _hit(Offset local) {
    final p = _toDial(local);
    return _geo.hitTest(p.dx, p.dy);
  }

  void _handleTap(Offset local) {
    final hit = _hit(local);
    final days = widget.model.index.days;
    switch (hit) {
      case null:
        return;
      case HubHit():
        if (widget.selected == widget.today) {
          widget.onOpen(DialRing.seasons, _info);
        } else {
          widget.onBackToToday();
        }
      case RingHit(ring: DialRing.months, :final day):
        final month = widget.model.segmentAt(DialRing.months, day)!.month!;
        widget.onSelect(DateTime(widget.model.year, month));
      case RingHit(ring: DialRing.days, :final day):
        widget.onSelect(DateTime(widget.model.year, 1, 1 + day));
      case RingHit(ring: DialRing.weather, :final day):
        final p = _toDial(local);
        final at = _geo.dayAtAngle(DialGeometry.angleAt(p.dx, p.dy));
        final n = widget.model.dayCount;
        for (final name in _layout.names) {
          if (name.covers(at, n) && days[day].weatherSeason != null) {
            widget.onOpen(DialRing.weather, days[day]);
            return;
          }
        }
        final cell = widget.model.cellAt(day);
        if (cell != null) _openBubble(cell);
      case RingHit(:final ring, :final day):
        widget.onOpen(ring, days[day]);
    }
  }

  // ———— فقاعة رموز الجو (R2.6) ————

  /// موضع مركز خلية على الشاشة (إحداثيات عامة).
  Offset? _globalOf(WeatherCell cell) {
    final box = _areaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final geo = _geo;
    final (x, y) = DialGeometry.polar(geo.angleOf(cell.center), geo.weatherMid);
    final local = (Offset(x, y) + _box.center(Offset.zero)) * _scale + _offset;
    return box.localToGlobal(local);
  }

  /// رموز الجو الظاهرة ومواضعها على الشاشة (للاختبار).
  @visibleForTesting
  List<({WeatherSymbol symbol, Offset center, WeatherCell cell})>
  get visibleMarks => [
    for (final m in _layout.marks)
      if (_globalOf(m.cell) case final c?)
        (symbol: m.symbol, center: c, cell: m.cell),
  ];

  void _openBubble(WeatherCell cell) {
    final symbol = cell.symbol;
    final box = _areaKey.currentContext?.findRenderObject() as RenderBox?;
    final center = _globalOf(cell);
    if (symbol == null || box == null || center == null) return;
    final upper =
        center.dy < box.localToGlobal(box.size.center(Offset.zero)).dy;
    showSymbolBubble(
      context,
      anchor: Rect.fromCircle(center: center, radius: widget.iconSize / 2),
      symbol: symbol,
      period: _periodText(cell),
      preferBelow: upper,
      onOutsideTap: (global) {
        if (!mounted) return;
        final local = box.globalToLocal(global);
        final hit = _hit(local);
        if (hit is RingHit && hit.ring == DialRing.weather) {
          final other = widget.model.cellAt(hit.day);
          if (other != null) _openBubble(other);
        }
      },
    );
  }

  /// «يتبع: دَرّ الستين — ٧ أكتوبر إلى ١٦ أكتوبر» أو «يتبع: طالع الهقعة — …».
  String _periodText(WeatherCell cell) {
    final l10n = AppLocalizations.of(context);
    String dm(DateTime d) =>
        l10n.dayMonthDate(formatInteger(d.day, widget.digits), 'g${d.month}');
    final start = DateTime(widget.model.year, 1, 1 + cell.start);
    final end = DateTime(widget.model.year, 1, cell.end);
    final dar = cell.dar;
    final name = dar != null
        ? l10n.darTitle(dar.name.ar)
        : l10n.wheelHubStar(widget.tables.items[cell.starItemId]?.name.ar ?? '');
    return l10n.bubblePeriod(l10n.bubbleRange(name, dm(start), dm(end)));
  }

  /// «اقرأ رموز الجو حول اليوم»: رموز الدَّرّ (أو الطالع) وموسم الجو الحاليين.
  void _readSymbols(DayInfo info) {
    final l10n = AppLocalizations.of(context);
    final symbols = <WeatherSymbol>{
      ...info.weather,
      if (info.weatherSeason != null)
        ...?widget.tables.items[info.weatherSeason!.itemId]?.weather.take(1),
    };
    final text = symbols.isEmpty
        ? l10n.wheelA11yWeather(l10n.wheelA11yNone)
        : [
            for (final s in symbols)
              '${weatherSymbolLabel(l10n, s)}. ${l10n.weatherSymbolDesc(s.code)}',
          ].join(' ');
    _announce(text);
  }

  void _announce(String text) => SemanticsService.sendAnnouncement(
    View.of(context),
    text,
    Directionality.of(context),
  );

  // السحب بإصبع واحد من أحداث اللمس الخام (مواضع دقيقة)، والتكبير والتحريك
  // من إيماءة القرص. الإيماءة تكسب الساحة فور الضغط فلا تتمرّر الصفحة.

  void _onPointerDown(PointerDownEvent e) {
    _pointers.add(e.pointer);
    if (_pointers.length == 1) {
      _anim.stop();
      _downAt = e.localPosition;
      _moved = false;
      _multi = false;
      _lastAngle = _angleAt(e.localPosition);
    } else {
      _multi = true;
      _dragging = false;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_pointers.length != 1 || _multi || _scale > 1) return;
    final down = _downAt;
    if (!_moved) {
      // حركة أقل من حد اللمس تبقى ضغطة لا سحباً.
      if (down != null && (e.localPosition - down).distance < kTouchSlop) {
        return;
      }
      _moved = true;
      _dragging = true;
    }
    final last = _lastAngle;
    final angle = _angleAt(e.localPosition);
    _lastAngle = angle;
    if (last == null) return;
    var delta = angle - last;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;
    final step = 2 * math.pi / widget.model.dayCount;
    // العقرب يتبع الإصبع: مع عقارب الساعة رجوع في الزمن (R3.1-3).
    _setRotation(_rotation.value - delta / step);
  }

  void _onPointerEnd(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.isNotEmpty) return;
    final down = _downAt;
    if (e is PointerUpEvent && !_moved && !_multi && down != null) {
      _onTap(down);
    }
    if (_dragging) {
      _dragging = false;
      _animateTo(_rotation.value.roundToDouble());
    }
    _downAt = null;
    _lastAngle = null;
  }

  double _angleAt(Offset local) {
    final p = _toDial(local);
    return math.atan2(p.dx, -p.dy);
  }

  void _onScaleStart(ScaleStartDetails d) {
    _scaleAtStart = _scale;
    _lastFocal = d.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    // إصبعان (تكبير) أو إصبع في وضع التكبير (تحريك) فقط.
    if (d.pointerCount < 2 && _scale == 1) return;
    if (d.pointerCount < 2 && !_moved) {
      final down = _downAt;
      if (down != null && (d.localFocalPoint - down).distance < kTouchSlop) {
        _lastFocal = d.localFocalPoint;
        return;
      }
      _moved = true;
    }
    _zoomPan(d);
  }

  void _setRotation(double value) {
    final first = widget.model.dayIndexOf(DateRange.first).toDouble();
    final last = widget.model.dayIndexOf(DateRange.last).toDouble();
    // حدود 2025 و2040: العقرب لا يتجاوزها.
    final clamped = value.clamp(first, last);
    final before = _rotation.value.round();
    _rotation.value = clamped;
    final after = clamped.round();
    if (after != before) {
      final date = addDays(DateTime(widget.model.year), after);
      _haptic(before, after);
      widget.onSelect(date);
    }
  }

  void _haptic(int before, int after) {
    final days = widget.model.index.days;
    if (before < 0 ||
        after < 0 ||
        before >= days.length ||
        after >= days.length) {
      return;
    }
    final a = days[before];
    final b = days[after];
    if (a.majorSeason.start != b.majorSeason.start) {
      HapticFeedback.mediumImpact();
    } else if ((a.dar?.start ?? a.star.start) !=
        (b.dar?.start ?? b.star.start)) {
      HapticFeedback.selectionClick();
    }
  }

  void _zoomPan(ScaleUpdateDetails d) {
    final focal = d.localFocalPoint;
    final last = _lastFocal ?? focal;
    _lastFocal = focal;
    setState(() {
      final next = (_scaleAtStart * d.scale).clamp(1.0, 3.0);
      if (d.pointerCount >= 2 && next != _scale) {
        // تكبير حول نقطة اللمس.
        _offset = focal - (focal - _offset) * (next / _scale);
        _scale = next;
      }
      _offset += focal - last;
      _clampOffset();
    });
  }

  void _clampOffset() {
    final min = _box * (1 - _scale);
    _offset = Offset(
      _offset.dx.clamp(min.width, 0),
      _offset.dy.clamp(min.height, 0),
    );
  }

  /// ضغطة: تنتظر مهلة الضغطة الثانية؛ ضغطتان متقاربتان = تكبير.
  void _onTap(Offset at) {
    final pending = _pendingTap;
    if (_tapTimer?.isActive == true &&
        pending != null &&
        (pending - at).distance < 48) {
      _tapTimer!.cancel();
      _pendingTap = null;
      _doubleTapAt = at;
      _onDoubleTap();
      return;
    }
    _pendingTap = at;
    _tapTimer?.cancel();
    _tapTimer = Timer(kDoubleTapTimeout, () {
      _pendingTap = null;
      if (mounted) _handleTap(at);
    });
  }

  void _onDoubleTap() {
    setState(() {
      if (_scale > 1) {
        _resetZoom();
      } else {
        final at = _doubleTapAt ?? _box.center(Offset.zero);
        _scale = 2;
        _offset = at - at * 2;
        _clampOffset();
      }
    });
  }

  void _resetZoom() {
    _scale = 1;
    _offset = Offset.zero;
  }

  // ———— قارئ الشاشة ————

  void _shift(int days) => widget.onShift(days);

  /// ما تفتحه ضغطة قارئ الشاشة: في الخليج موسم الجو المسمّى إن وُجد وإلا
  /// الموسم الكبير؛ وبلا درور صفحة الطالع (R3.10).
  DialRing _semanticRing(DayInfo info) => !widget.model.hasDurur
      ? DialRing.stars
      : info.weatherSeason != null
      ? DialRing.weather
      : DialRing.majorSeason;

  DayInfo get _info =>
      widget.model.index.days[widget.model.dayIndexOf(widget.selected)];

  /// بداية الفترة (الدَّرّ، أو الطالع بلا درور) التالية والسابقة.
  (DateTime next, DateTime prev) _jumps(DayInfo info) {
    final ActivePeriod period = info.dar ?? info.star;
    final next = period.end.add(const Duration(days: 1));
    final days = widget.model.index.days;
    final selectedIndex = widget.model.dayIndexOf(widget.selected);
    final prevIndex = selectedIndex - period.dayNumber;
    final ActivePeriod? before = prevIndex >= 0 && prevIndex < days.length
        ? (days[prevIndex].dar ?? days[prevIndex].star)
        : null;
    final prev = before?.start ?? period.start.subtract(const Duration(days: 1));
    return (
      DateTime(next.year, next.month, next.day),
      DateTime(prev.year, prev.month, prev.day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = DururColors.of(context);
    final l10n = AppLocalizations.of(context);
    final labels = _labelsFor(context, colors);
    final layout = _layoutFor(labels);
    final info = _info;
    final todayInYear = widget.today.year == widget.model.year
        ? widget.model.dayIndexOf(widget.today)
        : null;

    final dial = RepaintBoundary(
      child: CustomPaint(
        size: _box,
        painter: DialPainter(
          model: widget.model,
          labels: labels,
          colors: colors,
          radius: _radius,
          rotation: _rotation,
          todayDay: todayInYear,
          pictures: _pictures,
          layout: layout,
          zoom: _scale,
          iconSize: widget.iconSize,
          density: widget.density,
        ),
      ),
    );

    final (next, prev) = _jumps(info);
    final isToday = widget.selected == widget.today;
    final hasDurur = widget.model.hasDurur;
    final readSeasonZodiac = widget.onReadSeasonZodiac;

    return Semantics(
      key: DayDial.dialKey,
      container: true,
      label: widget.semanticsLabel,
      value: widget.semanticsValue,
      increasedValue: widget.increasedValue,
      decreasedValue: widget.decreasedValue,
      hint: hasDurur ? l10n.wheelA11yHintSeason : l10n.wheelA11yHintStar,
      onIncrease: widget.increasedValue == null ? null : () => _shift(1),
      onDecrease: widget.decreasedValue == null ? null : () => _shift(-1),
      onTap: () => widget.onOpen(_semanticRing(info), info),
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.wheelA11yOpenStar): () =>
            widget.onOpen(DialRing.stars, info),
        CustomSemanticsAction(label: l10n.wheelA11yOpenSeason): () =>
            widget.onOpen(DialRing.majorSeason, info),
        if (info.weatherSeason != null)
          CustomSemanticsAction(label: l10n.wheelA11yOpenWeatherSeason): () =>
              widget.onOpen(DialRing.weather, info),
        CustomSemanticsAction(label: l10n.wheelA11yOpenSeasonSheet): () =>
            widget.onOpen(DialRing.seasons, info),
        if (readSeasonZodiac != null)
          CustomSemanticsAction(label: l10n.wheelA11yReadSeasonZodiac): () =>
              _announce(readSeasonZodiac(info)),
        CustomSemanticsAction(label: l10n.wheelA11yReadSymbols): () =>
            _readSymbols(info),
        CustomSemanticsAction(
          label: hasDurur ? l10n.wheelA11yNextDar : l10n.wheelA11yNextStar,
        ): () =>
            widget.onSelect(next),
        CustomSemanticsAction(
          label: hasDurur ? l10n.wheelA11yPrevDar : l10n.wheelA11yPrevStar,
        ): () =>
            widget.onSelect(prev),
        if (!isToday)
          CustomSemanticsAction(label: l10n.wheelA11yBackToToday):
              widget.onBackToToday,
      },
      child: SizedBox.fromSize(
        size: _box,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ExcludeSemantics(
              child: RawGestureDetector(
                key: _areaKey,
                behavior: HitTestBehavior.opaque,
                gestures: {
                  _DialGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        _DialGestureRecognizer
                      >(
                        _DialGestureRecognizer.new,
                        (r) => r
                          ..onStart = _onScaleStart
                          ..onUpdate = _onScaleUpdate,
                      ),
                },
                child: Listener(
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerEnd,
                  onPointerCancel: _onPointerEnd,
                  child: ClipRect(
                    clipBehavior: _scale > 1 ? Clip.hardEdge : Clip.none,
                    child: Transform(
                      transform: Matrix4.identity()
                        ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
                        ..scaleByDouble(_scale, _scale, 1, 1),
                      child: dial,
                    ),
                  ),
                ),
              ),
            ),
            if (_scale > 1)
              PositionedDirectional(
                top: 0,
                end: 0,
                child: IconButton.filledTonal(
                  key: DayDial.resetZoomKey,
                  tooltip: l10n.wheelResetZoom,
                  icon: const Icon(Icons.zoom_out_map),
                  onPressed: () => setState(_resetZoom),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// إيماءة الدائرة: تكسب ساحة اللمس فور الضغط، فالسحب على الدائرة يحرّك
/// العقرب ولا يمرّر الصفحة (DESIGN 7.4).
class _DialGestureRecognizer extends ScaleGestureRecognizer {
  _DialGestureRecognizer() : super(debugOwner: null);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
