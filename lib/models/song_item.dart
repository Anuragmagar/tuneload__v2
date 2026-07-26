class SongItem {
  final String videoId;
  final String title;
  final String artist;
  final String thumbnailUrl;
  final int? durationSeconds;
  final String? albumName;
  final bool isExplicit;

  const SongItem({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    this.durationSeconds,
    this.albumName,
    this.isExplicit = false,
  });

  factory SongItem.fromMap(Map<String, dynamic> item, {String? artistOverride}) {
    final artists = item['artists'] as List<dynamic>?;
    final artistName = artistOverride ??
        (artists != null && artists.isNotEmpty
            ? (artists.first as Map<String, dynamic>)['name'] ?? 'Unknown Artist'
            : 'Unknown Artist');

    final thumbnails = item['thumbnails'] as List<dynamic>?;
    final thumbUrl = thumbnails != null && thumbnails.isNotEmpty
        ? (thumbnails.last as Map<String, dynamic>)['url'] ?? ''
        : '';

    return SongItem(
      videoId: item['videoId'] ?? '',
      title: item['title'] ?? 'Unknown',
      artist: artistName,
      thumbnailUrl: thumbUrl,
      durationSeconds: item['duration_seconds'] as int?,
      albumName: (item['album'] as Map<String, dynamic>?)?['name'],
      isExplicit: item['isExplicit'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'videoId': videoId,
        'title': title,
        'artists': [
          {'name': artist}
        ],
        'thumbnails': [
          {'url': thumbnailUrl}
        ],
        'duration_seconds': durationSeconds,
        'duration': durationSeconds != null
            ? '${durationSeconds! ~/ 60}:${(durationSeconds! % 60).toString().padLeft(2, '0')}'
            : '0:00',
        'isExplicit': isExplicit,
        'album': {'name': albumName ?? ''},
      };
}
