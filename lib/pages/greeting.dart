import 'package:flutter/material.dart';

class Greeting extends StatefulWidget {
  const Greeting({super.key});

  @override
  State<Greeting> createState() => _GreetingState();
}

class _GreetingState extends State<Greeting> {
  String greetingText = '';
  String morningText = 'Good Morning!';
  String afternoonText = 'Good Afternoon!';
  String eveningText = 'Good Evening!';

  @override
  void initState() {
    super.initState();
    _updateGreeting();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hi,',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          greetingText,
          style: const TextStyle(
            color: Color.fromRGBO(241, 86, 86, 1),
            fontSize: 18,
            fontFamily: 'Circular',
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  void _updateGreeting() {
    final now = DateTime.now();
    final hour = now.hour;
    if (hour < 12) {
      setState(() {
        greetingText = morningText;
      });
    } else if (hour < 17) {
      setState(() {
        greetingText = afternoonText;
      });
    } else {
      setState(() {
        greetingText = eveningText;
      });
    }
  }
}
