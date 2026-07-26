import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tuneload/manager/audio_player_manager.dart';
import 'package:tuneload/models/song_item.dart';
import 'package:tuneload/services/audio_handler.dart';

final audioHandlerProvider = Provider<AudioHandler>((ref) {
  return AudioHandler.instance;
});

final isLoadingStreamProvider = Provider<ValueNotifier<bool>>((ref) {
  return ref.watch(audioHandlerProvider).isLoadingStream;
});

final currentSongProvider = Provider<ValueNotifier<SongItem?>>((ref) {
  return ref.watch(audioHandlerProvider).currentSong;
});

final durationStateProvider = Provider<Stream<DurationState>>((ref) {
  return ref.watch(audioHandlerProvider).durationState;
});

final isPlayingProvider = Provider<bool>((ref) {
  return ref.watch(audioHandlerProvider).player.playing;
});
