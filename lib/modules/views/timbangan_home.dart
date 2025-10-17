import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timbangan_bt/main.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class TimbanganHomeState extends State<TimbanganHome> {
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? weightCharacteristic;
  String weightText = "Belum terkoneksi ,";
  File? capturedImage;
  StreamSubscription? scanSubscription;
  final ImagePicker _picker = ImagePicker();
  final List<String> logs = [];

  // Scroll controller untuk log
  final ScrollController _logScrollController = ScrollController();

  // Constants
  static const String serviceUuid = "12345678-1234-5678-1234-56789abcdef0";
  static const String characteristicUuid =
      "0000fff1-0000-1000-8000-00805f9b34fb";

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  void addLog(String message) {
    setState(() {
      logs.insert(0, "[${DateTime.now().toIso8601String()}] $message");
    });
  }

  Widget logWindow() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black87,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: ListView.builder(
        controller: _logScrollController,
        reverse: true, // log terbaru tetap di atas
        itemCount: logs.length,
        itemBuilder: (context, index) {
          return Text(
            logs[index],
            style: const TextStyle(color: Colors.white, fontSize: 12),
          );
        },
      ),
    );
  }

  Future<void> requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.camera,
    ].request();

    scanForDevice();
  }

  void scanForDevice() async {
    addLog("Mulai scan BLE...");

    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      addLog("Ditemukan ${results.length} device.");
      for (ScanResult r in results) {
        final deviceName = r.device.platformName.isNotEmpty
            ? r.device.platformName
            : r.advertisementData.advName;
        addLog("Device: name=$deviceName, id=${r.device.remoteId}");
        if (deviceName == "ESP32_Timbangan") {
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

  void connectToDevice(BluetoothDevice device) async {
    try {
      // Cek status koneksi saat ini
      var state = await device.connectionState.first;
      if (state == BluetoothConnectionState.connected) {
        addLog(
          "${device.platformName} sudah terkoneksi, tidak perlu connect lagi.",
        );
        setState(() => connectedDevice = device);
        // Lanjutkan subscribe ke characteristic jika perlu
        await discoverWeightCharacteristic(device);
        return;
      }

      // Jika belum terkoneksi, lakukan connect
      await device.connect(timeout: const Duration(seconds: 10));
      setState(() => connectedDevice = device);
      addLog("Terkoneksi ke ${device.platformName}");

      await discoverWeightCharacteristic(device);
    } catch (e) {
      addLog("Gagal konek: $e");
    }
  }

  // Fungsi tambahan untuk discover characteristic dan listen weight
  Future<void> discoverWeightCharacteristic(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService s in services) {
      addLog("Service UUID: ${s.uuid}");
      for (BluetoothCharacteristic c in s.characteristics) {
        addLog("Characteristic UUID: ${c.uuid}, properties: ${c.properties}");
        if (c.uuid.toString().toLowerCase().endsWith("fff1")) {
          weightCharacteristic = c;
          await c.setNotifyValue(true);
          c.lastValueStream.listen((value) {
            addLog("Data diterima: $value");
            if (value.length >= 2) {
              int weight = (value[0] << 8) | value[1];
              setState(() => weightText = "$weight gram");
              addLog("Weight updated: $weightText");
            }
          });
        }
      }
    }
  }

  Future<void> takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        capturedImage = File(photo.path);
      });
      addLog("Foto diambil: ${photo.path}");
    }
  }

  Future<void> sendWeightAndPhoto() async {
    if (capturedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ambil foto terlebih dahulu!")),
      );
      return;
    }

    String timestamp = DateTime.now().toIso8601String();
    String url = "https://yourserver.com/upload";

    var request = http.MultipartRequest('POST', Uri.parse(url));
    request.fields['weight'] = weightText;
    request.fields['timestamp'] = timestamp;
    request.files.add(
      await http.MultipartFile.fromPath(
        'photo',
        capturedImage!.path,
        filename: path.basename(capturedImage!.path),
      ),
    );

    try {
      var response = await request.send();
      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Berhasil mengirim data!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal mengirim data: ${response.statusCode}"),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    connectedDevice?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // seluruh layar gelap
      appBar: AppBar(
        title: const Text('Timbangan BLE'),
        backgroundColor: Colors.grey[900],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weightText,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // teks utama
                    ),
                  ),
                  const SizedBox(height: 20),
                  connectedDevice == null
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                            foregroundColor: Colors.white,
                          ),
                          onPressed: scanForDevice,
                          child: const Text("Scan ESP32"),
                        )
                      : Text(
                          "Terkoneksi: ${connectedDevice!.platformName}",
                          style: const TextStyle(color: Colors.greenAccent),
                        ),
                  const SizedBox(height: 20),
                  capturedImage != null
                      ? Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[700]!),
                          ),
                          child: Image.file(
                            capturedImage!,
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const SizedBox.shrink(),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                    ),
                    onPressed: takePhoto,
                    child: const Text("Ambil Foto"),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                    ),
                    onPressed: sendWeightAndPhoto,
                    child: const Text("Kirim Berat & Foto"),
                  ),
                ],
              ),
            ),
          ),
          // Terminal log
          // Terminal log sederhana
          // Terminal log sederhana, log terbaru di atas
          SizedBox(
            height: 150,
            child: Container(
              color: Colors.grey[900],
              padding: const EdgeInsets.all(4.0),
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log =
                      logs[index]; // ambil dari index 0, log terbaru di atas
                  return Text(
                    log,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Courier',
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
