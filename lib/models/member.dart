class Member {
  final int? id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final DateTime joinDate;
  final String membershipPlan;
  final bool isActive;
  final DateTime? lastAttendance;

  Member({
    this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.joinDate,
    required this.membershipPlan,
    this.isActive = true,
    this.lastAttendance,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'joinDate': joinDate.toIso8601String(),
      'membershipPlan': membershipPlan,
      'isActive': isActive ? 1 : 0,
      'lastAttendance': lastAttendance?.toIso8601String(),
    };
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      phone: map['phone'],
      address: map['address'],
      joinDate: DateTime.parse(map['joinDate']),
      membershipPlan: map['membershipPlan'],
      isActive: map['isActive'] == 1,
      lastAttendance: map['lastAttendance'] != null 
          ? DateTime.parse(map['lastAttendance']) 
          : null,
    );
  }

  Member copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    DateTime? joinDate,
    String? membershipPlan,
    bool? isActive,
    DateTime? lastAttendance,
  }) {
    return Member(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      joinDate: joinDate ?? this.joinDate,
      membershipPlan: membershipPlan ?? this.membershipPlan,
      isActive: isActive ?? this.isActive,
      lastAttendance: lastAttendance ?? this.lastAttendance,
    );
  }
}
