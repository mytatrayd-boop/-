import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show CustomSemanticsAction;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/day_info.dart';
import '../../../domain/local_date.dart';
import '../../../domain/tables.dart';
import '../../../formatting/digits.dart';
import '../../../theme/app_theme.dart';
import 'dial_model.dart';
import 'dial_painter.dart';

/// ما يُفتح من الدائرة: عنصر حلقة ليوم معيّن، أو الدَّرّ (المحور).
typedef DialOpen = void Function(DialRing ring, DayInfo day);

/// الدائرة التفاعلية لليوم (DESIGN §7): قرص يدور تحت مؤشر ثابت في الأعلى.
///
/// - سحب دائري بإصبع واحد يغيّر اليوم (≈ 1° لكل يوم)، ويستقر عند الرفع.
/// - ضغطة على قطعة ← [onOpen] لعنصرها؛ على حلقة الأشهر ← أول الشهر؛
///   على المحور ← الدَّرّ.
/// - ضغطتان أو قرص بإصبعين ← تكبير 1×–3×؛ في التكبير يحرّك السحب الدائرة.
/// - لقارئ الشاشة عنصر واحد قابل للتعديل (DESIGN 7.7).
///
/// الرسم بـ [CustomPainter] داخل [RepaintBoundary]: السحب يغيّر قيمة دوران
/// فيعيد رسم القرص وحده، وتُعاد بناء الواجهة فقط عند تغيّر اليوم.
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
    this.digits = DigitStyle.arabicIndic,
  });

  static const dialKey = Key('dayDial');
  static const resetZoomKey = Key('dialResetZoom');

  final double diameter;
  final DialDensity density;
  final DialModel model;
  final Tables tables;

  /// التاريخ المعروض (مقرّب) واليوم الحقيقي.
  final DateTime selected;
  final DateTime today;

  /// قارئ الشاشة (DESIGN 7.7): [semanticsLabel] البادئة الثابتة نسبياً
  /// («اليوم» أو «التاريخ المعروض»)، و[semanticsValue] الجزء المتغيّر
  /// (التاريخ، الدَّرّ واليوم داخله، النجم، موسم الجو، الجو). [increasedValue]
  /// و[decreasedValue] قيمة اليوم التالي والسابق، وnull عند حدّي 2025/2040
  /// (فلا يُعرض التعديل في ذلك الاتجاه).
  final String semanticsLabel;
  final String semanticsValue;
  final String? increasedValue;
  final String? decreasedValue;

  /// اختيار تاريخ جديد (يُحصر في المدى من المزوّد).
  final ValueChanged<DateTime> onSelect;

  /// نقل التاريخ المعروض بعدد أيام (من حالته الحالية، لا من آخر بناء).
  final ValueChanged<int> onShift;
  final DialOpen onOpen;
  final VoidCallback onBackToToday;

  /// شكل الأرقام (DESIGN 8.7) في المحور وحلقتي الأشهر والدرور.
  final DigitStyle digits;

  /// هامش أعلى الدائرة وأسفلها للمؤشر.
  static const double margin = 16;

  @override
  State<DayDial> createState() => _DayDialState();
}

class _DayDialState extends State<DayDial> with SingleTickerProviderStateMixin {
  late final ValueNotifier<double> _rotation = ValueNotifier(
    widget.model.dayIndexOf(widget.selected).toDouble(),
  );
  late final AnimationController _anim = AnimationController(vsync: this)
    ..addListener(_onAnimTick);
  double _animFrom = 0;
  double _animTo = 0;

