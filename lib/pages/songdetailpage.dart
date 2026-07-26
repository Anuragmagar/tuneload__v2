import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:animated_digit/animated_digit.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:dio/dio.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tuneload/local_notifications.dart';
import 'package:tuneload/manager/audio_player_manager.dart';
import 'package:tuneload/models/song_item.dart';
import 'package:tuneload/pages/explicit.dart';
import 'package:tuneload/providers/audio_provider.dart';
import 'package:tuneload/services/audio_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_lyric/lyric_ui/lyric_ui.dart';
import 'package:flutter_lyric/lyric_ui/ui_netease.dart';
import 'package:flutter_lyric/lyrics_model_builder.dart';
import 'package:flutter_lyric/lyrics_reader_widget.dart';
import 'package:just_audio/just_audio.dart';

class SongDetailPage extends ConsumerStatefulWidget {
  const SongDetailPage(this.item, this.initialArtists, this.highResImageUrl, {super.key});
  final dynamic item;
  final String initialArtists;
  final String highResImageUrl;

  @override
  ConsumerState<SongDetailPage> createState() => _SongDetailPageState();
}

class _SongDetailPageState extends ConsumerState<SongDetailPage> {
  String likes = "0";
  String views = "0";
  String year = "0000";
  String author = "Unknown Artist";
  bool isOnFavourite = false;
  dynamic favouriteKey = '';

  bool playing = false;
  bool isDownloading = false;
  double downloadProgress = 0;
  String artists = '';

  bool loadingLyrics = true;
  bool metadataLoaded = false;
  GlobalKey<FlipCardState> flipCardKey = GlobalKey<FlipCardState>();
  Map<String, dynamic> lyrics = {};
  dynamic lyricModel;
  var lyricUI = UINetease(
    highlight: false,
    defaultSize: 20,
    lyricAlign: LyricAlign.CENTER,
  );
  List<Color> colors = [
    const Color(0xFF101115),
    Colors.black,
  ];

  Color vibrantColor = const Color.fromRGBO(116, 0, 0, 1);
  Color lightMutedColor = Colors.white;
  StreamSubscription<bool>? _playingSub;

  void generateColors() async {
    final thumbnail = widget.item['thumbnails'].last;

    final paletteGenerator = await PaletteGenerator.fromImageProvider(
      NetworkImage(
        thumbnail['url'],
      ),
      size: const Size(540, 540),
      region: const Rect.fromLTRB(0, 0, 540, 540),
    );
    if (!mounted) return;
    setState(() {
      colors = [
        const Color(0xFF101115),
        paletteGenerator.vibrantColor?.color ?? const Color(0xFF101115),
      ];

      vibrantColor =
          paletteGenerator.vibrantColor?.color ?? const Color(0xFF101115);
      lightMutedColor =
          paletteGenerator.lightMutedColor?.color ?? const Color(0xFF101115);
    });
  }

