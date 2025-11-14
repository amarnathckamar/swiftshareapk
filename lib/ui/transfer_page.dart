import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:convert';
import '../services/tcp_client.dart';
import 'package:google_fonts/google_fonts.dart';
import 'history_page.dart';
import 'connect_page.dart';
import 'package:open_filex/open_filex.dart';

class TransferPage extends StatefulWidget {
  final String ip;
  final PythonSocketClient client;
  const TransferPage({super.key, required this.ip, required this.client});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final _chat = <String>[];
  final _receivedFiles = <Map<String, dynamic>>[];
  final _msg = TextEditingController();
  bool transferring = false;
  double progress = 0;

  @override
  void initState() {
    super.initState();

    // Listen to incoming messages and file notifications
    widget.client.messages.listen((m) {
      try {
        final decoded = jsonDecode(m);
        if (decoded["type"] == "file") {
          setState(() {
            _receivedFiles.add(decoded);
            _chat.add("📂 Received file: ${decoded["name"]}");
          });
        }
      } catch (_) {
        setState(() => _chat.add(m));
      }
    });

    widget.client.progress.listen((p) {
      setState(() {
        progress = p;
        transferring = p < 1.0;
      });
    });

    // Auto navigate to ConnectPage when disconnected
    widget.client.onDisconnect.listen((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Disconnected")),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ConnectPage()),
              (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          "Connected to ${widget.ip}",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.orangeAccent),
            tooltip: "View Transfer History",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.redAccent),
            tooltip: "Disconnect",
            onPressed: _disconnectAndReturn,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  Lottie.asset('assets/connected.json', width: 120, repeat: false),
                  const SizedBox(height: 10),
                  const Text("Connection Established",
                      style: TextStyle(color: Colors.tealAccent, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            buildOption(Icons.upload, "Send Files",
                "Documents, Photos, Videos & more", sendFile),
            buildOption(Icons.message, "Send Message",
                "Quick text notes or links", sendMessage),
            const SizedBox(height: 20),
            if (transferring) ...[
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              Text("${(progress * 100).toStringAsFixed(1)}%",
                  style: const TextStyle(color: Colors.white70)),
            ],
            const SizedBox(height: 20),
            const Divider(color: Colors.white24),
            const Text("Recent Activity",
                style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 10),
            Expanded(child: _buildChatList()),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    final total = _chat.length + _receivedFiles.length;
    return ListView.builder(
      itemCount: total,
      itemBuilder: (_, i) {
        if (i < _chat.length) {
          return ListTile(
            title: Text(
              _chat[i],
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          );
        }

        final file = _receivedFiles[i - _chat.length];
        final name = file["name"];
        final sizeMB = (file["size"] / 1024 / 1024).toStringAsFixed(2);
        final path = file["path"];

        return Card(
          color: const Color(0xFF1E1E1E),
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading:
            const Icon(Icons.insert_drive_file, color: Colors.tealAccent),
            title: Text(name,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            subtitle: Text("$sizeMB MB\nSaved at: $path",
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            isThreeLine: true,
            trailing: TextButton(
              onPressed: () => _openFile(path),
              child: const Text("Open",
                  style: TextStyle(color: Colors.orangeAccent)),
            ),
          ),
        );
      },
    );
  }

  Widget buildOption(
      IconData icon, String title, String subtitle, Function() onTap) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon, color: Colors.tealAccent, size: 32),
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 18)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        onTap: onTap,
      ),
    );
  }

  Future<void> sendFile() async {
    setState(() {
      transferring = true;
      progress = 0;
    });
    final r = await widget.client.sendFile();
    setState(() {
      _chat.add(r);
      transferring = false;
    });
  }

  void sendMessage() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Send Message",
              style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: _msg,
            decoration: const InputDecoration(
                hintText: "Enter text",
                hintStyle: TextStyle(color: Colors.white38)),
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () {
                widget.client.sendMessage(_msg.text);
                setState(() => _chat.add("📱 ${_msg.text}"));
                _msg.clear();
                Navigator.pop(ctx);
              },
              child:
              const Text("Send", style: TextStyle(color: Colors.tealAccent)),
            ),
          ],
        );
      },
    );
  }

  void _disconnectAndReturn() {
    widget.client.disconnect();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Disconnected")),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ConnectPage()),
          (route) => false,
    );
  }

  void _openFile(String path) async {
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Failed to open file")),
      );
    }
  }
}
