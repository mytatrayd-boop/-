import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/data_providers.dart';
import '../domain/models/review.dart';

/// صورة تقييم محفوظ، مع خلفية بديلة أثناء التحميل أو عند الخطأ.
class ReviewImage extends ConsumerWidget {
  const ReviewImage({super.key, required this.review, this.width, this.height, this.radius = 12});

  final Review review;
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final bytes = ref.watch(reviewImageProvider(review));
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHigh,
      child: Center(child: Icon(Icons.local_cafe_outlined, color: scheme.onSurfaceVariant)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: switch (bytes) {
          AsyncData(:final value) => Image.memory(
              value,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => placeholder,
            ),
          _ => placeholder,
        },
      ),
    );
  }
}
