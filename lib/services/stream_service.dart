import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class StreamService {
  static final Map<String, String> _urlCache = {};

  static Future<String?> getStreamUrl(String videoId) async {
    final cached = _urlCache[videoId];
    if (cached != null) {
      debugPrint('StreamService: Cache hit for $videoId');
      return cached;
    }

    final url = await _getExplodeStreamUrl(videoId);
    if (url != null) {
      _urlCache[videoId] = url;
    }
    return url;
  }

  static Future<String?> _getExplodeStreamUrl(String videoId) async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.androidVr],
      );

      List<AudioOnlyStreamInfo> audioStreams = manifest.audioOnly;
      final mp4Streams = audioStreams.where((s) => s.container == StreamContainer.mp4).toList();
      if (mp4Streams.isNotEmpty) {
        audioStreams = mp4Streams;
      }

      if (audioStreams.isEmpty) return null;

      final sorted = audioStreams.toList()
        ..sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));

      final best = sorted.first;
      debugPrint('StreamService: [Explode] Found stream at ${best.bitrate}');
      return best.url.toString();
    } finally {
      yt.close();
    }
  }

  static void clearCache() => _urlCache.clear();
  static void evict(String videoId) => _urlCache.remove(videoId);
}
