class Fee {
  final int? id;
  final int memberId;
  final double amount;
  final DateTime dueDate;
  final DateTime? paidDate;
  final String feeType; // 'monthly', 'annual', 'registration'
  final String status; // 'pending', 'paid', 'overdue'
  final String? notes;

  Fee({
    this.id,
    required this.memberId,
    required this.amount,
    required this.dueDate,
    this.paidDate,
    required this.feeType,
    this.status = 'pending',
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'memberId': memberId,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'paidDate': paidDate?.toIso8601String(),
      'feeType': feeType,
      'status': status,
      'notes': notes,
    };
  }

  factory Fee.fromMap(Map<String, dynamic> map) {
    return Fee(
      id: map['id'],
      memberId: map['memberId'],
      amount: map['amount'],
      dueDate: DateTime.parse(map['dueDate']),
      paidDate: map['paidDate'] != null 
          ? DateTime.parse(map['paidDate']) 
          : null,
      feeType: map['feeType'],
      status: map['status'],
      notes: map['notes'],
    );
  }

  Fee copyWith({
    int? id,
    int? memberId,
    double? amount,
    DateTime? dueDate,
    DateTime? paidDate,
    String? feeType,
    String? status,
    String? notes,
  }) {
    return Fee(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      paidDate: paidDate ?? this.paidDate,
      feeType: feeType ?? this.feeType,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  bool get isOverdue {
    return status == 'pending' && DateTime.now().isAfter(dueDate);
  }

  bool get isPaid {
    return status == 'paid' && paidDate != null;
  }
}
