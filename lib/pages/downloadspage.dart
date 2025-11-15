import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class Downloadspage extends StatefulWidget {
  const Downloadspage({super.key});

  @override
  State<Downloadspage> createState() => _DownloadspageState();
}

class _DownloadspageState extends State<Downloadspage> {
  // Main method.
  final OnAudioQuery _audioQuery = OnAudioQuery();
  List<SongModel> songs = [];

  // Indicate if application has permission to the library.
  bool _hasPermission = false;

  void getLocalSongs() async {
    List<SongModel> audios = await _audioQuery.querySongs(
        sortType: null,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
        path: '/storage/emulated/0/Download/TuneLoad');
    setState(() {
      songs = audios;
    });
  }

  @override
  void initState() {
    super.initState();

    getLocalSongs();
    checkAndRequestPermissions();
  }

  checkAndRequestPermissions({bool retry = false}) async {
    // The param 'retryRequest' is false, by default.
    _hasPermission = await _audioQuery.checkAndRequest(
      retryRequest: retry,
    );

    // Only call update the UI if application has all required permissions.
    _hasPermission ? setState(() {}) : null;
  }

  @override
  Widget build(BuildContext context) {
    if (!songs.isNotEmpty) {
      return SizedBox(
        height: MediaQuery.of(context).size.height - 150,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIconsRegular.musicNotesPlus,
                color: Colors.red,
                size: 80,
              ),
              SizedBox(
                height: 10,
              ),
              Text(
                "No Downloads found",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'You can download your favourite song by clicking "Download Now" button in meta data page and they will appear here & files.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            height: 20,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                "All Songs",
                style: TextStyle(
                  color: Color.fromARGB(255, 226, 226, 226),
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                " • ${songs.length} songs",
                style: const TextStyle(
                  color: Color.fromARGB(255, 226, 226, 226),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 20,
              )
            ],
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 210),
              child: Scrollbar(
                radius: const Radius.circular(8),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final item = songs[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.all(0),
                      title: Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        item.artist ?? "No Artist",
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      trailing: const Icon(
                        PhosphorIconsRegular.heart,
                        color: Colors.white38,
                      ),
                      leading: QueryArtworkWidget(
                        controller: _audioQuery,
                        id: item.id,
                        type: ArtworkType.AUDIO,
                        artworkBorder: BorderRadius.circular(0),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget noAccessToLibraryWidget() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.redAccent.withOpacity(0.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Application doesn't have access to the library"),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => checkAndRequestPermissions(retry: true),
            child: const Text("Allow"),
          ),
        ],
      ),
    );
  }
}
