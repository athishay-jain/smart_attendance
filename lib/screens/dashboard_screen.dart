import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_helper.dart';
import '../services/bluetooth_helper.dart';
import 'live_attendance_screen.dart';
import 'manage_students_screen.dart';
import 'statistics_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final BluetoothHelper _btHelper = BluetoothHelper();
  late Future<Map<String, int>> _statsFuture;

  StreamSubscription? _logsSubscription;
  StreamSubscription? _scanSubscription;

  // 🛠️ THROTTLE SET: Keeps track of recent IDs to prevent duplicates
  final Set<String> _recentScans = {};

  @override
  void initState() {
    super.initState();
    _statsFuture = _dbHelper.getDashboardStats();

    // 1. SYNC LISTENER
    _logsSubscription = _btHelper.logsStream.listen((logs) async {
      print("🔄 Dashboard: Received logs from ESP32. Syncing...");
      await _dbHelper.syncLogs(logs);
      _refreshData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync Complete! Data updated from Hardware.'),
            backgroundColor: Colors.teal.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    // 2. REAL-TIME LISTENER (With Throttle Fix)
    _scanSubscription = _btHelper.scanDataStream.listen((scanData) async {
      if (scanData.containsKey('uid') && scanData.containsKey('name')) {
        final String uid = scanData['uid'];
        final String name = scanData['name'];

        // 🛑 CHECK: If scanned in last 5 seconds, IGNORE it.
        if (_recentScans.contains(uid)) {
          print("⏳ Duplicate scan ignored for: $name");
          return;
        }

        // Add to recent list
        _recentScans.add(uid);
        // Remove after 5 seconds
        Future.delayed(Duration(seconds: 5), () => _recentScans.remove(uid));

        print("⚡ Dashboard: Real-time scan received: $name");

        // Save to App Database
        await _dbHelper.logAttendance(uid);

        // Refresh Dashboard UI
        _refreshData();

        // Show Feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(LucideIcons.circleCheck, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Marked Present: $name'),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              duration: Duration(milliseconds: 1500),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _logsSubscription?.cancel();
    _scanSubscription?.cancel();
    super.dispose();
  }

  void _refreshData() {
    if (mounted) {
      setState(() {
        _statsFuture = _dbHelper.getDashboardStats();
      });
    }
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
              Colors.grey.shade50,
            ],
            stops: [0.0, 0.3, 0.8],
          ),
        ),
        child: CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            // Sliver App Bar
            SliverAppBar(
              expandedHeight: 160.0,
              floating: false,
              pinned: true,
              stretch: true,
              elevation: 0,
              backgroundColor: Colors.teal.shade700,
              leading: SizedBox.shrink(),
              flexibleSpace: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double availableHeight = constraints.maxHeight;
                  final double percentage = ((availableHeight - kToolbarHeight) /
                      (160.0 - kToolbarHeight)).clamp(0.0, 1.0);

                  return FlexibleSpaceBar(
                    centerTitle: false,
                    titlePadding: EdgeInsets.only(
                      left: 20,
                      bottom: 16,
                      right: 20,
                    ),
                    title: AnimatedOpacity(
                      duration: Duration(milliseconds: 100),
                      opacity: percentage < 0.5 ? 1.0 : 0.0,
                      child: Text(
                        'Smart Attendance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    background: Container(
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
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 70),
                          child: AnimatedOpacity(
                            duration: Duration(milliseconds: 200),
                            opacity: percentage > 0.3 ? 1.0 : 0.0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Smart Attendance',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                          height: 1.2,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Dashboard Overview',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: (){
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => StatisticsScreen(),));
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Icon(
                                      LucideIcons.layoutDashboard,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Main Content
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                ),
                child: FutureBuilder<Map<String, int>>(
                  future: _statsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        height: MediaQuery.of(context).size.height - 200,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Colors.teal.shade700,
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return Container(
                        height: 200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                LucideIcons.circleAlert,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No data available',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final stats = snapshot.data!;
                    final total = stats['total'] ?? 0;
                    final present = stats['present'] ?? 0;
                    final absent = stats['absent'] ?? 0;

                    return Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Pie Chart Section
                          _buildChartCard(present, absent, total)
                              .animate()
                              .fadeIn(duration: 600.ms)
                              .scale(begin: Offset(0.8, 0.8)),

                          SizedBox(height: 24),

                          // Stats Cards
                          _buildStatsRow(total, present, absent),

                          SizedBox(height: 24),

                          // Action Cards
                          _buildActionCard(
                            context,
                            icon: LucideIcons.scanFace,
                            title: 'Start Live Session',
                            subtitle: 'Begin taking attendance with scanner',
                            color: Colors.teal.shade700,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LiveAttendanceScreen(),
                                ),
                              );
                              _refreshData();
                            },
                          ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.3),

                          SizedBox(height: 16),

                          _buildActionCard(
                            context,
                            icon: LucideIcons.userCog,
                            title: 'Manage Students',
                            subtitle: 'Add, edit, or remove student records',
                            color: Colors.deepPurple.shade700,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ManageStudentsScreen(),
                                ),
                              );
                              _refreshData();
                            },
                          ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.3),

                          SizedBox(height: 24),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(int present, int absent, int total) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Today\'s Attendance',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 24),
          AspectRatio(
            aspectRatio: 1.5,
            child: total > 0
                ? PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 60,
                sections: [
                  PieChartSectionData(
                    value: present.toDouble(),
                    title: '${((present / total) * 100).toStringAsFixed(0)}%',
                    color: Colors.teal.shade600,
                    radius: 60,
                    titleStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: absent.toDouble(),
                    title: '${((absent / total) * 100).toStringAsFixed(0)}%',
                    color: Colors.grey.shade400,
                    radius: 60,
                    titleStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            )
                : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.chartPie,
                    size: 60,
                    color: Colors.grey.shade300,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No students registered',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(int total, int present, int absent) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: LucideIcons.users,
            title: 'Total',
            value: total.toString(),
            color: Colors.blue.shade600,
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.3),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: LucideIcons.userCheck,
            title: 'Present',
            value: present.toString(),
            color: Colors.green.shade600,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: LucideIcons.userX,
            title: 'Absent',
            value: absent.toString(),
            color: Colors.red.shade600,
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                color: Colors.white,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}