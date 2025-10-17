import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';

Timer? btCheckTimer;

void main() {
  runApp(const AppTimbangan());
}

class ImagePreviewPage extends StatelessWidget {
  final Uint8List imageBytes;
  final String title;

  const ImagePreviewPage({
    super.key,
    required this.imageBytes,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(title), backgroundColor: Colors.grey[900]),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5.0, // bisa zoom sampai 5x
          child: Image.memory(imageBytes),
        ),
      ),
    );
  }
}

class AppTimbangan extends StatelessWidget {
  const AppTimbangan({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const TimbanganHome());
  }
}

class TimbanganHome extends StatefulWidget {
  const TimbanganHome({super.key});

  @override
  TimbanganHomeState createState() => TimbanganHomeState();
}

class TimbanganHomeState extends State<TimbanganHome> {
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? weightCharacteristic;
  String weightText = "Belum terkoneksi";
  File? capturedImageLeft;
  File? capturedImageRight;
  Uint8List? capturedImageLeftBytes;
  Uint8List? capturedImageRightBytes;
  StreamSubscription? scanSubscription;
  final ImagePicker _picker = ImagePicker();
  final List<String> logs = [];

  // Variabel untuk fitur Hold / Run
  bool isHold = false;
  double? lastHeldWeight;

  // Scroll controller untuk log
  //final ScrollController _logScrollController = ScrollController();

