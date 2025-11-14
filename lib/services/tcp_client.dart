import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PythonSocketClient {
  Socket? _socket;
  final _msgCtrl = StreamController<String>.broadcast();
  final _progressCtrl = StreamController<double>.broadcast();
  final _discCtrl = StreamController<void>.broadcast();

  final List<int> _incomingBuffer = [];

  // File receiving state
  bool _receivingFile = false;
  File? _currentFile;
  IOSink? _fileSink;
  int _receivedBytes = 0;
  int _currentFileSize = 0;

  Stream<String> get messages => _msgCtrl.stream;
  Stream<double> get progress => _progressCtrl.stream;
  Stream<void> get onDisconnect => _discCtrl.stream;

  // ------------------ CONNECT ------------------
  Future<bool> connect(String ip, int port) async {
    try {
      _socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 3));

      _socket!.listen(
            (data) async => await _handleIncomingData(data),
        onError: (_) => disconnect(),
        onDone: disconnect,
      );

      print("✅ Connected to $ip:$port");
      return true;
    } catch (e) {
      print("❌ Connection failed: $e");
      return false;
    }
  }

  // ------------------ SEND TEXT ------------------
  void sendMessage(String msg) {
    if (_socket == null) return;
    final bytes = utf8.encode(msg);
    _socket!.add(utf8.encode("TXT"));
    _socket!.add(_int32Bytes(bytes.length));
    _socket!.add(bytes);
    _msgCtrl.add("📱 $msg");
  }

  // ------------------ SEND FILE ------------------
  Future<String> sendFile() async {
    if (_socket == null) return "Not connected.";

    final picked = await FilePicker.platform.pickFiles();
    if (picked == null) return "❌ No file selected";

    final file = File(picked.files.single.path!);
    final name = picked.files.single.name;
    final size = await file.length();

    print("📦 Sending $name (${(size / 1024 / 1024).toStringAsFixed(2)} MB)");
    _msgCtrl.add("📤 Sending $name (${(size / 1024 / 1024).toStringAsFixed(2)} MB)");

    // Send header
    _socket!.add(utf8.encode("FIL"));
    _socket!.add(_int32Bytes(utf8.encode(name).length));
    _socket!.add(utf8.encode(name));
    _socket!.add(_int64Bytes(size));
    await _socket!.flush();

    // Send file chunks
    const chunkSize = 64 * 1024;
    final stream = file.openRead();
    int sent = 0;
    final completer = Completer<String>();

    stream.listen(
          (chunk) async {
        _socket!.add(chunk);
        sent += chunk.length;
        _progressCtrl.add(sent / size);
        await Future.delayed(const Duration(milliseconds: 10));
      },
      onDone: () async {
        await _socket!.flush();
        _progressCtrl.add(1.0);
        _msgCtrl.add("✅ File $name sent successfully");
        print("✅ File $name sent successfully");
        await _saveHistory(name, file.path, size, true);
        completer.complete("✅ File $name sent");
      },
      onError: (e) {
        print("❌ File send error: $e");
        completer.completeError(e);
      },
      cancelOnError: true,
    );

    return completer.future;
  }

  // ------------------ HANDLE INCOMING DATA ------------------
  Future<void> _handleIncomingData(Uint8List data) async {
    _incomingBuffer.addAll(data);

    while (true) {
      if (_receivingFile) {
        await _processFileData();
        if (_receivingFile) return; // Keep processing until complete
      }

      if (_incomingBuffer.length < 3) return;
      final header = utf8.decode(_incomingBuffer.sublist(0, 3));

      if (header == "TXT") {
        if (_incomingBuffer.length < 7) return;
        final lenBytes = _incomingBuffer.sublist(3, 7);
        final msgLen = ByteData.sublistView(Uint8List.fromList(lenBytes))
            .getUint32(0, Endian.big);
        if (_incomingBuffer.length < 7 + msgLen) return;

        final msgBytes = _incomingBuffer.sublist(7, 7 + msgLen);
        final msg = utf8.decode(msgBytes);
        _incomingBuffer.removeRange(0, 7 + msgLen);
        _msgCtrl.add("💻 $msg");
      }

      else if (header == "FIL") {
        if (_incomingBuffer.length < 7) return;
        final nameLenBytes = _incomingBuffer.sublist(3, 7);
        final nameLen = ByteData.sublistView(Uint8List.fromList(nameLenBytes))
            .getUint32(0, Endian.big);

        if (_incomingBuffer.length < 7 + nameLen + 8) return;

        final nameBytes = _incomingBuffer.sublist(7, 7 + nameLen);
        final fileName = utf8.decode(nameBytes);
        final sizeBytes = _incomingBuffer.sublist(7 + nameLen, 7 + nameLen + 8);
        final fileSize = ByteData.sublistView(Uint8List.fromList(sizeBytes))
            .getUint64(0, Endian.big);

        _incomingBuffer.removeRange(0, 7 + nameLen + 8);

        final dir = Directory("/storage/emulated/0/Download/SwiftShare/");
        if (!await dir.exists()) await dir.create(recursive: true);
        final file = File("${dir.path}$fileName");

        _receivingFile = true;
        _currentFile = file;
        _currentFileSize = fileSize;
        _receivedBytes = 0;
        _fileSink = file.openWrite();

        _msgCtrl.add("📦 Receiving $fileName (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)");
        await _processFileData();
      }

      else {
        _incomingBuffer.removeAt(0);
        print("⚠️ Unknown header skipped.");
      }
    }
  }

  // ------------------ PROCESS FILE DATA ------------------
  Future<void> _processFileData() async {
    if (_fileSink == null || !_receivingFile) return;

    while (_incomingBuffer.isNotEmpty) {
      final remaining = _currentFileSize - _receivedBytes;
      final toWrite = _incomingBuffer.length > remaining
          ? remaining
          : _incomingBuffer.length;

      if (toWrite <= 0) break;

      final chunk = _incomingBuffer.sublist(0, toWrite);
      _incomingBuffer.removeRange(0, toWrite);

      _fileSink!.add(chunk);
      _receivedBytes += chunk.length;
      _progressCtrl.add(_receivedBytes / _currentFileSize);

      // ✅ If file is completely received
      if (_receivedBytes >= _currentFileSize) {
        await _fileSink!.flush();
        await _fileSink!.close();

        _progressCtrl.add(1.0);

        final filePath = _currentFile!.path;
        final fileName = _currentFile!.path.split('/').last;

        _msgCtrl.add("✅ File saved to Downloads/SwiftShare/$fileName");
        _msgCtrl.add(jsonEncode({
          "type": "file",
          "name": fileName,
          "path": filePath,
          "size": _currentFileSize,
        }));

        await _saveHistory(fileName, filePath, _currentFileSize, false);

        _receivingFile = false;
        _currentFile = null;
        _fileSink = null;
        _receivedBytes = 0;
        _currentFileSize = 0;

        print("✅ File fully received and closed.");
        return;
      }
    }
  }

  // ------------------ SAVE HISTORY ------------------
  Future<void> _saveHistory(String name, String path, int size, bool sent) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList('history') ?? [];
      final newEntry = jsonEncode({
        "name": name,
        "path": path,
        "size": size,
        "sent": sent,
        "time": DateTime.now().toString()
      });
      existing.add(newEntry);
      await prefs.setStringList('history', existing);
    } catch (e) {
      print("⚠️ Failed to save history: $e");
    }
  }

  // ------------------ DISCONNECT ------------------
  void disconnect() {
    _socket?.destroy();
    _socket = null;
    _discCtrl.add(null);
  }

  // ------------------ HELPERS ------------------
  List<int> _int32Bytes(int v) {
    final b = ByteData(4)..setUint32(0, v, Endian.big);
    return b.buffer.asUint8List();
  }

  List<int> _int64Bytes(int v) {
    final b = ByteData(8)..setUint64(0, v, Endian.big);
    return b.buffer.asUint8List();
  }
}

