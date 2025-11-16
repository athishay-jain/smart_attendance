import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/database_helper.dart';
import '../services/bluetooth_helper.dart';
import '../models/student.dart';

class LiveAttendanceScreen extends StatefulWidget {
  const LiveAttendanceScreen({Key? key}) : super(key: key);

  @override
  State<LiveAttendanceScreen> createState() => _LiveAttendanceScreenState();
}

class _LiveAttendanceScreenState extends State<LiveAttendanceScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final BluetoothHelper _btHelper = BluetoothHelper();
  String _statusText = 'Connecting to scanner...';
  bool _isConnected = false;
  int _scannedCount = 0;

  // Track last scanned UID and timestamp to prevent duplicates
  String? _lastScannedUID;
  DateTime? _lastScanTime;
  final Duration _scanCooldown = Duration(seconds: 3);

  // Track if a bottom sheet is currently showing
  bool _isShowingSheet = false;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  @override
  void dispose() {
    // Reset the last scanned UID when leaving screen
    _lastScannedUID = null;
    _lastScanTime = null;
    super.dispose();
  }

  Future<void> _initializeScanner() async {
    try {
      await _btHelper.scanAndConnect();
      if (mounted) {
        setState(() {
          _isConnected = true;
          _statusText = 'Connected. Ready to scan cards.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusText = 'Connection failed. Retrying...';
        });
      }
    }
  }

  bool _shouldProcessScan(String uid) {
    final now = DateTime.now();

    // Check if it's the same card within cooldown period
    if (_lastScannedUID == uid && _lastScanTime != null) {
      final timeSinceLastScan = now.difference(_lastScanTime!);
      if (timeSinceLastScan < _scanCooldown) {
        return false; // Ignore duplicate scan
      }
    }

    // Check if a bottom sheet is already showing
    if (_isShowingSheet) {
      return false;
    }

    return true;
  }

  void _handleScan(String uid) async {
    // Prevent duplicate scans
    if (!_shouldProcessScan(uid)) {
      return;
    }

    // Update last scan tracking
    _lastScannedUID = uid;
    _lastScanTime = DateTime.now();
    _isShowingSheet = true;

    HapticFeedback.mediumImpact();

    final student = await _dbHelper.getStudentByUid(uid);

    if (student != null) {
      if (mounted) {
        setState(() {
          _scannedCount++;
        });
      }

      // Log attendance in background
      _dbHelper.logAttendance(uid);

      // Show success bottom sheet
      if (mounted) {
        await _showStudentSheet(student);
      }
    } else {
      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Row(
              children: [
                Icon(LucideIcons.triangleAlert, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error: Card not registered!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
        HapticFeedback.heavyImpact();
      }
    }

    // Reset showing state after a delay
    await Future.delayed(Duration(milliseconds: 500));
    _isShowingSheet = false;
  }

  Future<void> _showStudentSheet(Student student) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.teal.shade400, Colors.teal.shade700],
                ),
              ),
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 56,
                  backgroundImage: FileImage(File(student.imagePath)),
                ),
              ),
            )
                .animate()
                .scale(duration: 400.ms, curve: Curves.elasticOut)
                .fadeIn(),
            SizedBox(height: 20),
            Text(
              student.name,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.3),
            SizedBox(height: 8),
            Text(
              student.studentClass,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ).animate().fadeIn(delay: 200.ms),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade100, Colors.teal.shade50],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.circleCheck,
                      color: Colors.teal.shade700,
                      size: 20
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Attendance Marked!',
                    style: TextStyle(
                      color: Colors.teal.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms).scale(curve: Curves.elasticOut),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.teal.shade700,
              Colors.teal.shade500,
              Colors.grey.shade50,
            ],
            stops: [0.0, 0.3, 0.7],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(LucideIcons.arrowLeft, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Live Attendance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.users, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            _scannedCount.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: StreamBuilder<String>(
                  stream: _btHelper.uidStream,
                  builder: (context, snapshot) {
                    // Only process new data, don't trigger on every build
                    if (snapshot.hasData && snapshot.data != null) {
                      // Use addPostFrameCallback to avoid calling setState during build
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _handleScan(snapshot.data!);
                      });
                    }

                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Scanner Animation
                          Container(
                            padding: EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1),
                            ),
                            child: Container(
                              padding: EdgeInsets.all(30),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.2),
                              ),
                              child: Icon(
                                LucideIcons.scanLine,
                                size: 100,
                                color: Colors.white,
                              ),
                            ),
                          )
                              .animate(onPlay: (controller) => controller.repeat())
                              .shimmer(
                            duration: 2000.ms,
                            color: Colors.white.withOpacity(0.5),
                          )
                              .animate(onPlay: (controller) => controller.repeat())
                              .scale(
                            duration: 2000.ms,
                            begin: Offset(1.0, 1.0),
                            end: Offset(1.1, 1.1),
                            curve: Curves.easeInOut,
                          ),

                          SizedBox(height: 40),

                          // Status Text
                          Container(
                            margin: EdgeInsets.symmetric(horizontal: 40),
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _isConnected
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                    )
                                        .animate(
                                        onPlay: (c) => c.repeat(reverse: true))
                                        .fade(duration: 1000.ms),
                                    SizedBox(width: 12),
                                    Text(
                                      _statusText,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Hold card near the scanner',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3),

                          SizedBox(height: 60),

                          // Quick Stats
                          if (_scannedCount > 0)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.teal.withOpacity(0.2),
                                    blurRadius: 15,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.circleCheck,
                                    color: Colors.teal.shade700,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    '$_scannedCount student${_scannedCount > 1 ? 's' : ''} marked',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            )
                                .animate()
                                .fadeIn()
                                .scale(curve: Curves.elasticOut),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}