  // Constants
  static const String serviceUuid = "12345678-1234-5678-1234-56789abcdef0";
  static const String characteristicUuid =
      "0000fff1-0000-1000-8000-00805f9b34fb";
  static const String targetDeviceName = "SCALE_A12E";
  @override
  void initState() {
    super.initState();
    requestPermissions();

    // Start timer untuk cek koneksi BLE setiap 5 detik
    btCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (connectedDevice == null) {
        addLog("🔎 Cek koneksi BLE...");
        scanForDevice(); // otomatis scan jika belum connect
      }
    });
  }

  void addLog(String message) {
    setState(() {
      logs.insert(0, "[${DateTime.now().toIso8601String()}] $message");
    });
  }

  // ✅ 1. Request semua permission BLE
  Future<void> requestPermissions() async {
    addLog("🛠️ Meminta izin Bluetooth & lokasi...");
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();

    await scanForDevice();
  }

  void monitorConnection(BluetoothDevice device) {
    device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.connected) {
        addLog("✅ Tersambung ke GATT Server (${device.platformName})");
        setState(() => connectedDevice = device);
      } else if (state == BluetoothConnectionState.disconnected) {
        addLog("❌ GATT Server terputus (${device.platformName})");
        setState(() => connectedDevice = null);

        // Opsional: coba reconnect otomatis
        Future.delayed(const Duration(seconds: 3), () {
          addLog("🔁 Mencoba reconnect...");
          scanForDevice();
        });
      }
    });
  }

  Future<void> scanForDevice() async {
    addLog("🚀 Mulai scan BLE...");

    // Pastikan Bluetooth aktif
    if (!await FlutterBluePlus.isOn) {
      addLog("⚠️ Bluetooth mati, mencoba menyalakan...");
      await FlutterBluePlus.turnOn();
      return;
    }

    // Pastikan izin sudah diberikan
    if (!await Permission.bluetoothScan.isGranted ||
        !await Permission.bluetoothConnect.isGranted) {
      addLog("❌ Izin Bluetooth belum diberikan.");
      await requestPermissions();
      return;
    }

    // Hentikan scan lama (jika masih berjalan)
    await FlutterBluePlus.stopScan();
    scanSubscription?.cancel();

    // Mulai scan baru
    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        final deviceName = r.device.platformName.isNotEmpty
            ? r.device.platformName
            : r.advertisementData.advName;

        addLog("🔍 Ditemukan: $deviceName (${r.device.remoteId})");

        if (deviceName == targetDeviceName) {
          addLog("✅ $targetDeviceName ditemukan, menghentikan scan...");
          FlutterBluePlus.stopScan();
          scanSubscription?.cancel();
          connectToDevice(r.device);
          break;
        }
      }
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    // FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
  }

  Future<bool> requestBluetoothPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetooth,
      Permission.location,
    ].request();

    return await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted;
  }

  void connectToDevice(BluetoothDevice device) async {
    try {
      var state = await device.connectionState.first;
      if (state == BluetoothConnectionState.connected) {
        addLog(
          "${device.platformName} sudah terkoneksi, tidak perlu connect lagi.",
        );
        setState(() => connectedDevice = device);
        await discoverWeightCharacteristic(device);
        return;
      }

      await device.connect(
        // license: License.free,
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );

      setState(() => connectedDevice = device);
      addLog("Terkoneksi ke ${device.platformName}");

      // Untuk monitor server terputus atau tidak
      monitorConnection(device);

      await discoverWeightCharacteristic(device);
    } catch (e) {
      addLog("Gagal konek: $e");
    }
  }

  // Fungsi untuk membaca karakteristik BLE
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

            if (isHold) {
              // Jika sedang Hold, jangan update tampilan
              addLog("Mode HOLD aktif — data BLE diabaikan");
              return;
            }

            if (value.length == 4) {
              int weightEncoded = (value[0] << 24) |
                  (value[1] << 16) |
                  (value[2] << 8) |
                  (value[3]);

              double weightKg = weightEncoded / 100.0;
              setState(() => weightText = "${weightKg.toStringAsFixed(2)} kg");
              addLog("Weight updated: $weightText");
            } else if (value.length == 2) {
              int weight = (value[0] << 8) | value[1];
              setState(() => weightText = "$weight gram");
              addLog("Weight (2-byte mode): $weightText");
            } else {
              addLog("Format data tidak dikenal (${value.length} byte)");
            }
          });
        }
      }
    }
  }

  Future<Uint8List> addOverlayToBytes({
    required File originalImage,
    required String weight,
    required String timestamp,
    String location = "Lokasi Default",
    int targetWidth = 800, // resize lebar (sesuaikan)
  }) async {
    Uint8List bytes = await originalImage.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) throw Exception("Gagal decode gambar");

    // Resize proporsional
    int newWidth = targetWidth;
    int newHeight = (image.height * newWidth / image.width).toInt();
    img.Image resized = img.copyResize(
      image,
      width: newWidth,
      height: newHeight,
    );

    var font = img.arial_24;
    int whiteColor = img.getColor(255, 255, 255);
    int blackColor = img.getColor(0, 0, 0);

    void drawTextWithBackground(img.Image imgObj, String text, int x, int y) {
      int padding = 4;
      int charWidth = 12;
      int textWidth = text.length * charWidth;
      int textHeight = font.lineHeight;

      img.fillRect(
        imgObj,
        x - padding,
        y - padding,
        x + textWidth + padding,
        y + textHeight + padding,
        blackColor,
      );
      img.drawString(imgObj, font, x, y, text, color: whiteColor);
    }

    drawTextWithBackground(resized, "Berat: $weight", 10, 10);
    drawTextWithBackground(resized, "Time: $timestamp", 10, 40);
    drawTextWithBackground(resized, "Loc: $location", 10, 70);

    // Encode JPG dengan kualitas 80% untuk menurunkan ukuran
    Uint8List jpgBytes = Uint8List.fromList(
      img.encodeJpg(resized, quality: 80),
    );
    return jpgBytes;
  }

  Future<File> saveOverlayToGallery(Uint8List bytes) async {
    // Minta permission storage (untuk Android < 13 atau legacy)
    if (await Permission.storage.request().isGranted ||
        await Permission.photos.request().isGranted) {
      // Dapatkan folder Pictures
      Directory? picturesDir = Directory(
        "/storage/emulated/0/Pictures/TimbanganApp",
      );
      if (!await picturesDir.exists()) {
        await picturesDir.create(recursive: true);
      }

      String fileName =
          "photo_${DateTime.now().millisecondsSinceEpoch}_overlay.jpg";
      File file = File("${picturesDir.path}/$fileName");
      await file.writeAsBytes(bytes);

      return file;
    } else {
      throw Exception("Storage permission denied");
    }
  }

  Future<bool> requestStoragePermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    return status.isGranted;
  }

  Future<void> takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    File original = File(photo.path);
    String timestamp = DateTime.now().toIso8601String();

    // Tambahkan overlay ke bytes
    Uint8List overlayBytes = await addOverlayToBytes(
      originalImage: original,
      weight: weightText,
      timestamp: timestamp,
    );

    setState(() {
      // Tampilkan overlay di kotak foto
      if (capturedImageLeftBytes == null) {
        capturedImageLeftBytes = overlayBytes;
        addLog("📸 Foto 1 (preview) dibuat dengan overlay");
      } else if (capturedImageRightBytes == null) {
        capturedImageRightBytes = overlayBytes;
        addLog("📸 Foto 2 (preview) dibuat dengan overlay");
      } else {
        // Jika kedua foto sudah ada, ganti foto kiri dulu
        capturedImageLeftBytes = overlayBytes;
        capturedImageRightBytes = null;
        addLog("📸 Foto lama diganti, mulai dari Foto 1 lagi (preview)");
      }
    });

    // Kalau mau simpan ke gallery nanti, pakai saveOverlayToGallery(overlayBytes)
  }

  Future<void> sendWeightAndPhoto() async {
    if (capturedImageLeftBytes == null && capturedImageRightBytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("📸 Ambil minimal satu foto terlebih dahulu!"),
        ),
      );
      return;
    }

    String timestamp = DateTime.now().toIso8601String();
    String url = "https://yourserver.com/upload";

    addLog("Menyiapkan pengiriman data ke server...");
    var request = http.MultipartRequest('POST', Uri.parse(url));
    request.fields['weight'] = weightText;
    request.fields['timestamp'] = timestamp;

    // Tambahkan foto kiri
    if (capturedImageLeftBytes != null) {
      addLog("Menambahkan Foto 1 (kiri)");
      request.files.add(
        http.MultipartFile.fromBytes(
          'photo_left',
          capturedImageLeftBytes!,
          filename: "photo_left_${DateTime.now().millisecondsSinceEpoch}.jpg",
        ),
      );
    }

    // Tambahkan foto kanan
    if (capturedImageRightBytes != null) {
      addLog("Menambahkan Foto 2 (kanan)");
      request.files.add(
        http.MultipartFile.fromBytes(
          'photo_right',
          capturedImageRightBytes!,
          filename: "photo_right_${DateTime.now().millisecondsSinceEpoch}.jpg",
        ),
      );
    }

    addLog("⏳ Mengirim data ke server...");

    // Tampilkan dialog loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.lightBlueAccent),
      ),
    );

    try {
      var response = await request.send();

      // Setelah menunggu async, cek lagi apakah widget masih aktif
      if (!mounted) return;
      Navigator.of(context).pop(); // tutup loading dialog

      if (response.statusCode == 200) {
        addLog("✅ Data berhasil dikirim ke server ($url)");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Berat & foto berhasil dikirim!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        addLog("❌ Gagal mengirim data: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal mengirim data: ${response.statusCode}"),
            backgroundColor: const Color.fromARGB(255, 7, 30, 119),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Tutup dialog dan tampilkan error jika masih aktif
      if (!mounted) return;
      Navigator.of(context).pop();
      addLog("⚠️ Error saat mengirim data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: const Color.fromARGB(255, 7, 30, 119),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Demo Timbangan BLE'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white, // wajib supaya teks/ikon jelas
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
                      color: Colors.white,
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
                          child: const Text("🔍 Temukan Timbangan"),
                        )
                      : Text(
                          "Terkoneksi: ${connectedDevice!.platformName}",
                          style: const TextStyle(color: Colors.greenAccent),
                        ),
                  const SizedBox(height: 20),

                  // ======================
                  // DUA KOTAK FOTO BERJARJAR
                  // ======================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Foto 1
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (capturedImageLeftBytes != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ImagePreviewPage(
                                    imageBytes: capturedImageLeftBytes!,
                                    title: "Foto 1",
                                  ),
                                ),
                              );
                            }
                          },
                          child: Container(
                            height: 160,
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey[850],
                              border: Border.all(color: Colors.grey[700]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: capturedImageLeftBytes != null
                                ? Image.memory(
                                    capturedImageLeftBytes!,
                                    fit: BoxFit.contain,
                                  )
                                : const Center(
                                    child: Text(
                                      "📷 Foto 1",
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      // Foto 2
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (capturedImageRightBytes != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ImagePreviewPage(
                                    imageBytes: capturedImageRightBytes!,
                                    title: "Foto 2",
                                  ),
                                ),
                              );
                            }
                          },
                          child: Container(
                            height: 160,
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey[850],
                              border: Border.all(color: Colors.grey[700]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: capturedImageRightBytes != null
                                ? Image.memory(
                                    capturedImageRightBytes!,
                                    fit: BoxFit.contain,
                                  )
                                : const Center(
                                    child: Text(
                                      "📷 Foto 2",
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ======= BARIS TOMBOL =======
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Tombol HOLD / RUN
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isHold ? Colors.redAccent : Colors.grey[800],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 16.0,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                isHold = !isHold;
                                if (isHold) {
                                  lastHeldWeight = double.tryParse(
                                    weightText
                                        .replaceAll(" kg", "")
                                        .replaceAll(",", "."),
                                  );
                                  addLog(
                                    "Hold aktif: berat dikunci di $weightText",
                                  );
                                } else {
                                  addLog(
                                    "Run aktif: pembacaan berat real-time dilanjutkan",
                                  );
                                }
                              });
                            },
                            child: Text(isHold ? "⏸️ HOLD" : "▶️ RUN"),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Tombol Ambil Foto
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[800],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 16.0,
                              ),
                            ),
                            onPressed: takePhoto,
                            child: const Text("📸 Foto"),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Tombol Kirim Berat & Foto
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[800],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 16.0,
                              ),
                            ),
                            onPressed: sendWeightAndPhoto,
                            child: const Text("📤 Kirim"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ======= TERMINAL LOG =======
          SizedBox(
            height: 150,
            child: Container(
              color: Colors.grey[900],
              padding: const EdgeInsets.all(4.0),
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
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
