import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';

void main() => runApp(const TestPrintApp());

class TestPrintApp extends StatelessWidget {
  const TestPrintApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Zebra QLn420 Bluetooth Print'),
          backgroundColor: Colors.blueGrey,
        ),
        body: const BluetoothPrintDashboard(),
      ),
    );
  }
}

class BluetoothPrintDashboard extends StatefulWidget {
  const BluetoothPrintDashboard({Key? key}) : super(key: key);

  @override
  State<BluetoothPrintDashboard> createState() => _BluetoothPrintDashboardState();
}

class _BluetoothPrintDashboardState extends State<BluetoothPrintDashboard> {
  final _bluetoothPlugin = FlutterBlueClassic();
  String _status = "Pair printer in Android settings first";
  bool _isLoading = false;

  Future<void> _sendBluetoothPrintJob() async {
    setState(() {
      _isLoading = true;
      _status = "Scanning paired hardware list...";
    });

    const String zplPayload = 
        "^XA"
        "^FO50,50^GB730,200,6^FS" 
        "^FO100,90^A0N,45,45^FDZEBRA BLUETOOTH OK^FS"
        "^FO100,150^A0N,30,30^FDDirect Tablet Sideload^FS"
        "^XZ";

    try {
      // 1. Fetch bonded/paired devices natively (added empty fallback array if null)
      List<BluetoothDevice> bondedDevices = await _bluetoothPlugin.bondedDevices ?? [];
      BluetoothDevice? zebraPrinter;

      for (var device in bondedDevices) {
        if (device.name != null && device.name!.contains('QLn420')) {
          zebraPrinter = device;
          break;
        }
      }

      if (zebraPrinter == null) {
        setState(() => _status = "Error: QLn420 not found in paired devices list.\nPlease pair it in Android Bluetooth Settings.");
        return;
      }

      setState(() => _status = "Opening RFCOMM Serial Channel...");
      
      // 2. Open a nullable BluetoothConnection context safely
      BluetoothConnection? connection = await _bluetoothPlugin.connect(zebraPrinter.address);
      
      if (connection != null && connection.isConnected) {
        setState(() => _status = "Streaming raw ZPL payload over airwaves...");
        
        // 3. Removed 'await' since writeString returns void synchronously
        connection.writeString(zplPayload);
        
        // 4. Gracefully close out active pipeline streams
        await connection.finish();
        setState(() => _status = "Success! Label data fired over Bluetooth.");
      } else {
        setState(() => _status = "Error: Connection failed or channel is dead.");
      }
    } catch (e) {
      setState(() => _status = "Bluetooth Error: $e\n\nEnsure Bluetooth/Location permissions are granted on tablet.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_audio_rounded, size: 100, color: Colors.blueGrey),
            const SizedBox(height: 30),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isLoading ? null : _sendBluetoothPrintJob,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Fire ZPL via Bluetooth', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

/*import 'dart:io';
import 'package:flutter/material.dart';

void main() => runApp(const TestPrintApp());

class TestPrintApp extends StatelessWidget {
  const TestPrintApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Zebra QLn420 Test Print'),
          backgroundColor: Colors.blueGrey,
        ),
        body: const PrintDashboard(),
      ),
    );
  }
}

class PrintDashboard extends StatefulWidget {
  const PrintDashboard({Key? key}) : super(key: key);

  @override
  State<PrintDashboard> createState() => _PrintDashboardState();
}

class _PrintDashboardState extends State<PrintDashboard> {
  String _status = "Ready to print";
  bool _isLoading = false;

  Future<void> _sendPrintJob() async {
    setState(() {
      _isLoading = true;
      _status = "Connecting to Mac loopback (10.0.2.2:9100)...";
    });

    // 10.0.2.2 is the unique internal IP address the Android Emulator uses 
    // to step out of its virtual bubble and talk directly to your Mac's localhost.
    const String hostIp = '192.168.1.20';
    const int port = 9100;

    // Custom 203 DPI ZPL script: draws a border box and prints clear test titles
    const String zplPayload = 
        "^XA"
        "^FO50,50^GB730,200,6^FS" 
        "^FO100,90^A0N,45,45^FDZEBRA QLn420 SUCCESS^FS"
        "^FO100,150^A0N,30,30^FDPrinted via Flutter Emulator^FS"
        "^XZ";

    try {
      // Open a raw network streaming socket directly to the Mac port
      final socket = await Socket.connect(hostIp, port, timeout: const Duration(seconds: 5));
      
      setState(() => _status = "Streaming raw ZPL lines...");
      socket.write(zplPayload);
      
      // Clear buffers and close connection safely
      await socket.flush();
      await socket.close();
      
      setState(() => _status = "Success! Data pushed down the USB line.");
    } catch (e) {
      setState(() => _status = "Error: Connection to Mac loopback failed.\nEnsure your Terminal loop is running.\n\nDetails: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.print_rounded, size: 100, color: Colors.blueGrey),
            const SizedBox(height: 30),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isLoading ? null : _sendPrintJob,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Fire ZPL Command', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
          ),
        ),
    );
  }
}*/