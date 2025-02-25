import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import 'ble_controller.dart';

class DeviceDataPage extends StatefulWidget {
  @override
  _DeviceDataPageState createState() => _DeviceDataPageState();
}

class _DeviceDataPageState extends State<DeviceDataPage> {
  final BleController controller = Get.find<BleController>();
  final TextEditingController inputController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  List<String> terminalLogs = [];
  String? savedFilePath; // Store the saved file path

  @override
  void initState() {
    super.initState();
    controller.setOnDataReceived((String data) {
      setState(() {
        terminalLogs.add("Received: $data");
        scrollToBottom();
      });
    });
  }

  void scrollToBottom() {
    Future.delayed(Duration(milliseconds: 300), () {
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
    });
  }

  Future<void> saveToFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/heart_rate_data.txt');
      String data = terminalLogs.join("\n");
      await file.writeAsString(data);

      setState(() {
        savedFilePath = file.path;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File saved: ${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save file: $e')),
      );
    }
  }

  void openFile() {
    if (savedFilePath != null) {
      OpenFilex.open(savedFilePath!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No file found. Save data first.')),
      );
    }
  }

  void sendCommand() {
    String command = inputController.text.trim();
    if (command.isNotEmpty) {
      controller.sendData(command);
      setState(() {
        terminalLogs.add("Sent: $command");
        inputController.clear();
        scrollToBottom();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Device Data")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: terminalLogs.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    terminalLogs[index],
                    style: TextStyle(fontSize: 16),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: inputController,
                    decoration: InputDecoration(
                      labelText: "Enter command",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: sendCommand,
                  child: Text("Send"),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: saveToFile,
                child: Text("Download File"),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: openFile,
                child: Text("Open File"),
              ),
            ],
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }
}
