import 'package:flutter/material.dart';

class ReceiveDataView extends StatelessWidget {
  const ReceiveDataView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          "Halaman Receive Data",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
