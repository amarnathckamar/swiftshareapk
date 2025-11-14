import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DeviceInfo {
  final String name;
  final String ip;
  final int port;
  DeviceInfo(this.name, this.ip, this.port);
}

class UDPDiscoveryService {
  static const int udpPort = 5050;
  final List<DeviceInfo> discovered = [];
  RawDatagramSocket? socket;

  Future<void> startDiscovery(Function(List<DeviceInfo>) onUpdate) async {
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, udpPort);
    socket!.broadcastEnabled = true;

    socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket!.receive();
        if (datagram == null) return;
        final msg = utf8.decode(datagram.data);

        if (msg.startsWith('FTP_SERVER|')) {
          final parts = msg.split('|');
          if (parts.length >= 4) {
            final name = parts[1];
            final ip = parts[2];
            final port = int.tryParse(parts[3]) ?? 21;

            final exists = discovered.any((d) => d.ip == ip);
            if (!exists) {
              discovered.add(DeviceInfo(name, ip, port));
              onUpdate(List.from(discovered));
            }
          }
        }
      }
    });
  }

  void stop() {
    socket?.close();
    socket = null;
  }
}
