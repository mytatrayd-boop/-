import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';

class ScanImage extends StatelessWidget {
  const ScanImage({super.key, required this.path, this.size, this.fit = BoxFit.cover});

  final String path;
  final double? size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Image.file(
      File(path),
      width: size,
      height: size,
      fit: fit,
      semanticLabel: null,
      errorBuilder: (context, _, _) => Container(
        width: size,
        height: size,
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          color: scheme.onSurfaceVariant,
          semanticLabel: AppLocalizations.of(context).scanImageUnavailable,
        ),
      ),
    );
  }
}
