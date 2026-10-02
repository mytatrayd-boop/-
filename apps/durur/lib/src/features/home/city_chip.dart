import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../routing/app_router.dart';

/// شريحة المدينة أعلى الرئيسية: «الرياض · نجد»، والضغط يفتح اختيار المدينة
/// (DESIGN 5.3 و8.4). قبل اختيار مدينة تعرض «اختر مدينتك».
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
      avatar: const Icon(Icons.place_outlined),
      label: Text(label, overflow: TextOverflow.ellipsis),
      onPressed: () => context.push(AppRoutes.city),
    );
  }
}
