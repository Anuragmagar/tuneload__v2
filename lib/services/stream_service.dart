import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:tuneload/config.dart';
import 'youtube_sdk_exception.dart';

class StreamService {
  static final Map<String, String> _urlCache = {};

  // The rotation of YouTube API clients used to resolve + play audio streams.
  // YouTube blocks clients *per IP* and rate-limits the most-used ones, so we
  // rotate until one gives a stream that actually plays.
  //  - ios: no signature deciphering needed (reliable), fails on some IPs
  //  - android: higher quality, but URLs can 403 when actually fetched
  //  - tv:   library fallback, more permissive but slower
  //  - androidVr: what the app originally used (works on home networks)
  static final List<YoutubeApiClient> _clients = [
    YoutubeApiClient.ios,
    YoutubeApiClient.android,
    YoutubeApiClient.tv,
    YoutubeApiClient.androidVr,
  ];

  static List<YoutubeApiClient> get clients => List.unmodifiable(_clients);

  /// Whether the server-side fallback is configured (base URL set).
  static bool get isServerFallbackConfigured =>
      AppConfig.streamServerBaseUrl.isNotEmpty;

  static Future<String?> getStreamUrl(String videoId) async {
    final cached = _urlCache[videoId];
    if (cached != null) {
      debugPrint('StreamService: Cache hit for $videoId');
      return cached;
    }

    final url = await resolveStreamUrl(videoId);
    _urlCache[videoId] = url;
    return url;
  }

  /// Resolves the best audio-only stream URL for [videoId] using the default
  /// client rotation. Throws [YoutubeSdkException] if nothing resolves.
  static Future<String> resolveStreamUrl(String videoId) async {
    final yt = YoutubeExplode();
    try {
      final info = await _resolveBestAudioWithClients(yt, videoId, _clients);
      return info.url.toString();
    } finally {
      yt.close();
    }
  }

  /// Resolves a stream URL using a single specific client. Throws
  /// [YoutubeSdkException] on failure.
  static Future<String> resolveStreamUrlWithClient(
    String videoId,
    YoutubeApiClient client,
  ) async {
    final yt = YoutubeExplode();
    try {
      final info = await _resolveBestAudio(yt, videoId, client);
      if (info == null) {
        throw YoutubeSdkException('No audio stream returned.');
      }
      debugPrint(
        'StreamService: [Explode] Resolved with ${_clientName(client)}',
      );
      return info.url.toString();
    } catch (e) {
      debugPrint(
        'StreamService: client ${_clientName(client)} failed: $e',
      );
      throw YoutubeSdkException.fromYoutube(e);
    } finally {
      yt.close();
    }
  }

  static Future<AudioOnlyStreamInfo?> _resolveBestAudio(
    YoutubeExplode yt,
    String videoId,
    YoutubeApiClient client,
  ) async {
    final manifest = await yt.videos.streamsClient.getManifest(
      videoId,
      ytClients: [client],
    );

    var audioStreams = manifest.audioOnly.toList();
    final mp4 = audioStreams
        .where((s) => s.container == StreamContainer.mp4)
        .toList();
    if (mp4.isNotEmpty) audioStreams = mp4;

    if (audioStreams.isEmpty) return null;
    audioStreams.sort(
      (a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond),
    );
    return audioStreams.first;
  }

  static Future<AudioOnlyStreamInfo> _resolveBestAudioWithClients(
    YoutubeExplode yt,
    String videoId,
    List<YoutubeApiClient> clients,
  ) async {
    Object? lastError;
    for (final client in clients) {
      try {
        final info = await _resolveBestAudio(yt, videoId, client);
        if (info != null) return info;
      } catch (e) {
        lastError = e;
      }
    }
    throw YoutubeSdkException.fromYoutube(
      lastError ?? 'No client could resolve the stream.',
    );
  }

  /// Resolves a stream URL using the server-side resolver (hosted
  /// yt-dlp on a non-flagged IP). Used as a fallback when direct client-side
  /// extraction is blocked by YouTube. Throws [YoutubeSdkException] on failure.
  static Future<String> resolveStreamUrlFromServer(String videoId) async {
    if (AppConfig.streamServerBaseUrl.isEmpty) {
      throw YoutubeSdkException('Server fallback is not configured.');
    }

    final base = AppConfig.streamServerBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/stream?vid=$videoId');
    debugPrint('StreamService: [Server] resolving $videoId via $uri');

    try {
      final headers = <String, String>{};
      if (AppConfig.streamServerUser.isNotEmpty) {
        final auth =
            'Basic ${base64Encode(utf8.encode('${AppConfig.streamServerUser}:${AppConfig.streamServerPass}'))}';
        headers['Authorization'] = auth;
      }

      // Generous timeout: free hosts like Render "sleep" on idle and can take
      // ~30-50s to cold-start before answering the first request.
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 75));

      if (response.statusCode != 200) {
        debugPrint(
          'StreamService: [Server] HTTP ${response.statusCode}: ${response.body}',
        );
        throw YoutubeSdkException('Server could not resolve the stream.');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final url = data['url'] as String?;
      if (url == null || url.isEmpty) {
        throw YoutubeSdkException('Server returned no stream URL.');
      }
      return url;
    } on YoutubeSdkException {
      rethrow;
    } catch (e) {
      debugPrint('StreamService: [Server] Failed: $e');
      throw YoutubeSdkException('Server fallback failed: $e');
    }
  }

  /// Returns the server URL that RELAYS the audio bytes for [videoId].
  ///
  /// googlevideo stream URLs are IP-locked to whoever requested them, so a
  /// URL-returning proxy won't play on a different device. `/proxy` downloads
  /// the audio on the server (from its own IP, with cookies) and streams the
  /// bytes to this device, which just plays this endpoint directly.
  static String resolveProxyUrlFromServer(String videoId) {
    if (!isServerFallbackConfigured) {
      throw YoutubeSdkException('Server fallback is not configured.');
    }
    final base =
        AppConfig.streamServerBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    return '$base/proxy?vid=$videoId';
  }

  static String _clientName(YoutubeApiClient client) {
    try {
      return (client.payload['context']['client']['clientName'] ?? '?').toString();
    } catch (_) {
      return '?';
    }
  }

  static void clearCache() => _urlCache.clear();
  static void evict(String videoId) => _urlCache.remove(videoId);
}
