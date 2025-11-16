# 🎓 Smart Attendance System

A beautiful, modern, and fully offline Flutter application for managing student attendance using RFID cards and ESP32 Bluetooth connectivity.

## ✨ Features

- 📊 **Beautiful Dashboard** - Real-time attendance statistics with animated pie charts
- 🔍 **Live Scanner** - Bluetooth connection to ESP32 for RFID card scanning
- 👥 **Student Management** - Add, edit, delete students with photos
- 🎨 **Modern UI** - Material 3 design with smooth animations
- 💾 **Offline First** - All data stored locally using SQLite
- 📸 **Image Support** - Student photos with automatic compression
- 🎯 **Swipe Actions** - Intuitive swipe-to-delete functionality
- ⚡ **Fast & Responsive** - Optimized performance with beautiful transitions

## 🏗️ Architecture

```
lib/
├── main.dart                      # App entry point
├── models/
│   └── student.dart               # Student data model
├── screens/
│   ├── dashboard_screen.dart      # Home screen with stats
│   ├── live_attendance_screen.dart # BLE scanning screen
│   ├── manage_students_screen.dart # Student list screen
│   └── add_edit_screen.dart       # Add/Edit student form
└── services/
    ├── database_helper.dart       # SQLite operations
    ├── bluetooth_helper.dart      # BLE communication
    └── image_helper.dart          # Image handling
```

## 📦 Dependencies

```yaml
dependencies:
  lucide_icons_flutter: ^1.1.0    # Beautiful icons
  flutter_animate: ^4.5.0         # Smooth animations
  fl_chart: ^0.68.0               # Charts & graphs
  sqflite: ^2.3.3+1               # Local database
  flutter_blue_plus: ^1.32.12     # Bluetooth BLE
  image_picker: ^1.1.2            # Pick images
  image: ^4.2.0                   # Image compression
  path_provider: ^2.1.3           # File paths
  permission_handler: ^11.3.1     # Permissions
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Android Studio / VS Code
- ESP32 with RFID reader (RC522 or similar)

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/smart_attendance.git
cd smart_attendance
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Configure ESP32 Bluetooth**

Open `lib/services/bluetooth_helper.dart` and update:

```dart
static const String ESP32_NAME_PREFIX = 'ESP32'; // Your device name
static const String SERVICE_UUID = 'your-service-uuid';
static const String CHARACTERISTIC_UUID = 'your-characteristic-uuid';
```

4. **Run the app**
```bash
flutter run
```

## 🔧 ESP32 Setup

### Hardware Required
- ESP32 Development Board
- RC522 RFID Reader
- RFID Cards/Tags
- Jumper Wires

### Wiring Diagram
```
RC522    →    ESP32
SDA      →    GPIO 5
SCK      →    GPIO 18
MOSI     →    GPIO 23
MISO     →    GPIO 19
IRQ      →    Not Connected
GND      →    GND
RST      →    GPIO 22
3.3V     →    3.3V
```

### Arduino Code Example

```cpp
#include 
#include 
#include 
#include 
#include 
#include 

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

#define SS_PIN 5
#define RST_PIN 22

MFRC522 rfid(SS_PIN, RST_PIN);
BLECharacteristic *pCharacteristic;
bool deviceConnected = false;

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
    };
    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
    }
};

void setup() {
  Serial.begin(115200);
  SPI.begin();
  rfid.PCD_Init();
  
  // Initialize BLE
  BLEDevice::init("ESP32-Attendance");
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  
  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_NOTIFY
  );
  
  pCharacteristic->addDescriptor(new BLE2902());
  pService->start();
  
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->start();
  
  Serial.println("BLE Ready!");
}

void loop() {
  if (deviceConnected && rfid.PICC_IsNewCardPresent() && rfid.PICC_ReadCardSerial()) {
    String uid = "";
    for (byte i = 0; i < rfid.uid.size; i++) {
      uid += String(rfid.uid.uidByte[i] < 0x10 ? "0" : "");
      uid += String(rfid.uid.uidByte[i], HEX);
    }
    uid.toUpperCase();
    
    pCharacteristic->setValue(uid.c_str());
    pCharacteristic->notify();
    
    Serial.println("Card UID: " + uid);
    
    rfid.PICC_HaltA();
    rfid.PCD_StopCrypto1();
    
    delay(1000); // Debounce
  }
}
```

## 📱 Permissions

### Android

The app requires the following permissions:

- ✅ Bluetooth (for BLE scanning)
- ✅ Location (required for Bluetooth on Android)
- ✅ Camera (for taking photos)
- ✅ Storage (for saving images)

All permissions are handled automatically by the app.

### iOS

Add to `ios/Runner/Info.plist`:

```xml
NSBluetoothAlwaysUsageDescription
Need Bluetooth to scan RFID cards
NSBluetoothPeripheralUsageDescription
Need Bluetooth to connect to scanner
NSCameraUsageDescription
Need camera to take student photos
NSPhotoLibraryUsageDescription
Need photo library to select student photos
```

## 🎨 Customization

### Changing Theme Colors

Edit `main.dart`:

```dart
colorScheme: ColorScheme.fromSeed(
  seedColor: Colors.teal.shade700, // Change this color
  brightness: Brightness.light,
),
```

### Modifying Animations

All animations use `flutter_animate` package. Adjust durations in screen files:

```dart
.animate()
.fadeIn(duration: 600.ms) // Change duration
.slideY(begin: 0.3)        // Change animation type
```

## 📊 Database Schema

### Students Table
```sql
CREATE TABLE students (
  uid TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  studentClass TEXT NOT NULL,
  imagePath TEXT NOT NULL,
  otherDetails TEXT
)
```

### Attendance Table
```sql
CREATE TABLE attendance (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uid TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  date TEXT NOT NULL,
  FOREIGN KEY (uid) REFERENCES students (uid)
)
```

## 🐛 Troubleshooting

### Bluetooth not connecting
- Ensure ESP32 is powered on
- Check BLE is enabled on phone
- Verify UUIDs match in code
- Grant location permissions

### Images not saving
- Check storage permissions
- Ensure sufficient storage space
- Verify path_provider is working

### Database errors
- Clear app data and reinstall
- Check SQLite version compatibility

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📧 Contact

For questions or support, please open an issue on GitHub.

## 🎉 Acknowledgments

- Flutter team for the amazing framework
- Material Design 3 for design guidelines
- flutter_blue_plus for BLE support
- All open-source contributors

---

Made with ❤️ using Flutter