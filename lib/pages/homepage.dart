import 'dart:math';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tuneload/pages/greeting.dart';
import 'package:tuneload/pages/searchpage.dart';
import 'package:tuneload/pages/songdetailpage.dart';
import 'package:tuneload/providers/recommendation_provider.dart';

class Homepage extends ConsumerStatefulWidget {
  const Homepage({super.key});

  @override
  ConsumerState<Homepage> createState() => _HomepageState();
}

class _HomepageState extends ConsumerState<Homepage> {
  final YTMusic ytMusic = YTMusic();
  bool _ytMusicInitialized = false;

  Map<String, dynamic> results = {};
  bool isSearching = true;
  bool isSearchTap = false;
  bool hasError = false;
  String errorMsg = ' ';

  static const List<String> _keywords = [
    'pop hits 2025',
    'hip hop',
    'rock classics',
    'lofi beats',
    'Bollywood hits',
    'EDM mix',
    'R&B',
    'K-pop',
    'Latin music',
    'indie',
    'rap',
    'reggaeton',
    'jazz',
    'metal',
    'country hits',
    'blues',
    'classical piano',
  ];

  Map<String, dynamic> _songToItem(SongDetailed song) {
    final duration = song.duration;
    final mins = duration != null ? duration ~/ 60 : 0;
    final secs = duration != null ? duration % 60 : 0;
    return {
      'title': song.name,
      'videoId': song.videoId,
      'duration': '$mins:${secs.toString().padLeft(2, '0')}',
      'duration_seconds': duration ?? 0,
      'isExplicit': false,
      'artists': [
        {'name': song.artist.name}
      ],
      'thumbnails': [
        {'url': song.thumbnails.last.url}
      ],
      'album': {'name': song.album?.name ?? ''},
    };
  }

  void getRecommendation() async {
    if (!mounted) return;
    setState(() {
      hasError = false;
      errorMsg = ' ';
      isSearching = true;
      isSearchTap = true;
    });
    try {
      if (!_ytMusicInitialized) {
        await ytMusic.initialize();
        _ytMusicInitialized = true;
      }

      final random = Random();
      final pickedKeywords = [
        _keywords[random.nextInt(_keywords.length)],
        _keywords[random.nextInt(_keywords.length)],
      ];

      final Set<String> seenIds = {};
      final List<Map<String, dynamic>> allSongs = [];

      for (final keyword in pickedKeywords) {
        final songs = await ytMusic.searchSongs(keyword);
        for (final song in songs) {
          if (seenIds.add(song.videoId)) {
            allSongs.add(_songToItem(song));
          }
        }
      }

      if (!mounted) return;
      final body = {
        'count': allSongs.length,
        'songs': allSongs,
      };
      setState(() {
        isSearching = false;
        isSearchTap = false;
        results = body;
      });

      ref.read(recommendationProvider.notifier).addTasks(results);
      ref.read(isRecommendLoaded.notifier).state = true;
    } catch (e) {
      debugPrint('$e');
      if (!mounted) return;
      setState(() {
        hasError = true;
        errorMsg = 'Failed to load recommendations';
        isSearching = false;
        isSearchTap = false;
      });
    }
  }

  void getPermission() async {
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
  }

  @override
  void initState() {
    super.initState();

    getPermission();

    var reco = ref.read(isRecommendLoaded);
    if (reco != true) {
      getRecommendation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final recomm = ref.watch(recommendationProvider);
    final isRecomLoaded = ref.watch(isRecommendLoaded);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            height: 50,
          ),

          //Greeting
          const Greeting(),

          const SizedBox(
            height: 30,
          ),

          //Search
          const Text(
            "Search",
            style: TextStyle(
              color: Colors.white,
              fontSize: 33,
              fontFamily: 'Circular',
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: 10,
          ),
          GestureDetector(
            onTap: () {
              Get.to(
                () => const SearchPage(),
                transition: Transition.downToUp,
                duration: const Duration(milliseconds: 100),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color.fromRGBO(217, 104, 104, 1),
                ),
                borderRadius: BorderRadius.circular(10),
                color: const Color.fromRGBO(217, 107, 107, 0.36),
              ),
              width: double.infinity,
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIconsBold.magnifyingGlass,
                      color: Colors.white,
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    Text(
                      "Enter music title to download",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'Circular',
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 50,
          ),

          //Recommendation
          Row(
            children: [
              const Text(
                "Recommended for you",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: getRecommendation,
                icon: const Icon(
                  PhosphorIconsRegular.arrowClockwise,
                  color: Colors.white,
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          (isRecomLoaded == false)
              ? SizedBox(
                  width: double.infinity,
                  height: 250,
                  child: Shimmer.fromColors(
                    baseColor: Colors.grey.shade500,
                    highlightColor: const Color.fromRGBO(147, 65, 78, 1),
                    enabled: true,
                    period: const Duration(seconds: 1),
                    child: ListView.builder(
                      itemCount: 7,
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (build, context) => SizedBox(
                        width: 200,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 200,
                                width: 200,
                                color: Colors.white70,
                              ),
                              const SizedBox(height: 10),
                              Container(
                                height: 10,
                                width: 100,
                                color: Colors.white70,
                              ),
                              const SizedBox(height: 10),
                              Container(
                                height: 10,
                                width: 100,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),

          SizedBox(
            height: 250,
            child: (!isSearching || isRecomLoaded) && recomm['songs'] != null
                ? ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: recomm['count'] ?? 0,
                    itemBuilder: (context, index) {
                      final item = recomm['songs'][index];

                      List<dynamic> artistNames = item['artists'] != null
                          ? item['artists']
                              .map((artist) => artist['name'] ?? 'N/A')
                              .toList()
                          : [];
                      String combinedArtistNames = artistNames.join(', ');

                      final widthRegex = RegExp(r'w\d+-');
                      String highResImageUrl = (item['thumbnails'] != null &&
                              item['thumbnails'].isNotEmpty)
                          ? item['thumbnails']
                              .last['url']
                              .replaceAll(widthRegex, 'w540-')
                          : '';

                      final heightRegex = RegExp(r'h\d+-');
                      highResImageUrl =
                          highResImageUrl.replaceAll(heightRegex, 'h540-');

                      return GestureDetector(
                        onTap: () {
                          Get.to(
                            () => SongDetailPage(
                              item,
                              combinedArtistNames,
                              highResImageUrl,
                            ),
                            transition: Transition.rightToLeft,
                            duration: const Duration(milliseconds: 300),
                          );
                        },
                        child: SizedBox(
                          width: 200,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 180,
                                  width: 200,
                                  color: const Color.fromRGBO(
                                      217, 107, 107, 0.36),
                                  child: Image(
                                    image: NetworkImage(
                                      item['thumbnails'].last['url'],
                                    ),
                                    fit: BoxFit.contain,
                                    loadingBuilder: (BuildContext context,
                                        Widget child,
                                        ImageChunkEvent? loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  item['title'] ?? 'Unknown Title',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  combinedArtistNames,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.normal),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
