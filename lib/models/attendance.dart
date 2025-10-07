class Attendance {
  final int? id;
  final int memberId;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final String notes;

  Attendance({
    this.id,
    required this.memberId,
    required this.checkInTime,
    this.checkOutTime,
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'memberId': memberId,
      'checkInTime': checkInTime.toIso8601String(),
      'checkOutTime': checkOutTime?.toIso8601String(),
      'notes': notes,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'],
      memberId: map['memberId'],
      checkInTime: DateTime.parse(map['checkInTime']),
      checkOutTime: map['checkOutTime'] != null 
          ? DateTime.parse(map['checkOutTime']) 
          : null,
      notes: map['notes'] ?? '',
    );
  }

  Attendance copyWith({
    int? id,
    int? memberId,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    String? notes,
  }) {
    return Attendance(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      notes: notes ?? this.notes,
    );
  }

  Duration? get duration {
    if (checkOutTime != null) {
      return checkOutTime!.difference(checkInTime);
    }
    return null;
  }

  bool get isActive {
    return checkOutTime == null;
  }
}
