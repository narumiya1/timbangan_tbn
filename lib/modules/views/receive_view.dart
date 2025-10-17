import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timbangan_bt/modules/controllers/receive_data_controller.dart';
import 'package:timbangan_bt/modules/views/location_service.dart';
import '../controllers/home_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ReceiveView extends GetView<ReceiveDataController> {
  const ReceiveView({super.key});

  @override
  Widget build(BuildContext context) {
    final locationService = Get.find<LocationService>();

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('TPS - Mobile', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ✅ Status Koneksi
            Obx(() => Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: controller.isConnected.value
                        ? Colors.green.shade400
                        : Colors.red.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      controller.isConnected.value
                          ? "Status: Connected"
                          : "Status: Not Connected",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                )),
            const SizedBox(height: 20),

            // 🧭 Lokasi real-time
            Obx(() {
              final pos = locationService.currentPosition.value;
              return Text(
                pos == null
                    ? 'Menunggu lokasi...'
                    : 'Lokasi: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 14),
              );
            }),
            const SizedBox(height: 20),

            // 📦 Card Data Timbangan
            Obx(() => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Terima Data dari Timbangan TPS",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Weight: ${controller.weight.value} Kg",
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500)),
                          Text("ID: ${controller.id.value}",
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: controller.receiveData,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.lightBlueAccent),
                          child: const Text("Terima Data"),
                        ),
                      ),

                      const Divider(),
                      Row(
                        children: const [
                          Icon(Icons.my_location_rounded,
                              color: Colors.blueAccent),
                          SizedBox(width: 8),
                          Text("Foto Timbangan",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Foto Timbangan pada lokasi TPS",
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 10),

                      // Gambar dummy
                      Obx(() => controller.photoPath.value == null
                          ? Image.asset("assets/timbangan.png",
                              height: 150, fit: BoxFit.contain)
                          : Image.asset(controller.photoPath.value!,
                              height: 150, fit: BoxFit.cover)),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: controller.sendDataAndImage,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.lightBlueAccent),
                              child: const Text("Kirim Data & Gambar"),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: controller.takePhoto,
                              child: const Text("Ambil Foto"),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
