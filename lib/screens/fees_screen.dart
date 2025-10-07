import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/fee.dart';
import '../models/member.dart';
import '../services/database_helper.dart';
import 'add_fee_screen.dart';
import 'member_details_screen.dart';

class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key});

  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  
  List<Fee> _fees = [];
  List<Fee> _filteredFees = [];
  Map<int, Member> _membersMap = {};
  bool _isLoading = true;
  String _filterStatus = 'all'; // 'all', 'pending', 'paid', 'overdue'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFeesAndMembers();
  }

  Future<void> _loadFeesAndMembers() async {
    setState(() => _isLoading = true);

    try {
      final fees = await _databaseHelper.getAllFees();
      final members = await _databaseHelper.getAllMembers();
      
      final membersMap = <int, Member>{};
      for (var member in members) {
        membersMap[member.id!] = member;
      }

      setState(() {
        _fees = fees;
        _membersMap = membersMap;
        _applyFilters();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading fees: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    List<Fee> filtered = _fees;

    // Update overdue status
    filtered = filtered.map((fee) {
      if (fee.isOverdue && fee.status != 'overdue') {
        return fee.copyWith(status: 'overdue');
      }
      return fee;
    }).toList();

    // Apply status filter
    if (_filterStatus != 'all') {
      filtered = filtered.where((fee) => fee.status == _filterStatus).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((fee) {
        final member = _membersMap[fee.memberId];
        return member != null && 
               member.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Sort by due date
    filtered.sort((a, b) => b.dueDate.compareTo(a.dueDate));

    setState(() => _filteredFees = filtered);
  }

  Future<void> _markAsPaid(Fee fee) async {
    try {
      await _databaseHelper.markFeeAsPaid(fee.id!, DateTime.now());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fee marked as paid'), backgroundColor: Colors.green),
        );
      }
      _loadFeesAndMembers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteFee(Fee fee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Fee'),
        content: const Text('Are you sure you want to delete this fee record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _databaseHelper.deleteFee(fee.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fee deleted'), backgroundColor: Colors.red),
          );
        }
        _loadFeesAndMembers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  double _getTotalAmount(String status) {
    return _fees
        .where((fee) => status == 'all' || fee.status == status)
        .fold(0.0, (sum, fee) => sum + fee.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Management', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Summary Cards
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                _buildSummaryCard('Total', _getTotalAmount('all'), Colors.blue),
                _buildSummaryCard('Pending', _getTotalAmount('pending'), Colors.orange),
                _buildSummaryCard('Paid', _getTotalAmount('paid'), Colors.green),
                _buildSummaryCard('Overdue', _getTotalAmount('overdue'), Colors.red),
              ],
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                _buildFilterChip('Pending', 'pending'),
                _buildFilterChip('Paid', 'paid'),
                _buildFilterChip('Overdue', 'overdue'),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by member name...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilters();
                });
              },
            ),
          ),

          // Fees List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFees.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payment, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('No fees found', style: Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadFeesAndMembers,
                        child: ListView.builder(
                          itemCount: _filteredFees.length,
                          itemBuilder: (context, index) {
                            final fee = _filteredFees[index];
                            final member = _membersMap[fee.memberId];
                            return _buildFeeCard(fee, member);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddFeeScreen()),
          );
          if (result == true) _loadFeesAndMembers();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryCard(String label, double amount, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              '₹${NumberFormat('#,##0.00').format(amount)}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _filterStatus = value;
            _applyFilters();
          });
        },
      ),
    );
  }

  Widget _buildFeeCard(Fee fee, Member? member) {
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
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(Icons.payment, color: statusColor),
        ),
        title: Text(
          member?.name ?? 'Unknown Member',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${fee.feeType} - ₹${NumberFormat('#,##0.00').format(fee.amount)}'),
            Text(
              'Due: ${DateFormat('dd MMM yyyy').format(fee.dueDate)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (fee.paidDate != null)
              Text(
                'Paid: ${DateFormat('dd MMM yyyy').format(fee.paidDate!)}',
                style: TextStyle(fontSize: 12, color: Colors.green.shade700),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                fee.status.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'mark_paid':
                    _markAsPaid(fee);
                    break;
                  case 'edit':
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddFeeScreen(fee: fee)),
                    ).then((result) {
                      if (result == true) _loadFeesAndMembers();
                    });
                    break;
                  case 'view_member':
                    if (member != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MemberDetailsScreen(member: member)),
                      );
                    }
                    break;
                  case 'delete':
                    _deleteFee(fee);
                    break;
                }
              },
              itemBuilder: (context) => [
                if (fee.status != 'paid')
                  const PopupMenuItem(
                    value: 'mark_paid',
                    child: Row(
                      children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('Mark as Paid')],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [Icon(Icons.edit), SizedBox(width: 8), Text('Edit')]),
                ),
                const PopupMenuItem(
                  value: 'view_member',
                  child: Row(children: [Icon(Icons.person), SizedBox(width: 8), Text('View Member')]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))]),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
