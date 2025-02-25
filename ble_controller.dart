import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

class BleController extends GetxController {
  final RxList<ScanResult> scanResults = <ScanResult>[].obs;
  final RxBool isConnected = false.obs;
  final RxBool isScanning = false.obs;
  BluetoothDevice? connectedDevice;
  Function(String)? onDataReceived;

  /// Ensures Bluetooth is ON before scanning
  void initializeBluetooth() async {
    if (!await FlutterBluePlus.isOn) {
      await FlutterBluePlus.turnOn();
    }
  }

  /// Scans for BLE devices
  void scanDevices() async {
    if (isScanning.value) return; // Prevent multiple scans

    scanResults.clear(); // Clear previous results
    isScanning.value = true;

    try {
      await FlutterBluePlus.stopScan(); // Stop any previous scan

      FlutterBluePlus.scanResults.listen((results) {
        scanResults.assignAll(results);
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

      await Future.delayed(const Duration(seconds: 5));
    } catch (e) {
      print("Scan Error: $e");
    } finally {
      isScanning.value = false;
    }
  }

  /// Connects to a BLE device and sets up notifications
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      connectedDevice = device;
      isConnected.value = true;

      try {
        int mtu = await device.requestMtu(244);
        print("MTU set to: $mtu");
      } catch (e) {
        print("Failed to set MTU: $e");
      }

      await Future.delayed(const Duration(milliseconds: 500));
      _setupNotifications(device);
    } catch (e) {
      print("Connection Error: $e");
    }
  }

  /// Sets up notifications for receiving data from the device
  void _setupNotifications(BluetoothDevice device) async {
    try {
      var services = await device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            characteristic.value.listen((value) {
              _handleIncomingData(value);
            }, onError: (error) {
              print("BLE Data Error: $error");
            });
          }
        }
      }
    } catch (e) {
      print("Notification Setup Error: $e");
    }
  }

  /// Handles incoming BLE data
  void _handleIncomingData(List<int> value) {
    String newData = utf8.decode(value);
    if (onDataReceived != null) {
      onDataReceived!(newData);
    }
  }

  /// Sends data to the connected BLE device
  Future<void> sendData(String data) async {
    if (connectedDevice != null) {
      try {
        var services = await connectedDevice!.discoverServices();
        for (var service in services) {
          for (var characteristic in service.characteristics) {
            if (characteristic.properties.write) {
              await characteristic.write(utf8.encode(data + "\n"));
            }
          }
        }
      } catch (e) {
        print("Data Send Error: $e");
      }
    }
  }

  /// Sets a callback for handling received data
  void setOnDataReceived(Function(String) callback) {
    onDataReceived = callback;
  }

  /// Disconnects from the BLE device safely
  Future<void> disconnectDevice() async {
    try {
      await connectedDevice?.disconnect();
    } catch (e) {
      print("Disconnection Error: $e");
    } finally {
      connectedDevice = null;
      isConnected.value = false;
    }
  }
}
