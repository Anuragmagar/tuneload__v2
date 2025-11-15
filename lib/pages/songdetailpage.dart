import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:animated_digit/animated_digit.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:audiotagger/audiotagger.dart';
import 'package:audiotagger/models/tag.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter_file_downloader/flutter_file_downloader.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tuneload/local_notifications.dart';
import 'package:tuneload/manager/audio_player_manager.dart';
import 'package:tuneload/pages/explicit.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:rxdart/rxdart.dart' as rxdart;
import 'package:flutter_lyric/lyric_ui/lyric_ui.dart';
import 'package:flutter_lyric/lyric_ui/ui_netease.dart';
import 'package:flutter_lyric/lyrics_model_builder.dart';
import 'package:flutter_lyric/lyrics_reader_widget.dart';

class SongDetailPage extends ConsumerStatefulWidget {
  SongDetailPage(this.item, this.artists, this.highResImageUrl, {super.key});
  final dynamic item;
  String artists;
  final String highResImageUrl;

  @override
  ConsumerState<SongDetailPage> createState() => _SongDetailPageState();
}

class _SongDetailPageState extends ConsumerState<SongDetailPage> {
  final YoutubeExplode yt = YoutubeExplode();
  final player = AudioPlayer();
  late Stream<DurationState> durationState;

  Video? currentSong;
  String likes = "0";
  String views = "0";
  String year = "0000";
  String author = "Unknown Artist";
  bool isOnFavourite = false;
  dynamic favouriteKey = '';

  bool playing = false;
  bool loading = true;
  String? audioUrl; // Store the audio URL

  bool loadingLyrics = true;
  GlobalKey<FlipCardState> flipCardKey = GlobalKey<FlipCardState>();
  Map<String, dynamic> lyrics = {};
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

