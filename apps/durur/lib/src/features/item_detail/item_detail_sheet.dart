import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers.dart';
import 'detail_data.dart';
import 'item_detail_view.dart';

/// الورقة السفلية لصفحة عنصر من الدائرة (DESIGN 8.6، 5.5): بنصف الشاشة
/// وتُسحب لأعلى لتصبح كاملة. شريحة الموسم تفتح صفحته داخل الورقة نفسها مع
/// زر رجوع داخلي.
Future<void> showItemDetailSheet(BuildContext context, DetailRequest request) {
  return showModalBottomSheet<void>(
    context: context,
    // فوق شريط التبويب (DESIGN R2.9)، وفي موجّه الجذر الذي يراقبه
    // PopupRouteTracker.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => ItemDetailSheet(initial: request),
  );
}

class ItemDetailSheet extends ConsumerStatefulWidget {
  const ItemDetailSheet({super.key, required this.initial});

  static const sheetKey = Key('itemSheet');
  static const backKey = Key('itemSheetBack');

  final DetailRequest initial;

  @override
  ConsumerState<ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends ConsumerState<ItemDetailSheet> {
  late final List<DetailRequest> _stack = [widget.initial];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canPop = _stack.length > 1;
    return PopScope(
      // الرجوع يعود داخل الورقة أولاً.
      canPop: !canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && canPop) setState(_stack.removeLast);
      },
      child: DraggableScrollableSheet(
        key: ItemDetailSheet.sheetKey,
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.25,
        maxChildSize: 1,
        builder: (context, controller) => ItemDetailView(
          key: ValueKey(_stack.length),
          request: _stack.last,
          controller: controller,
          header: Row(
            children: [
              if (canPop)
                IconButton(
                  key: ItemDetailSheet.backKey,
                  tooltip: l10n.commonBack,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(_stack.removeLast),
                ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonClose),
              ),
            ],
          ),
          onOpen: (request) => setState(() => _stack.add(request)),
          onGoToStart: (start) {
            Navigator.of(context).pop();
            ref.read(selectedDateProvider.notifier).select(start);
          },
        ),
      ),
    );
  }
}
