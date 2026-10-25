enum CoffeeType {
  espresso('espresso'),
  v60('v60'),
  frenchPress('french_press');

  const CoffeeType(this.wire);

  /// القيمة في قاعدة البيانات والخادم.
  final String wire;

  /// التحليل البصري محدود لـ V60 وفرنش بريس (SPEC F5 معيار 2).
  bool get isVisualLimited => this != CoffeeType.espresso;

  static CoffeeType fromWire(String value) =>
      values.firstWhere((t) => t.wire == value,
          orElse: () => throw FormatException('coffee_type: $value'));
}
