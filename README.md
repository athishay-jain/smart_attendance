# Smart Attendance System - Mobile App 📱

A modern, offline-first Flutter application designed to interface with the ESP32-based Smart Attendance hardware. This app allows administrators to manage students, view real-time attendance, visualize statistics, and sync data via Bluetooth Low Energy (BLE).

## ✨ Key Features

### 1\. 📊 Interactive Dashboard

  * **Real-time Overview**: View daily attendance stats (Present/Absent/Total) at a glance.
  * **Visual Data**: Animated Pie Charts showing daily attendance distribution.
  * **Quick Actions**: Shortcuts to start live sessions or manage students.

### 2\. 📡 Live Attendance Mode

  * **Real-time Scanning**: Connects to the ESP32 scanner. When a student scans their card, their photo and details pop up instantly on the phone.
  * **Visual Feedback**: Distinct success/error animations and haptic feedback for registered vs. unregistered cards.
  * **Duplicate Prevention**: Built-in throttling to prevent accidental double-scanning within 5 seconds.

### 3\. 🎓 Student Management

  * **CRUD Operations**: Add, Edit, and Delete student records directly from the app.
  * **Photo Support**: capture or select student profile photos (stored locally).
  * **Auto-Sync**: Changes made in the app (like adding a new student) are automatically sent to the ESP32 hardware via BLE to update its internal memory.

### 4\. 📈 Advanced Statistics

  * **Weekly Trends**: Bar charts displaying attendance counts for the last 7 days.
  * **Calendar View**: Drill down into specific dates to see who was present.
  * **Hardware Monitor**: a dedicated "ESP32" tab to view hardware uptime, storage usage, and raw logs.

### 5\. 🛠 Hardware Control

  * **Remote Wipe**: Send commands to clear "Today's Attendance" or "Factory Reset" the ESP32 directly from the app.
  * **Log Syncing**: Fetch offline attendance logs stored on the ESP32 while the phone was disconnected.

## 🛠️ Tech Stack & Libraries

This project uses **Flutter** with **Material 3** design.

| Category | Package | Purpose |
| :--- | :--- | :--- |
| **Connectivity** | `flutter_blue_plus` | Managing Bluetooth Low Energy (BLE) scanning and data transfer. |
| **Database** | `sqflite` | Local SQL database to store student details and attendance logs. |
| **UI Components** | `lucide_icons_flutter` | Modern, clean icon set. |
| **Charts** | `fl_chart` | Rendering Pie charts and Bar charts for statistics. |
| **Animations** | `flutter_animate` | Smooth entrance animations for list items and cards. |
| **Media** | `image_picker` | capturing student photos via Camera or Gallery. |
| **Utils** | `permission_handler` | Managing Android/iOS Bluetooth & Storage permissions. |

## 🔌 BLE Communication Protocol

The app communicates with the ESP32 using the following UUID configuration:

  * **Service UUID**: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`

| Characteristic | UUID | Direction | Function |
| :--- | :--- | :--- | :--- |
| **SCAN\_DATA** | `...26a8` | ESP -\> App | Receives real-time UID scans. |
| **STUDENT\_RX** | `...e8cd` | App -\> ESP | Sends JSON to Add/Update/Delete students. |
| **STUDENT\_TX** | `...021b` | ESP -\> App | Receives the full list of students from hardware. |
| **STATS** | `...da91` | ESP -\> App | Receives hardware stats (uptime, counts). |
| **LOGS** | `...5f2d` | ESP -\> App | Receives historical attendance logs. |
| **COMMAND** | `...9e0f` | App -\> ESP | Sends commands like `CLEAR_TODAY`, `GET_LOGS`. |

## 🚀 Getting Started

### Prerequisites

  * Flutter SDK (Version 3.0.0 or higher)
  * Physical Android/iOS device (Simulators cannot use Bluetooth)
  * The ESP32 Hardware running the companion firmware.

### Installation

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/athishay-jain/smart_attendance.git
    ```

2.  **Install dependencies:**

    ```bash
    flutter pub get
    ```

3.  **Run the app:**
    Connect your physical device and run:

    ```bash
    flutter run
    ```

## 📂 Project Structure

```
lib/
├── main.dart                  # Entry point & Theme configuration
├── models/
│   └── student.dart           # Student data model
├── screens/
│   ├── dashboard_screen.dart  # Main home screen
│   ├── live_attendance.dart   # Real-time scanning UI
│   ├── manage_students.dart   # List and Search students
│   ├── add_edit_screen.dart   # Form to add students
│   └── statistics_screen.dart # Charts and Hardware info
└── services/
    ├── bluetooth_helper.dart  # Singleton for BLE logic
    ├── database_helper.dart   # Singleton for SQLite logic
    └── image_helper.dart      # Photo handling utilities
```

## 👤 Author
**Athishay Jain**
