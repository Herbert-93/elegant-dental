import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid, name, email, role;
  final bool active;
  AppUser(
      {required this.uid,
      required this.name,
      required this.email,
      required this.role,
      required this.active});
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
  final String id,
      date,
      name,
      address,
      phone,
      email,
      treatment,
      paymentMethod,
      notes,
      status,
      createdBy,
      treatedBy;
  final int number, age;
  final double? cost;
  final double balance;
  final String nextAppointment;
  final DateTime? createdAt, treatedAt;

  Visit({
    required this.id,
    required this.date,
    required this.number,
    required this.name,
    required this.age,
    required this.address,
    required this.phone,
    required this.email,
    required this.treatment,
    required this.cost,
    required this.paymentMethod,
    required this.notes,
    required this.status,
    required this.createdBy,
    required this.treatedBy,
    required this.createdAt,
    required this.treatedAt,
    this.balance = 0,
    this.nextAppointment = '',
  });

  bool get treated => status == 'treated';
  String get receiptNo =>
      'EDC-${date.replaceAll('-', '')}-${number.toString().padLeft(3, '0')}';

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
      email: (m['email'] ?? '') as String,
      treatment: (m['treatment'] ?? '') as String,
      cost: (m['cost'] as num?)?.toDouble(),
      paymentMethod: (m['paymentMethod'] ?? '') as String,
      notes: (m['notes'] ?? '') as String,
      status: (m['status'] ?? 'waiting') as String,
      createdBy: (m['createdByName'] ?? '') as String,
      treatedBy: (m['treatedByName'] ?? '') as String,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      treatedAt: (m['treatedAt'] as Timestamp?)?.toDate(),
      balance: (m['balance'] as num?)?.toDouble() ?? 0,
      nextAppointment: (m['nextAppointment'] ?? '') as String,
    );
  }
}

class Appointment {
  final String id, name, phone, reason, date, time, status, createdBy;
  Appointment({
    required this.id,
    required this.name,
    required this.phone,
    required this.reason,
    required this.date,
    required this.time,
    required this.status,
    required this.createdBy,
  });

  bool get scheduled => status == 'scheduled';

  factory Appointment.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Appointment(
      id: d.id,
      name: (m['name'] ?? '') as String,
      phone: (m['phone'] ?? '') as String,
      reason: (m['reason'] ?? '') as String,
      date: (m['date'] ?? '') as String,
      time: (m['time'] ?? '') as String,
      status: (m['status'] ?? 'scheduled') as String,
      createdBy: (m['createdByName'] ?? '') as String,
    );
  }
}

class Expense {
  final String id, date, description, category, createdBy;
  final double amount;
  final DateTime? createdAt;
  Expense(
      {required this.id,
      required this.date,
      required this.description,
      required this.category,
      required this.amount,
      required this.createdBy,
      required this.createdAt});

  factory Expense.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Expense(
      id: d.id,
      date: (m['date'] ?? '') as String,
      description: (m['description'] ?? '') as String,
      category: (m['category'] ?? 'Other') as String,
      amount: (m['amount'] as num?)?.toDouble() ?? 0,
      createdBy: (m['createdByName'] ?? '') as String,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// A medical form written for one patient (created on demand, not for every patient).
class MedicalForm {
  final String id,
      patientName,
      phone,
      email,
      address,
      complaints,
      notes,
      diagnosis,
      management,
      treatment,
      formBy,
      createdBy;
  final int age;
  final DateTime? createdAt;
  MedicalForm({
    required this.id,
    required this.patientName,
    required this.age,
    required this.phone,
    required this.email,
    required this.address,
    required this.complaints,
    required this.notes,
    required this.diagnosis,
    required this.management,
    required this.treatment,
    required this.formBy,
    required this.createdBy,
    required this.createdAt,
  });

  String get formNo {
    final d = createdAt ?? DateTime.now();
    final ymd =
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    final tail = id.length >= 4 ? id.substring(0, 4).toUpperCase() : id;
    return 'EDC-MF-$ymd-$tail';
  }

  factory MedicalForm.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return MedicalForm(
      id: d.id,
      patientName: (m['name'] ?? '') as String,
      age: (m['age'] as num?)?.toInt() ?? 0,
      phone: (m['phone'] ?? '') as String,
      email: (m['email'] ?? '') as String,
      address: (m['address'] ?? '') as String,
      complaints: (m['complaints'] ?? '') as String,
      notes: (m['notes'] ?? '') as String,
      diagnosis: (m['diagnosis'] ?? '') as String,
      management: (m['management'] ?? '') as String,
      treatment: (m['treatment'] ?? '') as String,
      formBy: (m['formBy'] ?? '') as String,
      createdBy: (m['createdByName'] ?? '') as String,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
