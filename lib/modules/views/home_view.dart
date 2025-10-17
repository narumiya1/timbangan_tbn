import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timbangan_bt/modules/views/location_service.dart';
import 'package:timbangan_bt/modules/views/receive_view.dart';
import 'package:timbangan_bt/modules/views/transfer_view.dart';
import '../controllers/home_controller.dart';

class HomeView extends StatelessWidget {
  HomeView({super.key});
  final HomeController c = Get.put(HomeController());

  @override
  Widget build(BuildContext context) {
    return Obx(() => Scaffold(
          backgroundColor: Colors.grey[100],
          body: SafeArea(
            child: IndexedStack(
              index: c.selectedIndex.value,
              children: [
                // index 0 = Home page (current design)
                _homeContent(c),
                // index 1 = Receive
                const ReceiveView(),
                // index 2 = Transfer
                const TransferView(),
              ],
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: c.selectedIndex.value,
            onTap: (i) => c.changeTab(i),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.bluetooth), label: 'Receive Data'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.cloud_upload), label: 'Transfer Data'),
            ],
          ),
        ));
  }

  Widget _statusCard(String title, String value,
      {Color? color = Colors.green}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$title: $value',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center),
    );
  }

  Widget _actionRow(
      IconData icon, String subtitle, String buttonText, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)]),
      child: Row(
        children: [
          CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              child: Icon(icon, color: Colors.blue)),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(subtitle,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child:
                    ElevatedButton(onPressed: onTap, child: Text(buttonText)),
              )
            ]),
          )
        ],
      ),
    );
  }

  Widget _homeContent(HomeController c) {
    final locationService = Get.find<LocationService>();

    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          color: Colors.blue.shade700,
          child: const Center(
            child: Text(
              'TPS - Mobile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Status cards

        Obx(() {
          final pos = locationService.currentPosition.value;
          return Text(
            pos == null
                ? 'Menunggu lokasi...'
                : 'Lokasi: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
          );
        }),
        /**  Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _statusCard(
                'Lokasi',
                c.latitude.value.isEmpty
                    ? 'Mendeteksi lokasi...'
                    : 'Lat: ${c.latitude.value}, Lon: ${c.longitude.value}',
                color: Colors.green.shade400,
              ),
              const SizedBox(height: 8),
              _statusCard(
                'Status',
                c.isConnected.value ? 'Connected' : 'Not Connected',
                color: c.isConnected.value ? Colors.green : Colors.red,
              ),
            ],
          ),
        ),
             **/
        const SizedBox(height: 16),

        // Buttons area
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _actionRow(
                Icons.bluetooth,
                'Mulai Koneksi Bluetooth',
                'Start Connection',
                () {
                  c.startBleScan();
                },
              ),
              const SizedBox(height: 10),
              _actionRow(
                Icons.download,
                'Terima Data & Ambil Gambar',
                'Receive Data',
                () {
                  c.changeTab(1);
                },
              ),
              const SizedBox(height: 10),
              _actionRow(
                Icons.upload,
                'Kirim Data ke Server',
                'Transfer Data',
                () {
                  c.changeTab(2);
                },
              ),
            ],
          ),
        ),

        const Spacer(),

        // Log atau debug info kecil di bawah
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            'Log terakhir: ${c.logs.isNotEmpty ? c.logs.first : "-"}',
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
