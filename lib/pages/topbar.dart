import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class Topbar extends StatelessWidget {
  const Topbar(this.mainkey, {super.key});
  final GlobalKey<ScaffoldState> mainkey;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        //App bar
        GestureDetector(
          onTap: () {
            mainkey.currentState!.openDrawer();
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                // color: const Color.fromRGBO(139, 139, 139, 1),
                color: const Color.fromRGBO(139, 139, 139, 0),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(5),
              color: const Color.fromRGBO(217, 217, 217, 0.25),
            ),
            child: const Padding(
              padding: EdgeInsets.all(5.0),
              child: Icon(
                PhosphorIconsBold.list,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Tune ",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontFamily: 'Circular',
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                "Load",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color.fromRGBO(241, 86, 86, 1),
                  fontSize: 20,
                  fontFamily: 'Circular',
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
