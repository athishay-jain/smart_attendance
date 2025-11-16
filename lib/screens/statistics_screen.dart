import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/student.dart';
import '../services/database_helper.dart';
import '../services/bluetooth_helper.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final BluetoothHelper _btHelper = BluetoothHelper();

  late TabController _tabController;
  Map<String, dynamic>? _esp32Stats;
  bool _isLoadingESP32Data = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Check connection and load stats
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_btHelper.isConnected) {
        _loadESP32Statistics();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadESP32Statistics() async {
    if (!_btHelper.isConnected) {
      print('⚠️ Not connected to ESP32');
      if (mounted) {
        setState(() {
          _isLoadingESP32Data = false;
          _esp32Stats = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingESP32Data = true;
      });
    }

    try {
      // Request stats from ESP32
      await _btHelper.requestStatistics();

      // Listen for response with timeout
      bool receivedData = false;

      final subscription = _btHelper.statsStream.listen((stats) {
        if (mounted && !receivedData) {
          receivedData = true;
          setState(() {
            _esp32Stats = stats;
            _isLoadingESP32Data = false;
          });
          print('✓ ESP32 Stats received: $stats');
        }
      });

      // Wait up to 5 seconds for response
      await Future.delayed(Duration(seconds: 5));
      await subscription.cancel();

      if (mounted && !receivedData) {
        setState(() {
          _isLoadingESP32Data = false;
        });
        print('⚠️ No stats received from ESP32');

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(LucideIcons.circleAlert, color: Colors.white),
                SizedBox(width: 12),
                Text('No response from ESP32. Please try again.'),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
    } catch (e) {
      print('❌ Error loading ESP32 stats: $e');
      if (mounted) {
        setState(() {
          _isLoadingESP32Data = false;
        });
      }
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
              Colors.indigo.shade700,
              Colors.indigo.shade500,
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
                            'Statistics',
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
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_btHelper.isConnected)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(LucideIcons.refreshCw, color: Colors.white),
                          onPressed: _loadESP32Statistics,
                        ),
                      ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: -0.3),

              // Tab Bar
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: Colors.indigo.shade700,
                  unselectedLabelColor: Colors.white70,
                  tabs: [
                    Tab(text: 'Overview'),
                    Tab(text: 'Daily'),
                    Tab(text: 'ESP32'),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms),

              SizedBox(height: 16),

              // Tab Views
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                  ),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildDailyTab(),
                      _buildESP32Tab(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return FutureBuilder<Map<String, int>>(
      future: _dbHelper.getDashboardStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data ?? {'total': 0, 'present': 0, 'absent': 0};

        return SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              // Quick Stats Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Students',
                      stats['total'].toString(),
                      LucideIcons.users,
                      Colors.blue.shade600,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Present Today',
                      stats['present'].toString(),
                      LucideIcons.userCheck,
                      Colors.green.shade600,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Absent Today',
                      stats['absent'].toString(),
                      LucideIcons.userX,
                      Colors.red.shade600,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Attendance Rate',
                      '${stats['total']! > 0 ? ((stats['present']! / stats['total']!) * 100).toStringAsFixed(0) : 0}%',
                      LucideIcons.trendingUp,
                      Colors.orange.shade600,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24),

              // Weekly Chart
              _buildWeeklyChart(),

              SizedBox(height: 24),

              // Recent Activity
              _buildRecentActivity(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDailyTab() {
    return ListView.builder(
      padding: EdgeInsets.all(24),
      itemCount: 30, // Last 30 days
      itemBuilder: (context, index) {
        final date = DateTime.now().subtract(Duration(days: index));
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        return FutureBuilder<List<dynamic>>(
          future: _dbHelper.getAttendanceByDate(date),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return SizedBox.shrink();
            }

            final attendees = snapshot.data!;
            if (attendees.isEmpty && index > 7) {
              return SizedBox.shrink(); // Don't show old empty days
            }

            return _buildDayCard(date, attendees.length);
          },
        );
      },
    );
  }

  Widget _buildESP32Tab() {
    if (!_btHelper.isConnected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.bluetoothOff,
              size: 80,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 20),
            Text(
              'ESP32 Not Connected',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Connect to ESP32 to view hardware stats',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                try {
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
                            CircularProgressIndicator(color: Colors.indigo.shade700),
                            SizedBox(height: 16),
                            Text('Connecting to ESP32...'),
                          ],
                        ),
                      ),
                    ),
                  );

                  await _btHelper.scanAndConnect();

                  Navigator.pop(context); // Close loading dialog

                  if (_btHelper.isConnected) {
                    setState(() {});
                    await _loadESP32Statistics();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(LucideIcons.circleCheck, color: Colors.white),
                            SizedBox(width: 12),
                            Text('Connected to ESP32!'),
                          ],
                        ),
                        backgroundColor: Colors.green.shade700,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(LucideIcons.circleX, color: Colors.white),
                            SizedBox(width: 12),
                            Text('Failed to connect'),
                          ],
                        ),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
                  }
                } catch (e) {
                  Navigator.pop(context); // Close loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(LucideIcons.circleAlert, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(child: Text('Error: $e')),
                        ],
                      ),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
              },
              icon: Icon(LucideIcons.bluetooth),
              label: Text('Connect to ESP32'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade700,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoadingESP32Data) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.indigo.shade700),
            SizedBox(height: 20),
            Text(
              'Loading ESP32 data...',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (_esp32Stats == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.database,
              size: 80,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 20),
            Text(
              'No Data Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadESP32Statistics,
              icon: Icon(LucideIcons.refreshCw),
              label: Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          _buildESP32InfoCard(
            'Total Students in ESP32',
            _esp32Stats!['totalStudents'].toString(),
            LucideIcons.database,
            Colors.purple.shade600,
          ),
          SizedBox(height: 12),
          _buildESP32InfoCard(
            'Today Present (ESP32)',
            _esp32Stats!['todayPresent'].toString(),
            LucideIcons.circleCheck,
            Colors.green.shade600,
          ),
          SizedBox(height: 12),
          _buildESP32InfoCard(
            'Today Absent (ESP32)',
            _esp32Stats!['todayAbsent'].toString(),
            LucideIcons.circleX,
            Colors.red.shade600,
          ),
          SizedBox(height: 12),
          _buildESP32InfoCard(
            'System Uptime',
            _formatUptime(_esp32Stats!['uptime']),
            LucideIcons.clock,
            Colors.blue.shade600,
          ),
          SizedBox(height: 12),
          _buildESP32InfoCard(
            'Current Date (ESP32)',
            _esp32Stats!['date'].toString(),
            LucideIcons.calendar,
            Colors.orange.shade600,
          ),

          SizedBox(height: 24),

          // Actions
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                // Show confirmation
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: Row(
                      children: [
                        Icon(LucideIcons.triangleAlert,
                            color: Colors.orange.shade700
                        ),
                        SizedBox(width: 12),
                        Text('Clear Today?'),
                      ],
                    ),
                    content: Text(
                      'This will clear today\'s attendance on ESP32. '
                          'This action cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                        ),
                        child: Text('Clear'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await _btHelper.clearTodayAttendance();

                  // Refresh data
                  await _loadESP32Statistics();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(LucideIcons.circleCheck, color: Colors.white),
                            SizedBox(width: 12),
                            Text('Today\'s attendance cleared on ESP32'),
                          ],
                        ),
                        backgroundColor: Colors.green.shade700,
                      ),
                    );
                  }
                }
              },
              icon: Icon(LucideIcons.trash2),
              label: Text('Clear Today on ESP32'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                padding: EdgeInsets.all(16),
              ),
            ),
          ),

          SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await _btHelper.requestAttendanceLogs();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(LucideIcons.download, color: Colors.white),
                        SizedBox(width: 12),
                        Text('Requesting logs from ESP32...'),
                      ],
                    ),
                  ),
                );
              },
              icon: Icon(LucideIcons.download),
              label: Text('Download Logs from ESP32'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.all(16),
                side: BorderSide(color: Colors.indigo.shade700),
                foregroundColor: Colors.indigo.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
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
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildWeeklyChart() {
    return FutureBuilder<List<int>>(
      future: _getLast7DaysData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final maxValue = data.reduce((a, b) => a > b ? a : b);
        final chartMaxY = maxValue > 0 ? (maxValue + 5).toDouble() : 10.0;

        return Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Last 7 Days',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: 20),
              AspectRatio(
                aspectRatio: 1.5,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: chartMaxY,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${rod.toY.toInt()} students',
                            TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                            final today = DateTime.now();
                            final dayIndex = (today.weekday - 1 - (6 - value.toInt())) % 7;
                            return Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                days[dayIndex < 0 ? dayIndex + 7 : dayIndex],
                                style: TextStyle(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(7, (index) {
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: data[6 - index].toDouble(),
                            color: Colors.indigo.shade600,
                            width: 16,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 200.ms);
      },
    );
  }

  Future<List<int>> _getLast7DaysData() async {
    final List<int> data = [];
    final today = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final students = await _dbHelper.getAttendanceByDate(date);
      data.add(students.length);
    }

    return data;
  }

  Widget _buildRecentActivity() {
    return FutureBuilder<List<Student>>(
      future: _dbHelper.getAttendanceByDate(DateTime.now()),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.activity, color: Colors.indigo.shade700),
                    SizedBox(width: 8),
                    Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        LucideIcons.inbox,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No attendance today',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final recentStudents = snapshot.data!.take(5).toList();

        return Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.activity, color: Colors.indigo.shade700),
                  SizedBox(width: 8),
                  Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              ...recentStudents.map((student) => _buildActivityItem(
                student.name,
                'Marked present',
                'Today',
              )),
            ],
          ),
        );
      },
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildActivityItem(String name, String action, String time) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.user, color: Colors.indigo.shade700, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  action,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(DateTime date, int presentCount) {
    final isToday = date.day == DateTime.now().day &&
        date.month == DateTime.now().month &&
        date.year == DateTime.now().year;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _showDayDetailsDialog(date, presentCount);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isToday ? Colors.indigo.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: isToday
                  ? Border.all(color: Colors.indigo.shade700, width: 2)
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isToday ? Colors.indigo.shade700 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        date.day.toString(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isToday ? Colors.white : Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        _getMonthName(date.month),
                        style: TextStyle(
                          fontSize: 10,
                          color: isToday ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getDayName(date.weekday),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        '$presentCount students present',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      presentCount > 0 ? LucideIcons.circleCheck : LucideIcons.circle,
                      color: presentCount > 0 ? Colors.green : Colors.grey.shade400,
                    ),
                    SizedBox(width: 8),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 20,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.2);
  }

  Future<void> _showDayDetailsDialog(DateTime date, int presentCount) async {
    final students = await _dbHelper.getAttendanceByDate(date);
    final dateStr = '${date.day} ${_getMonthName(date.month)} ${date.year}';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: BoxConstraints(maxHeight: 500),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.calendar, color: Colors.indigo.shade700),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        Text(
                          '$presentCount students present',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Divider(),
              SizedBox(height: 8),
              if (students.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.userX,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No attendance recorded',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: 8),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.indigo.shade100,
                              child: Text(
                                student.name[0].toUpperCase(),
                                style: TextStyle(
                                  color: Colors.indigo.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  Text(
                                    student.studentClass,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              LucideIcons.circleCheck,
                              color: Colors.green.shade600,
                              size: 20,
                            ),
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

  Widget _buildESP32InfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.2);
  }

  String _formatUptime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}