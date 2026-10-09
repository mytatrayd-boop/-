class Program {
  final String id, name;
  final int day;
  const Program(this.id, this.name, this.day);
}

const programs = <Program>[
  Program('ss', 'الضمان الاجتماعي', 1),
  Program('pension', 'الراتب التقاعدي', 1),
  Program('hafiz', 'حافز', 5),
  Program('citizen', 'حساب المواطن', 10),
  Program('housing', 'الدعم السكني', 24),
  Program('rehab', 'التأهيل الشامل', 26),
  Program('gov', 'رواتب الموظفين الحكوميين', 27),
];

class Occasion {
  final String name;
  final int month, day;
  const Occasion(this.name, this.month, this.day);
}

const occasions = <Occasion>[
  Occasion('يوم التأسيس', 2, 22),
  Occasion('يوم العلم', 3, 11),
  Occasion('اليوم الوطني', 9, 23),
];

const weekdayAr = {
  1: 'الاثنين', 2: 'الثلاثاء', 3: 'الأربعاء', 4: 'الخميس',
  5: 'الجمعة', 6: 'السبت', 7: 'الأحد',
};
const monthAr = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

String leftText(int d) => d == 0
    ? 'اليوم'
    : d == 1
        ? 'غداً'
        : d == 2
            ? 'بعد يومين'
            : d <= 10
                ? 'بعد $d أيام'
                : 'بعد $d يوماً';
