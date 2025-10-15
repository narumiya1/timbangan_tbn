import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timbangan_bt/controller/ble_controller.dart';

class LogView extends GetView<BleController> {
  const LogView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Obx(() => ListView.builder(
            itemCount: controller.logs.length,
            itemBuilder: (context, index) {
              final log = controller.logs[index];
              return Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text(
                  log,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              );
            },
          )),
    );
  }
}
