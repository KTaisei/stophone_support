import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart'; 
import 'package:path_provider/path_provider.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SensorRecorder(),
    );
  }
}

class SensorRecorder extends StatefulWidget {
  @override
  _SensorRecorderState createState() => _SensorRecorderState();
}

class _SensorRecorderState extends State<SensorRecorder> {
  List<List<dynamic>> _accelerometerData = [];
  StreamSubscription? _subscription;
  bool _isRecording = false;
  List<String> _savedFiles = []; // 保存されたCSVファイルのリスト

  @override
  void initState() {
    super.initState();
    _requestPermissions(); // 権限をリクエスト
  }

  // 権限のリクエスト
  Future<void> _requestPermissions() async {
    await Permission.storage.request();
  }

  // ストレージのDownloadフォルダのパスを取得
  Future<String> getDownloadDirectory() async {
    final directory = await getExternalStorageDirectory();
    if (directory != null) {
      return directory.path;
    } else {
      throw Exception('ストレージのパスが取得できません');
    }
  }

  // 記録開始
  void _startRecording() {
    setState(() {
      _isRecording = true;
      _accelerometerData = [
        ['Timestamp', 'X', 'Y', 'Z', 'Magnitude'] // ヘッダー行を追加
      ];
    });

    _subscription = accelerometerEvents.listen((AccelerometerEvent event) {
      final timestamp = DateTime.now().toIso8601String();
      final double magnitude =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      final dataRow = [timestamp, event.x, event.y, event.z, magnitude];
      setState(() {
        _accelerometerData.add(dataRow);
      });
    });
  }

  // 記録停止とCSV保存
  void _stopRecording() async {
    _subscription?.cancel();
    setState(() {
      _isRecording = false;
    });

    if (_accelerometerData.isNotEmpty) {
      final csvData = const ListToCsvConverter().convert(_accelerometerData);
      final downloadPath = await getDownloadDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '$downloadPath/accelerometer_data_$timestamp.csv';
      final file = File(filePath);
      await file.writeAsString(csvData);

      setState(() {
        _savedFiles.add(filePath);
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('データを保存しました: $filePath')),
        );
      }
    }
  }

  // ファイル共有
  void _shareFile(String filePath) {
    Share.shareXFiles(
      [XFile(filePath)], 
      text: '加速度データを共有します',
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('加速度データ記録')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: _isRecording
                ? Text(
                    '記録中: ${_accelerometerData.length - 1} 件', // ヘッダー行を除外
                    style: TextStyle(fontSize: 20, color: Colors.green),
                  )
                : Text(
                    '記録停止中',
                    style: TextStyle(fontSize: 20, color: Colors.red),
                  ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isRecording ? null : _startRecording,
            child: Text('記録開始'),
          ),
          ElevatedButton(
            onPressed: _isRecording ? _stopRecording : null,
            child: Text('記録停止'),
          ),
          Divider(),
          Text(
            '保存されたファイル',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _savedFiles.length,
              itemBuilder: (context, index) {
                final filePath = _savedFiles[index];
                return ListTile(
                  title: Text(filePath),
                  trailing: IconButton(
                    icon: Icon(Icons.share),
                    onPressed: () => _shareFile(filePath), // 共有ボタン
                  ),
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('保存場所: $filePath')),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
