class Program {
  final String id, name;
  final int day;

  /// The official body that pays it, and its website (Google Play requires a
  /// clear link to the government source of any government information).
  final String source, sourceUrl;
  const Program(this.id, this.name, this.day, this.source, this.sourceUrl);
}

const programs = <Program>[
  Program('ss', 'الضمان الاجتماعي', 1, 'وزارة الموارد البشرية والتنمية الاجتماعية', 'https://sbis.hrsd.gov.sa'),
  Program('pension', 'الراتب التقاعدي', 1, 'المؤسسة العامة للتأمينات الاجتماعية', 'https://www.gosi.gov.sa'),
  Program('hafiz', 'حافز', 5, 'صندوق تنمية الموارد البشرية (هدف)', 'https://www.hrdf.org.sa'),
  Program('citizen', 'حساب المواطن', 10, 'برنامج حساب المواطن', 'https://www.ca.gov.sa'),
  Program('housing', 'الدعم السكني', 24, 'وزارة البلديات والإسكان (سكني)', 'https://sakani.sa'),
  Program('rehab', 'التأهيل الشامل', 26, 'وزارة الموارد البشرية والتنمية الاجتماعية', 'https://www.hrsd.gov.sa'),
  Program('gov', 'رواتب الموظفين الحكوميين', 27, 'وزارة المالية', 'https://www.mof.gov.sa'),
];

/// Official sources for the holiday calendar.
const holidaySources = <(String, String)>[
  ('الإجازات الرسمية: وزارة الموارد البشرية والتنمية الاجتماعية', 'https://www.hrsd.gov.sa'),
  ('التقويم الدراسي: وزارة التعليم', 'https://moe.gov.sa'),
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