  DialLabels? _labels;
  Object? _labelsKey;

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
  void didUpdateWidget(DayDial old) {
    super.didUpdateWidget(old);
    if (old.model.year != widget.model.year) {
      // تغيّرت السنة: يُعاد حساب فهرس الدوران بالنسبة لـ 1 يناير الجديد.
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
      );
      _labelsKey = key;
    }
    return _labels!;
  }

  // ———— اللمس ————

  /// نقطة في إطار الدائرة غير المكبّرة، بالنسبة لمركزها.
  Offset _toDial(Offset local) {
    final unscaled = (local - _offset) / _scale;
    return unscaled - _box.center(Offset.zero);
  }

  DialHit? _hit(Offset local) {
    final p = _toDial(local);
    final geo = DialGeometry(radius: _radius, dayCount: widget.model.dayCount);
    return geo.hitTest(p.dx, p.dy, _rotation.value.roundToDouble());
  }

  void _handleTap(Offset local) {
    final hit = _hit(local);
    final days = widget.model.index.days;
    switch (hit) {
      case null:
        return;
      case HubHit():
        widget.onOpen(_hubRing(_info), _info);
      case RingHit(ring: DialRing.months, :final day):
        final month = widget.model.segmentAt(DialRing.months, day)!.month!;
        widget.onSelect(DateTime(widget.model.year, month));
      case RingHit(:final ring, :final day):
        if (ring == DialRing.weather && days[day].weatherSeason == null) {
          return;
        }
        widget.onOpen(ring, days[day]);
    }
  }

  // التدوير بإصبع واحد من أحداث اللمس الخام (مواضع دقيقة)، والتكبير والتحريك
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
    // تدوير القرص مع عقارب الساعة يُرجع التاريخ، وعكسها يقدّمه (DESIGN 7.1).
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
    // حدود 2025 و2040: القرص لا يتجاوزها.
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
    } else if (a.dar.start != b.dar.start) {
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

  /// ما يفتحه المحور: الدَّرّ، أو للمستعيرة الموسم المعروض فيه (7.8).
  static DialRing _hubRing(DayInfo info) => !info.borrowsDurur
      ? DialRing.durur
      : info.weatherSeason != null
      ? DialRing.weather
      : DialRing.seasons;

  DayInfo get _info =>
      widget.model.index.days[widget.model.dayIndexOf(widget.selected)];

  @override
  Widget build(BuildContext context) {
    final colors = DururColors.of(context);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final labels = _labelsFor(context, colors);
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
        ),
      ),
    );

    // المحور (DESIGN 7.2، 7.8): اسم الدَّرّ واليوم داخله؛ وللمنطقة المستعيرة
    // موسم الجو المسمّى أو الموسم الكبير وتحته «طالع {النجم}». تكبير الخط
    // حتى 1.3× (7.6).
    String name(String? id) => widget.tables.items[id]?.name.ar ?? '';
    final (hubTitle, hubSubtitle) = info.borrowsDurur
        ? (
            name(info.weatherSeason?.itemId ?? info.majorSeason.itemId),
            l10n.wheelHubStar(name(info.star.itemId)),
          )
        : (
            info.dar.name.ar,
            l10n.homeDayOfDar(
              formatInteger(info.dar.dayNumber, widget.digits),
              formatInteger(info.dar.length, widget.digits),
            ),
          );
    final hubSize =
        DialGeometry(
          radius: _radius,
          dayCount: widget.model.dayCount,
        ).hubRadius *
        2 *
        0.78;
    final hub = MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: SizedBox.square(
        dimension: hubSize,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(hubTitle, style: theme.textTheme.titleMedium),
              Text(hubSubtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );

    final next = info.dar.end.add(const Duration(days: 1));
    final prev = info.dar.start.subtract(const Duration(days: 1));
    final days = widget.model.index.days;
    final selectedIndex = widget.model.dayIndexOf(widget.selected);
    final isToday = widget.selected == widget.today;

    return Semantics(
      key: DayDial.dialKey,
      container: true,
      label: widget.semanticsLabel,
      value: widget.semanticsValue,
      increasedValue: widget.increasedValue,
      decreasedValue: widget.decreasedValue,
      hint: info.borrowsDurur ? l10n.wheelA11yHintSeason : l10n.wheelA11yHint,
      onIncrease: widget.increasedValue == null ? null : () => _shift(1),
      onDecrease: widget.decreasedValue == null ? null : () => _shift(-1),
      onTap: () => widget.onOpen(_hubRing(info), info),
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.wheelA11yOpenStar): () =>
            widget.onOpen(DialRing.stars, info),
        CustomSemanticsAction(label: l10n.wheelA11yOpenSeason): () =>
            widget.onOpen(DialRing.seasons, info),
        if (info.weatherSeason != null)
          CustomSemanticsAction(label: l10n.wheelA11yOpenWeatherSeason): () =>
              widget.onOpen(DialRing.weather, info),
        CustomSemanticsAction(label: l10n.wheelA11yNextDar): () =>
            widget.onSelect(DateTime(next.year, next.month, next.day)),
        CustomSemanticsAction(label: l10n.wheelA11yPrevDar): () {
          // بداية الدَّرّ السابق.
          final prevIndex = selectedIndex - info.dar.dayNumber;
          final start = prevIndex >= 0 && prevIndex < days.length
              ? days[prevIndex].dar.start
              : prev;
          widget.onSelect(DateTime(start.year, start.month, start.day));
        },
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
                    child: Transform(
                      transform: Matrix4.identity()
                        ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
                        ..scaleByDouble(_scale, _scale, 1, 1),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          dial,
                          IgnorePointer(child: hub),
                        ],
                      ),
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

/// إيماءة الدائرة: تكسب ساحة اللمس فور الضغط، فالسحب على الدائرة يدوّرها
/// ولا يمرّر الصفحة (DESIGN 7.4). الضغطة والضغطتان تُميَّزان يدوياً في الحالة.
class _DialGestureRecognizer extends ScaleGestureRecognizer {
  _DialGestureRecognizer() : super(debugOwner: null);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
