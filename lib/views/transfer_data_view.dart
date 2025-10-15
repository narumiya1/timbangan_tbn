import 'package:flutter/material.dart';

class TransferDataView extends StatelessWidget {
  const TransferDataView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          "Halaman Transfer Data",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
