import 'package:intl/intl.dart' show Bidi;
import 'package:material_ui/material_ui.dart';

/// اتجاه تلقائي لكل عنوان (عنوان إنجليزي داخل واجهة عربية والعكس).
TextDirection textDirectionFor(String text) =>
    Bidi.detectRtlDirectionality(text) ? TextDirection.rtl : TextDirection.ltr;
