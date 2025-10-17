import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class HomeController extends GetxController {
  // NAV index (akan dikontrol nanti oleh BNB)
  final selectedIndex = 0.obs;

  // Lokasi
  final latitude = ''.obs;
  final longitude = ''.obs;
  StreamSubscription<Position>? _posSub;

  // BLE / weight (placeholder)
  final weightText = 'Belum terkoneksi'.obs;
  final isConnected = false.obs;

  // Camera
  final capturedImagePath = RxnString();

  // Logs
  final logs = <String>[].obs;

  // BLE scan subscription (jika pakai)
  StreamSubscription? scanSubscription;

  final ImagePicker _picker = ImagePicker();

  @override
  void onInit() {
    super.onInit();
    requestPermissionsAndStart();
  }

  @override
  void onClose() {
    _posSub?.cancel();
    scanSubscription?.cancel();
    super.onClose();
  }

  void addLog(String msg) {
    logs.insert(0, '[${DateTime.now().toIso8601String()}] $msg');
  }

  // NAV helper
  void changeTab(int index) => selectedIndex.value = index;

  // ====== Permissions & Location ======
  Future<void> requestPermissionsAndStart() async {
    // Minta permissions runtime
    await [
      Permission.location,
      Permission.camera,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    // Cek dan minta user aktifkan Location Service bila perlu
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      addLog('Location service belum aktif, minta user mengaktifkan.');
      await Geolocator.openLocationSettings();
      // kembali cek setelah user
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        addLog('User tidak mengaktifkan lokasi.');
        return;
      }
    }

    // mulai track lokasi
    startLocationTracking();

    // (opsional) mulai BLE scan otomatis
    // startBleScan();
  }

  void startLocationTracking() {
    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 2,
    );

    _posSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (Position pos) {
        latitude.value = pos.latitude.toStringAsFixed(6);
        longitude.value = pos.longitude.toStringAsFixed(6);
        addLog('Lokasi update: ${latitude.value}, ${longitude.value}');
      },
      onError: (e) {
        addLog('Error lokasi: $e');
      },
    );
    addLog('Mulai tracking lokasi.');
  }

  // ====== Kamera  ======
  Future<void> takePhoto() async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.camera);
      if (file != null) {
        capturedImagePath.value = file.path;
        addLog('Foto diambil: ${file.path}');
      } else {
        addLog('User batal ambil foto.');
      }
    } catch (e) {
      addLog('Error ambil foto: $e');
    }
  }

  // ====== BLE (placeholder, copy logic lama jika perlu) ======
  void startBleScan() {
    addLog('Mulai scan BLE (placeholder)');
    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      addLog('Ditemukan ${results.length} device.');
      for (var r in results) {
        final name = r.device.platformName.isNotEmpty
            ? r.device.platformName
            : r.advertisementData.advName;
        addLog('Device: $name');
        if (name == 'ESP32_Timbangan') {
          addLog('ESP32 ditemukan, berhenti scan. (kamu bisa connect di sini)');
          FlutterBluePlus.stopScan();
          scanSubscription?.cancel();
          // connectToDevice(r.device);
          break;
        }
      }
    });
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
  }
}
