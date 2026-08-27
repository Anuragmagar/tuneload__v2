import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Rx; // hide Rx to avoid conflict with rxdart
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tuneload/manager/audio_player_manager.dart';
import 'package:tuneload/models/song_item.dart';
import 'package:tuneload/config.dart';
import 'package:tuneload/services/stream_service.dart';
import 'package:tuneload/services/youtube_sdk_exception.dart';

class AudioHandler {
  AudioHandler._();
  static final AudioHandler _instance = AudioHandler._();
  static AudioHandler get instance => _instance;

  final AudioPlayer player = AudioPlayer();
  final ValueNotifier<bool> isLoadingStream = ValueNotifier(false);
  final ValueNotifier<SongItem?> currentSong = ValueNotifier(null);
  String _resolvedUrl = '';
  String get resolvedUrl => _resolvedUrl;

  Stream<DurationState> get durationState =>
      Rx.combineLatest2<Duration, PlaybackEvent, DurationState>(
        player.positionStream,
        player.playbackEventStream,
        (position, playbackEvent) => DurationState(
          progress: position,
          buffered: playbackEvent.bufferedPosition,
          total: playbackEvent.duration,
        ),
      ).asBroadcastStream();

  Future<void> playSong(SongItem song) async {
    try {
      isLoadingStream.value = true;
      currentSong.value = song;

      var lastError = YoutubeSdkException(
        'Could not get the song link right now. Please try again.',
      );
      var succeeded = false;

      if (AppConfig.preferServer && StreamService.isServerFallbackConfigured) {
        // Go straight to the server proxy (faster/more reliable on flagged
        // networks). No slow direct-client attempts.
        succeeded = await _tryServerProxy(song);
        if (!succeeded) {
          lastError = YoutubeSdkException(
            'Could not play this song via the server. Please try again.',
          );
        }
      } else {
        // Try each YouTube client in order. A client may resolve a URL that
        // still fails to play (YouTube 403s the actual stream), so we only
        // accept a client whose stream actually starts playing.
        for (final client in StreamService.clients) {
          if (succeeded) break;
          try {
            _resolvedUrl = await StreamService.resolveStreamUrlWithClient(
              song.videoId,
              client,
            );
            await _tryPlayResolved();
            succeeded = true;
          } catch (e) {
            debugPrint('AudioHandler: client failed to play: $e');
            lastError = e is YoutubeSdkException
                ? e
                : YoutubeSdkException.fromYoutube(e);
            await player.stop();
          }
        }

        if (!succeeded && StreamService.isServerFallbackConfigured) {
          succeeded = await _tryServerProxy(song);
        }
      }

      if (!succeeded) {
        _resolvedUrl = '';
        _showStreamError(lastError);
      }
    } finally {
      isLoadingStream.value = false;
    }
  }

  /// Attempts to play via the server proxy. Warms the server by resolving
  /// first, then plays the relayed audio. Retries on the free tier's
  /// transient 502s/cold-starts. Returns true on success.
  Future<bool> _tryServerProxy(SongItem song) async {
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await StreamService.resolveStreamUrlFromServer(song.videoId);
        _resolvedUrl = StreamService.resolveProxyUrlFromServer(song.videoId);
        await _tryPlayResolved();
        return true;
      } catch (e) {
        debugPrint(
          'AudioHandler: server proxy attempt $attempt/3 failed: $e',
        );
        await player.stop();
        if (attempt < 3) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
    }
    return false;
  }

  // Plays the currently resolved URL.
  //
  // just_audio reports load failures (e.g. YouTube 403s when the stream is
  // actually fetched) ASYNCHRONOUSLY through the playback event stream's
  // onError, not as a thrown exception from setUrl/play. So we subscribe to
  // the stream and resolve a completer either on success (stream became
  // ready/buffering) or on error, and let the caller rotate to the next
  // client if it fails.
  Future<void> _tryPlayResolved() async {
    final completer = Completer<void>();
    StreamSubscription<PlaybackEvent>? sub;

    sub = player.playbackEventStream.listen(
      (event) {
        final state = event.processingState;
        if (state == ProcessingState.ready ||
            state == ProcessingState.buffering) {
          if (!completer.isCompleted) completer.complete();
        }
      },
      onError: (Object e) {
        if (!completer.isCompleted) {
          completer.completeError(YoutubeSdkException.fromYoutube(e));
        }
      },
    );

    try {
      await player.setUrl(_resolvedUrl);
      await player.play();
      await completer.future.timeout(const Duration(seconds: 20));
    } finally {
      await sub.cancel();
    }
  }

  void _showStreamError(YoutubeSdkException error) {
    try {
      Get.snackbar(
        'Can\u2019t play this song',
        error.message,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
        isDismissible: true,
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
      );
    } catch (_) {
      // UI not ready (e.g. headless) — ignore.
    }
  }

  void togglePlayPause() {
    if (player.playing) {
      player.pause();
    } else {
      player.play();
    }
  }

  void seek(Duration position) {
    player.seek(position);
  }

  void stop() {
    player.stop();
    isLoadingStream.value = false;
  }

  void dispose() {
    player.dispose();
    isLoadingStream.dispose();
    currentSong.dispose();
  }
}