  void generateColors() async {
    final thumbnail = widget.item['thumbnails'].last;

    final paletteGenerator = await PaletteGenerator.fromImageProvider(
      NetworkImage(
        thumbnail['url'],
      ),
      size: const Size(540, 540),
      region: const Rect.fromLTRB(0, 0, 540, 540),
    );
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

  String formatDuration(int milliseconds) {
    int seconds = milliseconds ~/ 1000;
    int minutes = seconds ~/ 60;
    int hours = minutes ~/ 60;

    String hoursStr = hours.toString().padLeft(2, '0');
    String minutesStr = (minutes % 60).toString().padLeft(2, '0');
    String secondsStr = (seconds % 60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hoursStr:$minutesStr:$secondsStr';
    } else {
      return '$minutesStr:$secondsStr';
    }
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

  void attachMetadata(String inputFile) async {
    var imageBytes = await downloadImage(widget.highResImageUrl);

    // var inputFile = "/storage/emulated/0/Download/TuneLoad/finaltry.webm";
    String filePath = await _localPath;
    var outputFile = "$filePath/${widget.item['videoId']}.mp3";

    await FFmpegKit.execute(
            '-i $inputFile -vn -c:a libmp3lame -ar 44100 -ac 2 -b:a 192k $outputFile')
        .then((session) async {
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        await File(inputFile).delete();

        if (lyrics.isNotEmpty) {
          getLyrics;
        }

        await MetadataGod.writeMetadata(
          file: outputFile,
          metadata: Metadata(
            title: widget.item['title'],
            artist: widget.artists,
            album: widget.item['album']['name'],
            albumArtist: widget.artists,
            // trackNumber: widget.item['track_number'],
            // trackTotal: widget.item['album']['total_tracks'],
            // discNumber: widget.item['disc_number'],
            durationMs:
                double.parse(widget.item['duration_seconds'].toString()) * 1000,
            year: int.parse(year),
            picture: Picture(
              data: imageBytes,
              mimeType: "image/jpg",
            ),
          ),
        );

        final tagger = Audiotagger();
        if (lyrics['syncedLyrics'] != null) {
          final result = await tagger.writeTags(
            path: outputFile,
            tag: Tag(
              lyrics: utf8.decode(lyrics['syncedLyrics'].codeUnits),
            ),
          );
          print('Success $result');
        } else if (lyrics['plainLyrics'] != null) {
          final result = await tagger.writeTags(
            path: outputFile,
            tag: Tag(
              lyrics: utf8.decode(lyrics['plainLyrics'].codeUnits),
            ),
          );
          print('Success $result');
        } else {
          print('No lyrics to write');
        }

        await File(outputFile).rename(
            "$filePath/${widget.item['title']} - ${widget.artists}.mp3");

        LocalNotification.cancelNotification(
            int.parse(widget.item['duration_seconds'].toString()) + 1);

        final loadmsg = await MediaScanner.loadMedia(
          path: "$filePath/${widget.item['title']} - ${widget.artists}.mp3",
        );

        LocalNotification.showSimpleNotification(
            title: "Download complete!",
            body: "${widget.item['title']} - ${widget.artists}.mp3",
            payload: "thisi s simple data");
      } else if (ReturnCode.isCancel(returnCode)) {
        // CANCEL
      } else {
        FFmpegKitConfig.enableLogCallback((log) {
          // final message = log.getMessage();
        });
      }
    });
  }

  // Future<void> attachMetadata(String inputFile) async {
  //   final notificationId = int.parse(widget.item['duration_seconds'].toString()) + 1;
  //
  //   try {
  //     // Sanitize filename early to avoid issues
  //     final sanitizedTitle = widget.item['title']
  //         .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
  //         .trim();
  //     final sanitizedArtist = widget.artists
  //         .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
  //         .trim();
  //
  //     final filePath = await _localPath;
  //     final outputFile = "$filePath/$sanitizedTitle - $sanitizedArtist.mp3";
  //
  //     // Parallel execution: download image while checking file
  //     final imageBytesFuture = downloadImage(widget.highResImageUrl);
  //
  //     // Verify input file exists
  //     final inputFileObj = File(inputFile);
  //     if (!await inputFileObj.exists()) {
  //       throw Exception('Input file does not exist: $inputFile');
  //     }
  //
  //     // Update notification to conversion phase
  //     await LocalNotification.showIndeterminateProgressNotification(
  //       id: notificationId,
  //       title: "Converting to MP3...",
  //       body: "This may take a moment",
  //     );
  //
  //     // Execute FFmpeg conversion
  //     final session = await FFmpegKit.execute(
  //         '-i "$inputFile" -vn -c:a libmp3lame -ar 44100 -ac 2 -b:a 192k "$outputFile"'
  //     );
  //
  //     final returnCode = await session.getReturnCode();
  //
  //     if (!ReturnCode.isSuccess(returnCode)) {
  //       // Log FFmpeg errors
  //       final logs = await session.getLogs();
  //       final errorMessage = logs.map((log) => log.getMessage()).join('\n');
  //       debugPrint('FFmpeg conversion failed: $errorMessage');
  //       throw Exception('Audio conversion failed');
  //     }
  //
  //     // Delete input file after successful conversion
  //     await inputFileObj.delete();
  //
  //     // Update notification to metadata phase
  //     await LocalNotification.showIndeterminateProgressNotification(
  //       id: notificationId,
  //       title: "Adding metadata...",
  //       body: "Almost done",
  //     );
  //
  //     // Wait for image download
  //     final imageBytes = await imageBytesFuture;
  //
  //     // Write metadata
  //     await MetadataGod.writeMetadata(
  //       file: outputFile,
  //       metadata: Metadata(
  //         title: widget.item['title'],
  //         artist: widget.artists,
  //         album: widget.item['album']['name'],
  //         albumArtist: widget.artists,
  //         durationMs: double.parse(widget.item['duration_seconds'].toString()) * 1000,
  //         year: int.parse(year),
  //         picture: Picture(
  //           data: imageBytes,
  //           mimeType: "image/jpg",
  //         ),
  //       ),
  //     );
  //
  //     // Write lyrics if available (non-blocking)
  //     if (lyrics.isNotEmpty) {
  //       await _writeLyricsToFile(outputFile);
  //     }
  //
  //     // Scan media file
  //     await MediaScanner.loadMedia(path: outputFile);
  //
  //     // Cancel progress notification
  //     await LocalNotification.cancelNotification(notificationId);
  //
  //     // Show completion notification
  //     await LocalNotification.showSimpleNotification(
  //       title: "Download complete!",
  //       body: "$sanitizedTitle - $sanitizedArtist.mp3",
  //       payload: "download_complete",
  //     );
  //
  //     // Show success snackbar
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('Download complete with metadata!'),
  //           backgroundColor: Colors.green,
  //           duration: Duration(seconds: 3),
  //         ),
  //       );
  //     }
  //   } catch (e, stackTrace) {
  //     debugPrint('Error in attachMetadata: $e');
  //     debugPrint('Stack trace: $stackTrace');
  //
  //     // Cancel progress notification
  //     await LocalNotification.cancelNotification(notificationId);
  //
  //     // Show error notification
  //     await LocalNotification.showSimpleNotification(
  //       title: "Processing failed",
  //       body: "Failed to process audio file",
  //       payload: "processing_error",
  //     );
  //
  //     // Show error snackbar
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Processing failed: ${e.toString()}'),
  //           backgroundColor: Colors.red,
  //           duration: const Duration(seconds: 4),
  //         ),
  //       );
  //     }
  //   }
  // }

// Separate method for lyrics writing
  Future<void> _writeLyricsToFile(String outputFile) async {
    try {
      final tagger = Audiotagger();
      String? lyricsToWrite;

      if (lyrics['syncedLyrics'] != null) {
        lyricsToWrite = utf8.decode(lyrics['syncedLyrics'].codeUnits);
      } else if (lyrics['plainLyrics'] != null) {
        lyricsToWrite = utf8.decode(lyrics['plainLyrics'].codeUnits);
      }

      if (lyricsToWrite != null) {
        final result = await tagger.writeTags(
          path: outputFile,
          tag: Tag(lyrics: lyricsToWrite),
        );
        debugPrint('Lyrics written successfully: $result');
      }
    } catch (e) {
      debugPrint('Failed to write lyrics: $e');
      // Don't throw - lyrics are optional
    }
  }

  downloadSong() async {
    if (audioUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio URL not ready. Please try again.')),
      );
      return;
    }

    try {
      String fileName = widget.item['videoId'];
      String filePath = await _localPath;

      LocalNotification.showIndeterminateProgressNotification(
        id: int.parse(widget.item['duration_seconds'].toString()),
        title: "Downloading started ...",
        body: "Preparing link",
      );

      LocalNotification.cancelNotification(
          int.parse(widget.item['duration_seconds'].toString()));

      getLyrics();

      // Download as the actual format (webm or m4a) instead of mp3
      FileDownloader.downloadFile(
        url: audioUrl!, // Use the stored audio URL
        name: "$fileName.webm", // Download as webm (actual format)
        subPath: '/TuneLoad',
        onProgress: (String? fileName, double progress) {
          print("progress $progress");
        },
        onDownloadCompleted: (String fpath) {
          print("Download completed: $fpath");

          LocalNotification.showIndeterminateProgressNotification(
            id: int.parse(widget.item['duration_seconds'].toString()) + 1,
            title: "Processing audio file...",
            body: "This may take a few seconds",
          );

          attachMetadata(fpath);
        },
        onDownloadError: (String error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download failed: $error')),
          );
        },
        downloadDestination: DownloadDestinations.publicDownloads,
      );
    } catch (e) {
      debugPrint("Download error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: ${e.toString()}')),
      );
    }
  }

  String convertImageToHighRes(String url) {
    final widthRegex = RegExp(r'w\d+-');
    url = url.replaceAll(widthRegex, 'w540-');

    final heightRegex = RegExp(r'h\d+-');
    url = url.replaceAll(heightRegex, 'h540-');

    return url;
  }

  Future<void> getYtMetadata() async {
    try {
      print('Getting metadata for ${widget.item['videoId']}');

      // Parallel execution of independent operations
      final results = await Future.wait([
        yt.videos.get('https://youtube.com/watch?v=${widget.item['videoId']}'),
        yt.videos.streams.getManifest(widget.item['videoId'], ytClients: [
          YoutubeApiClient.safari,
          YoutubeApiClient.androidVr
        ])
      ]);

      print('Results $results');

      final video = results[0] as Video;
      final manifest = results[1] as StreamManifest;

      // Get best audio stream
      final bestAudioStream = manifest.audioOnly.withHighestBitrate();
      final audioUrlTemp = bestAudioStream.url.toString();

      print('Best audio available: $audioUrlTemp');

      // Set audio URL
      await player.setUrl(audioUrlTemp);

      // Format numbers once
      final formatter = NumberFormat.compact(locale: "en_US");

      // Determine artist name
      final artists = (widget.item['artists']?.isEmpty ?? true)
          ? video.author
          : widget.artists;

      // Single setState call
      setState(() {
        loading = false;
        audioUrl = audioUrlTemp; // Store the audio URL
        currentSong = video;
        likes = formatter.format(video.engagement.likeCount ?? 0);
        views = formatter.format(video.engagement.viewCount ?? 0);
        year = video.publishDate?.year.toString() ?? '0';
        widget.artists = artists;
      });
    } catch (e) {
      print('Error getting metadata: $e');
      setState(() {
        loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load song: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> addFavourite(Map<String, dynamic> newItem) async {
    final favouritesBox = Hive.box('favourites');
    await favouritesBox.add(newItem);
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
    final data = favouritesBox.keys.map((key) {
      final item = favouritesBox.get(key);
      if (item['title'] == widget.item['title']) {
        setState(() {
          isOnFavourite = true;
          favouriteKey = key;
        });
      }
    }).toList();
  }

  void streamMusic() async {
    player.play();
    setState(() {
      playing = true;
    });
  }

  void pauseMusic() async {
    await player.pause();
    setState(() {
      playing = false;
    });
  }

  void getLyrics() async {
    try {
      final queryParameters = {
        'track_name': widget.item['title'],
        'artist_name': widget.artists,
        'album_name': widget.item['album']['name'],
        'duration': '${widget.item['duration_seconds']}',
      };
      final uri = Uri.https('lrclib.net', '/api/get', queryParameters);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        setState(() {
          lyrics = jsonDecode(response.body);
          print("lyrics $lyrics");
          loadingLyrics = false;
        });
      } else {
        print("Trying with multiple query");

        final queryParameters = {
          'track_name': widget.item['title'],
          'artist_name': widget.artists,
          'album_name': widget.item['album']['name'],
          'duration': '${widget.item['duration_seconds']}',
        };
        final uri = Uri.https('lrclib.net', '/api/search', queryParameters);
        final response = await http.get(uri);
        if (response.statusCode == 200) {
          setState(() {
            if (jsonDecode(response.body).length > 0) {
              lyrics = jsonDecode(response.body)[0];
            }
            print("lyrics $lyrics");
            loadingLyrics = false;
          });
        }
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  void initState() {
    super.initState();
    generateColors();
    getYtMetadata();
    isFavourite();

    durationState =
        rxdart.Rx.combineLatest2<Duration, PlaybackEvent, DurationState>(
      player.positionStream,
      player.playbackEventStream,
      (position, playbackEvent) => DurationState(
        progress: position,
        buffered: playbackEvent.bufferedPosition,
        total: playbackEvent.duration,
      ),
    ).asBroadcastStream();
  }

  @override
  void dispose() {
    player.dispose();
    durationState.drain();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
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
            filter: ImageFilter.blur(sigmaX: 10),
            child: Container(
              width: double.infinity,
              color: Colors.black.withOpacity(0.3),
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title start
                        SizedBox(
                          width: double.infinity,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color:
                                      const Color.fromRGBO(217, 217, 217, 0.25),
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    Get.back();
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(
                                      PhosphorIconsBold.arrowLeft,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Column(
                                      children: [
                                        const Text(
                                          "From Album",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontFamily: 'Circular',
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        if (widget
                                                .item['album']['name'].length <
                                            35)
                                          Text(
                                            widget.item['album']['name'],
                                            style: const TextStyle(
                                              fontFamily: 'CircularStd',
                                              fontSize: 12,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        if (widget
                                                .item['album']['name'].length >=
                                            35)
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxHeight: 20,
                                              maxWidth: 300,
                                              minWidth: 300,
                                              minHeight: 20,
                                            ),
                                            child: TextScroll(
                                              widget.item['album']['name'],
                                              mode: TextScrollMode.endless,
                                              velocity: const Velocity(
                                                  pixelsPerSecond:
                                                      Offset(50, 0)),
                                              delayBefore: const Duration(
                                                  milliseconds: 800),
                                              pauseBetween: const Duration(
                                                  milliseconds: 1000),
                                              style: const TextStyle(
                                                fontFamily: 'CircularStd',
                                                fontSize: 12,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                              ),
                                              textAlign: TextAlign.right,
                                              selectable: true,
                                            ),
                                          )
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color:
                                        const Color.fromRGBO(139, 139, 139, 1),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      getLyrics();
                                    });
                                    flipCardKey.currentState?.toggleCard();
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(
                                      PhosphorIconsBold.musicNotes,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Title end

                        const SizedBox(
                          height: 30,
                        ),

                        FlipCard(
                          key: flipCardKey,
                          flipOnTouch: false,
                          fill: Fill.fillBack,
                          direction: FlipDirection.HORIZONTAL,
                          side: CardSide.FRONT,
                          front: GestureDetector(
                            onTap: () async {
                              getLyrics();
                              flipCardKey.currentState?.toggleCard();
                            },
                            child: Container(
                              color: vibrantColor,
                              width: 300,
                              height: 300,
                              child: Image(
                                image: NetworkImage(
                                  widget.highResImageUrl,
                                ),
                                fit: BoxFit.contain,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                                errorBuilder: (BuildContext context,
                                    Object exception, StackTrace? stackTrace) {
                                  return const Text('Failed to load image');
                                },
                              ),
                            ),
                          ),
                          back: GestureDetector(
                            onTap: () => flipCardKey.currentState?.toggleCard(),
                            child: Container(
                              child: loadingLyrics
                                  ? SizedBox(
                                      width: 300.0,
                                      height: 300.0,
                                      child: Shimmer.fromColors(
                                        baseColor: Colors.grey.shade300,
                                        highlightColor: Colors.grey.shade100,
                                        child: Container(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    )
                                  : StreamBuilder<DurationState>(
                                      stream: durationState,
                                      builder: (context, snapshot) {
                                        final durationState = snapshot.data;
                                        final progress =
                                            durationState?.progress ??
                                                Duration.zero;
                                        var syncedLyrics =
                                            lyrics['syncedLyrics'];

                                        if (syncedLyrics == null) {
                                          if (lyrics.isEmpty ||
                                              lyrics['plainLyrics'] == null) {
                                            return const Center(
                                              child: Scrollbar(
                                                child: SingleChildScrollView(
                                                  child: Text(
                                                    "No lyrics found.",
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          } else {
                                            return Center(
                                              child: Scrollbar(
                                                child: SingleChildScrollView(
                                                  child: Text(
                                                    lyrics['plainLyrics'],
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                        } else {
                                          var lyricModel =
                                              LyricsModelBuilder.create()
                                                  .bindLyricToMain(utf8.decode(
                                                      lyrics['syncedLyrics']
                                                          .codeUnits))
                                                  .getModel();
                                          return LyricsReader(
                                            model: lyricModel,
                                            position:
                                                progress.inMilliseconds.toInt(),
                                            lyricUi: lyricUI,
                                            playing: false,
                                            emptyBuilder: () => const Center(
                                              child: Text(
                                                "No lyrics",
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 30,
                        ),

                        if (widget.item['title'].length < 35)
                          Text(
                            widget.item['title'],
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontFamily: 'Circular',
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        if (widget.item['title'].length >= 35)
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 30,
                              minHeight: 30,
                              maxWidth: double.infinity,
                              minWidth: double.infinity,
                            ),
                            child: TextScroll(
                              widget.item['title'],
                              mode: TextScrollMode.endless,
                              velocity: const Velocity(
                                  pixelsPerSecond: Offset(60, 0)),
                              delayBefore: const Duration(milliseconds: 500),
                              pauseBetween: const Duration(milliseconds: 1000),
                              style: const TextStyle(
                                fontFamily: 'CircularStd',
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                              textAlign: TextAlign.right,
                              selectable: true,
                            ),
                          ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            widget.item['isExplicit']
                                ? const Row(
                                    children: [
                                      ExplicitPage(),
                                      SizedBox(
                                        width: 4.0,
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                            Flexible(
                              child: Text(
                                widget.artists?.isEmpty ?? true
                                    ? 'Unknown Artist'
                                    : widget.artists,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  fontFamily: 'Circular',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        // Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // For music streaming
                            if (loading)
                              const CircularProgressIndicator(
                                  color: Colors.white),
                            if (!loading)
                              playing
                                  ? IconButton(
                                      onPressed: pauseMusic,
                                      icon: const Icon(
                                        PhosphorIconsFill.pause,
                                        color: Colors.white,
                                      ),
                                    )
                                  : IconButton(
                                      onPressed: streamMusic,
                                      icon: const Icon(
                                        PhosphorIconsBold.play,
                                        color: Colors.white,
                                      ),
                                    ),

                            const SizedBox(width: 10),
                            // Download button - disabled until metadata loads
                            FilledButton.icon(
                              onPressed: loading || audioUrl == null
                                  ? null
                                  : downloadSong,
                              icon:
                                  const Icon(PhosphorIconsBold.downloadSimple),
                              label: const Text("Download Now"),
                              style: ButtonStyle(
                                backgroundColor:
                                    MaterialStateProperty.resolveWith<Color>(
                                  (Set<MaterialState> states) {
                                    if (states.contains(MaterialState.disabled)) {
                                      return Colors.grey;
                                    }
                                    return vibrantColor;
                                  },
                                ),
                              ),
                            ),
                            isOnFavourite
                                ? IconButton(
                                    onPressed: () async {
                                      removeFavourite(favouriteKey);
                                    },
                                    icon: const Icon(PhosphorIconsFill.heart),
                                    color: Colors.white,
                                  )
                                : IconButton(
                                    onPressed: () async {
                                      addFavourite({
                                        "title": widget.item['title'],
                                        "artist": widget.artists,
                                        "duration": widget.item['duration'],
                                        "image": widget.highResImageUrl,
                                        "year": year,
                                        "likes": likes,
                                      });
                                    },
                                    icon: const Icon(PhosphorIconsBold.heart),
                                    color: Colors.white,
                                  ),
                          ],
                        ),
                        // Buttons end

                        const SizedBox(
                          height: 30,
                        ),

                        StreamBuilder<DurationState>(
                          stream: durationState,
                          builder: (context, snapshot) {
                            final durationState = snapshot.data;
                            final progress =
                                durationState?.progress ?? Duration.zero;
                            final buffered =
                                durationState?.buffered ?? Duration.zero;
                            final total = durationState?.total ?? Duration.zero;
                            return playing
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: ProgressBar(
                                      progress: progress,
                                      buffered: buffered,
                                      total: total,
                                      onSeek: (value) {
                                        player.seek(value);
                                      },
                                      barHeight: 5,
                                      thumbRadius: 7,
                                      progressBarColor: Colors.white,
                                      thumbColor: Colors.white,
                                      bufferedBarColor: Colors.grey,
                                      baseBarColor: Colors.white24,
                                      thumbGlowRadius: 20,
                                      timeLabelTextStyle:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  )
                                : const SizedBox.shrink();
                          },
                        ),

                        const SizedBox(
                          height: 30,
                        ),
                        // Metadata
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20.0,
                                    horizontal: 0,
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        "Year",
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontFamily: 'Circular',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 20,
                                      ),
                                      AnimatedDigitWidget(
                                        value: int.parse(year),
                                        textStyle: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 35,
                                          fontFamily: 'Circular',
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 20,
                            ),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20.0,
                                    horizontal: 0,
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        "Duration",
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontFamily: 'Circular',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 20,
                                      ),
                                      Text(
                                        widget.item['duration'],
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 35,
                                          fontFamily: 'Circular',
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        // Second metadata
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20.0,
                                    horizontal: 0,
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        "Likes",
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontFamily: 'Circular',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 20,
                                      ),
                                      Text(
                                        likes,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 35,
                                          fontFamily: 'Circular',
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 20,
                            ),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20.0,
                                    horizontal: 0,
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        "Views",
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontFamily: 'Circular',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 20,
                                      ),
                                      Text(
                                        views,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 35,
                                          fontFamily: 'Circular',
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                        // Metadata end
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DurationState {
  const DurationState({
    required this.progress,
    required this.buffered,
    this.total,
  });
  final Duration progress;
  final Duration buffered;
  final Duration? total;
}
