/// ماذا نفعل بموضع التشغيل الحالي عند الحفظ.
enum PositionAction { save, delete, skip }

/// قاعدة حفظ الموضع (SPEC 6 / ARCHITECTURE):
/// - أقل من [minWatched]: لا يُحفظ (ولا يُمسّ المحفوظ سابقاً).
/// - ضمن [endMargin] من النهاية (المدة معروفة): يُحذف المحفوظ (انتهى الفيديو).
/// - غير ذلك: يُحفظ.
class PositionPolicy {
  const PositionPolicy._();

  static const minWatched = Duration(seconds: 10);
  static const endMargin = Duration(seconds: 10);

  static PositionAction decide(Duration position, Duration? duration) {
    if (position < minWatched) return PositionAction.skip;
    if (duration != null &&
        duration > Duration.zero &&
        position >= duration - endMargin) {
      return PositionAction.delete;
    }
    return PositionAction.save;
  }
}