  Future<Uint8List> downloadImage(String url) async {
    var response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return Uint8List.fromList(response.bodyBytes);
    } else {
      throw Exception('Failed to load image from URL');
    }
  }

  static Future<String> getExternalDocumentPath() async {
    final DeviceInfoPlugin info = DeviceInfoPlugin();
    final AndroidDeviceInfo androidInfo = await info.androidInfo;
    final int androidVersion = int.parse(androidInfo.version.release);

    if (androidVersion < 13) {
      var status = await Permission.storage.status;

      if (!status.isGranted) {
        await Permission.storage.request();
      }
    } else {
      var status = await Permission.audio.status;
      var notistatus = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.audio.request();
      }
      if (!notistatus.isGranted) {
        await Permission.notification.request();
      }
    }

    Directory directory = Directory("dir");
    if (Platform.isAndroid) {
      directory = Directory("/storage/emulated/0/Download/TuneLoad");
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    final exPath = directory.path;
    await Directory(exPath).create(recursive: true);
    return exPath;
  }

  static Future<String> get _localPath async {
    final String directory = await getExternalDocumentPath();
    return directory;
  }

  Future<void> _insertLyricsToMp4(String filePath, String lyrics) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final bd = ByteData.view(bytes.buffer);

    int u32(int off) => bd.getUint32(off);

    (int, int)? findAtom(int start, int end, int targetType) {
      int p = start;
      while (p + 8 <= end) {
        int sz = u32(p);
        int tp = u32(p + 4);
        if (sz == 0) return null;
        if (sz == 1) {
          if (p + 16 > end) return null;
          int sz64 = bd.getUint64(p + 8);
          if (tp == targetType) return (p, sz64);
          p += sz64;
          continue;
        }
        if (tp == targetType) return (p, sz);
        p += sz;
      }
      return null;
    }

    final moov = findAtom(0, bytes.length, 0x6D6F6F76);
    if (moov == null) return;

    final udta = findAtom(moov.$1 + 8, moov.$1 + moov.$2, 0x75647461);
    if (udta == null) return;

    final meta = findAtom(udta.$1 + 8, udta.$1 + udta.$2, 0x6D657461);
    if (meta == null) return;

    final ilst = findAtom(meta.$1 + 12, meta.$1 + meta.$2, 0x696C7374);
    if (ilst == null) return;

    final lyricsBytes = utf8.encode(lyrics);
    final dataAtomSize = 16 + lyricsBytes.length;
    final lyrAtomSize = 8 + dataAtomSize;

    final lyrAtom = Uint8List(lyrAtomSize);
    final lyrBD = ByteData.view(lyrAtom.buffer);

    lyrBD.setUint32(0, lyrAtomSize);
    lyrBD.setUint8(4, 0xA9);
    lyrBD.setUint8(5, 0x6C);
    lyrBD.setUint8(6, 0x79);
    lyrBD.setUint8(7, 0x72);

    lyrBD.setUint32(8, dataAtomSize);
    lyrBD.setUint32(12, 0x64617461);
    lyrBD.setUint32(16, 1);
    lyrBD.setUint32(20, 0);
    lyrAtom.setRange(24, 24 + lyricsBytes.length, lyricsBytes);

    final insertAt = ilst.$1 + ilst.$2;
    final newBytes = Uint8List(bytes.length + lyrAtomSize);
    newBytes.setRange(0, insertAt, bytes);
    newBytes.setRange(insertAt, insertAt + lyrAtomSize, lyrAtom);
    newBytes.setRange(insertAt + lyrAtomSize, newBytes.length, bytes, insertAt);

    final newBD = ByteData.view(newBytes.buffer);
    newBD.setUint32(ilst.$1, ilst.$2 + lyrAtomSize);
    newBD.setUint32(meta.$1, meta.$2 + lyrAtomSize);
    newBD.setUint32(udta.$1, udta.$2 + lyrAtomSize);
    newBD.setUint32(moov.$1, moov.$2 + lyrAtomSize);

    await file.writeAsBytes(newBytes);
  }

  Future<void> downloadSong() async {
    if (AudioHandler.instance.resolvedUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio stream not ready. Please try again.')),
      );
      return;
    }

    if (isDownloading) return;

    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/tuneload_${widget.item['videoId']}.m4a';
    final tempFile = File(tempPath);

    try {
      if (!mounted) return;
      setState(() {
        isDownloading = true;
        downloadProgress = 0;
      });

      LocalNotification.showProgressNotification(
        id: _notifId,
        title: "Downloading...",
        body: widget.item['title'],
        progress: 0,
        maxProgress: 100,
      );

      final dio = Dio();
      final url = AudioHandler.instance.resolvedUrl;

      int totalBytes = 0;
      try {
        final headResponse = await dio.head(url);
        totalBytes = int.parse(
          headResponse.headers.value('content-length') ?? '0',
        );
      } catch (_) {}

      final sink = tempFile.openWrite();
      int downloadedBytes = 0;
      int lastReportedProgress = 0;

      if (totalBytes > 0) {
        const chunkSize = 1024 * 1024;
        int start = 0;
        while (true) {
          final end = (start + chunkSize - 1).clamp(0, totalBytes - 1);
          final chunkResponse = await dio.get(
            url,
            options: Options(
              responseType: ResponseType.stream,
              headers: {'Range': 'bytes=$start-$end'},
            ),
          );
          await for (final chunk in chunkResponse.data!.stream) {
            final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
            sink.add(bytes);
            downloadedBytes += bytes.length;
          }
          final progress = (downloadedBytes / totalBytes * 100).clamp(0, 100).toInt();
          if (progress != lastReportedProgress) {
            lastReportedProgress = progress;
            if (mounted) setState(() => downloadProgress = progress.toDouble());
            LocalNotification.showProgressNotification(
              id: _notifId,
              title: "Downloading... $progress%",
              body: widget.item['title'],
              progress: progress,
              maxProgress: 100,
            );
          }
          start += chunkSize;
          if (start >= totalBytes) break;
        }
      } else {
        final response = await dio.get(
          url,
          options: Options(responseType: ResponseType.stream),
        );
        final contentLength = int.parse(
          response.headers.value('content-length') ?? '0',
        );
        await for (final chunk in response.data!.stream) {
          final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
          sink.add(bytes);
          downloadedBytes += bytes.length;
          if (contentLength > 0) {
            final progress = (downloadedBytes / contentLength * 100).toInt();
            if (progress != lastReportedProgress) {
              lastReportedProgress = progress;
              if (mounted) setState(() => downloadProgress = progress.toDouble());
              LocalNotification.showProgressNotification(
                id: _notifId,
                title: "Downloading... $progress%",
                body: widget.item['title'],
                progress: progress,
                maxProgress: 100,
              );
            }
          }
        }
      }

      await sink.flush();
      await sink.close();

      LocalNotification.cancelNotification(_notifId);

      LocalNotification.showProgressNotification(
        id: _notifId,
        title: "Writing metadata...",
        body: widget.item['title'],
        progress: 100,
        maxProgress: 100,
      );

      final filePath = await _localPath;
      final sanitizedTitle = _sanitizeFileName(widget.item['title']);
      final sanitizedArtist = _sanitizeFileName(artists);
      final finalPath = '$filePath/$sanitizedTitle - $sanitizedArtist.m4a';

      await tempFile.copy(finalPath);
      await tempFile.delete();

      final metaTemp = File('${tempDir.path}/tuneload_meta_${widget.item['videoId']}.m4a');
      try {
        final original = File(finalPath);
        final originalBytes = await original.readAsBytes();
        await original.copy(metaTemp.path);

        final imageBytes = await downloadImage(widget.highResImageUrl);
        await MetadataGod.writeMetadata(
          file: metaTemp.path,
          metadata: Metadata(
            title: widget.item['title'],
            artist: artists,
            album: widget.item['album']?['name'] ?? '',
            albumArtist: artists,
            durationMs: double.parse(widget.item['duration_seconds'].toString()) * 1000,
            year: int.parse(year),
            picture: Picture(data: imageBytes, mimeType: "image/jpg"),
          ),
        );

        if (lyrics.isEmpty) {
          await _fetchLyrics();
        }
        String? lyricsToWrite;
        if (lyrics.isNotEmpty) {
          if (lyrics['syncedLyrics'] != null &&
              (lyrics['syncedLyrics'] as String).isNotEmpty) {
            lyricsToWrite = lyrics['syncedLyrics'].toString();
          } else if (lyrics['plainLyrics'] != null &&
              (lyrics['plainLyrics'] as String).isNotEmpty) {
            lyricsToWrite = lyrics['plainLyrics'].toString();
          }
        }
        if (lyricsToWrite != null && lyricsToWrite.isNotEmpty) {
          await _insertLyricsToMp4(metaTemp.path, lyricsToWrite);
          debugPrint('Lyrics embedded');
        }

        final metaBytes = await metaTemp.readAsBytes();
        final hasFtyp = metaBytes.length > 8 &&
            metaBytes[4] == 0x66 && metaBytes[5] == 0x74 &&
            metaBytes[6] == 0x79 && metaBytes[7] == 0x70;
        final sizeRatio = metaBytes.length / originalBytes.length;

        if (hasFtyp && sizeRatio > 0.5 && sizeRatio < 2.0) {
          await metaTemp.copy(finalPath);
          debugPrint('Metadata+lyrics written successfully');
        } else {
          debugPrint('Validation failed, keeping original');
        }
      } catch (e) {
        debugPrint('Metadata/lyrics write error, keeping original: $e');
      }
      try { await metaTemp.delete(); } catch (_) {}

      await MediaScanner.loadMedia(path: finalPath);

      LocalNotification.cancelNotification(_notifId);

      LocalNotification.showSimpleNotification(
        title: "Download complete!",
        body: "$sanitizedTitle - $sanitizedArtist.m4a",
        payload: finalPath,
      );

      if (!mounted) return;
      setState(() {
        isDownloading = false;
        downloadProgress = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download complete!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Download error: $e');
      LocalNotification.cancelNotification(_notifId);

      try {
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        isDownloading = false;
        downloadProgress = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  }

  int get _notifId => widget.item['videoId'].hashCode & 0x7FFFFFFF;

  Future<T> _retryWithBackoff<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    int baseDelayMs = 2000,
  }) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        final isLastAttempt = attempt == maxRetries;
        if (isLastAttempt) rethrow;

        final isRateLimit = e.toString().contains('RequestLimitExceededException') ||
            e.toString().contains('rate limiting');
        if (!isRateLimit) rethrow;

        final delay = baseDelayMs * (1 << attempt);
        debugPrint('Rate limited, retrying in ${delay}ms (attempt ${attempt + 1}/$maxRetries)');
        await Future.delayed(Duration(milliseconds: delay));
      }
    }
    throw StateError('Retry loop completed without result');
  }

  Future<void> _loadVideoMetadata() async {
    try {
      debugPrint('Getting metadata for ${widget.item['videoId']}');
      final yt = YoutubeExplode();
      try {
        final video = await _retryWithBackoff(
          () => yt.videos.get('https://youtube.com/watch?v=${widget.item['videoId']}'),
        );

        final formatter = NumberFormat.compact(locale: "en_US");

        final resolvedArtists = (widget.item['artists']?.isEmpty ?? true)
            ? video.author
            : artists;

        if (!mounted) return;
        setState(() {
          metadataLoaded = true;
          likes = formatter.format(video.engagement.likeCount ?? 0);
          views = formatter.format(video.engagement.viewCount);
          year = video.publishDate?.year.toString() ?? '0';
          artists = resolvedArtists;
        });

        getLyrics();
      } finally {
        yt.close();
      }
    } catch (e) {
      debugPrint('Error getting metadata: $e');
      if (!mounted) return;
      setState(() {
        metadataLoaded = true;
      });
      if (mounted) {
        final isRateLimit = e.toString().contains('RequestLimitExceededException') ||
            e.toString().contains('rate limiting');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isRateLimit
                ? 'YouTube rate limit reached. Please wait a moment and try again.'
                : 'Failed to load metadata: $e'),
            action: isRateLimit
                ? SnackBarAction(
                    label: 'Retry',
                    textColor: Colors.white,
                    onPressed: _loadVideoMetadata,
                  )
                : null,
          ),
        );
      }
    }
  }

  Future<void> addFavourite(Map<String, dynamic> newItem) async {
    final favouritesBox = Hive.box('favourites');
    await favouritesBox.add(newItem);
    if (!mounted) return;
    setState(() {
      isOnFavourite = true;
    });
  }

  void removeFavourite(dynamic removeKey) async {
    final favouritesBox = Hive.box('favourites');
    favouritesBox.delete(removeKey);
    setState(() {
      isOnFavourite = false;
      favouriteKey = '';
    });
  }

  void isFavourite() {
    final favouritesBox = Hive.box('favourites');
    for (final key in favouritesBox.keys) {
      final item = favouritesBox.get(key);
      if (item['title'] == widget.item['title']) {
        setState(() {
          isOnFavourite = true;
          favouriteKey = key;
        });
        break;
      }
    }
  }

  void streamMusic() async {
    final audioHandler = ref.read(audioHandlerProvider);
    if (audioHandler.player.processingState == ProcessingState.ready ||
        audioHandler.player.processingState == ProcessingState.buffering) {
      audioHandler.player.play();
    } else {
      await audioHandler.playSong(
        SongItem.fromMap(widget.item, artistOverride: artists),
      );
    }
  }

  void pauseMusic() {
    final audioHandler = ref.read(audioHandlerProvider);
    audioHandler.player.pause();
  }

  void _buildLyricModel() {
    final syncedLyrics = lyrics['syncedLyrics'];
    if (syncedLyrics != null && syncedLyrics.toString().isNotEmpty) {
      lyricModel = LyricsModelBuilder.create()
          .bindLyricToMain(syncedLyrics.toString())
          .getModel();
    } else {
      lyricModel = null;
    }
  }

  Future<void> _fetchLyrics() async {
    try {
      final queryParameters = {
        'track_name': widget.item['title'],
        'artist_name': artists,
        'album_name': widget.item['album']?['name'] ?? '',
        'duration': '${widget.item['duration_seconds']}',
      };
      final uri = Uri.https('lrclib.net', '/api/get', queryParameters);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            lyrics = Map<String, dynamic>.from(decoded);
          });
        }
      } else {
        final searchUri = Uri.https('lrclib.net', '/api/search', queryParameters);
        final searchResponse = await http.get(searchUri);
        if (searchResponse.statusCode == 200) {
          final results = jsonDecode(searchResponse.body);
          if (results is List && results.isNotEmpty) {
            if (!mounted) return;
            setState(() {
              lyrics = Map<String, dynamic>.from(results[0]);
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Lyrics fetch error: $e");
    }
  }

  void getLyrics() async {
    await _fetchLyrics();
    if (mounted) {
      setState(() {
        _buildLyricModel();
        loadingLyrics = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    artists = widget.initialArtists;
    generateColors();
    isFavourite();

    _loadVideoMetadata();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPlayback();
    });
  }

  Future<void> _startPlayback() async {
    final audioHandler = ref.read(audioHandlerProvider);

    _playingSub?.cancel();
    _playingSub = audioHandler.player.playingStream.listen((isPlaying) {
      if (mounted) {
        setState(() {
          playing = isPlaying;
        });
      }
    });

    await audioHandler.playSong(
      SongItem.fromMap(widget.item, artistOverride: artists),
    );
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    AudioHandler.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final albumArtSize = screenWidth * 0.95;
    final audioHandler = ref.watch(audioHandlerProvider);

    return ListenableBuilder(
      listenable: audioHandler.isLoadingStream,
      builder: (context, _) {
        final streamLoading = audioHandler.isLoadingStream.value;
        final canPlay = !streamLoading;

        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                stops: const [0.6, 1],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: colors,
              ),
            ),
            child: Center(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: double.infinity,
                  color: Colors.black.withValues(alpha: 0.25),
                  child: SafeArea(
                    child: Column(
                      children: [
                        // ── Header ──
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              _buildCircleButton(
                                icon: PhosphorIconsBold.caretDown,
                                onTap: () => Get.back(),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      "NOW PLAYING",
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 11,
                                        fontFamily: 'Circular',
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    if (widget.item['album']['name'].toString().length < 35)
                                      Text(
                                        widget.item['album']['name'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontFamily: 'Circular',
                                          fontWeight: FontWeight.w900,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      )
                                    else
                                      SizedBox(
                                        width: 200,
                                        height: 18,
                                        child: TextScroll(
                                          widget.item['album']['name'],
                                          mode: TextScrollMode.endless,
                                          velocity: const Velocity(pixelsPerSecond: Offset(50, 0)),
                                          delayBefore: const Duration(milliseconds: 800),
                                          pauseBetween: const Duration(milliseconds: 1000),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontFamily: 'Circular',
                                            fontWeight: FontWeight.w900,
                                          ),
                                          selectable: true,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              _buildCircleButton(
                                icon: PhosphorIconsBold.musicNotes,
                                onTap: () {
                                  getLyrics();
                                  flipCardKey.currentState?.toggleCard();
                                },
                              ),
                            ],
                          ),
                        ),

                        // ── Scrollable content ──
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                const SizedBox(height: 16),

                                // ── Album Art ──
                                Hero(
                                  tag: 'album_art_${widget.item['videoId']}',
                                  child: FlipCard(
                                    key: flipCardKey,
                                    flipOnTouch: false,
                                    fill: Fill.fillBack,
                                    direction: FlipDirection.HORIZONTAL,
                                    side: CardSide.FRONT,
                                    front: GestureDetector(
                                      onTap: () {
                                        getLyrics();
                                        flipCardKey.currentState?.toggleCard();
                                      },
                                      child: Container(
                                        width: albumArtSize,
                                        height: albumArtSize,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: vibrantColor.withValues(alpha: 0.45),
                                              blurRadius: 50,
                                              spreadRadius: -5,
                                              offset: const Offset(0, 15),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: Image(
                                            image: NetworkImage(widget.highResImageUrl),
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child, progress) {
                                              if (progress == null) return child;
                                              return Container(
                                                color: Colors.white.withValues(alpha: 0.05),
                                                child: const Center(
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white38,
                                                  ),
                                                ),
                                              );
                                            },
                                            errorBuilder: (context, error, stack) {
                                              return Container(
                                                color: Colors.white.withValues(alpha: 0.05),
                                                child: const Icon(
                                                  PhosphorIconsBold.musicNote,
                                                  size: 48,
                                                  color: Colors.white24,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    back: GestureDetector(
                                      onTap: () => flipCardKey.currentState?.toggleCard(),
                                      child: Container(
                                        width: albumArtSize,
                                        height: albumArtSize,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          color: Colors.black.withValues(alpha: 0.6),
                                          boxShadow: [
                                            BoxShadow(
                                              color: vibrantColor.withValues(alpha: 0.3),
                                              blurRadius: 50,
                                              spreadRadius: -5,
                                              offset: const Offset(0, 15),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: _buildLyricsContent(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 32),

                                // ── Title ──
                                if (widget.item['title'].length < 40)
                                  Text(
                                    widget.item['title'],
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontFamily: 'Circular',
                                      fontWeight: FontWeight.w900,
                                    ),
                                  )
                                else
                                  SizedBox(
                                    width: double.infinity,
                                    height: 30,
                                    child: TextScroll(
                                      widget.item['title'],
                                      mode: TextScrollMode.endless,
                                      velocity: const Velocity(pixelsPerSecond: Offset(50, 0)),
                                      delayBefore: const Duration(milliseconds: 500),
                                      pauseBetween: const Duration(milliseconds: 800),
                                      style: const TextStyle(
                                        fontFamily: 'CircularStd',
                                        fontSize: 22,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                      selectable: true,
                                    ),
                                  ),

                                const SizedBox(height: 8),

                                // ── Artist ──
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (widget.item['isExplicit']) ...[
                                      const ExplicitPage(),
                                      const SizedBox(width: 6),
                                    ],
                                    Flexible(
                                      child: Text(
                                        artists.isEmpty ? 'Unknown Artist' : artists,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.7),
                                          fontSize: 15,
                                          fontFamily: 'Circular',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 28),

                                // ── Controls ──
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Favourite
                                    IconButton(
                                      onPressed: () {
                                        if (isOnFavourite) {
                                          removeFavourite(favouriteKey);
                                        } else {
                                          addFavourite({
                                            "title": widget.item['title'],
                                            "artist": artists,
                                            "duration": widget.item['duration'],
                                            "image": widget.highResImageUrl,
                                            "year": year,
                                            "likes": likes,
                                          });
                                        }
                                      },
                                      icon: Icon(
                                        isOnFavourite
                                            ? PhosphorIconsFill.heart
                                            : PhosphorIconsBold.heart,
                                        color: isOnFavourite
                                            ? vibrantColor
                                            : Colors.white.withValues(alpha: 0.7),
                                        size: 26,
                                      ),
                                    ),

                                    const SizedBox(width: 20),

                                    // Play / Pause
                                    GestureDetector(
                                      onTap: canPlay ? (playing ? pauseMusic : streamMusic) : null,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        width: 68,
                                        height: 68,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: !canPlay
                                              ? Colors.white.withValues(alpha: 0.15)
                                              : vibrantColor,
                                          boxShadow: [
                                            BoxShadow(
                                              color: vibrantColor.withValues(alpha: 0.4),
                                              blurRadius: 24,
                                              spreadRadius: -2,
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: streamLoading
                                              ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    color: Colors.white54,
                                                  ),
                                                )
                                              : Icon(
                                                  playing
                                                      ? PhosphorIconsFill.pause
                                                      : PhosphorIconsFill.play,
                                                  color: Colors.white,
                                                  size: 30,
                                                ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 20),

                                    // Download
                                    IconButton(
                                      onPressed: canPlay && !isDownloading ? downloadSong : null,
                                      icon: isDownloading
                                          ? SizedBox(
                                              width: 26,
                                              height: 26,
                                              child: CircularProgressIndicator(
                                                value: downloadProgress / 100,
                                                strokeWidth: 2.5,
                                                color: vibrantColor,
                                                backgroundColor: Colors.white.withValues(alpha: 0.15),
                                              ),
                                            )
                                          : Icon(
                                              PhosphorIconsBold.downloadSimple,
                                              color: canPlay
                                                  ? Colors.white.withValues(alpha: 0.7)
                                                  : Colors.white.withValues(alpha: 0.2),
                                              size: 26,
                                            ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                // ── Progress Bar ──
                                StreamBuilder<DurationState>(
                                  stream: audioHandler.durationState,
                                  builder: (context, snapshot) {
                                    final state = snapshot.data;
                                    final progress = state?.progress ?? Duration.zero;
                                    final buffered = state?.buffered ?? Duration.zero;
                                    final total = state?.total ?? Duration.zero;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: ProgressBar(
                                        progress: progress,
                                        buffered: buffered,
                                        total: total,
                                        onSeek: (value) => audioHandler.seek(value),
                                        barHeight: 5,
                                        thumbRadius: 7,
                                        progressBarColor: vibrantColor,
                                        thumbColor: Colors.white,
                                        bufferedBarColor: vibrantColor.withValues(alpha: 0.3),
                                        baseBarColor: Colors.white.withValues(alpha: 0.1),
                                        thumbGlowRadius: 20,
                                        timeLabelTextStyle: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          fontSize: 12,
                                          fontFamily: 'Circular',
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                const SizedBox(height: 28),

                                // ── Metadata ──
                                Row(
                                  children: [
                                    _buildMetadataCard(
                                      label: "Year",
                                      child: AnimatedDigitWidget(
                                        value: int.parse(year),
                                        textStyle: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 32,
                                          fontFamily: 'Circular',
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _buildMetadataCard(
                                      label: "Duration",
                                      child: Text(
                                        widget.item['duration'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 32,
                                          fontFamily: 'Circular',
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildMetadataCard(
                                      label: "Likes",
                                      child: AnimatedDigitWidget(
                                        value: int.tryParse(likes.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
                                        textStyle: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 32,
                                          fontFamily: 'Circular',
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _buildMetadataCard(
                                      label: "Views",
                                      child: AnimatedDigitWidget(
                                        value: int.tryParse(views.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
                                        textStyle: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 32,
                                          fontFamily: 'Circular',
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetadataCard({
    required String label,
    required Widget child,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          children: [
            child,
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
                fontFamily: 'Circular',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricsContent() {
    if (loadingLyrics) {
      return SizedBox(
        width: double.infinity,
        height: 300,
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade800,
          highlightColor: Colors.grey.shade600,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      );
    }

    final syncedLyrics = lyrics['syncedLyrics'];

    if (syncedLyrics == null) {
      if (lyrics.isEmpty || lyrics['plainLyrics'] == null) {
        return const SizedBox(
          height: 300,
          child: Center(
            child: Text(
              "No lyrics found.",
              style: TextStyle(
                fontSize: 16,
                color: Colors.white54,
                fontFamily: 'Circular',
              ),
            ),
          ),
        );
      }
      return SizedBox(
        height: 300,
        child: Center(
          child: Scrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(
                lyrics['plainLyrics'],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.8,
                  color: Colors.white70,
                  fontFamily: 'Circular',
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (lyricModel == null) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: Text(
            "No lyrics",
            style: TextStyle(
              fontSize: 16,
              color: Colors.white54,
              fontFamily: 'Circular',
            ),
          ),
        ),
      );
    }

    return StreamBuilder<DurationState>(
      stream: ref.read(audioHandlerProvider).durationState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final progress = state?.progress ?? Duration.zero;
        return SizedBox(
          height: 300,
          child: LyricsReader(
            model: lyricModel,
            position: progress.inMilliseconds.toInt(),
            lyricUi: lyricUI,
            playing: playing,
            emptyBuilder: () => const Center(
              child: Text(
                "No lyrics",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white54,
                  fontFamily: 'Circular',
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.1),
        ),
        child: Icon(
          icon,
          size: 18,
          color: Colors.white.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}
