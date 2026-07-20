import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
// import 'package:tuneload/models/song.dart';
import 'dart:convert'; // required to encode/decode json data
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:dart_ytmusic_api/yt_music.dart';
import 'package:dart_ytmusic_api/types.dart';
import 'package:tuneload/pages/explicit.dart';
import 'package:tuneload/pages/songdetailpage.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

enum SearchMode { server, ytMusicApi, ytExplode, videoId }

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  List<dynamic> results = [];

  bool isSearching = false;
  bool isSearchTap = false;
  bool hasError = false;
  String errorMsg = ' ';
  int totalSongs = 0;
  final YoutubeExplode yt = YoutubeExplode();
  final YTMusic _ytMusic = YTMusic();
  bool _ytMusicInitialized = false;
  SearchMode _searchMode = SearchMode.server;

  TextEditingController searchTextController = TextEditingController();

  Map<String, dynamic> _mapSongToItem(SongDetailed song) {
    final durationStr = song.duration != null
        ? '${song.duration! ~/ 60}:${(song.duration! % 60).toString().padLeft(2, '0')}'
        : '0:00';
    return {
      'title': song.name,
      'videoId': song.videoId,
      'duration': durationStr,
      'duration_seconds': song.duration ?? 0,
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

  Map<String, dynamic> _mapVideoToItem(Video video) {
    final durationStr = video.duration != null
        ? '${video.duration!.inMinutes}:${(video.duration!.inSeconds % 60).toString().padLeft(2, '0')}'
        : '0:00';
    return {
      'title': video.title,
      'videoId': video.id.value,
      'duration': durationStr,
      'duration_seconds': video.duration?.inSeconds ?? 0,
      'isExplicit': false,
      'artists': [
        {'name': video.author}
      ],
      'thumbnails': [
        {'url': video.thumbnails.highResUrl}
      ],
      'album': {'name': ''},
    };
  }

  void _performSearch() {
    if (searchTextController.text.trim().isEmpty) return;

    switch (_searchMode) {
      case SearchMode.server:
        _searchWithServer();
        break;
      case SearchMode.ytMusicApi:
        _searchWithYouTubeMusic();
        break;
      case SearchMode.ytExplode:
        _searchWithYouTube();
        break;
      case SearchMode.videoId:
        _searchByVideoId();
        break;
    }
  }

  void _searchWithServer() async {
    setState(() {
      hasError = false;
      errorMsg = ' ';
      isSearching = true;
      isSearchTap = true;
    });
    try {
      final response = await http.post(
        Uri.parse("http://tuneload.anuragmagar.com.np/"),
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {
          "song": searchTextController.text,
        },
      );
      final value = json.decode(response.body);
      if (!mounted) return;
      setState(() {
        isSearching = false;
        isSearchTap = false;
        results = value;
        totalSongs = results.length;
      });
    } catch (e) {
      debugPrint("$e");
      if (!mounted) return;
      setState(() {
        isSearching = false;
        hasError = true;
        errorMsg = 'Search failed. Please try again.';
      });
    }
  }

  void _searchWithYouTubeMusic() async {
    setState(() {
      hasError = false;
      errorMsg = ' ';
      isSearching = true;
      isSearchTap = true;
      results = [];
      totalSongs = 0;
    });
    try {
      if (!_ytMusicInitialized) {
        await _ytMusic.initialize();
        _ytMusicInitialized = true;
      }
      final songs = await _ytMusic.searchSongs(searchTextController.text);
      final mapped = songs.map((song) => _mapSongToItem(song)).toList();
      if (!mounted) return;
      setState(() {
        isSearching = false;
        isSearchTap = false;
        results = mapped;
        totalSongs = results.length;
      });
    } catch (e) {
      debugPrint("$e");
      if (!mounted) return;
      setState(() {
        isSearching = false;
        hasError = true;
        errorMsg = 'YouTube Music search failed. Please try again.';
      });
    }
  }

  void _searchWithYouTube() async {
    setState(() {
      hasError = false;
      errorMsg = ' ';
      isSearching = true;
      isSearchTap = true;
      results = [];
      totalSongs = 0;
    });
    try {
      final searchList = await yt.search.search(searchTextController.text);
      final mapped = searchList.map((video) => _mapVideoToItem(video)).toList();
      if (!mounted) return;
      setState(() {
        isSearching = false;
        isSearchTap = false;
        results = mapped;
        totalSongs = results.length;
      });
    } catch (e) {
      debugPrint("$e");
      if (!mounted) return;
      setState(() {
        isSearching = false;
        hasError = true;
        errorMsg = 'YouTube search failed. Please try again.';
      });
    }
  }

  void _searchByVideoId() async {
    final videoId = searchTextController.text.trim();
    setState(() {
      hasError = false;
      errorMsg = ' ';
      isSearching = true;
      isSearchTap = true;
    });
    try {
      final video = await yt.videos.get(videoId);
      final item = _mapVideoToItem(video);

      List<dynamic> artistNames = item['artists'] != null
          ? item['artists']
              .map((artist) => artist['name'] ?? 'N/A')
              .toList()
          : [];
      String combinedArtistNames = artistNames.join(', ');

      final widthRegex = RegExp(r'w\d+-');
      String highResImageUrl = item['thumbnails']
          .last['url']
          .replaceAll(widthRegex, 'w540-');
      final heightRegex = RegExp(r'h\d+-');
      highResImageUrl = highResImageUrl.replaceAll(heightRegex, 'h540-');

      if (!mounted) return;
      setState(() {
        isSearching = false;
        isSearchTap = false;
      });

      Get.to(
        () => SongDetailPage(item, combinedArtistNames, highResImageUrl),
        transition: Transition.rightToLeft,
        duration: const Duration(milliseconds: 300),
      );
    } catch (e) {
      debugPrint("$e");
      if (!mounted) return;
      setState(() {
        isSearching = false;
        hasError = true;
        errorMsg = 'Invalid video ID. Please check and try again.';
      });
    }
  }

  Widget _buildChip(String label, SearchMode mode) {
    final selected = _searchMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _searchMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: selected
              ? const LinearGradient(
                  colors: [
                    Color.fromRGBO(217, 104, 104, 1),
                    Color.fromRGBO(147, 65, 78, 1),
                  ],
                )
              : null,
          color: selected ? null : const Color.fromRGBO(217, 107, 107, 0.08),
          border: Border.all(
            color: selected
                ? const Color.fromRGBO(217, 104, 104, 0.8)
                : const Color.fromRGBO(217, 104, 104, 0.3),
            width: 1,
          ),
          boxShadow: selected
              ? [
                  const BoxShadow(
                    color: Color.fromRGBO(217, 104, 104, 0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  // Future<List<Song>> songsFuture = getSongs();
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    searchTextController.dispose();
    yt.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        // height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            stops: [0.6, 1],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xFF101115), Color(0xFF832F47)],
          ),
        ),
        child: Center(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10),
            child: Container(
              color: Colors.black.withValues(
                  alpha: 0.3), // You can adjust the opacity to your liking
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Theme(
                        data: Theme.of(context).copyWith(
                          textSelectionTheme: const TextSelectionThemeData(
                            selectionColor: Color.fromARGB(122, 255, 255, 255),
                          ),
                        ),
                        child: TextField(
                          controller: searchTextController,
                          style: const TextStyle(color: Colors.white),
                          autofocus: true,
                          cursorColor: Colors.white,
                          onSubmitted: (_) => _performSearch(),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            filled: true,
                            enabled: true,
                            fillColor: const Color.fromRGBO(217, 107, 107, 0.1),
                            border: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)),
                              borderSide: BorderSide(
                                color: Color.fromRGBO(217, 104, 104, 1),
                                width: 1,
                              ),
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)),
                              borderSide: BorderSide(
                                color: Color.fromRGBO(217, 104, 104, 1),
                                width: 1,
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)),
                              borderSide: BorderSide(
                                color: Color.fromRGBO(217, 104, 104, 1),
                                width: 1,
                              ),
                            ),
                            hintText: _searchMode == SearchMode.videoId
                                ? 'Paste YouTube video ID'
                                : _searchMode == SearchMode.ytMusicApi
                                    ? 'Search YouTube Music'
                                    : _searchMode == SearchMode.ytExplode
                                        ? 'Search YouTube'
                                        : 'Search songs on server',
                            contentPadding: const EdgeInsets.fromLTRB(
                                20.0, 10.0, 20.0, 10.0),
                            prefixIcon: IconButton(
                              icon: const Icon(
                                PhosphorIconsBold.arrowLeft,
                              ),
                              color: Colors.white,
                              onPressed: () {
                                Get.back();
                              },
                            ),
                            suffixIcon: Row(
                              // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    PhosphorIconsBold.x,
                                  ),
                                  color: Colors.white,
                                  onPressed: () {
                                    searchTextController.text = '';
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    PhosphorIconsBold.magnifyingGlass,
                                  ),
                                  color: Colors.white,
                                  onPressed: () {
                                    _performSearch();
                                  },
                                ),
                              ],
                            ),
                            hintStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      //End of search text box

                      const SizedBox(
                        height: 12,
                      ),

                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildChip('Server', SearchMode.server),
                            const SizedBox(width: 8),
                            _buildChip('YTMusic API', SearchMode.ytMusicApi),
                            const SizedBox(width: 8),
                            _buildChip('YT Explode', SearchMode.ytExplode),
                            const SizedBox(width: 8),
                            _buildChip('Video ID', SearchMode.videoId),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height: 15,
                      ),

                      isSearching
                          ? SizedBox(
                              height: 1000,
                              child: Shimmer.fromColors(
                                baseColor: Colors.grey.shade500,
                                highlightColor:
                                    const Color.fromRGBO(147, 65, 78, 1),
                                enabled: true,
                                period: const Duration(seconds: 1),
                                child: ListView.builder(
                                  itemCount: 7,
                                  itemBuilder: (build, context) => Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(12.0),
                                            color: const Color.fromRGBO(
                                                147, 65, 78, 1),
                                          ),
                                        ),
                                        const SizedBox(width: 12.0),
                                        Expanded(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: double.infinity,
                                                height: 10.0,
                                                color: const Color.fromRGBO(
                                                    147, 65, 78, 1),
                                                margin: const EdgeInsets.only(
                                                    bottom: 8.0),
                                              ),
                                              Container(
                                                width: 100.0,
                                                height: 10.0,
                                                color: const Color.fromRGBO(
                                                    147, 65, 78, 1),
                                              )
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),

                      hasError
                          ? Padding(
                              padding: const EdgeInsets.only(top: 120.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      const Color.fromRGBO(217, 107, 107, 0.1),
                                  border: Border.all(
                                    color:
                                        const Color.fromRGBO(217, 104, 104, 1),
                                  ),
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: Column(
                                  children: [
                                    const SizedBox(height: 20.0),
                                    const SizedBox(
                                      height: 150,
                                      child: Center(
                                        child: Image(
                                          image: AssetImage(
                                              'assets/images/search.png'),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 20,
                                    ),
                                    Text(
                                      errorMsg,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    )
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),

                      Expanded(
                        child: totalSongs > 0
                            ? Scrollbar(
                                radius: const Radius.circular(8),
                                child: ListView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: results.length,
                                  itemBuilder: (context, index) {
                                    final item = results[index];

                                    debugPrint("$item");
                                    // final item =
                                    //     results?.items[index];

                                    // List<String, dynamic> artistNames = item
                                    //     .map((artist) => item['artists'])
                                    //     .toList();
                                    List<dynamic> artistNames =
                                        item['artists'] != null
                                            ? item['artists']
                                                .map((artist) =>
                                                    artist['name'] ?? 'N/A')
                                                .toList()
                                            : [];
                                    String combinedArtistNames =
                                        artistNames.join(', ');

                                    //to get the highest resolution image url
                                    // Use regular expression to find 'w' followed by digits and '-'
                                    final widthRegex = RegExp(r'w\d+-');
                                    // Replace 'w' followed by digits and '-' with 'w540-'
                                    String highResImageUrl = item['thumbnails']
                                        .last['url']
                                        .replaceAll(widthRegex, 'w540-');

                                    // Use regular expression to find 'h' followed by digits and '-'
                                    final heightRegex = RegExp(r'h\d+-');
                                    // Replace 'h' followed by digits and '-' with 'h540-'
                                    highResImageUrl = highResImageUrl
                                        .replaceAll(heightRegex, 'h540-');

                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 15),
                                      child: GestureDetector(
                                        onTap: () {
                                          Get.to(
                                            () => SongDetailPage(
                                                item,
                                                combinedArtistNames,
                                                highResImageUrl),
                                            transition: Transition.rightToLeft,
                                            duration: const Duration(
                                                milliseconds: 300),
                                          );
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                                color: const Color.fromRGBO(
                                                    147, 65, 78, 1),
                                              ),
                                              child:
                                                  // SizedBox.shrink(),
                                                  Image(
                                                image: NetworkImage(
                                                  item['thumbnails']
                                                      .last['url'],
                                                ),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            const SizedBox(width: 12.0),
                                            Expanded(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    // item.title,
                                                    item['title'] ?? 'N/A',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 16.0,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  Row(
                                                    children: [
                                                      item['isExplicit']
                                                          ? const Row(
                                                              children: [
                                                                ExplicitPage(),
                                                                SizedBox(
                                                                  width: 4.0,
                                                                ),
                                                              ],
                                                            )
                                                          : const SizedBox
                                                              .shrink(),
                                                      Flexible(
                                                        child: Text(
                                                          '${combinedArtistNames.isEmpty ? 'Unknown Artist' : combinedArtistNames} • ${item['duration']}',
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                            color:
                                                                Colors.white60,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
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
