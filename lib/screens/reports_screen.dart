import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  
  bool _isLoading = true;
  int _totalMembers = 0;
  int _activeMembers = 0;
  int _inactiveMembers = 0;
  double _totalRevenue = 0;
  double _pendingRevenue = 0;
  double _paidRevenue = 0;
  int _totalAttendances = 0;
  int _todayAttendances = 0;
  Map<String, int> _membershipPlanCount = {};
  List<Map<String, dynamic>> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    _loadReportsData();
  }

  Future<void> _loadReportsData() async {
    setState(() => _isLoading = true);

    try {
      // Load members data
      final members = await _databaseHelper.getAllMembers();
      final activeMembers = members.where((m) => m.isActive).length;
      final inactiveMembers = members.length - activeMembers;
      
      // Count membership plans
      final planCount = <String, int>{};
      for (var member in members) {
        planCount[member.membershipPlan] = (planCount[member.membershipPlan] ?? 0) + 1;
      }

      // Load fees data
      final fees = await _databaseHelper.getAllFees();
      final totalRevenue = fees.fold<double>(0, (sum, fee) => sum + fee.amount);
      final paidRevenue = fees.where((f) => f.status == 'paid').fold<double>(0, (sum, fee) => sum + fee.amount);
      final pendingRevenue = fees.where((f) => f.status == 'pending' || f.status == 'overdue').fold<double>(0, (sum, fee) => sum + fee.amount);

      // Load attendance data
      final allAttendances = await _databaseHelper.getAllAttendance();
      final todayAttendances = await _databaseHelper.getTodayAttendance();

      // Recent activities (last 10 members joined)
      final recentMembers = members.toList()
        ..sort((a, b) => b.joinDate.compareTo(a.joinDate));
      final recentActivities = recentMembers.take(10).map((m) => {
        'type': 'member_joined',
        'name': m.name,
        'date': m.joinDate,
      }).toList();

      setState(() {
        _totalMembers = members.length;
        _activeMembers = activeMembers;
        _inactiveMembers = inactiveMembers;
        _totalRevenue = totalRevenue;
        _paidRevenue = paidRevenue;
        _pendingRevenue = pendingRevenue;
        _totalAttendances = allAttendances.length;
        _todayAttendances = todayAttendances.length;
        _membershipPlanCount = planCount;
        _recentActivities = recentActivities;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reports: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReportsData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReportsData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Members Statistics
                    Text(
                      'Member Statistics',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Total', _totalMembers.toString(), Icons.people, Colors.blue)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildStatCard('Active', _activeMembers.toString(), Icons.check_circle, Colors.green)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildStatCard('Inactive', _inactiveMembers.toString(), Icons.cancel, Colors.red)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Revenue Statistics
                    Text(
                      'Revenue Statistics',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildStatCard(
                      'Total Revenue',
                      '₹${NumberFormat('#,##0.00').format(_totalRevenue)}',
                      Icons.account_balance_wallet,
                      Colors.indigo,
                      isFullWidth: true,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Paid',
                            '₹${NumberFormat('#,##0.00').format(_paidRevenue)}',
                            Icons.check_circle,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            'Pending',
                            '₹${NumberFormat('#,##0.00').format(_pendingRevenue)}',
                            Icons.pending,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Attendance Statistics
                    Text(
                      'Attendance Statistics',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Visits',
                            _totalAttendances.toString(),
                            Icons.login,
                            Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            'Today',
                            _todayAttendances.toString(),
                            Icons.today,
                            Colors.teal,
                          ),
                        ),
                      ],
                    ),
                    
                    if (_totalMembers > 0) ...[
                      const SizedBox(height: 8),
                      _buildStatCard(
                        'Average Visits/Member',
                        (_totalAttendances / _totalMembers).toStringAsFixed(1),
                        Icons.analytics,
                        Colors.blue,
                        isFullWidth: true,
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Membership Plan Distribution
                    if (_membershipPlanCount.isNotEmpty) ...[
                      Text(
                        'Membership Plan Distribution',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: _membershipPlanCount.entries.map((entry) {
                              final percentage = (_totalMembers > 0 
                                  ? (entry.value / _totalMembers * 100) 
                                  : 0.0).toStringAsFixed(1);
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          entry.key,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          '${entry.value} ($percentage%)',
                                          style: TextStyle(color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: _totalMembers > 0 ? entry.value / _totalMembers : 0,
                                      backgroundColor: Colors.grey.shade200,
                                      minHeight: 8,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Recent Activity
                    Text(
                      'Recent Activity',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: _recentActivities.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: Text('No recent activities')),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _recentActivities.length,
                              separatorBuilder: (context, index) => const Divider(),
                              itemBuilder: (context, index) {
                                final activity = _recentActivities[index];
                                return ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person_add),
                                  ),
                                  title: Text(activity['name'] as String),
                                  subtitle: Text(
                                    'Joined on ${DateFormat('dd MMM yyyy').format(activity['date'] as DateTime)}',
                                  ),
                                  trailing: Text(
                                    DateFormat('dd MMM').format(activity['date'] as DateTime),
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                );
                              },
                            ),
                    ),

                    const SizedBox(height: 24),

                    // Quick Insights
                    Text(
                      'Quick Insights',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildInsightRow(
                              Icons.trending_up,
                              'Revenue Collection Rate',
                              _totalRevenue > 0 
                                  ? '${(_paidRevenue / _totalRevenue * 100).toStringAsFixed(1)}%'
                                  : '0%',
                              Colors.green,
                            ),
                            const Divider(),
                            _buildInsightRow(
                              Icons.people,
                              'Active Member Rate',
                              _totalMembers > 0
                                  ? '${(_activeMembers / _totalMembers * 100).toStringAsFixed(1)}%'
                                  : '0%',
                              Colors.blue,
                            ),
                            const Divider(),
                            _buildInsightRow(
                              Icons.calendar_today,
                              'Avg Daily Attendance',
                              _totalMembers > 0 && _totalAttendances > 0
                                  ? '${(_todayAttendances / _activeMembers * 100).toStringAsFixed(1)}%'
                                  : '0%',
                              Colors.purple,
                            ),
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool isFullWidth = false}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: isFullWidth ? 24 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
