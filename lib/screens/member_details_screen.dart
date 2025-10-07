import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/member.dart';
import '../models/fee.dart';
import '../models/attendance.dart';
import '../services/database_helper.dart';
import 'add_member_screen.dart';
import 'add_fee_screen.dart';

class MemberDetailsScreen extends StatefulWidget {
  final Member member;

  const MemberDetailsScreen({super.key, required this.member});

  @override
  State<MemberDetailsScreen> createState() => _MemberDetailsScreenState();
}

class _MemberDetailsScreenState extends State<MemberDetailsScreen> with SingleTickerProviderStateMixin {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  late TabController _tabController;
  
  List<Fee> _fees = [];
  List<Attendance> _attendances = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMemberData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMemberData() async {
    setState(() => _isLoading = true);

    try {
      final fees = await _databaseHelper.getFeesByMemberId(widget.member.id!);
      final attendances = await _databaseHelper.getAttendanceByMemberId(widget.member.id!);

      setState(() {
        _fees = fees;
        _attendances = attendances;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double get _totalFees => _fees.fold(0.0, (sum, fee) => sum + fee.amount);
  double get _pendingFees => _fees.where((f) => f.status == 'pending' || f.status == 'overdue').fold(0.0, (sum, fee) => sum + fee.amount);
  double get _paidFees => _fees.where((f) => f.status == 'paid').fold(0.0, (sum, fee) => sum + fee.amount);

  Future<void> _checkInMember() async {
    try {
      final activeAttendance = await _databaseHelper.getActiveAttendanceForMember(widget.member.id!);
      
      if (activeAttendance != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member is already checked in'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      final attendance = Attendance(
        memberId: widget.member.id!,
        checkInTime: DateTime.now(),
      );

      await _databaseHelper.insertAttendance(attendance);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checked in successfully'), backgroundColor: Colors.green),
        );
      }
      
      _loadMemberData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.member.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddMemberScreen(member: widget.member)),
              );
              if (result == true) {
                Navigator.pop(context, true);
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.info), text: 'Info'),
            Tab(icon: Icon(Icons.payment), text: 'Fees'),
            Tab(icon: Icon(Icons.access_time), text: 'Attendance'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildInfoTab(),
                _buildFeesTab(),
                _buildAttendanceTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _checkInMember,
        icon: const Icon(Icons.login),
        label: const Text('Check In'),
      ),
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Member Avatar
          CircleAvatar(
            radius: 50,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              widget.member.name[0].toUpperCase(),
              style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            widget.member.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          
          const SizedBox(height: 8),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.member.isActive ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              widget.member.isActive ? 'Active' : 'Inactive',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Contact Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Contact Information', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const Divider(),
                  _buildInfoRow(Icons.email, 'Email', widget.member.email),
                  _buildInfoRow(Icons.phone, 'Phone', widget.member.phone),
                  _buildInfoRow(Icons.location_on, 'Address', widget.member.address),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Membership Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Membership Information', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const Divider(),
                  _buildInfoRow(Icons.card_membership, 'Plan', widget.member.membershipPlan),
                  _buildInfoRow(Icons.calendar_today, 'Join Date', DateFormat('dd MMM yyyy').format(widget.member.joinDate)),
                  if (widget.member.lastAttendance != null)
                    _buildInfoRow(Icons.access_time, 'Last Visit', DateFormat('dd MMM yyyy').format(widget.member.lastAttendance!)),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Financial Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Financial Summary', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const Divider(),
                  _buildInfoRow(Icons.attach_money, 'Total Fees', '₹${NumberFormat('#,##0.00').format(_totalFees)}'),
                  _buildInfoRow(Icons.check_circle, 'Paid', '₹${NumberFormat('#,##0.00').format(_paidFees)}', color: Colors.green),
                  _buildInfoRow(Icons.pending, 'Pending', '₹${NumberFormat('#,##0.00').format(_pendingFees)}', color: Colors.orange),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Statistics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Statistics', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const Divider(),
                  _buildInfoRow(Icons.receipt, 'Total Fees', _fees.length.toString()),
                  _buildInfoRow(Icons.login, 'Total Visits', _attendances.length.toString()),
                  _buildInfoRow(Icons.calendar_month, 'Member Since', '${DateTime.now().difference(widget.member.joinDate).inDays} days'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeesTab() {
    if (_fees.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No fee records'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddFeeScreen()),
                );
                if (result == true) _loadMemberData();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Fee'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _fees.length,
      itemBuilder: (context, index) {
        final fee = _fees[index];
        Color statusColor;
        switch (fee.status) {
          case 'paid':
            statusColor = Colors.green;
            break;
          case 'overdue':
            statusColor = Colors.red;
            break;
          default:
            statusColor = Colors.orange;
        }

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.2),
              child: Icon(Icons.payment, color: statusColor),
            ),
            title: Text('${fee.feeType} - ₹${NumberFormat('#,##0.00').format(fee.amount)}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Due: ${DateFormat('dd MMM yyyy').format(fee.dueDate)}'),
                if (fee.paidDate != null)
                  Text('Paid: ${DateFormat('dd MMM yyyy').format(fee.paidDate!)}', style: const TextStyle(color: Colors.green)),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(fee.status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildAttendanceTab() {
    if (_attendances.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.login, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No attendance records'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _attendances.length,
      itemBuilder: (context, index) {
        final attendance = _attendances[index];
        
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: attendance.isActive ? Colors.green : Colors.blue,
              child: Icon(attendance.isActive ? Icons.login : Icons.logout, color: Colors.white),
            ),
            title: Text(DateFormat('dd MMM yyyy').format(attendance.checkInTime)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('In: ${DateFormat('hh:mm a').format(attendance.checkInTime)}'),
                if (attendance.checkOutTime != null)
                  Text('Out: ${DateFormat('hh:mm a').format(attendance.checkOutTime!)}'),
                if (attendance.duration != null)
                  Text('Duration: ${attendance.duration!.inHours}h ${attendance.duration!.inMinutes.remainder(60)}m'),
              ],
            ),
            trailing: attendance.isActive
                ? const Chip(label: Text('Active', style: TextStyle(fontSize: 10)), backgroundColor: Colors.green, labelStyle: TextStyle(color: Colors.white))
                : null,
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
