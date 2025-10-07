import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance.dart';
import '../models/member.dart';
import '../services/database_helper.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  
  List<Attendance> _attendances = [];
  Map<int, Member> _membersMap = {};
  bool _isLoading = true;
  bool _showTodayOnly = true;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => _isLoading = true);

    try {
      final attendances = _showTodayOnly 
          ? await _databaseHelper.getTodayAttendance()
          : await _databaseHelper.getAllAttendance();
      final members = await _databaseHelper.getAllMembers();
      
      final membersMap = <int, Member>{};
      for (var member in members) {
        membersMap[member.id!] = member;
      }

      setState(() {
        _attendances = attendances;
        _membersMap = membersMap;
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

  Future<void> _checkInMember() async {
    final members = await _databaseHelper.getActiveMembers();
    
    if (members.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active members found'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    final selectedMember = await showDialog<Member>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Member'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return ListTile(
                leading: CircleAvatar(child: Text(member.name[0].toUpperCase())),
                title: Text(member.name),
                subtitle: Text(member.email),
                onTap: () => Navigator.pop(context, member),
              );
            },
          ),
        ),
      ),
    );

    if (selectedMember != null) {
      try {
        // Check if member is already checked in
        final activeAttendance = await _databaseHelper.getActiveAttendanceForMember(selectedMember.id!);
        
        if (activeAttendance != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Member is already checked in'), backgroundColor: Colors.orange),
            );
          }
          return;
        }

        final attendance = Attendance(
          memberId: selectedMember.id!,
          checkInTime: DateTime.now(),
        );

        await _databaseHelper.insertAttendance(attendance);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${selectedMember.name} checked in'), backgroundColor: Colors.green),
          );
        }
        
        _loadAttendance();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _checkOutMember(Attendance attendance) async {
    try {
      await _databaseHelper.checkOutMember(attendance.id!, DateTime.now());
      
      final member = _membersMap[attendance.memberId];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member?.name ?? "Member"} checked out'), backgroundColor: Colors.blue),
        );
      }
      
      _loadAttendance();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return 'In Progress';
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_showTodayOnly ? Icons.today : Icons.calendar_month),
            onPressed: () {
              setState(() {
                _showTodayOnly = !_showTodayOnly;
              });
              _loadAttendance();
            },
            tooltip: _showTodayOnly ? 'Show All' : 'Show Today',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Card
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat('Total', _attendances.length.toString(), Colors.blue),
                  _buildStat('Active', _attendances.where((a) => a.isActive).length.toString(), Colors.green),
                  _buildStat('Completed', _attendances.where((a) => !a.isActive).length.toString(), Colors.orange),
                ],
              ),
            ),
          ),

          // Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.filter_list),
                const SizedBox(width: 8),
                Text(
                  _showTodayOnly ? 'Today\'s Attendance' : 'All Attendance Records',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Attendance List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _attendances.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('No attendance records', style: Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAttendance,
                        child: ListView.builder(
                          itemCount: _attendances.length,
                          itemBuilder: (context, index) {
                            final attendance = _attendances[index];
                            final member = _membersMap[attendance.memberId];
                            return _buildAttendanceCard(attendance, member);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _checkInMember,
        icon: const Icon(Icons.login),
        label: const Text('Check In'),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 24)),
      ],
    );
  }

  Widget _buildAttendanceCard(Attendance attendance, Member? member) {
    final isActive = attendance.isActive;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.green : Colors.blue,
          child: Icon(isActive ? Icons.login : Icons.logout, color: Colors.white),
        ),
        title: Text(
          member?.name ?? 'Unknown Member',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.access_time, size: 14),
                const SizedBox(width: 4),
                Text('In: ${DateFormat('hh:mm a').format(attendance.checkInTime)}'),
              ],
            ),
            if (attendance.checkOutTime != null)
              Row(
                children: [
                  const Icon(Icons.exit_to_app, size: 14),
                  const SizedBox(width: 4),
                  Text('Out: ${DateFormat('hh:mm a').format(attendance.checkOutTime!)}'),
                ],
              ),
            Row(
              children: [
                const Icon(Icons.timer, size: 14),
                const SizedBox(width: 4),
                Text(_formatDuration(attendance.duration)),
              ],
            ),
          ],
        ),
        trailing: isActive
            ? ElevatedButton.icon(
                onPressed: () => _checkOutMember(attendance),
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Check Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Completed', style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
        isThreeLine: true,
      ),
    );
  }
}
