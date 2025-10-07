import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/fee.dart';
import '../models/member.dart';
import '../services/database_helper.dart';

class AddFeeScreen extends StatefulWidget {
  final Fee? fee;

  const AddFeeScreen({super.key, this.fee});

  @override
  State<AddFeeScreen> createState() => _AddFeeScreenState();
}

class _AddFeeScreenState extends State<AddFeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<Member> _members = [];
  Member? _selectedMember;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  DateTime? _paidDate;
  String _feeType = 'monthly';
  String _status = 'pending';
  bool _isLoading = false;

  final List<String> _feeTypes = ['monthly', 'quarterly', 'half-yearly', 'annual', 'registration', 'personal-training'];
  final List<String> _statuses = ['pending', 'paid', 'overdue'];

  @override
  void initState() {
    super.initState();
    _loadMembers();
    if (widget.fee != null) {
      _populateFormFields();
    }
  }

  Future<void> _loadMembers() async {
    final members = await _databaseHelper.getAllMembers();
    setState(() {
      _members = members.where((m) => m.isActive).toList();
      if (widget.fee != null) {
        _selectedMember = _members.firstWhere((m) => m.id == widget.fee!.memberId, orElse: () => _members.first);
      }
    });
  }

  void _populateFormFields() {
    final fee = widget.fee!;
    _amountController.text = fee.amount.toString();
    _notesController.text = fee.notes ?? '';
    _dueDate = fee.dueDate;
    _paidDate = fee.paidDate;
    _feeType = fee.feeType;
    _status = fee.status;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _selectPaidDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _paidDate = picked);
  }

  Future<void> _saveFee() async {
    if (!_formKey.currentState!.validate() || _selectedMember == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fee = Fee(
        id: widget.fee?.id,
        memberId: _selectedMember!.id!,
        amount: double.parse(_amountController.text),
        dueDate: _dueDate,
        paidDate: _paidDate,
        feeType: _feeType,
        status: _status,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (widget.fee == null) {
        await _databaseHelper.insertFee(fee);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fee added successfully'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        }
      } else {
        await _databaseHelper.updateFee(fee);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fee updated successfully'), backgroundColor: Colors.blue),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fee == null ? 'Add Fee' : 'Edit Fee',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveFee,
            child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fee Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      
                      DropdownButtonFormField<Member>(
                        value: _selectedMember,
                        decoration: const InputDecoration(
                          labelText: 'Member *',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        items: _members.map((member) {
                          return DropdownMenuItem(value: member, child: Text(member.name));
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedMember = value),
                        validator: (value) => value == null ? 'Please select a member' : null,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount *',
                          prefixIcon: Icon(Icons.currency_rupee),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter amount';
                          if (double.tryParse(value) == null) return 'Please enter valid amount';
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      DropdownButtonFormField<String>(
                        value: _feeType,
                        decoration: const InputDecoration(
                          labelText: 'Fee Type',
                          prefixIcon: Icon(Icons.category),
                          border: OutlineInputBorder(),
                        ),
                        items: _feeTypes.map((type) {
                          return DropdownMenuItem(value: type, child: Text(type));
                        }).toList(),
                        onChanged: (value) => setState(() => _feeType = value!),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      ListTile(
                        title: const Text('Due Date'),
                        subtitle: Text(DateFormat('dd MMM yyyy').format(_dueDate)),
                        leading: const Icon(Icons.calendar_today),
                        trailing: const Icon(Icons.edit),
                        onTap: _selectDueDate,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      DropdownButtonFormField<String>(
                        value: _status,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          prefixIcon: Icon(Icons.info),
                          border: OutlineInputBorder(),
                        ),
                        items: _statuses.map((status) {
                          return DropdownMenuItem(value: status, child: Text(status));
                        }).toList(),
                        onChanged: (value) => setState(() => _status = value!),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      if (_status == 'paid')
                        ListTile(
                          title: const Text('Paid Date'),
                          subtitle: Text(_paidDate != null ? DateFormat('dd MMM yyyy').format(_paidDate!) : 'Not set'),
                          leading: const Icon(Icons.payment),
                          trailing: const Icon(Icons.edit),
                          onTap: _selectPaidDate,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          prefixIcon: Icon(Icons.note),
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveFee,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(widget.fee == null ? 'Add Fee' : 'Update Fee', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
