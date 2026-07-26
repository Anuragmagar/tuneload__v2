import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tuneload/manager/audio_player_manager.dart';
import 'package:tuneload/models/song_item.dart';
import 'package:tuneload/services/stream_service.dart';

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

      final streamUrl = await StreamService.getStreamUrl(song.videoId);

      if (streamUrl == null) {
        debugPrint('AudioHandler: Failed to get stream URL for ${song.videoId}');
        isLoadingStream.value = false;
        return;
      }

      _resolvedUrl = streamUrl;
      await player.setUrl(streamUrl);
      isLoadingStream.value = false;
      await player.play();
    } catch (e) {
      debugPrint('AudioHandler: Error playing song: $e');
      isLoadingStream.value = false;
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
