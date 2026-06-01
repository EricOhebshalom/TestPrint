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
          title: const Text('Zebra Dynamic Print Client'),
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
  List<BluetoothDevice> _pairedDevices = [];
  BluetoothDevice? _selectedDevice;
  String _status = "Initializing Bluetooth backend...";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPairedDevices();
  }

  // Fetch all bonded hardware from the Android OS registry
  Future<void> _loadPairedDevices() async {
    try {
      List<BluetoothDevice> devices = await _bluetoothPlugin.bondedDevices ?? [];
      BluetoothDevice? smartDefault;

      for (var device in devices) {
        String name = (device.name ?? "").toLowerCase();
        // Smart Filter: Auto-detect Zebra naming conventions or serial formats
        if (name.contains('qln') || name.contains('zebra') || name.startsWith('xx')) {
          smartDefault = device;
        }
      }

      setState(() {
        _pairedDevices = devices;
        _selectedDevice = smartDefault ?? (devices.isNotEmpty ? devices.first : null);
        _status = devices.isEmpty 
            ? "No paired devices found. Pair your printer in Android Settings."
            : "Ready to print.";
      });
    } catch (e) {
      setState(() => _status = "Initialization Error: $e");
    }
  }

  Future<void> _sendBluetoothPrintJob() async {
    if (_selectedDevice == null) {
      setState(() => _status = "Error: No target device selected.");
      return;
    }

    setState(() {
      _isLoading = true;
      _status = "Connecting to ${_selectedDevice!.name ?? 'Printer'}...";
    });

    const String zplPayload = 
        "^XA"
        "^FO50,50^GB730,200,6^FS" 
        "^FO100,90^A0N,45,45^FDZEBRA DYNAMIC OK^FS"
        "^FO100,150^A0N,30,30^FDFiltered Device Selector^FS"
        "^XZ";

    try {
      // Open connection directly to whatever device is chosen in the UI dropdown
      BluetoothConnection? connection = await _bluetoothPlugin.connect(_selectedDevice!.address);
      
      if (connection != null && connection.isConnected) {
        setState(() => _status = "Streaming raw ZPL payload over airwaves...");
        
        connection.writeString(zplPayload);
        await connection.finish();
        
        setState(() => _status = "Success! Label fired to ${_selectedDevice!.name}.");
      } else {
        setState(() => _status = "Error: Connection handshake failed.");
      }
    } catch (e) {
      setState(() => _status = "Bluetooth Error: $e");
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
            const Icon(Icons.print_rounded, size: 80, color: Colors.blueGrey),
            const SizedBox(height: 20),
            
            // Dropdown Selector Label
            const Text(
              "Target Bluetooth Device:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            // Interactive Dropdown Menu Layout
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueGrey, width: 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<BluetoothDevice>(
                  value: _selectedDevice,
                  isExpanded: true,
                  hint: const Text("Select Printer"),
                  items: _pairedDevices.map((device) {
                    return DropdownMenuItem<BluetoothDevice>(
                      value: device,
                      child: Text("${device.name ?? 'Unknown'} (${device.address})"),
                    );
                  }).toList(),
                  onChanged: _isLoading ? null : (device) {
                    setState(() => _selectedDevice = device);
                  },
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Status Monitor Console
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
            const SizedBox(height: 30),

            // Execution Trigger Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loadPairedDevices,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Refresh List"),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading || _selectedDevice == null ? null : _sendBluetoothPrintJob,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Print Label', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ),
              ],
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