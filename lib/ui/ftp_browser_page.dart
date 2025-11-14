import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:path_provider/path_provider.dart';

class FTPBrowserPage extends StatefulWidget {
  final String ip;
  const FTPBrowserPage({super.key, required this.ip});

  @override
  State<FTPBrowserPage> createState() => _FTPBrowserPageState();
}

class _FTPBrowserPageState extends State<FTPBrowserPage> {
  late FTPConnect ftp;
  bool connected = false;
  bool downloading = false;
  bool connecting = false;
  List<FTPEntry> files = [];
  String? downloadedPath;
  String currentDir = "/";

  // New: input controllers
  final userController = TextEditingController(text: "user");
  final passController = TextEditingController(text: "12345");

  /// Connect to FTP server
  Future<void> connectAndList() async {
    setState(() {
      connecting = true;
    });

    try {
      ftp = FTPConnect(
        widget.ip,
        user: userController.text.trim(),
        pass: passController.text.trim(),
        timeout: 10, // seconds (int, not Duration)
      );


      await ftp.connect();
      final list = await ftp.listDirectoryContent();

      setState(() {
        connected = true;
        files = list;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Connection failed: $e")),
      );
    } finally {
      setState(() {
        connecting = false;
      });
    }
  }

  /// Download a file
  Future<void> downloadFile(String name) async {
    setState(() => downloading = true);
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/$name");
    await ftp.downloadFile(name, file);
    setState(() {
      downloading = false;
      downloadedPath = file.path;
    });
  }

  /// Detect if entry is a directory (fixes older ftpconnect versions)
  bool isDirectory(FTPEntry entry) {
    final t = entry.type.toString().toLowerCase();
    if (t.contains('dir') || t.contains('folder') || t.contains('directory')) {
      return true;
    }
    if (entry.name.endsWith('/')) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          connected ? 'FTP: ${widget.ip}' : 'Connect to FTP Server',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: connected ? buildFileList() : buildLoginForm(),
    );
  }

  /// FTP Login UI
  Widget buildLoginForm() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_outlined, color: Colors.tealAccent, size: 80),
          const SizedBox(height: 20),
          TextField(
            controller: userController,
            decoration: const InputDecoration(
              labelText: "Username",
              labelStyle: TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Color(0xFF1E1E1E),
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: passController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: "Password",
              labelStyle: TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Color(0xFF1E1E1E),
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 20),
          connecting
              ? const CircularProgressIndicator()
              : ElevatedButton.icon(
            onPressed: connectAndList,
            icon: const Icon(Icons.login),
            label: const Text("Connect"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
              padding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// FTP File Browser UI
  Widget buildFileList() {
    return Column(
      children: [
        if (downloading)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              final list = await ftp.listDirectoryContent();
              setState(() => files = list);
            },
            child: ListView.builder(
              itemCount: files.length,
              itemBuilder: (_, i) {
                final f = files[i];
                final dir = isDirectory(f);

                return Card(
                  color: const Color(0xFF1E1E1E),
                  margin:
                  const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: ListTile(
                    leading: Icon(
                      dir ? Icons.folder : Icons.insert_drive_file,
                      color: dir ? Colors.amber : Colors.tealAccent,
                    ),
                    title: Text(
                      f.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: dir
                        ? () async {
                      try {
                        await ftp.changeDirectory(f.name);
                        final list =
                        await ftp.listDirectoryContent();
                        setState(() {
                          files = list;
                          currentDir = f.name;
                        });
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                              Text('Failed to open folder: $e')),
                        );
                      }
                    }
                        : () => downloadFile(f.name),
                  ),
                );
              },
            ),
          ),
        ),
        if (downloadedPath != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "✅ Saved to: $downloadedPath",
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
