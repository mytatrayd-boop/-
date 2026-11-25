class NowPlaying {
  const NowPlaying({required this.videoId, required this.title, this.author, this.duration});

  final String videoId;
  final String title;
  final String? author;
  final Duration? duration;
}
