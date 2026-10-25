import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid, name, email, role;
  final bool active;
  AppUser({required this.uid, required this.name, required this.email, required this.role, required this.active});
  bool get isAdmin => role == 'admin';

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return AppUser(
      uid: d.id,
      name: (m['name'] ?? '') as String,
      email: (m['email'] ?? '') as String,
      role: (m['role'] ?? 'operations') as String,
      active: (m['active'] ?? false) == true,
    );
  }
}

class Visit {
  final String id, date, name, address, phone, treatment, paymentMethod, notes, status, createdBy;
  final int number, age;
  final double? cost;
  final DateTime? createdAt, treatedAt;

  Visit({
    required this.id, required this.date, required this.number, required this.name, required this.age,
    required this.address, required this.phone, required this.treatment, required this.cost,
    required this.paymentMethod, required this.notes, required this.status, required this.createdBy,
    required this.createdAt, required this.treatedAt,
  });

  bool get treated => status == 'treated';
  String get receiptNo => 'EDC-${date.replaceAll('-', '')}-${number.toString().padLeft(3, '0')}';

  factory Visit.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Visit(
      id: d.id,
      date: (m['date'] ?? '') as String,
      number: (m['number'] as num?)?.toInt() ?? 0,
      name: (m['name'] ?? '') as String,
      age: (m['age'] as num?)?.toInt() ?? 0,
      address: (m['address'] ?? '') as String,
      phone: (m['phone'] ?? '') as String,
      treatment: (m['treatment'] ?? '') as String,
      cost: (m['cost'] as num?)?.toDouble(),
      paymentMethod: (m['paymentMethod'] ?? '') as String,
      notes: (m['notes'] ?? '') as String,
      status: (m['status'] ?? 'waiting') as String,
      createdBy: (m['createdByName'] ?? '') as String,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      treatedAt: (m['treatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