// ------------------ NETWORK DISCOVERY ------------------
Future<String> getLocalSubnet() async {
  try {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (var iface in interfaces) {
      for (var addr in iface.addresses) {
        final ip = addr.address;
        if (ip.startsWith("127.") ||
            ip.startsWith("169.") ||
            ip.startsWith("192.0.") ||
            ip.startsWith("0.") ||
            ip == "0.0.0.0") continue;

        if (ip.startsWith("192.168.") || ip.startsWith("10.")) {
          final parts = ip.split(".");
          final subnet = "${parts[0]}.${parts[1]}.${parts[2]}";
          print("🌐 Detected valid subnet: $subnet.*");
          return subnet;
        }
      }
    }
    print("⚠️ No valid IP found, fallback to 192.168.137");
    return "192.168.137";
  } catch (e) {
    print("⚠️ Subnet detection failed: $e");
    return "192.168.137";
  }
}

// ------------------ NETWORK SCAN ------------------
Future<List<String>> scanNetwork({required String baseIp, int port = 4040}) async {
  final found = <String>[];
  print("📡 Scanning $baseIp.* ...");
  final completer = Completer<List<String>>();

  for (int i = 1; i < 255; i++) {
    final ip = "$baseIp.$i";
    Socket.connect(ip, port, timeout: const Duration(milliseconds: 300))
        .then((sock) {
      print("🖥️ Found receiver: $ip:$port");
      found.add(ip);
      sock.destroy();
    }).catchError((_) {});
  }

  Timer(const Duration(seconds: 4), () => completer.complete(found));
  return completer.future;
}
