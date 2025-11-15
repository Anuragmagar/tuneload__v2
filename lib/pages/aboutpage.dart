import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class Aboutpage extends StatelessWidget {
  const Aboutpage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 20,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              "Settings",
              style: TextStyle(
                color: Color.fromARGB(255, 226, 226, 226),
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(
              height: 40,
            )
          ],
        ),
        //download tile
        ListTile(
          contentPadding: EdgeInsets.all(0),
          title: Text(
            "Download Path",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            "/storage/emulated/0/Download/TuneLoad",
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              color: Colors.white60,
            ),
          ),
          leading: Icon(
            PhosphorIconsBold.downloadSimple,
            color: Colors.white,
          ),
        ),

        //version tile
        ListTile(
          contentPadding: EdgeInsets.all(0),
          title: Text(
            "Version",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            "1.0.0",
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              color: Colors.white60,
            ),
          ),
          leading: Icon(
            PhosphorIconsBold.gitBranch,
            color: Colors.white,
          ),
        ),

        //share tile
        ListTile(
          contentPadding: EdgeInsets.all(0),
          title: Text(
            "Share App",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            "Let your friends know about us",
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              color: Colors.white60,
            ),
          ),
          leading: Icon(
            PhosphorIconsBold.shareFat,
            color: Colors.white,
          ),
        ),

        //feedback tile
        ListTile(
          contentPadding: EdgeInsets.all(0),
          title: Text(
            "Feedback",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            "Help us sharing the error and improvements to make",
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              color: Colors.white60,
            ),
          ),
          leading: Icon(
            PhosphorIconsBold.warningCircle,
            color: Colors.white,
          ),
        ),

        //about me tile
        ListTile(
          contentPadding: EdgeInsets.all(0),
          title: Text(
            "About Developer",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            "For detail, visit anuragmagar.com.np",
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              color: Colors.white60,
            ),
          ),
          leading: Icon(
            PhosphorIconsBold.userFocus,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
