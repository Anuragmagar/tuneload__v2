import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tuneload/local_notifications.dart';
import 'package:tuneload/pages/greeting.dart';
import 'package:tuneload/pages/searchpage.dart';
import 'dart:convert'; // required to encode/decode json data
import 'package:http/http.dart' as http;
import 'package:tuneload/pages/songdetailpage.dart';
import 'package:tuneload/providers/recommendation_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class Homepage extends ConsumerStatefulWidget {
  const Homepage({super.key});

  @override
  ConsumerState<Homepage> createState() => _HomepageState();
}

class _HomepageState extends ConsumerState<Homepage> {
  final YoutubeExplode yt = YoutubeExplode();

  Map<String, dynamic> results = {};
  bool isSearching = true;
  bool isSearchTap = false;
  bool hasError = false;
  String errorMsg = ' ';
  int totalSongs = 0;
  String token =
      "BQDLuvGbG2ls8qNNkvml15ekfDrjUJrtby67LLYsgn5gyHgCen32-5SbDWKT_AfTUcKrgDoCTPOfQVbubd9mbYlK5MQ1_MH3XNaKupBONoW6LxXXG0A";

  getAccessToken() async {
    ref.read(isRecommendLoaded.notifier).state = false;
    try {
      final response = await http
          .post(Uri.parse("https://accounts.spotify.com/api/token"), headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      }, body: {
        "grant_type": "client_credentials",
        "client_id": "5d9129c2a9224eb8903668e80796b1cf",
        "client_secret": "50a052bfbfaf4934b33537202098b3f0",
      });
      final body = json.decode(response.body);
      setState(() {
        token = body["access_token"];
      });
      getRecommendation();
    } catch (e) {
      debugPrint("$e");
    }
  }

  void getRecommendation() async {
    // final ass = await getAccessToken();
    setState(() {
      hasError = false;
      errorMsg = ' ';
      isSearching = true;
      isSearchTap = true;
    });
    try {
      final response = await http.get(
        Uri.parse(
            "https://api.spotify.com/v1/recommendations?seed_artists=1RyvyyTE3xzB2ZywiAwp0i%2C0iEtIxbK0KxaSlF7G42ZOp%2C1deQzOQwArAsUgm2WdjtyI%2C00FQb4jTyendYWaN8pK0wa%2C3sauLUNFUPvJVWIADSYTvZ"),
        headers: {
          "Content-Type": "application/json",
          "authorization": "Bearer $token"
        },
      );
      final body = json.decode(response.body);
      final errorstat = body['error'];
      if (errorstat != null) {
        setState(() {
          hasError = true;
          errorMsg = body['error']['message'];
        });
        int errorCode = body['error']['status'];
        if (errorCode == 401) {
          getAccessToken();
        }
      }
      setState(() {
        isSearching = false;
        isSearchTap = false;
        results = body;
      });

      ref.read(recommendationProvider.notifier).addTasks(results);
      ref.read(isRecommendLoaded.notifier).state = true;
    } catch (e) {
      debugPrint('$e');
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

  void songDetailpageRouter(String item, String artist) async {
    LocalNotification.showIndeterminateProgressNotification(
      id: 3456,
      title: "Getting music",
      body: "You'll be redirected after getting the music url",
    );
    try {
      final response = await http.post(
        // Uri.parse("https://tuneload.anuragmagar.com.np/"),
        Uri.parse("http://anuragmagar.pythonanywhere.com/"),
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {
          "song": "$item $artist",
        },
      );
      final value = json.decode(response.body);
      // List val = value[0]['artists'].toList();
      // print(value[0]);
      // print(value[0]['album']);
      List<dynamic> artistNames = value[0]['artists'] != null
          ? value[0]['artists']
              .map((artist) => artist['name'] ?? 'N/A')
              .toList()
          : [];
      String combinedArtistNames = artistNames.join(', ');

      final widthRegex = RegExp(r'w\d+-');
      // Replace 'w' followed by digits and '-' with 'w540-'
      String highResImageUrl =
          value[0]['thumbnails'].last['url'].replaceAll(widthRegex, 'w540-');

      // Use regular expression to find 'h' followed by digits and '-'
      final heightRegex = RegExp(r'h\d+-');
      // Replace 'h' followed by digits and '-' with 'h540-'
      highResImageUrl = highResImageUrl.replaceAll(heightRegex, 'h540-');
      LocalNotification.cancelNotification(3456);
      Get.to(
        () => SongDetailPage(value[0], combinedArtistNames, highResImageUrl),
        transition: Transition.downToUp,
        duration: const Duration(milliseconds: 100),
      );
    } catch (e) {
      debugPrint("$e");
    }
  }

  @override
  void initState() {
    super.initState();

    getPermission();

    var reco = ref.read(isRecommendLoaded);
    if (reco != true) {
      getAccessToken();
    }
    // getStoredData();
  }

  @override
  Widget build(BuildContext context) {
    final recomm = ref.watch(recommendationProvider);
    final isRecomLoaded = ref.watch(isRecommendLoaded);

    // print(recomm['ldf'].length);
    return Column(
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
            // Navigator.push(context, MaterialPageRoute(builder: (context)=> const SearchPage()));
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
                    // size: 20,
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
              onPressed: getAccessToken,
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
          child: (!isSearching || isRecomLoaded)
              ? ListView.builder(
                  scrollDirection: Axis.horizontal,
                  // itemCount: results['tracks'].length,
                  itemCount: recomm['tracks'].length,
                  itemBuilder: (context, index) {
                    final item = recomm['tracks'][index];
                    // final item = results['tracks'][index];
                    // final item = recomm.elementAt(index);

                    List<dynamic> artistNames = item['artists']
                        .map((artist) => artist['name'])
                        .toList();
                    String combinedArtistNames = artistNames.join(', ');

                    return GestureDetector(
                      onTap: () async {
                        songDetailpageRouter(
                            item['name'], item['artists'][0]['name']);
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
                                color:
                                    const Color.fromRGBO(217, 107, 107, 0.36),
                                child: Image(
                                  image: NetworkImage(
                                    item['album']['images'][0]['url'],
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
                                item['name'],
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
    );
  }
}
