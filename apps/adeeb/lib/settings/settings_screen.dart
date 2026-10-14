import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ask/ask_providers.dart';
import '../audio/listen_actions.dart';
import '../audio/listening_player.dart';
import '../audio/listening_providers.dart';
import '../audio/player_sheets.dart';
import '../l10n/app_localizations.dart';
import '../library/library_text.dart';
import '../reader/display_settings_sheet.dart';
import '../reader/reader_settings.dart';
import 'app_settings.dart';

/// شاشة الإعدادات (DESIGN §13): اللغة والمظهر، والقراءة، والاستماع،
/// و«اسأل الأديب»، وعن التطبيق. كلها تعمل دون إنترنت.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    final reader =
        ref.watch(readerSettingsProvider).value ?? const ReaderSettings();
    final audio =
        ref.watch(audioSettingsProvider).value ?? const AudioSettings();
    final hasAnswer = ref.watch(lastAnswerProvider).value != null;
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.only(bottom: 24),
          children: [
            _Header(l10n.settingsGeneral),
            _SettingTile(
              icon: Icons.language,
              title: l10n.settingsLanguage,
              value: _languageName(l10n, settings.language),
              onTap: () => _chooseLanguage(context, ref, settings.language),
            ),
            _SettingTile(
              icon: Icons.brightness_6_outlined,
              title: l10n.settingsAppearance,
              value: _themeName(l10n, settings.themeMode),
              onTap: () => _chooseTheme(context, ref, settings.themeMode),
            ),
            _Header(l10n.settingsReading),
            _SettingTile(
              icon: Icons.format_size,
              title: l10n.settingsTextSizeAndColor,
              value: l10n.textSizeLevel(
                l10n.number(context, reader.level),
                l10n.number(context, readerFontSizes.length),
              ),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => const DisplaySettingsSheet(),
              ),
            ),
            _Header(l10n.settingsListening),
            _SettingTile(
              icon: Icons.record_voice_over_outlined,
              title: l10n.audioVoice,
              value: _voiceName(ref, l10n, audio.voiceName, lang),
              onTap: () => showVoicePicker(context),
            ),
            _SpeedChoices(selected: audio.speed),
            _Header(l10n.askTitle),
            _SettingTile(
              icon: Icons.person_outline,
              title: l10n.settingsResetAge,
              value: l10n.settingsResetAgeHint,
              onTap: () => _resetAge(context, ref),
            ),
            _SettingTile(
              icon: Icons.delete_outline,
              title: l10n.settingsClearAnswer,
              value: hasAnswer
                  ? l10n.settingsClearAnswerHint
                  : l10n.settingsNoAnswer,
              onTap: hasAnswer ? () => _clearAnswer(context, ref) : null,
            ),
            _Header(l10n.settingsAbout),
            _SettingTile(
              icon: Icons.menu_book_outlined,
              title: l10n.sourcesTitle,
              onTap: () => context.push('/settings/sources'),
            ),
            _SettingTile(
              icon: Icons.privacy_tip_outlined,
              title: l10n.privacyTitle,
              onTap: () => context.push('/settings/privacy'),
            ),
            _SettingTile(
              icon: Icons.info_outline,
              title: l10n.aboutTitle,
              onTap: () => context.push('/settings/about'),
            ),
          ],
        ),
      ),
    );
  }

  static String _languageName(AppLocalizations l10n, AppLanguage language) =>
      switch (language) {
        AppLanguage.system => l10n.languageSystem,
        AppLanguage.ar => l10n.languageArabic,
        AppLanguage.en => l10n.languageEnglish,
      };

  static String _themeName(AppLocalizations l10n, ThemeMode mode) =>
      switch (mode) {
        ThemeMode.system => l10n.appearanceSystem,
        ThemeMode.light => l10n.appearanceLight,
        ThemeMode.dark => l10n.appearanceDark,
      };

  static String _voiceName(
    WidgetRef ref,
    AppLocalizations l10n,
    String? selected,
    String lang,
  ) {
    final voices = ref.watch(arabicVoicesProvider).value;
    if (voices == null || voices.isEmpty) return l10n.settingsVoiceDefault;
    final voice = voices.where((v) => v.name == selected).firstOrNull;
    return voice == null
        ? l10n.settingsVoiceDefault
        : voiceLabel(l10n, voices, voice, lang);
  }

  Future<void> _chooseLanguage(
    BuildContext context,
    WidgetRef ref,
    AppLanguage current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final picked = await _choose<AppLanguage>(
      context,
      title: l10n.settingsLanguage,
      current: current,
      options: [
        for (final l in AppLanguage.values) (l, _languageName(l10n, l)),
      ],
    );
    if (picked == null || picked == current || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final view = View.of(context);
    await ref.read(appSettingsProvider.notifier).setLanguage(picked);
    // الرسالة العابرة باللغة الجديدة (DESIGN §13.1).
    final locale = resolveAppLocale(
      picked,
      WidgetsBinding.instance.platformDispatcher.locale,
    );
    final message = lookupAppLocalizations(locale).languageChanged;
    final direction = locale.languageCode == 'ar'
        ? TextDirection.rtl
        : TextDirection.ltr;
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textDirection: direction),
          duration: const Duration(seconds: 4),
        ),
      );
    unawaited(SemanticsService.sendAnnouncement(view, message, direction));
  }

  Future<void> _chooseTheme(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final picked = await _choose<ThemeMode>(
      context,
      title: l10n.settingsAppearance,
      current: current,
      options: [
        (ThemeMode.light, l10n.appearanceLight),
        (ThemeMode.dark, l10n.appearanceDark),
        (ThemeMode.system, l10n.appearanceSystem),
      ],
    );
    if (picked == null || picked == current) return;
    await ref.read(appSettingsProvider.notifier).setThemeMode(picked);
  }

  Future<void> _resetAge(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsResetAgeQuestion),
        content: Text(l10n.settingsResetAgeHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.settingsReset),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(ageConfirmedProvider.notifier).reset();
    if (!context.mounted) return;
    _toast(context, l10n.settingsResetAgeDone);
  }

  Future<void> _clearAnswer(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    await ref.read(lastAnswerProvider.notifier).set(null);
    if (!context.mounted) return;
    _toast(context, l10n.settingsClearAnswerDone);
  }
}

