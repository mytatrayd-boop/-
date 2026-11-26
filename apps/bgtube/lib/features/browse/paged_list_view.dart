import 'package:material_ui/material_ui.dart';

import '../../core/app_failure.dart';
import '../../core/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../login/login_screen.dart';
import '../player/failure_message.dart';
import 'paged_loader.dart';

/// خطأ في موضع المحتوى: أيقونة وجملة واضحة وإجراء واحد (DESIGN: حالات الخطأ).
/// الجلسة: زر الدخول. الحصة: «الصق رابطاً» إن توفّر. غير ذلك: «إعادة المحاولة».
class ApiErrorView extends StatelessWidget {
  const ApiErrorView({super.key, required this.failure, required this.onRetry, this.onPaste, this.compact = false});

  final AppFailure failure;
  final VoidCallback onRetry;
  final VoidCallback? onPaste;

  /// سطر صغير (أسفل قائمة) بدل بطاقة كاملة.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (IconData icon, Widget? action) = switch (failure.kind) {
      FailureKind.authExpired || FailureKind.notSignedIn => (
          Icons.account_circle_outlined,
          FilledButton(
            key: const Key('apiErrorSignIn'),
            onPressed: () async {
              if (await openLoginScreen(context)) onRetry();
            },
            child: Text(l.signIn),
          ),
        ),
      FailureKind.quotaExceeded => (
          Icons.hourglass_bottom,
          onPaste == null
              ? null
              : OutlinedButton(key: const Key('apiErrorPaste'), onPressed: onPaste, child: Text(l.pasteLinkAction)),
        ),
      FailureKind.network => (
          Icons.wifi_off,
          FilledButton(key: const Key('apiErrorRetry'), onPressed: onRetry, child: Text(l.retry)),
        ),
      _ => (
          Icons.error_outline,
          FilledButton(key: const Key('apiErrorRetry'), onPressed: onRetry, child: Text(l.retry)),
        ),
    };
    final message = failure.kind == FailureKind.notSignedIn ? l.searchNeedsSignIn : failureMessage(l, failure);
    final color = failure.kind == FailureKind.quotaExceeded ? AppColors.warning : AppColors.error;
    if (compact) {
      return Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: TextStyle(color: color))),
            ?action,
          ],
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(message, key: const Key('apiErrorMessage'), textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }
}

/// نص ودي في موضع قائمة فارغة.
class EmptyListView extends StatelessWidget {
  const EmptyListView({super.key, required this.icon, required this.message, this.action});
  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      );
}

/// هياكل صفوف رمادية بشكل بطاقة الفيديو (لا دوّامة وسط الشاشة).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 6});
  final int rows;

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6)),
        );
    return ListView.builder(
      key: const Key('skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows,
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(120, 67.5),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [bar(double.infinity, 14), const SizedBox(height: 8), bar(120, 12)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// قائمة من [PagedLoader]: هياكل عند التحميل الأول، خطأ في الموضع، فراغ ودي،
/// شريط «هذه نسخة محفوظة»، وتحميل المزيد عند بلوغ آخرها. [onRefresh] (سحب
/// للتحديث) اختياري، ولا تحديث تلقائي.
class PagedListView<T> extends StatelessWidget {
  const PagedListView({
    super.key,
    required this.loader,
    required this.itemBuilder,
    required this.empty,
    this.header,
    this.onRefresh,
    this.onPaste,
  });

  final PagedLoader<T> loader;
  final Widget Function(BuildContext, T) itemBuilder;
  final Widget empty;
  final Widget? header;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onPaste;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: loader,
      builder: (context, _) {
        final items = loader.items;
        final Widget body;
        if (items.isEmpty) {
          if (loader.loading || (!loader.loaded && loader.failure == null)) {
            body = const SkeletonList();
          } else if (loader.failure != null) {
            body = ApiErrorView(failure: loader.failure!, onRetry: loader.load, onPaste: onPaste);
          } else {
            body = empty;
          }
          final h = header;
          final column = Column(children: [?h, Expanded(child: body)]);
          if (onRefresh == null || loader.loading) return column;
          // السحب للتحديث يعمل على الفراغ والخطأ أيضاً.
          return RefreshIndicator(
            onRefresh: onRefresh!,
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(height: c.maxHeight, child: column),
              ),
            ),
          );
        }
        final top = <Widget>[
          ?header,
          if (loader.stale)
            Container(
              key: const Key('staleBanner'),
              width: double.infinity,
              color: AppColors.surfaceHigh,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8),
              child: Text(l.staleBanner, style: const TextStyle(color: AppColors.warning)),
            ),
          if (loader.failure != null)
            ApiErrorView(failure: loader.failure!, onRetry: loader.load, onPaste: onPaste, compact: true),
        ];
        final list = ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: top.length + items.length + 1,
          itemBuilder: (context, i) {
            if (i < top.length) return top[i];
            final j = i - top.length;
            if (j < items.length) return itemBuilder(context, items[j]);
            return _Footer(loader: loader);
          },
        );
        return onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list);
      },
    );
  }
}

/// آخر القائمة: يطلب الصفحة التالية عند ظهوره، بمؤشر صغير، أو سطر خطأ.
class _Footer extends StatelessWidget {
  const _Footer({required this.loader});
  final PagedLoader<Object?> loader;

  @override
  Widget build(BuildContext context) {
    final f = loader.moreFailure;
    if (f != null) return ApiErrorView(failure: f, onRetry: loader.loadMore, compact: true);
    if (!loader.hasMore) return const SizedBox(height: 16);
    if (!loader.loadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) => loader.loadMore());
    }
    return const Padding(
      key: Key('loadingMore'),
      padding: EdgeInsetsDirectional.all(16),
      child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
    );
  }
}
