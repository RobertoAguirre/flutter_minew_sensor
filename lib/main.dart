import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:minew_beacon_plus_flutter/minew_beacon_plus_flutter.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: BeaconScannerPage(),
    );
  }
}

class BeaconScannerPage extends StatefulWidget {
  const BeaconScannerPage({super.key});

  @override
  State<BeaconScannerPage> createState() => _BeaconScannerPageState();
}

class _BeaconScannerPageState extends State<BeaconScannerPage> {
  final _minewBeaconPlugin = MinewBeaconPlus();
  final _eventChannel = const EventChannel('minew_beacon_devices_scan');
  StreamSubscription? _subscription;
  String _debugInfo = '';
  bool _isScanning = false;
  String _temperature = 'N/A';

  @override
  void initState() {
    super.initState();
    _setupBeaconPlugin();
  }

  void _setupBeaconPlugin() async {
    await _subscription?.cancel();
    _subscription = null;

    // Solicitar permisos
    if (Platform.isAndroid) {
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();
      await Permission.location.request();
    } else if (Platform.isIOS) {
      await Permission.bluetooth.request();
      await Permission.location.request();
    }
  }

  void _addDebugLog(String msg) {
    setState(() {
      _debugInfo = '${DateTime.now()}: $msg\n$_debugInfo';
    });
    print(msg);
  }

  void _startListening() {
    try {
      _subscription = _eventChannel.receiveBroadcastStream().listen(
        (data) {
          _addDebugLog('Datos recibidos: $data');
          _processBeaconData(data);
        },
        onError: (error) {
          _addDebugLog('Error en stream: $error');
        },
      );
    } catch (e) {
      _addDebugLog('Error al iniciar escucha: $e');
    }
  }

  void _processBeaconData(dynamic data) {
    if (data is! List) return;

    for (var device in data) {
      if (device is! Map) continue;

      final name = device['name'] as String?;
      if (name == 'P1') {
        final frames = device['advFrames'] as List?;
        if (frames == null) continue;

        // Buscar el frame de temperatura y extraer su valor
        for (var frame in frames) {
          _addDebugLog('Analizando frame: $frame');
          if (frame is Map && frame['type'] == 'FrameTempSensor') {
            // Intentamos obtener la temperatura de diferentes maneras
            final temp = frame['temp'] ?? frame['temperature'] ?? frame['value'];
            if (temp != null) {
              setState(() {
                _temperature = temp.toString();
                _addDebugLog('Nueva temperatura: $_temperature');
              });
            }
          }
        }
      }
    }
  }

  Future<void> _toggleScan() async {
    try {
      if (!_isScanning) {
        // Verificar permisos antes de escanear
        bool canProceed = true;
        
        if (!await Permission.bluetoothScan.isGranted) {
          _addDebugLog('Permiso de escaneo Bluetooth no concedido');
          canProceed = false;
        }
        
        if (!await Permission.location.isGranted) {
          _addDebugLog('Permiso de ubicación no concedido');
          canProceed = false;
        }

        if (!canProceed) {
          _addDebugLog('No se pueden obtener los permisos necesarios');
          return;
        }

        final started = await _minewBeaconPlugin.startScan();
        _addDebugLog('Escaneo iniciado: $started');
        if (started == true) {
          _startListening();
          setState(() => _isScanning = true);
        }
      } else {
        await _minewBeaconPlugin.stopScan();
        await _subscription?.cancel();
        setState(() => _isScanning = false);
      }
    } catch (e) {
      _addDebugLog('Error en toggle scan: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _minewBeaconPlugin.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minew Scanner'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Temperatura', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    Text(
                      '$_temperature°C',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _toggleScan,
              child: Text(_isScanning ? 'Detener Escaneo' : 'Iniciar Escaneo'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_debugInfo),
              ),
            ),
          ],
        ),
      ),
    );
  }
}