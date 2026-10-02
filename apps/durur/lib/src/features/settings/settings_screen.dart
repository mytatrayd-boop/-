import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../formatting/digits.dart';
import '../../location/city_locator.dart';
import '../../providers.dart';
import '../../repository/settings_repository.dart';
import '../../routing/app_routes.dart';
import '../report/report_sheet.dart';
import 'data_update_section.dart';

/// الإعدادات (DESIGN 8.7): «المنطقة» (صف المدينة، الميزة 3؛ و«تحديد موقعي
/// مرة أخرى»، الميزة 4)، و«التنبيهات» (مفتاحان مستقلان وملاحظة الإذن وخطأ
/// الجدولة، الميزة 8)، و«المظهر» (السمة والأرقام)، و«تحديث البيانات» (الميزة
/// 11ب، [DataUpdateSection])، و«البيانات والمساعدة»
/// (المصادر، D27؛ وأبلغ عن خطأ، الميزة 9). «عن التطبيق» لم يُبنَ بعد.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const cityRowKey = Key('settingsCityRow');
  static const relocateRowKey = Key('settingsRelocateRow');
  static const sourcesRowKey = Key('settingsSourcesRow');
  static const reportRowKey = Key('settingsReportRow');
  static const importantSwitchKey = Key('settingsNotifyImportant');
  static const darSwitchKey = Key('settingsNotifyDar');
  static const permissionNoteKey = Key('settingsNotifPermissionNote');
  static const openDeviceSettingsKey = Key('settingsOpenDeviceSettings');
  static const scheduleErrorKey = Key('settingsNotifScheduleError');
  static Key themeChipKey(ThemeChoice t) => Key('settingsTheme_${t.code}');
  static Key digitsChipKey(DigitStyle d) => Key('settingsDigits_${d.code}');

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _locating = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final city = ref.watch(currentCityProvider);
    final region = ref.watch(currentRegionProvider);
    final settings = ref.watch(settingsProvider);
    final digits = settings.digits;
    // الملاحظة تظهر فقط إن عُرف أن الإذن غير ممنوح.
    final permitted = ref.watch(notificationPermissionProvider).value ?? true;
    // فشل الجدولة يُعرض فقط والإذن ممنوح (بلا إذن تكفي ملاحظة الإذن).
    final syncFailed =
        ref.watch(notificationPermissionProvider).value == true &&
        ref.watch(notificationSyncProvider) == NotificationSyncStatus.failed;
    Widget header(String text) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 24, 16, 8),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleLarge),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          header(l10n.settingsSectionRegion),
          ListTile(
            key: SettingsScreen.cityRowKey,
            minTileHeight: 56,
            leading: const Icon(Icons.place_outlined),
            title: Text(l10n.settingsCity),
            subtitle: Text(
              city == null || region == null
                  ? l10n.cityPickerTitle
                  : l10n.settingsCityValue(city.name.ar, region.name.ar),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.city),
          ),
          ListTile(
            key: SettingsScreen.relocateRowKey,
            minTileHeight: 56,
            leading: const Icon(Icons.my_location),
            title: Text(l10n.settingsRelocate),
            subtitle: _locating
                ? Semantics(
                    liveRegion: true,
                    child: Text(l10n.onboardingLocationLoading),
                  )
                : null,
            trailing: _locating
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _locating ? null : _relocate,
          ),
          header(l10n.settingsSectionNotifications),
          if (!permitted)
            _NoteCard(
              key: SettingsScreen.permissionNoteKey,
              text: l10n.settingsNotifDenied,
              action: TextButton(
                key: SettingsScreen.openDeviceSettingsKey,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: _openDeviceSettings,
                child: Text(l10n.settingsNotifOpenDeviceSettings),
              ),
            ),
          if (syncFailed)
            _NoteCard(
              key: SettingsScreen.scheduleErrorKey,
              text: l10n.settingsNotifScheduleError,
              live: true,
            ),
          SwitchListTile(
            key: SettingsScreen.importantSwitchKey,
            minTileHeight: 64,
            title: Text(l10n.settingsNotifImportant),
            subtitle: Text(l10n.settingsNotifImportantDesc),
            value: settings.notifyImportant,
            onChanged: (on) => _setNotify(on, important: true),
          ),
          SwitchListTile(
            key: SettingsScreen.darSwitchKey,
            minTileHeight: 64,
            title: Text(l10n.settingsNotifDar),
            subtitle: Text(l10n.settingsNotifDarDesc),
            value: settings.notifyDar,
            onChanged: (on) => _setNotify(on, important: false),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 0),
            child: Text(
              localizeDigits(l10n.settingsNotifTimeNote, digits),
              style: theme.textTheme.bodySmall,
            ),
          ),
          header(l10n.settingsSectionAppearance),
          _ChoiceRow<ThemeChoice>(
            title: l10n.settingsTheme,
            values: ThemeChoice.values,
            selected: settings.theme,
            keyOf: SettingsScreen.themeChipKey,
            labelOf: (t) => switch (t) {
              ThemeChoice.system => l10n.settingsThemeSystem,
              ThemeChoice.light => l10n.settingsThemeLight,
              ThemeChoice.dark => l10n.settingsThemeDark,
            },
            onSelected: (t) =>
                _save(() => ref.read(settingsProvider.notifier).setTheme(t)),
          ),
          _ChoiceRow<DigitStyle>(
            title: l10n.settingsDigits,
            values: DigitStyle.values,
            selected: digits,
            keyOf: SettingsScreen.digitsChipKey,
            labelOf: (d) => switch (d) {
              DigitStyle.arabicIndic => l10n.settingsDigitsArabic,
              DigitStyle.latin => l10n.settingsDigitsLatin,
            },
            onSelected: (d) =>
                _save(() => ref.read(settingsProvider.notifier).setDigits(d)),
          ),
          // «تحديث البيانات» بين «المظهر» و«البيانات والمساعدة»؛ يُخفى إن لم
          // يكن متاحاً (DESIGN 8.7).
          DataUpdateSection(header: header),
          header(l10n.settingsSectionHelp),
          ListTile(
            key: SettingsScreen.sourcesRowKey,
            minTileHeight: 56,
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(l10n.settingsSources),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.sources),
          ),
          // بلاغ عام غير مرتبط بعنصر (DESIGN 8.7، الميزة 9).
          ListTile(
            key: SettingsScreen.reportRowKey,
            minTileHeight: 56,
            leading: const Icon(Icons.flag_outlined),
            title: Text(l10n.settingsReport),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showReportSheet(
              context,
              regionName: region?.name.ar,
              date: ref.read(selectedDateProvider),
            ),
          ),
        ],
      ),
    );
  }

  /// يحفظ اختياراً؛ عند الفشل رسالة والقيمة لا تتغير.
  Future<void> _save(Future<void> Function() save) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await save();
    } on Object {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.citySaveError),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  /// يحفظ المفتاح (ويُطبَّق عند منح الإذن)؛ تشغيله والإذن غير ممنوح يطلب
  /// الإذن مرة، وإن رُفض تبقى الملاحظة (DESIGN 8.7).
  Future<void> _setNotify(bool on, {required bool important}) async {
    final controller = ref.read(settingsProvider.notifier);
    await _save(
      () => important
          ? controller.setNotifyImportant(on)
          : controller.setNotifyDar(on),
    );
    if (!on || !mounted) return;
    final permission = ref.read(notificationPermissionProvider);
    if (permission.value == false) {
      await ref.read(notificationPermissionProvider.notifier).request();
    }
  }

  Future<void> _openDeviceSettings() async {
    try {
      await ref.read(notificationSchedulerProvider).openSystemSettings();
    } on Object {
      // لا شيء: الملاحظة باقية.
    }
  }

  /// قراءة واحدة ثم أقرب مدينة (DESIGN 8.7).
  Future<void> _relocate() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // يؤخذ الموجّه قبل أي انتظار: سياق الصفحة قد يزول قبل ضغط زر الرسالة.
    final router = GoRouter.of(context);
    final previousId = ref.read(settingsProvider).cityId;
    setState(() => _locating = true);

    String message;
    var offerPicker = false;
    try {
      final tables = await ref.read(tablesProvider.future);
      final result = await ref.read(cityLocatorProvider).locate(tables.cities);
      switch (result) {
        case LocateFound(:final city):
          await ref.read(settingsProvider.notifier).selectCity(city.id);
          message = city.id == previousId
              ? l10n.locationUnchanged(city.name.ar)
              : l10n.locationUpdated(
                  city.name.ar,
                  tables.region(city.regionId)?.name.ar ?? city.regionId,
                );
        case LocateOutOfRange():
          message = l10n.locationOutOfRange;
          offerPicker = true;
        case LocateDenied() || LocateUnavailable() || LocateTimeout():
          message = l10n.locationFailedSettings;
          offerPicker = true;
      }
    } on Object {
      // فشل حفظ المدينة أو قراءة البيانات أو أي خطأ غير متوقع.
      message = l10n.citySaveError;
    }

    if (!mounted) return;
    setState(() => _locating = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        action: offerPicker
            ? SnackBarAction(
                label: l10n.locationChooseCity,
                onPressed: () => router.push(AppRoutes.city),
              )
            : null,
      ),
    );
  }
}

/// بطاقة ملاحظة (DESIGN 5.2): `surface-alt`، أيقونة معلومات، نص، وزر اختياري.
class _NoteCard extends StatelessWidget {
  const _NoteCard({super.key, required this.text, this.action, this.live = false});

  final String text;
  final Widget? action;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
      child: Card(
        margin: EdgeInsetsDirectional.zero,
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ExcludeSemantics(child: Icon(Icons.info_outline)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      liveRegion: live,
                      child: Text(text, style: theme.textTheme.bodyMedium),
                    ),
                  ),
                ],
              ),
              ?action,
            ],
          ),
        ),
      ),
    );
  }
}

/// صف اختيار بشرائح (DESIGN 8.7، 5.3): المختارة بتعبئة وعلامة صح.
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.title,
    required this.values,
    required this.selected,
    required this.keyOf,
    required this.labelOf,
    required this.onSelected,
  });

  final String title;
  final List<T> values;
  final T selected;
  final Key Function(T) keyOf;
  final String Function(T) labelOf;
  final void Function(T) onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in values)
                ChoiceChip(
                  key: keyOf(v),
                  label: Text(labelOf(v)),
                  selected: v == selected,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (_) {
                    if (v != selected) onSelected(v);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
