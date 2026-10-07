import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../routing/app_router.dart';
import '../../theme/app_theme.dart';

/// شريحة المدينة الزجاجية أعلى الرئيسية: «الرياض · نجد» بدبوس `cyan`،
/// ارتفاع 36 ولمس 48، والضغط يفتح اختيار المدينة (DESIGN R2.8 بند 1).
/// قبل اختيار مدينة تعرض «اختر مدينتك».
class CityChip extends ConsumerWidget {
  const CityChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final city = ref.watch(currentCityProvider);
    final region = ref.watch(currentRegionProvider);
    final label = city == null || region == null
        ? l10n.cityPickerTitle
        : l10n.cityChipLabel(city.name.ar, region.name.ar);
    return ActionChip(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      avatar: Icon(Icons.place_outlined, color: DururColors.of(context).primary),
      label: Text(label, overflow: TextOverflow.ellipsis),
      onPressed: () => context.push(AppRoutes.city),
    );
  }
}
