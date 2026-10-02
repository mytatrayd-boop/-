import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';

/// يلفّ كل الشاشات: شريط «بيانات تجريبية — غير معتمدة» ثابت في الأعلى ما دام
/// في البيانات المحمّلة سجل غير معتمد (DESIGN 5.7). لا يمكن إخفاؤه، ويختفي
/// وحده حين تكون كل السجلات معتمدة.
class DraftBannerFrame extends ConsumerWidget {
  const DraftBannerFrame({super.key, required this.child});

  static const bannerKey = Key('draftDataBanner');

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hasUnapprovedDataProvider)) return child;
    final colors = DururColors.of(context);
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    return Column(
      children: [
        Material(
          key: bannerKey,
          color: colors.warningBg,
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              top: media.padding.top + 4,
              bottom: 4,
              start: 16,
              end: 16,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                l10n.draftDataBanner,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onWarning),
              ),
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}
