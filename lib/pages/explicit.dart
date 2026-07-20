import 'package:flutter/material.dart';

class ExplicitPage extends StatelessWidget {
  const ExplicitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(179, 179, 179, 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 4.0,
        ),
        child: Text(
          'E',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
