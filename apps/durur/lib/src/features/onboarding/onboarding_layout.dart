import 'package:flutter/material.dart';

/// هيكل مشترك لشاشات البداية: محتوى قابل للتمرير (يتمدد مع تكبير الخط)
/// وأزرار بعرض كامل في الأسفل (DESIGN 5.1).
class OnboardingLayout extends StatelessWidget {
  const OnboardingLayout({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.actions,
    this.extra,
  });

  /// أيقونة زخرفية مؤقتة مكان الرسم (مخفية عن قارئ الشاشة).
  final IconData icon;
  final String title;
  final String body;
  final Widget? extra;
  final List<Widget> actions;

  /// أزرار الشاشات التعريفية: ارتفاع 52dp وعرض كامل (DESIGN 5.1).
  static final ButtonStyle buttonStyle = ButtonStyle(
    minimumSize: WidgetStateProperty.all(const Size.fromHeight(52)),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: Icon(icon, size: 96, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                body,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (extra != null) ...[extra!, const SizedBox(height: 16)],
              for (final (i, action) in actions.indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
