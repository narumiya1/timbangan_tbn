import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timbangan_bt/controller/ble_controller.dart';

class TimbanganView extends GetView<BleController> {
  const TimbanganView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Obx(() => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  controller.weightText.value,
                  style: const TextStyle(fontSize: 40, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  "Lokasi: ${controller.latitude.value}, ${controller.longitude.value}",
                  style:
                      const TextStyle(color: Colors.greenAccent, fontSize: 14),
                ),
                const SizedBox(height: 20),
                controller.connectedDevice.value == null
                    ? ElevatedButton(
                        onPressed: controller.scanForDevice,
                        child: const Text("Scan ESP32"),
                      )
                    : Text(
                        "Terkoneksi: ${controller.connectedDevice.value!.platformName}",
                        style: const TextStyle(color: Colors.greenAccent),
                      ),
                const SizedBox(height: 20),
                if (controller.capturedImage.value != null)
                  Image.file(
                    controller.capturedImage.value!,
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: controller.takePhoto,
                  child: const Text("Ambil Foto"),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: controller.sendWeightAndPhoto,
                  child: const Text("Kirim Berat, Foto & Lokasi"),
                ),
              ],
            )),
      ),
    );
  }
}
