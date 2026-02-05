import 'package:flutter/material.dart';

class LogPanel extends StatelessWidget {
  const LogPanel({super.key, required this.logs});

  final List<String> logs;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.all(8),
      child: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final line = logs[logs.length - 1 - index];
          return Text(line, style: const TextStyle(color: Colors.greenAccent, fontSize: 12));
        },
      ),
    );
  }
}
