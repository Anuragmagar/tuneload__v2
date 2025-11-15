import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:tuneload/local_notifications.dart';
import 'package:tuneload/pages/aboutpage.dart';
import 'package:tuneload/pages/downloadspage.dart';
import 'package:tuneload/pages/favouritespage.dart';
import 'package:tuneload/pages/homepage.dart';
import 'package:tuneload/pages/topbar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MetadataGod.initialize();
  await LocalNotification.init();
  await Hive.initFlutter();
  await Hive.openBox('favourites');

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Color.fromARGB(255, 35, 37, 46),
      // systemNavigationBarDividerColor: Colors.white,
      // statusBarColor: Colors.pink, // status bar color
      // systemNavigationBarIconBrightness: Brightness.light,
    ));
    return GetMaterialApp(
      theme: ThemeData(
        fontFamily: 'Circular',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var _currentIndex = 0;
  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> _key = GlobalKey(); // Create a key

    return Scaffold(
      key: _key,

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
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10),
          child: Container(
            color: Colors.black
                .withOpacity(0.3), // You can adjust the opacity to your liking
            child: SafeArea(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: ListView(
                  children: [
                    // App bar
                    Topbar(_key),

                    if (_currentIndex == 0) const Homepage(),
                    if (_currentIndex == 1) const Favouritespage(),
                    if (_currentIndex == 2) const Downloadspage(),
                    if (_currentIndex == 3) const Aboutpage(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),

      // bottomNavigationBar: ,
      bottomNavigationBar: SalomonBottomBar(
        unselectedItemColor: Colors.white,
        backgroundColor: const Color.fromARGB(255, 35, 37, 46),
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: [
          /// Home
          SalomonBottomBarItem(
            icon: const Icon(
              PhosphorIconsBold.house,
              // size: 18,
              color: Colors.white,
            ),
            title: const Text("Home"),
            selectedColor: const Color.fromARGB(255, 224, 224, 224),
          ),

          /// Search
          SalomonBottomBarItem(
            icon: const Icon(PhosphorIconsBold.heart),
            title: const Text("Favourites"),
            selectedColor: Colors.white,
          ),

          /// Profile
          SalomonBottomBarItem(
            icon: const Icon(PhosphorIconsBold.downloadSimple),
            title: const Text("Downloads"),
            selectedColor: Colors.white,
          ),

          /// Profile
          SalomonBottomBarItem(
            icon: const Icon(PhosphorIconsBold.user),
            title: const Text("Profile"),
            selectedColor: Colors.white,
          ),
        ],
      ),
      drawer: Drawer(
        shape: const Border(
          right: BorderSide.none,
        ),
        backgroundColor: Colors.black,
        child: CustomScrollView(
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              automaticallyImplyLeading: false,
              elevation: 0,
              stretch: true,
              expandedHeight: MediaQuery.of(context).size.height * 0.2,
              flexibleSpace: FlexibleSpaceBar(
                title: RichText(
                  text: const TextSpan(
                    text: "TuneLoad",
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.w900,
                    ),
                    children: <TextSpan>[
                      TextSpan(
                        text: "1.0.0",
                        style: TextStyle(
                          fontSize: 7.0,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.end,
                ),
                titlePadding: const EdgeInsets.only(bottom: 40.0),
                centerTitle: true,
                background: ShaderMask(
                  shaderCallback: (rect) {
                    return LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.black.withOpacity(0.1),
                      ],
                    ).createShader(
                      Rect.fromLTRB(0, 0, rect.width, rect.height),
                    );
                  },
                  blendMode: BlendMode.dstIn,
                  child: const Image(
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    image: AssetImage('assets/images/header.jpg'),
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate(
                [
                  ListTile(
                    title: const Text(
                      "Home",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20.0),
                    leading: const Icon(
                      PhosphorIconsFill.house,
                      color: Colors.white,
                    ),
                    selected: true,
                    onTap: () {},
                  ),
                  ListTile(
                    title: const Text(
                      "About",
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20.0),
                    leading: const Icon(
                      PhosphorIconsFill.info,
                      color: Colors.white,
                    ),
                    onTap: () {},
                  ),
                  ListTile(
                    title: const Text(
                      "Developer website",
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                    subtitle: const Text(
                      "https://anuragmagar.com.np",
                      style: TextStyle(
                        color: Colors.white60,
                      ),
                    ),
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20.0),
                    leading: const Icon(
                      PhosphorIconsFill.globe,
                      color: Colors.white,
                    ),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: <Widget>[
                  Spacer(),
                  Padding(
                    padding: EdgeInsets.fromLTRB(5, 30, 5, 20),
                    child: Center(
                      child: Text(
                        "Made with ❤️ by Anurag Magar",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // ),
    );
  }
}
