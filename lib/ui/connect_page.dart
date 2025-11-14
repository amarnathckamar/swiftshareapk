import 'package:flutter/material.dart';
import '../services/tcp_client.dart';
import 'transfer_page.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final client = PythonSocketClient();
  bool scanning = false;
  List<String> receivers = [];

  Future<void> discoverReceivers() async {
    setState(() => scanning = true);
    final subnet = await getLocalSubnet();
    final found = await scanNetwork(baseIp: subnet, port: 4040);
    setState(() {
      scanning = false;
      receivers = found;
    });
  }

  @override
  void initState() {
    super.initState();
    discoverReceivers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text('SwiftShare',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: discoverReceivers,
          )
        ],
      ),
      body: scanning
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/scan.json', width: 200, repeat: true),
            const SizedBox(height: 10),
            const Text('Scanning for Devices...',
                style: TextStyle(color: Colors.white70)),
          ],
        ),
      )
          : receivers.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.computer, color: Colors.white24, size: 80),
            const SizedBox(height: 20),
            const Text("No devices found",
                style:
                TextStyle(color: Colors.white54, fontSize: 18)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: discoverReceivers,
              icon: const Icon(Icons.refresh),
              label: const Text("Scan Again"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            )
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: receivers.length,
        itemBuilder: (_, i) {
          final ip = receivers[i];
          return Card(
            color: const Color(0xFF2A2A2A),
            margin: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading:
              const Icon(Icons.computer, color: Colors.tealAccent),
              title: Text(
                'Device $i',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(ip,
                  style: const TextStyle(color: Colors.white70)),
              trailing: const Icon(Icons.circle,
                  color: Colors.tealAccent, size: 12),
              onTap: () async {
                showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(
                      child: CircularProgressIndicator(),
                    ));
                final ok = await client.connect(ip, 4040);
                if (mounted) Navigator.pop(context);

                if (ok && mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TransferPage(
                        ip: ip,
                        client: client,
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Connection failed"),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        label: const Text("Connect with QR Code"),
        icon: const Icon(Icons.qr_code),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }
}
