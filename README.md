# file_transfer

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.



SwiftShare Android App - Documentation

SwiftShare Android is a fast LAN-based file sharing and messaging application built using Flutter. 
It connects with SwiftShare Desktop (Windows) using TCP and UDP for high-speed offline transfers.

----------------------------------------------------
Features
----------------------------------------------------
• Auto device discovery using UDP.
• Connect and send files to PC over TCP.
• Real-time file transfer progress.
• Receive files from PC and open with third‑party apps.
• Messages can be sent and received instantly.
• Local file history with full path display.
• Clean modern UI with Lottie animations.
• Works on Wi-Fi or mobile hotspot.

----------------------------------------------------
Technology Stack
----------------------------------------------------
• Flutter 3.0+
• Dart
• TCP Sockets (file/message transfer)
• UDP (device discovery)
• Lottie, Google Fonts
• File Picker, Path Provider
• Shared Preferences

----------------------------------------------------
Project Structure
----------------------------------------------------
lib/
 ├── services/
 │    ├── tcp_client.dart
 │    ├── udp_discovery.dart
 │
 ├── ui/
 │    ├── connect_page.dart
 │    ├── transfer_page.dart
 │    ├── history_page.dart
 │
 ├── main.dart

----------------------------------------------------
APK Build Instructions
----------------------------------------------------
1. Install Flutter SDK.
2. Run:
   flutter pub get
3. Build APK:
   flutter build apk --release
4. Install:
   flutter install

APK Location:
build/app/outputs/flutter-apk/app-release.apk

----------------------------------------------------
Connection Requirements
----------------------------------------------------
• Android and PC must be on the same Wi-Fi network or hotspot.
• PC server must be running SwiftShare Desktop on port 4040.
• UDP port 5050 must be open.
• Firewall must allow local network communication.

----------------------------------------------------
Usage Workflow
----------------------------------------------------
1. Run SwiftShare Desktop on PC → Click "Start Server".
2. Open the Android App → Device auto-discovers the server.
3. Tap on the PC name to connect.
4. Use "Send File" or "Send Message" options.
5. Receive files with full progress tracking.

----------------------------------------------------
Tested On
----------------------------------------------------
• Android 8 to Android 14
• Wi-Fi hotspot and router
• Large file transfers (1GB – 3GB)
• Multi-device connectivity

----------------------------------------------------
Roadmap
----------------------------------------------------
• Add QR code connection
• iOS support
• Encrypted transfers
• Folder transfer
• macOS / Linux desktop support

----------------------------------------------------
Developer
----------------------------------------------------
Created by: Amarnath CK

Note:The application is not fully developed its is a prototype
