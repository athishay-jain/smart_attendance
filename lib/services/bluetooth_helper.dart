import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothHelper {
  static final BluetoothHelper _instance = BluetoothHelper._internal();
  factory BluetoothHelper() => _instance;
  BluetoothHelper._internal();

  // Stream controllers
  final StreamController<String> _uidController = StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _scanDataController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> _studentsController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<Map<String, dynamic>> _statsController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> _logsController = StreamController<List<Map<String, dynamic>>>.broadcast();

  // ESP32 device and characteristics
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _charScan;
  BluetoothCharacteristic? _charStudentRx;
  BluetoothCharacteristic? _charStudentTx;
  BluetoothCharacteristic? _charStats;
  BluetoothCharacteristic? _charLogs;
  BluetoothCharacteristic? _charCommand;

  // UUIDs - Must match ESP32
  static const String ESP32_NAME_PREFIX = 'SmartAttendance';
  static const String SERVICE_UUID = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String CHAR_SCAN_UUID = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String CHAR_STUDENT_RX_UUID = 'a07498ca-ad5b-474e-940d-16f1fbe7e8cd';
  static const String CHAR_STUDENT_TX_UUID = '51ff12bb-3ed8-46e5-b4f9-d64e2fec021b';
  static const String CHAR_STATS_UUID = '0972ef8c-7613-4075-ad52-756f33d4da91';
  static const String CHAR_LOGS_UUID = '9a8ca5b5-6f3d-4b0e-8b3e-4c8b8e8a5f2d';
  static const String CHAR_COMMAND_UUID = '7e7d1c3b-8c5e-4b1f-9d2e-5a6b7c8d9e0f';

  // Public streams
  Stream<String> get uidStream => _uidController.stream;
  Stream<Map<String, dynamic>> get scanDataStream => _scanDataController.stream;
  Stream<List<Map<String, dynamic>>> get studentsStream => _studentsController.stream;
  Stream<Map<String, dynamic>> get statsStream => _statsController.stream;
  Stream<List<Map<String, dynamic>>> get logsStream => _logsController.stream;

  // ==================== CONNECTION ====================

  Future<void> scanAndConnect() async {
    try {
      if (await FlutterBluePlus.isSupported == false) {
        throw Exception('Bluetooth not supported by this device');
      }

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        throw Exception('Bluetooth is not turned on');
      }

      if (_connectedDevice != null && _charScan != null) {
        return; // Already connected
      }

      print('🔍 Scanning for ESP32...');

      final subscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult result in results) {
          if (result.device.platformName.contains(ESP32_NAME_PREFIX)) {
            print('✓ Found ESP32: ${result.device.platformName}');
            await FlutterBluePlus.stopScan();
            await _connectToDevice(result.device);
            break;
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: 10),
        androidUsesFineLocation: true,
      );

      await Future.delayed(Duration(seconds: 10));
      await subscription.cancel();

      if (_connectedDevice == null) {
        throw Exception('ESP32 device not found');
      }
    } catch (e) {
      print('❌ Bluetooth scan error: $e');
      rethrow;
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      print('🔗 Connecting to ${device.platformName}...');

      await device.connect(
        timeout: Duration(seconds: 15),
        autoConnect: false,
      );

      _connectedDevice = device;
      print('✓ Connected!');

      List<BluetoothService> services = await device.discoverServices();

      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
          print('✓ Found attendance service');

          for (BluetoothCharacteristic characteristic in service.characteristics) {
            final uuid = characteristic.uuid.toString().toLowerCase();

            // Scan notifications (from ESP32)
            if (uuid == CHAR_SCAN_UUID.toLowerCase()) {
              _charScan = characteristic;
              await characteristic.setNotifyValue(true);
              characteristic.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  _handleScanNotification(value);
                }
              });
              print('✓ Scan characteristic ready');
            }

            // Student data receive (to ESP32)
            else if (uuid == CHAR_STUDENT_RX_UUID.toLowerCase()) {
              _charStudentRx = characteristic;
              print('✓ Student RX characteristic ready');
            }

            // Student data transmit (from ESP32)
            else if (uuid == CHAR_STUDENT_TX_UUID.toLowerCase()) {
              _charStudentTx = characteristic;
              await characteristic.setNotifyValue(true);
              characteristic.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  _handleStudentData(value);
                }
              });
              print('✓ Student TX characteristic ready');
            }

            // Statistics (from ESP32)
            else if (uuid == CHAR_STATS_UUID.toLowerCase()) {
              _charStats = characteristic;
              await characteristic.setNotifyValue(true);
              characteristic.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  _handleStatsData(value);
                }
              });
              print('✓ Stats characteristic ready');
            }

            // Logs (from ESP32)
            else if (uuid == CHAR_LOGS_UUID.toLowerCase()) {
              _charLogs = characteristic;
              await characteristic.setNotifyValue(true);
              characteristic.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  _handleLogsData(value);
                }
              });
              print('✓ Logs characteristic ready');
            }

            // Command (to ESP32)
            else if (uuid == CHAR_COMMAND_UUID.toLowerCase()) {
              _charCommand = characteristic;
              print('✓ Command characteristic ready');
            }
          }
        }
      }

      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        }
      });

      print('✅ All characteristics initialized!');
    } catch (e) {
      print('❌ Connection error: $e');
      rethrow;
    }
  }

  // ==================== DATA HANDLERS ====================

  void _handleScanNotification(List<int> value) {
    try {
      final jsonString = utf8.decode(value);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Emit UID for backward compatibility
      if (data.containsKey('uid')) {
        _uidController.add(data['uid'] as String);
      }

      // Emit full scan data
      _scanDataController.add(data);

      print('📇 Scan received: ${data['name']} (${data['uid']})');
    } catch (e) {
      // Fallback: treat as plain UID string
      final uid = String.fromCharCodes(value).trim();
      if (uid.isNotEmpty) {
        _uidController.add(uid);
        print('📇 UID received: $uid');
      }
    }
  }

  void _handleStudentData(List<int> value) {
    try {
      final jsonString = utf8.decode(value);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      if (data.containsKey('students')) {
        final students = (data['students'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _studentsController.add(students);
        print('📥 Received ${students.length} students from ESP32');
      }
    } catch (e) {
      print('❌ Error parsing student data: $e');
    }
  }

  void _handleStatsData(List<int> value) {
    try {
      final jsonString = utf8.decode(value);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      _statsController.add(data);
      print('📊 Stats received: ${data.toString()}');
    } catch (e) {
      print('❌ Error parsing stats: $e');
    }
  }

  void _handleLogsData(List<int> value) {
    try {
      final jsonString = utf8.decode(value);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      if (data.containsKey('logs')) {
        final logs = (data['logs'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _logsController.add(logs);
        print('📋 Received ${logs.length} attendance logs from ESP32');
      }
    } catch (e) {
      print('❌ Error parsing logs: $e');
    }
  }

  // ==================== COMMANDS TO ESP32 ====================

  Future<bool> addStudent(String uid, String name, String studentClass) async {
    if (_charStudentRx == null) {
      print('❌ Not connected to ESP32');
      return false;
    }

    try {
      final data = {
        'action': 'add',
        'uid': uid,
        'name': name,
        'class': studentClass,
      };

      final jsonString = jsonEncode(data);
      final bytes = utf8.encode(jsonString);

      await _charStudentRx!.write(bytes, withoutResponse: false);
      print('✓ Student added to ESP32: $name');
      return true;
    } catch (e) {
      print('❌ Error adding student: $e');
      return false;
    }
  }

  Future<bool> updateStudent(String uid, String name, String studentClass) async {
    if (_charStudentRx == null) return false;

    try {
      final data = {
        'action': 'update',
        'uid': uid,
        'name': name,
        'class': studentClass,
      };

      final jsonString = jsonEncode(data);
      final bytes = utf8.encode(jsonString);

      await _charStudentRx!.write(bytes, withoutResponse: false);
      print('✓ Student updated on ESP32: $name');
      return true;
    } catch (e) {
      print('❌ Error updating student: $e');
      return false;
    }
  }

  Future<bool> deleteStudent(String uid) async {
    if (_charStudentRx == null) return false;

    try {
      final data = {
        'action': 'delete',
        'uid': uid,
      };

      final jsonString = jsonEncode(data);
      final bytes = utf8.encode(jsonString);

      await _charStudentRx!.write(bytes, withoutResponse: false);
      print('✓ Student deleted from ESP32: $uid');
      return true;
    } catch (e) {
      print('❌ Error deleting student: $e');
      return false;
    }
  }

  Future<void> requestStudentList() async {
    await _sendCommand('GET_STUDENTS');
  }

  Future<void> requestStatistics() async {
    await _sendCommand('GET_STATS');
  }

  Future<void> requestAttendanceLogs() async {
    await _sendCommand('GET_LOGS');
  }

  Future<void> clearTodayAttendance() async {
    await _sendCommand('CLEAR_TODAY');
  }

  Future<void> clearAllData() async {
    await _sendCommand('CLEAR_ALL');
  }

  Future<void> _sendCommand(String command) async {
    if (_charCommand == null) {
      print('❌ Not connected to ESP32');
      return;
    }

    try {
      final bytes = utf8.encode(command);
      await _charCommand!.write(bytes, withoutResponse: false);
      print('📤 Command sent: $command');
    } catch (e) {
      print('❌ Error sending command: $e');
    }
  }

  // ==================== UTILITY ====================

  void _handleDisconnection() {
    _connectedDevice = null;
    _charScan = null;
    _charStudentRx = null;
    _charStudentTx = null;
    _charStats = null;
    _charLogs = null;
    _charCommand = null;
    print('🔌 Device disconnected');
  }

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _handleDisconnection();
    }
  }

  bool get isConnected =>
      _connectedDevice != null &&
          _charScan != null &&
          _charStudentRx != null &&
          _charCommand != null;

  String? get connectedDeviceName => _connectedDevice?.platformName;

  // Get actual connection state from device
  Future<bool> checkConnectionState() async {
    if (_connectedDevice == null) return false;

    try {
      final state = await _connectedDevice!.connectionState.first;
      final isActuallyConnected = state == BluetoothConnectionState.connected;

      if (!isActuallyConnected) {
        // Device thinks it's disconnected, clean up
        _handleDisconnection();
      }

      return isActuallyConnected && _charScan != null;
    } catch (e) {
      print('Error checking connection state: $e');
      return false;
    }
  }

  void dispose() {
    disconnect();
    _uidController.close();
    _scanDataController.close();
    _studentsController.close();
    _statsController.close();
    _logsController.close();
  }

  // For testing: Simulate card scan
  void simulateScan(String uid) {
    _uidController.add(uid);
  }

  Future<List<BluetoothDevice>> getConnectedDevices() async {
    return await FlutterBluePlus.connectedDevices;
  }

  Future<bool> isBluetoothEnabled() async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  Future<void> turnOnBluetooth() async {
    try {
      if (await FlutterBluePlus.isSupported) {
        await FlutterBluePlus.turnOn();
      }
    } catch (e) {
      print('❌ Error turning on Bluetooth: $e');
      rethrow;
    }
  }
}