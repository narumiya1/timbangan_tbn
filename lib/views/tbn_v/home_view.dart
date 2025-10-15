import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timbangan_bt/controller/ble_controller.dart';
import 'package:timbangan_bt/views/tbn_v/log_view.dart';
import 'package:timbangan_bt/views/tbn_v/profile_view.dart';
import 'package:timbangan_bt/views/tbn_v/timbangan_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final controller = Get.put(BleController());
  int currentIndex = 0;

  final pages = [
    const TimbanganView(),
    const LogView(),
    const ProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => setState(() => currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.scale), label: 'Timbangan'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Log'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
