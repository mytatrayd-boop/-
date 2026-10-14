import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../library/library_controller.dart';
import '../library/library_text.dart';

/// خطوط التطبيق المضمّنة وملفات تراخيصها (SIL OFL 1.1).
/// (الاسم المعروض، ملف الترخيص، اسم الحزمة في صفحة التراخيص).
const appFonts = <(String Function(AppLocalizations), String, String)>[
  (_amiri, 'assets/fonts/amiri/OFL.txt', 'Amiri'),
  (_plex, 'assets/fonts/ibm_plex_sans_arabic/OFL.txt', 'IBM Plex Sans Arabic'),
];

String _amiri(AppLocalizations l10n) => l10n.fontAmiri;
String _plex(AppLocalizations l10n) => l10n.fontIbmPlex;

/// يضيف تراخيص الخطوط إلى صفحة التراخيص القياسية (showLicensePage).
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (_, asset, package) in appFonts) {
      final text = await rootBundle.loadString(asset);
      yield LicenseEntryWithLineBreaks([package], text);
    }
  });
}

/// المصادر والتراخيص (DESIGN §14، D21): مصدر كل كتاب من الفهرس وملف الكتاب،
/// مع ذكر OpenITI والشاملة والطبعة والترخيص وما حُذف، ثم الخطوط والخدمات
/// والمكتبات البرمجية. الصفحة محلية وتعمل دون إنترنت.
class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = ref.watch(libraryControllerProvider).items;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sourcesTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
          children: [
            Text(l10n.sourcesIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(l10n.sourcesOpenItiLicense, style: theme.textTheme.bodyMedium),
            _LinkRow(name: l10n.sourcesOpenItiLink, url: openItiUrl),
            _LinkRow(name: l10n.sourcesLicenseLink, url: ccLicenseUrl),
            _Section(l10n.sourcesBooks),
            if (items.isEmpty)
              Text(l10n.sourcesNoBooks, style: theme.textTheme.bodyMedium),
            for (final item in items) ...[
              _BookSourceCard(item: item),
              const SizedBox(height: 12),
            ],
            _Section(l10n.sourcesFonts),
            for (final (name, asset, _) in appFonts)
              _FontRow(name: name(l10n), asset: asset),
            _Section(l10n.sourcesServices),
            for (final s in [
              l10n.sourcesServiceAi,
              l10n.sourcesServiceTts,
              l10n.sourcesServiceHosting,
            ])
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 8),
                child: Text(s, style: theme.textTheme.bodyMedium),
              ),
            _Section(l10n.sourcesLibraries),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: l10n.appTitle,
                  applicationLegalese: l10n.aboutFree,
                ),
                child: Text(l10n.sourcesViewLibraries),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: 24, bottom: 8),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

class _BookSourceCard extends StatelessWidget {
  const _BookSourceCard({required this.item});
  final LibraryItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final installed = item.installed;
    final url = item.entry?.sourceUrl ?? installed?.sourceUrl;
    final version = item.entry?.version ?? installed!.version;

    // تسمية بلغة الواجهة، والقيمة العربية من ملف الكتاب RTL دائماً.
    Widget field(String label, String value, {bool bookText = false}) =>
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 6),
          child: MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(label, style: theme.textTheme.labelLarge),
                Text(
                  value,
                  textDirection: bookText ? TextDirection.rtl : null,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        );

    return Card(
      margin: EdgeInsetsDirectional.zero,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                item.title.ar,
                textDirection: TextDirection.rtl,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: bookFont,
                ),
              ),
            ),
            Text(
              l10n.authorLine(context, item.author.ar, item.authorDeathHijri),
              style: theme.textTheme.bodyMedium,
            ),
            field(l10n.sourcesSourceLabel, item.sourceName),
            if (installed?.original case final original?)
              field(l10n.sourcesOriginalLabel, original, bookText: true),
            if (installed?.edition case final edition?)
              field(l10n.sourcesEditionLabel, edition, bookText: true),
            field(l10n.sourcesLicenseLabel, l10n.licenseName(item.license)),
            field(l10n.sourcesFileVersionLabel, l10n.number(context, version)),
            if (installed?.removed case final removed?)
              field(l10n.sourcesRemovedLabel, removed, bookText: true)
            else
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 6),
                child: Text(
                  l10n.sourcesDetailsAfterDownload,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (url != null) ...[
              field(l10n.sourcesLinkLabel, url),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Semantics(
                  label: l10n.sourcesCopyLinkSemantics(item.title.ar),
                  button: true,
                  excludeSemantics: true,
                  onTap: () => _copy(context, url),
                  child: TextButton.icon(
                    icon: const Icon(Icons.copy),
                    label: Text(l10n.sourcesCopyLink),
                    onPressed: () => _copy(context, url),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context, String url) =>
      copyLink(context, url);
}

const openItiUrl = 'https://openiti.org';
const ccLicenseUrl = 'https://creativecommons.org/licenses/by-nc-sa/4.0/';

/// ينسخ [url] مع رسالة عابرة (لا url_launcher بعد، انظر STATUS).
Future<void> copyLink(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = AppLocalizations.of(context).sourcesLinkCopied;
  await Clipboard.setData(ClipboardData(text: url));
  messenger
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
}

/// رابط عام: الاسم والرابط ظاهران، وزر «انسخ الرابط» بوصف لقارئ الشاشة.
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.name, required this.url});
  final String name;
  final String url;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.labelLarge),
                Text(url, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Semantics(
            label: l10n.sourcesCopyNamedLinkSemantics(name),
            button: true,
            excludeSemantics: true,
            onTap: () => copyLink(context, url),
            child: TextButton.icon(
              icon: const Icon(Icons.copy),
              label: Text(l10n.sourcesCopyLink),
              onPressed: () => copyLink(context, url),
            ),
          ),
        ],
      ),
    );
  }
}

class _FontRow extends StatelessWidget {
  const _FontRow({required this.name, required this.asset});
  final String name;
  final String asset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsetsDirectional.zero,
      minTileHeight: 56,
      title: Text(name),
      subtitle: Text(l10n.sourcesFontLicense),
      trailing: Semantics(
        label: l10n.sourcesViewLicenseSemantics(name),
        button: true,
        excludeSemantics: true,
        onTap: () => _open(context),
        child: TextButton(
          onPressed: () => _open(context),
          child: Text(l10n.sourcesViewLicense),
        ),
      ),
    );
  }

  void _open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => FontLicenseScreen(name: name, asset: asset),
    ),
  );
}

/// النص الكامل لترخيص الخط من ملف الأصول (يعمل دون إنترنت).
class FontLicenseScreen extends StatelessWidget {
  const FontLicenseScreen({super.key, required this.name, required this.asset});
  final String name;
  final String asset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.fontLicenseTitle(name))),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: DefaultAssetBundle.of(context).loadString(asset),
          builder: (context, snapshot) {
            final text = snapshot.data;
            if (text == null) {
              return Center(
                child: snapshot.hasError
                    ? Text(l10n.licenseLoadError)
                    : Semantics(
                        label: l10n.loading,
                        child: const CircularProgressIndicator(),
                      ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(16),
              child: Text(text, textDirection: TextDirection.ltr),
            );
          },
        ),
      ),
    );
  }
}
