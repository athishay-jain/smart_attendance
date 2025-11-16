import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/database_helper.dart';
import '../services/bluetooth_helper.dart';
import '../services/image_helper.dart';
import '../models/student.dart';

class AddEditScreen extends StatefulWidget {
  final Student? student;

  const AddEditScreen({Key? key, this.student}) : super(key: key);

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final BluetoothHelper _btHelper = BluetoothHelper();
  final ImageHelper _imageHelper = ImageHelper();

  late TextEditingController _nameController;
  late TextEditingController _classController;
  late TextEditingController _detailsController;

  File? _imageFile;
  String? _scannedUID;
  bool _isScanning = false;

  bool get _isEditMode => widget.student != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.student?.name ?? '');
    _classController =
        TextEditingController(text: widget.student?.studentClass ?? '');
    _detailsController =
        TextEditingController(text: widget.student?.otherDetails ?? '');

    if (_isEditMode) {
      _imageFile = File(widget.student!.imagePath);
      _scannedUID = widget.student!.uid;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _classController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _imageHelper.pickAndSaveImage();
    if (image != null) {
      setState(() {
        _imageFile = image;
      });
    }
  }

  Future<void> _scanCard() async {
  /*  if (!_btHelper.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(LucideIcons.bluetoothOff, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                    'ESP32 not connected. Please connect from dashboard first.'),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }*/

    setState(() {
      _isScanning = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.scanLine,
                size: 80,
                color: Colors.teal.shade700,
              ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2000.ms),
              SizedBox(height: 24),
              Text(
                'Ready to Scan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Hold the NEW RFID card near the ESP32 reader',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.info,
                        size: 16, color: Colors.blue.shade700),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Make sure this card is not already registered',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              LinearProgressIndicator(
                color: Colors.teal.shade700,
                backgroundColor: Colors.teal.shade100,
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isScanning = false;
                  });
                  Navigator.pop(context);
                },
                child: Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );

    // Listen for one UID
    final subscription = _btHelper.uidStream.listen((uid) async {
      if (_isScanning && mounted) {
        // Check if card is already registered
        final existingStudent = await _dbHelper.getStudentByUid(uid);

        if (existingStudent != null && !_isEditMode) {
          setState(() {
            _isScanning = false;
          });
          Navigator.pop(context); // Close scan dialog

          // Show error - card already registered
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(LucideIcons.triangleAlert,
                      color: Colors.orange.shade700),
                  SizedBox(width: 12),
                  Text('Card Already Registered'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('This card is already assigned to:'),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          existingStudent.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          existingStudent.studentClass,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'UID: $uid',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Please use a different RFID card.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _scanCard(); // Try again
                  },
                  child: Text('Scan Another Card'),
                ),
              ],
            ),
          );
          return;
        }

        // Card is new - assign it
        setState(() {
          _scannedUID = uid;
          _isScanning = false;
        });
        Navigator.pop(context); // Close scan dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(LucideIcons.circleCheck, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Card Scanned Successfully!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'UID: $uid',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    });

    // Timeout after 30 seconds
    await Future.delayed(Duration(seconds: 30));
    await subscription.cancel();

    if (_isScanning && mounted) {
      setState(() {
        _isScanning = false;
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(LucideIcons.clock, color: Colors.white),
              SizedBox(width: 12),
              Text('Scan timeout. Please try again.'),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    }
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(LucideIcons.circleAlert, color: Colors.white),
              SizedBox(width: 12),
              Text('Please add a student photo'),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    if (!_isEditMode && _scannedUID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(LucideIcons.circleAlert, color: Colors.white),
              SizedBox(width: 12),
              Text('Please scan an RFID card'),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.teal.shade700),
              SizedBox(height: 16),
              Text('Syncing with ESP32...'),
            ],
          ),
        ),
      ),
    );

    final student = Student(
      uid: _scannedUID!,
      name: _nameController.text.trim(),
      studentClass: _classController.text.trim(),
      imagePath: _imageFile!.path,
      otherDetails: _detailsController.text.trim(),
    );

    // Save to local database
    if (_isEditMode) {
      await _dbHelper.updateStudent(student);
    } else {
      await _dbHelper.addStudent(student);
    }

    // Sync with ESP32 if connected
    bool esp32Synced = false;
    if (_btHelper.isConnected) {
      try {
        if (_isEditMode) {
          esp32Synced = await _btHelper.updateStudent(
            student.uid,
            student.name,
            student.studentClass,
          );
        } else {
          esp32Synced = await _btHelper.addStudent(
            student.uid,
            student.name,
            student.studentClass,
          );
        }
      } catch (e) {
        print('Error syncing with ESP32: $e');
      }
    }

    Navigator.pop(context); // Close loading dialog

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              esp32Synced ? LucideIcons.circleCheck : LucideIcons.circleAlert,
              color: Colors.white,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                _isEditMode
                    ? (esp32Synced
                        ? 'Student updated & synced with ESP32!'
                        : 'Student updated (ESP32 not connected)')
                    : (esp32Synced
                        ? 'Student added & synced with ESP32!'
                        : 'Student added (ESP32 not connected)'),
              ),
            ),
          ],
        ),
        backgroundColor:
            esp32Synced ? Colors.teal.shade700 : Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: Duration(seconds: 3),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.teal.shade700,
              Colors.teal.shade500,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(LucideIcons.arrowLeft, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditMode ? 'Edit Student' : 'Add New Student',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _btHelper.isConnected
                                      ? Colors.greenAccent
                                      : Colors.red.shade300,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                _btHelper.isConnected
                                    ? 'ESP32 Connected'
                                    : 'ESP32 Offline',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: -0.3),

              SizedBox(height: 20),

              // Main Form
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Image Picker
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.teal.shade400,
                                    Colors.teal.shade700,
                                  ],
                                ),
                              ),
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey.shade50,
                                ),
                                child: CircleAvatar(
                                  radius: 70,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage: _imageFile != null
                                      ? FileImage(_imageFile!)
                                      : null,
                                  child: _imageFile == null
                                      ? Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              LucideIcons.camera,
                                              size: 40,
                                              color: Colors.grey.shade600,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Add Photo',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          )
                              .animate()
                              .scale(delay: 100.ms, curve: Curves.elasticOut)
                              .fadeIn(),

                          SizedBox(height: 32),

                          // Name Field
                          _buildTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            icon: LucideIcons.user,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter student name';
                              }
                              return null;
                            },
                          ).animate().fadeIn(delay: 150.ms).slideX(begin: -0.2),

                          SizedBox(height: 16),

                          // Class Field
                          _buildTextField(
                            controller: _classController,
                            label: 'Class / Grade',
                            icon: LucideIcons.graduationCap,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter class';
                              }
                              return null;
                            },
                          ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.2),

                          SizedBox(height: 16),

                          // Details Field
                          _buildTextField(
                            controller: _detailsController,
                            label: 'Additional Details (Optional)',
                            icon: LucideIcons.fileText,
                            maxLines: 3,
                          ).animate().fadeIn(delay: 250.ms).slideX(begin: -0.2),

                          SizedBox(height: 24),

                          // Card Scanner (Add Mode Only)
                          if (!_isEditMode) ...[
                            Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _scannedUID != null
                                      ? Colors.teal.shade300
                                      : Colors.grey.shade300,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.shade50,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          LucideIcons.nfc,
                                          color: Colors.teal.shade700,
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'RFID Card',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              _scannedUID ?? 'Not scanned yet',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: _scannedUID != null
                                                    ? Colors.teal.shade700
                                                    : Colors.grey.shade600,
                                                fontWeight: _scannedUID != null
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_scannedUID == null) ...[
                                    SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed:
                                            _isScanning ? null : _scanCard,
                                        icon: Icon(LucideIcons.scanLine),
                                        label: Text(
                                          _isScanning
                                              ? 'Scanning...'
                                              : 'Scan Card',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal.shade700,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                              vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ).animate().fadeIn(delay: 300.ms).scale(),
                          ],

                          // Card Info (Edit Mode Only)
                          if (_isEditMode) ...[
                            Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade400,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      LucideIcons.creditCard,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Card UID',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          widget.student!.uid,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    LucideIcons.lock,
                                    color: Colors.grey.shade500,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(delay: 300.ms),
                          ],

                          SizedBox(height: 32),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _saveStudent,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isEditMode
                                        ? LucideIcons.check
                                        : LucideIcons.userPlus,
                                    size: 24,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    _isEditMode
                                        ? 'Update Student'
                                        : 'Add Student',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal.shade700),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.teal.shade700, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade700, width: 2),
        ),
      ),
    );
  }
}
