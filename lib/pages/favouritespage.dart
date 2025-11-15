import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class Favouritespage extends StatefulWidget {
  const Favouritespage({super.key});

  @override
  State<Favouritespage> createState() => _FavouritespageState();
}

class _FavouritespageState extends State<Favouritespage> {
  List<Map<String, dynamic>> favourites = [];
  final favouritesBox = Hive.box('favourites');
  getTasks() async {
    final data = favouritesBox.keys.map((key) {
      final item = favouritesBox.get(key);
      return {
        "key": key,
        "title": item["title"],
        "artist": item["artist"],
        "duration": item['duration'],
        "image": item['image'],
        "year": item['year'],
        "likes": item['likes'],
      };
    }).toList();

    setState(() {
      favourites = data.reversed.toList();
    });
  }

  @override
  void initState() {
    super.initState();
    getTasks();
  }

  @override
  Widget build(BuildContext context) {
    if (!favourites.isNotEmpty) {
      return SizedBox(
        height: MediaQuery.of(context).size.height - 150,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIconsRegular.listPlus,
                color: Colors.red,
                size: 80,
              ),
              SizedBox(
                height: 10,
              ),
              Text(
                "No Favourites found",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'You can add your favourite song by clicking "Heart icon" in meta data page and they will appear here.',
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
                "Favourites",
                style: TextStyle(
                  color: Color.fromARGB(255, 226, 226, 226),
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                " • ${favourites.length} songs",
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
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: favourites.length,
                itemBuilder: (context, index) {
                  final item = favourites[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.all(0),
                    title: Text(
                      '${item["title"]}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${item['artist']} • ${item['duration']}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    leading: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7.0),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        color: const Color.fromRGBO(217, 107, 107, 0.36),
                        height: 45,
                        width: 45,
                        child: Image.network(
                          item['image'],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        PhosphorIconsFill.heart,
                        color: Colors.red,
                      ),
                      onPressed: () async {
                        await favouritesBox.delete(item['key']);
                        getTasks();
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      );
    }
  }
}
