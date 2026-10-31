import 'package:cloud_firestore/cloud_firestore.dart';
import 'config.dart';

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

/// One medicine given to a patient, with its own price.
class Medicine {
  final String name;
  final double cost;
  const Medicine(this.name, this.cost);
  Map<String, dynamic> toMap() => {'name': name, 'cost': cost};
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
  final String nextOfKin;
  final DateTime? createdAt, treatedAt;

  String doctor;

  /// How the cost was paid, per method (e.g. {Cash: 50000, MTN Mobile Money: 50000}).
  /// Empty on old records that were saved with a single payment method.
  final Map<String, double> payments;

  /// Medicines given on this visit. [cost] is always the GRAND TOTAL
  /// (treatment + medicines), so every total in the app stays correct.
  final List<Medicine> medicines;

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
    this.nextOfKin = '',
    this.doctor = '',
    this.payments = const {},
    this.medicines = const [],
  });

  double get medicineTotal => medicines.fold<double>(0, (a, m) => a + m.cost);

  /// The treatment on its own (grand total minus medicines).
  double get treatmentCost {
    final t = (cost ?? 0) - medicineTotal;
    return t < 0 ? 0 : t;
  }

  /// e.g. "Amoxicillin (UGX 5,000), Painkillers (UGX 5,000)"
  String get medicineSummary =>
      medicines.map((m) => '${m.name} (${money(m.cost)})').join(', ');

  bool get treated => status == 'treated';

  /// True when the customer paid with more than one method.
  bool get isSplitPayment => payments.length > 1;

  /// Amount received per method. Old single-method records fall back to the whole cost.
  Map<String, double> get paymentSplit {
    if (payments.isNotEmpty) return payments;
    return {paymentMethod.isEmpty ? 'Other' : paymentMethod: cost ?? 0};
  }

  /// Short label, e.g. "Cash + MTN Mobile Money" (or just "Cash").
  String get paymentLabel =>
      isSplitPayment ? payments.keys.join(' + ') : paymentMethod;

  /// Label with amounts for split payments, e.g. "Cash UGX 50,000 + MTN Mobile Money UGX 50,000".
  String get paymentDetail => isSplitPayment
      ? payments.entries.map((e) => '${e.key} ${money(e.value)}').join(' + ')
      : (paymentMethod.isEmpty ? '-' : paymentMethod);
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
      nextOfKin: (m['nextOfKin'] ?? '') as String,
      doctor: (m['doctor'] ?? '') as String,
      payments: {
        for (final e in ((m['payments'] as Map?) ?? const {}).entries)
          if (e.value is num) e.key.toString(): (e.value as num).toDouble()
      },
      medicines: [
        for (final e in ((m['medicines'] as List?) ?? const []))
          if (e is Map)
            Medicine((e['name'] ?? '').toString(),
                ((e['cost'] as num?) ?? 0).toDouble())
      ],
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
  final String nextOfKin;
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
    this.nextOfKin = '',
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
      nextOfKin: (m['nextOfKin'] ?? '') as String,
    );
  }
}
