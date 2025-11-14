import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';
import 'package:google_fonts/google_fonts.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList('history') ?? [];

    setState(() {
      history = entries
          .map((e) => jsonDecode(e) as Map<String, dynamic>) // ✅ Explicit cast
          .toList()
          .reversed
          .toList();
    });
  }


  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('history');
    setState(() => history.clear());
  }

  Future<void> _openFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ File not found: $path")),
      );
      return;
    }
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("⚠️ Failed to open file")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text("Transfer History",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _clearHistory,
          )
        ],
      ),
      body: history.isEmpty
          ? const Center(
        child: Text("No history yet.",
            style: TextStyle(color: Colors.white70)),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: history.length,
        itemBuilder: (_, i) {
          final item = history[i];
          final sent = item["sent"] as bool;
          final name = item["name"];
          final sizeMB =
          (item["size"] / 1024 / 1024).toStringAsFixed(2);
          final path = item["path"];
          final date = DateTime.tryParse(item["time"] ?? "");
          final formattedDate = date != null
              ? "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}"
              : "Unknown";

          return Card(
            color: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: Icon(
                sent ? Icons.upload_file : Icons.download,
                color: sent ? Colors.orangeAccent : Colors.tealAccent,
                size: 30,
              ),
              title: Text(name,
                  style:
                  const TextStyle(color: Colors.white, fontSize: 16)),
              subtitle: Text(
                  "$sizeMB MB\nStored at: $path\n$formattedDate",
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 13)),
              isThreeLine: true,
              trailing: TextButton(
                onPressed: () => _openFile(path),
                child: const Text("Open",
                    style: TextStyle(color: Colors.orangeAccent)),
              ),
            ),
          );
        },
      ),
    );
  }
}
