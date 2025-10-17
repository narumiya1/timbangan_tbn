import 'package:get/get.dart';
import 'dart:io';

class ReceiveDataController extends GetxController {
  var isConnected = true.obs; // dummy koneksi bluetooth
  var weight = 0.0.obs;
  var id = ''.obs;
  var photoPath = RxnString();

  void receiveData() {
    // Dummy data dari timbangan
    weight.value = 200.0;
    id.value = "123456789";
  }

  void takePhoto() {
    // Dummy path foto
    photoPath.value = "assets/dummy_image.jpg";
  }

  void sendDataAndImage() {
    Get.snackbar("Kirim Data", "Data & gambar berhasil dikirim!");
  }
}
