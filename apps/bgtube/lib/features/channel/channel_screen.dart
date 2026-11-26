import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../domain/models/video_ref.dart';
import '../../domain/models/youtube_content.dart';
import '../../l10n/gen/app_localizations.dart';
import '../browse/paged_list_view.dart';
import '../browse/paged_loader.dart';
import '../browse/video_result_row.dart';
import '../player/text_direction.dart';

/// فيديوهات قناة عبر قائمة الرفع (وحدة لكل صفحة، لا بحث). سحب للتحديث فقط.
class ChannelScreen extends ConsumerStatefulWidget {
  const ChannelScreen({super.key, required this.channel});
  final ChannelSummary channel;

  @override
  ConsumerState<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends ConsumerState<ChannelScreen> {
  late final PagedLoader<VideoRef> _loader;

  @override
  void initState() {
    super.initState();
    final api = ref.read(youTubeApiProvider);
    final id = widget.channel.id;
    _loader = PagedLoader<VideoRef>((token, refresh) => api.channelVideos(id, pageToken: token, refresh: refresh))
      ..load();
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title = widget.channel.title;
    return Scaffold(
      appBar: AppBar(title: Text(title, textDirection: textDirectionFor(title))),
      body: PagedListView<VideoRef>(
        loader: _loader,
        onRefresh: () => _loader.load(refresh: true),
        empty: EmptyListView(icon: Icons.video_library_outlined, message: l.channelEmpty),
        itemBuilder: (context, v) => VideoResultRow(video: v),
      ),
    );
  }
}
