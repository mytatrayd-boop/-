import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';
import '../../routing/app_routes.dart';
import '../common/load_error.dart';
import 'detail_data.dart';
import 'item_detail_view.dart';

/// صفحة كاملة لعنصر أو دَرّ (`/item/<id>`، `/dar/<regionId>/<MM-DD>`) من
/// بطاقة اليوم أو التنبيه (DESIGN 8.6). مسار لا يجد عنصره أو سجله (تصحيح
/// بيانات بعد تحديث، D26) يعود إلى الرئيسية بلا رسالة خطأ.
class ItemDetailPage extends ConsumerStatefulWidget {
  const ItemDetailPage({super.key, required this.target, this.from});

  static const pageKey = Key('itemDetailPage');
  static const loadErrorKey = Key('itemDetailLoadError');

  /// null لمسار غير صالح.
  final DetailTarget? target;

  /// التاريخ المرجعي؛ الافتراضي التاريخ المعروض في الرئيسية.
  final DateTime? from;

  @override
  ConsumerState<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends ConsumerState<ItemDetailPage> {
  bool _leaving = false;

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    final tables = ref.watch(tablesProvider);
    final tablesReady = tables.hasValue;
    // فشل تحميل الجداول: رسالة و«إعادة المحاولة» كالرئيسية (DESIGN 8.1).
    if (tables.hasError && !tables.isLoading) {
      return Scaffold(
        key: ItemDetailPage.pageKey,
        appBar: AppBar(),
        body: DataLoadError(
          key: ItemDetailPage.loadErrorKey,
          onRetry: () => ref.invalidate(tablesProvider),
        ),
      );
    }
    final DateTime from = widget.from ?? ref.watch(selectedDateProvider);
    final DetailRequest? request = target == null
        ? null
        : (target: target, from: from);
    final missing =
        request == null ||
        (tablesReady &&
            // صفحة العنصر تحتاج منطقة المستخدم؛ بلا مدينة يتولى التوجيه.
            (target is DarTarget || ref.watch(engineProvider) != null) &&
            ItemDetailView.resolve(ref, request) == null);
    if (missing && !_leaving) {
      _leaving = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.home);
      });
    }
    return Scaffold(
      key: ItemDetailPage.pageKey,
      appBar: AppBar(),
      body: request == null || !tablesReady
          ? const SizedBox.shrink()
          : ItemDetailView(
              request: request,
              onOpen: (next) =>
                  context.push(AppRoutes.detail(next.target, from: next.from)),
              onGoToStart: (start) {
                ref.read(selectedDateProvider.notifier).select(start);
                context.go(AppRoutes.home);
              },
            ),
    );
  }
}
