import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../library/library_text.dart';
import 'reader_settings.dart';

/// ورقة إعدادات العرض «Aa» (DESIGN §9.2): حجم الخط بستة مستويات مع معاينة
/// حية، ولون الصفحة (فاتح، ورق، داكن). التغيير يُطبَّق فوراً ويُحفظ.
class DisplaySettingsSheet extends ConsumerWidget {
  const DisplaySettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings =
        ref.watch(readerSettingsProvider).value ?? const ReaderSettings();
    final controller = ref.read(readerSettingsProvider.notifier);
    final level = settings.level;
    final total = readerFontSizes.length;
    final current = settings.effectiveTheme(theme.brightness);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.displaySettings,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.textSize, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Semantics(
                  label: l10n.decreaseText,
                  button: true,
                  excludeSemantics: true,
                  onTap: level > 1
                      ? () => controller.setLevel(level - 1)
                      : null,
                  child: OutlinedButton(
                    onPressed: level > 1
                        ? () => controller.setLevel(level - 1)
                        : null,
                    child: Text(l10n.decreaseTextLabel),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    label: l10n.textSizeLevel(
                      l10n.number(context, level),
                      l10n.number(context, total),
                    ),
                    liveRegion: true,
                    excludeSemantics: true,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 1; i <= total; i++)
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsetsDirectional.symmetric(
                              horizontal: 4,
                            ),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i <= level
                                  ? theme.colorScheme.primary
                                  : null,
                              border: Border.all(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Semantics(
                  label: l10n.increaseText,
                  button: true,
                  excludeSemantics: true,
                  onTap: level < total
                      ? () => controller.setLevel(level + 1)
                      : null,
                  child: OutlinedButton(
                    onPressed: level < total
                        ? () => controller.setLevel(level + 1)
                        : null,
                    child: Text(l10n.increaseTextLabel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ExcludeSemantics(
              child: Text(
                l10n.textPreview,
                textDirection: TextDirection.rtl,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: bookFont,
                  fontSize: readerFontSize(
                    level,
                    MediaQuery.textScalerOf(context),
                  ),
                  height: 2.0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.pageColor, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceEvenly,
              children: [
                for (final t in ReaderPageTheme.values)
                  _ThemeChoice(
                    theme: t,
                    label: switch (t) {
                      ReaderPageTheme.light => l10n.themeLight,
                      ReaderPageTheme.paper => l10n.themePaper,
                      ReaderPageTheme.dark => l10n.themeDark,
                    },
                    selected: t == current,
                    onTap: () => controller.setPageTheme(t),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// دائرة لون مع تسميتها، وعلامة ✓ على المختار (لا يعتمد على اللون وحده).
class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ReaderPageTheme theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(theme);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 72, minHeight: 48),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: palette.background,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? scheme.primary : scheme.outline,
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: selected
                      ? Icon(Icons.check, color: palette.text, size: 20)
                      : null,
                ),
                const SizedBox(height: 4),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
