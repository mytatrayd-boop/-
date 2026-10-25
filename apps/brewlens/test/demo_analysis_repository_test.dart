import 'package:brewlens/backend/demo/demo_analysis_repository.dart';
import 'package:brewlens/domain/models/usage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('riyadhDay', () {
    test('23:59 and 00:00 Riyadh time are different days', () {
      // 23:59 بتوقيت الرياض = 20:59 UTC.
      expect(riyadhDay(DateTime.utc(2026, 10, 25, 20, 59)), '2026-10-25');
      expect(riyadhDay(DateTime.utc(2026, 10, 25, 21, 0)), '2026-10-26');
    });

    test('month and year boundaries', () {
      expect(riyadhDay(DateTime.utc(2026, 12, 31, 21, 30)), '2027-01-01');
    });
  });

  group('DemoAnalysisRepository.usage', () {
    final now = DateTime.utc(2026, 10, 25, 12);

    Future<DemoAnalysisRepository> repoWith(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      return DemoAnalysisRepository(await SharedPreferences.getInstance(), clock: () => now);
    }

    test('fresh user has 2 of 2 per day', () async {
      final usage = await (await repoWith({})).usage();
      expect(usage, const Usage(remaining: 2, limit: 2));
    });

    test('counts today attempts', () async {
      final r = await repoWith({
        DemoAnalysisRepository.dayKey: '2026-10-25',
        DemoAnalysisRepository.countKey: 1,
      });
      expect((await r.usage()).remaining, 1);
    });

    test('never goes below zero', () async {
      final r = await repoWith({
        DemoAnalysisRepository.dayKey: '2026-10-25',
        DemoAnalysisRepository.countKey: 5,
      });
      expect((await r.usage()).remaining, 0);
    });

    test('resets on a new Riyadh day', () async {
      final r = await repoWith({
        DemoAnalysisRepository.dayKey: '2026-10-24',
        DemoAnalysisRepository.countKey: 2,
      });
      expect((await r.usage()).remaining, 2);
    });
  });
}