void _toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
      );

/// ورقة اختيار واحد بعلامة ✓ على المختار (اللون ليس الوسيلة الوحيدة).
Future<T?> _choose<T>(
  BuildContext context, {
  required String title,
  required T current,
  required List<(T, String)> options,
}) => showModalBottomSheet<T>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsetsDirectional.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
            child: Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
          for (final (value, label) in options)
            Semantics(
              selected: value == current,
              inMutuallyExclusiveGroup: true,
              child: ListTile(
                minTileHeight: 48,
                title: Text(label),
                trailing: value == current ? const Icon(Icons.check) : null,
                selected: value == current,
                onTap: () => Navigator.of(context).pop(value),
              ),
            ),
        ],
      ),
    ),
  ),
);

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 24, 16, 8),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// صف واحد يُقرأ «التسمية، القيمة، زر» (DESIGN §13.2)، والقيمة تحت التسمية
/// فلا يُقص النص عند تكبير الخط.
class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    return ListTile(
      minTileHeight: 56,
      leading: ExcludeSemantics(child: Icon(icon)),
      title: Text(title),
      subtitle: value == null ? null : Text(value),
      trailing: onTap == null
          ? null
          : const ExcludeSemantics(child: Icon(Icons.chevron_right)),
      enabled: onTap != null,
      onTap: onTap,
    );
  }
}

/// شرائح السرعة من ٠٫٥× إلى ٢× (DESIGN §13.1)، مثل المشغّل الكامل.
class _SpeedChoices extends ConsumerWidget {
  const _SpeedChoices({required this.selected});
  final double selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.audioSpeed, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in listeningSpeeds)
                Semantics(
                  label: l10n.audioSpeedSemantics(formatSpeed(v, lang)),
                  excludeSemantics: true,
                  selected: v == selected,
                  button: true,
                  child: ChoiceChip(
                    label: Text(l10n.audioSpeedValue(formatSpeed(v, lang))),
                    selected: v == selected,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onSelected: (_) =>
                        ref.read(audioSettingsProvider.notifier).setSpeed(v),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
