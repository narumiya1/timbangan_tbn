import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class BleController extends GetxController {
  final Rx<BluetoothDevice?> connectedDevice = Rx<BluetoothDevice?>(null);
  final RxString weightText = "Belum terkoneksi".obs;
  final Rx<File?> capturedImage = Rx<File?>(null);
  final RxList<String> logs = <String>[].obs;

  final RxString latitude = "-".obs;
  final RxString longitude = "-".obs;

  final ImagePicker _picker = ImagePicker();
  StreamSubscription? scanSubscription;
  StreamSubscription<Position>? positionStream;

  static const String serviceUuid = "12345678-1234-5678-1234-56789abcdef0";
  static const String characteristicUuid =
      "0000fff1-0000-1000-8000-00805f9b34fb";

  BluetoothCharacteristic? weightCharacteristic;

  @override
  void onInit() {
    super.onInit();
    requestPermissions();
  }

  void addLog(String msg) {
    logs.insert(0, "[${DateTime.now().toIso8601String()}] $msg");
  }

  /// 🔹 Meminta izin Bluetooth + Lokasi + Kamera
  Future<void> requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.camera,
      Permission.storage,
    ].request();

    // Cek apakah lokasi aktif
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Get.snackbar("Lokasi Tidak Aktif", "Aktifkan GPS untuk melanjutkan");
      await Geolocator.openLocationSettings();
      return;
    }

    // Mulai tracking lokasi
    startLocationTracking();

    // Mulai scanning BLE
    scanForDevice();
  }

  /// 🔹 Mulai tracking posisi real-time
  void startLocationTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 2,
    );

    positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position pos) {
      latitude.value = pos.latitude.toStringAsFixed(6);
      longitude.value = pos.longitude.toStringAsFixed(6);
    });
  }

  /// 🔹 Scan dan koneksi ke ESP32
  void scanForDevice() async {
    addLog("Mulai scan BLE...");
    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        final name = r.device.platformName.isNotEmpty
            ? r.device.platformName
            : r.advertisementData.advName;

        if (name == "ESP32_Timbangan") {
          addLog("ESP32 ditemukan! Menghentikan scan...");
          FlutterBluePlus.stopScan();
          scanSubscription?.cancel();
          connectToDevice(r.device);
          break;
        }
      }
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
  }

  /// 🔹 Koneksi ke device
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(license: License.free);
      connectedDevice.value = device;
      addLog("Terkoneksi ke ${device.platformName}");
      await discoverWeightCharacteristic(device);
    } catch (e) {
      addLog("Gagal konek: $e");
    }
  }

  /// 🔹 Cari dan listen characteristic timbangan
  Future<void> discoverWeightCharacteristic(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (var s in services) {
      for (var c in s.characteristics) {
        if (c.uuid.toString().toLowerCase().endsWith("fff1")) {
          weightCharacteristic = c;
          await c.setNotifyValue(true);
          c.lastValueStream.listen((value) {
            if (value.length >= 2) {
              int weight = (value[0] << 8) | value[1];
              weightText.value = "$weight gram";
            }
          });
        }
      }
    }
  }

  /// 🔹 Ambil foto dan simpan ke folder lokal
  Future<void> takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    // Ambil folder lokal penyimpanan
    final Directory appDir = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final String folderPath = path.join(appDir.path, 'tbn_bluetooth');

    // Buat folder jika belum ada
    await Directory(folderPath).create(recursive: true);

    // Buat nama file unik
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String fileName =
        'photo_${timestamp}_(${latitude.value},${longitude.value}).jpg';
    final String savedPath = path.join(folderPath, fileName);

    // Simpan ke folder
    final File savedImage = await File(photo.path).copy(savedPath);

    capturedImage.value = savedImage;
    addLog("Foto disimpan di: $savedPath");
  }

  /// 🔹 Kirim data ke server
  Future<void> sendWeightAndPhoto() async {
    if (capturedImage.value == null) {
      Get.snackbar("Gagal", "Ambil foto terlebih dahulu!");
      return;
    }

    String timestamp = DateTime.now().toIso8601String();
    String url = "https://yourserver.com/upload";

    var request = http.MultipartRequest('POST', Uri.parse(url));
    request.fields['weight'] = weightText.value;
    request.fields['latitude'] = latitude.value;
    request.fields['longitude'] = longitude.value;
    request.fields['timestamp'] = timestamp;
    request.files.add(
      await http.MultipartFile.fromPath(
        'photo',
        capturedImage.value!.path,
        filename: path.basename(capturedImage.value!.path),
      ),
    );

    var response = await request.send();
    if (response.statusCode == 200) {
      Get.snackbar("Sukses", "Data berhasil dikirim!");
    } else {
      Get.snackbar("Gagal", "Gagal mengirim data (${response.statusCode})");
    }
  }

  @override
  void onClose() {
    scanSubscription?.cancel();
    positionStream?.cancel();
    connectedDevice.value?.disconnect();
    super.onClose();
  }
}
