import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'models.dart';

class Svc {
  static final db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get visits =>
      db.collection('visits');
  static CollectionReference<Map<String, dynamic>> get users =>
      db.collection('users');
  static CollectionReference<Map<String, dynamic>> get appts =>
      db.collection('appointments');
  static CollectionReference<Map<String, dynamic>> get expenses =>
      db.collection('expenses');
  static CollectionReference<Map<String, dynamic>> get medForms =>
      db.collection('medical_forms');

  static String fmtDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  static String todayStr() => fmtDate(DateTime.now());

  static Future<AppUser?> loadUser(String uid) async {
    final d = await users.doc(uid).get();
    if (!d.exists) return null;
    return AppUser.fromDoc(d);
  }

  // ------------------------------------------------------------ visits
  static Stream<List<Visit>> visitsForDate(String date) =>
      visits.where('date', isEqualTo: date).snapshots().map((s) {
        final l = s.docs.map(Visit.fromDoc).toList();
        l.sort((a, b) => a.number.compareTo(b.number));
        return l;
      });

  static Stream<List<Visit>> visitsSince(String fromDate) => visits
      .where('date', isGreaterThanOrEqualTo: fromDate)
      .snapshots()
      .map((s) => s.docs.map(Visit.fromDoc).toList());

  static Stream<List<Visit>> allVisits() => visits
      .orderBy('createdAt', descending: true)
      .limit(2000)
      .snapshots()
      .map((s) => s.docs.map(Visit.fromDoc).toList());

  static String _sameName(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Every visit ever recorded for ONE patient (same name; phone is used only to narrow the search,
  /// so other people who share the phone number are not included).
  static Stream<List<Visit>> visitsForPatient(String phone, String name) {
    final q = phone.trim().isNotEmpty
        ? visits.where('phone', isEqualTo: phone.trim())
        : visits.where('name', isEqualTo: name);
    return q.snapshots().map((s) {
      final l = s.docs
          .map(Visit.fromDoc)
          .where((v) => _sameName(v.name) == _sameName(name))
          .toList();
      l.sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.number.compareTo(a.number);
      });
      return l;
    });
  }

  static Future<int> nextNumber() async {
    final s = await visits.where('date', isEqualTo: todayStr()).get();
    var m = 0;
    for (final d in s.docs) {
      final n = (d.data()['number'] as num?)?.toInt() ?? 0;
      if (n > m) m = n;
    }
    return m + 1;
  }

  static Future<void> addVisit({
    required int number,
    required String name,
    required int age,
    required String address,
    required String phone,
    String email = '',
    String nextOfKin = '',
    required String treatment,
    required AppUser by,
  }) async {
    final date = todayStr();
    final dup = await visits
        .where('date', isEqualTo: date)
        .where('number', isEqualTo: number)
        .limit(1)
        .get();
    if (dup.docs.isNotEmpty)
      throw 'Patient number $number has already been used today.';
    await visits.add({
      'date': date,
      'number': number,
      'name': name,
      'age': age,
      'address': address,
      'phone': phone,
      'email': email,
      'nextOfKin': nextOfKin,
      'treatment': treatment,
      'status': 'waiting',
      'cost': null,
      'paymentMethod': '',
      'notes': '',
      'createdBy': by.uid,
      'createdByName': by.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> recordTreatment(
      String id, double cost, String method, String notes, AppUser by,
      {double balance = 0,
      String nextAppointment = '',
      String doctor = '',
      Map<String, double>? payments,
      List<Medicine> medicines = const []}) {
    // [cost] is the grand total = treatment + medicines.
    // One entry = single method; several entries = the customer split the payment.
    final split = <String, double>{
      for (final e in (payments ?? {method: cost}).entries)
        if (e.value > 0) e.key: e.value
    };
    final label = split.isEmpty ? method : split.keys.join(' + ');
    return visits.doc(id).update({
      'status': 'treated',
      'cost': cost,
      'paymentMethod': label,
      'payments': split,
      'medicines': medicines.map((m) => m.toMap()).toList(),
      'medicineTotal': medicines.fold<double>(0, (a, m) => a + m.cost),
      'notes': notes,
      'balance': balance,
      'nextAppointment': nextAppointment,
      'doctor': doctor,
      'treatedAt': FieldValue.serverTimestamp(),
      'treatedBy': by.uid,
      'treatedByName': by.name,
    });
  }

  static Future<void> deleteVisit(String id) => visits.doc(id).delete();

  // ------------------------------------------------------------ edit patient
  /// Corrects a patient's details on every record of that patient (visits, medical forms, appointments).
  /// [treatment], when given, only changes the "came for" text of the visit [old] itself.
  static Future<void> updatePatient(
    Visit old, {
    required String name,
    required int age,
    required String phone,
    required String email,
    required String address,
    required String nextOfKin,
    String? treatment,
  }) async {
    final oldPhone = old.phone.trim();
    Query<Map<String, dynamic>> mine(
            CollectionReference<Map<String, dynamic>> c) =>
        oldPhone.isNotEmpty
            ? c.where('phone', isEqualTo: oldPhone)
            : c.where('name', isEqualTo: old.name);
    final results = await Future.wait([
      mine(visits).get(),
      mine(medForms).get(),
      mine(appts).get(),
    ]);
    final wanted = _sameName(old.name);
    bool isHers(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
        _sameName((d.data()['name'] ?? '') as String) == wanted;
    final batch = db.batch();
    for (final d in results[0].docs.where(isHers)) {
      batch.update(d.reference, {
        'name': name,
        'age': age,
        'phone': phone,
        'email': email,
        'address': address,
        'nextOfKin': nextOfKin,
        if (treatment != null && d.id == old.id) 'treatment': treatment,
      });
    }
    for (final d in results[1].docs.where(isHers)) {
      batch.update(d.reference, {
        'name': name,
        'age': age,
        'phone': phone,
        'email': email,
        'address': address,
        'nextOfKin': nextOfKin,
      });
    }
    for (final d in results[2].docs.where(isHers)) {
      batch.update(d.reference, {'name': name, 'phone': phone});
    }
    await batch.commit();
  }

  // ------------------------------------------------------------ medical forms
  /// Every medical form written for one patient (matched by phone; by name if no phone), newest first.
  static Stream<List<MedicalForm>> medicalFormsForPatient(
      String phone, String name) {
    final q = phone.trim().isNotEmpty
        ? medForms.where('phone', isEqualTo: phone.trim())
        : medForms.where('name', isEqualTo: name);
    return q.snapshots().map((s) {
      final l = s.docs
          .map(MedicalForm.fromDoc)
          .where((f) => _sameName(f.patientName) == _sameName(name))
          .toList();
      l.sort((a, b) => (b.createdAt ?? DateTime.now())
          .compareTo(a.createdAt ?? DateTime.now()));
      return l;
    });
  }

  /// Saves the form and returns its id.
  static Future<String> addMedicalForm({
    required String name,
    required int age,
    required String phone,
    required String email,
    required String address,
    String nextOfKin = '',
    required String complaints,
    required String notes,
    required String diagnosis,
    required String management,
    required String treatment,
    required String formBy,
    required AppUser by,
  }) async {
    final ref = await medForms.add({
      'name': name,
      'age': age,
      'phone': phone.trim(),
      'email': email,
      'address': address,
      'nextOfKin': nextOfKin,
      'complaints': complaints,
      'notes': notes,
      'diagnosis': diagnosis,
      'management': management,
      'treatment': treatment,
      'formBy': formBy,
      'createdBy': by.uid,
      'createdByName': by.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  static Future<void> deleteMedicalForm(String id) => medForms.doc(id).delete();

  // ------------------------------------------------------------ expenses
  static Stream<List<Expense>> expensesForDate(String date) =>
      expenses.where('date', isEqualTo: date).snapshots().map((s) {
        final l = s.docs.map(Expense.fromDoc).toList();
        l.sort((a, b) => (a.createdAt ?? DateTime.now())
            .compareTo(b.createdAt ?? DateTime.now()));
        return l;
      });

  static Future<void> addExpense({
    required String date,
    required String description,
    required String category,
    required double amount,
    required AppUser by,
  }) =>
      expenses.add({
        'date': date,
        'description': description,
        'category': category,
        'amount': amount,
        'createdBy': by.uid,
        'createdByName': by.name,
        'createdAt': FieldValue.serverTimestamp(),
      });

  static Future<void> updateExpense(String id,
          {required String description,
          required String category,
          required double amount}) =>
      expenses.doc(id).update(
          {'description': description, 'category': category, 'amount': amount});

  static Future<void> deleteExpense(String id) => expenses.doc(id).delete();

  // ------------------------------------------------------------ appointments
  /// Appointments from 30 days ago onwards, sorted by date then time.
  static Stream<List<Appointment>> appointments() {
    final from = fmtDate(DateTime.now().subtract(const Duration(days: 30)));
    return appts
        .where('date', isGreaterThanOrEqualTo: from)
        .orderBy('date')
        .snapshots()
        .map((s) {
      final l = s.docs.map(Appointment.fromDoc).toList();
      l.sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : a.time.compareTo(b.time);
      });
      return l;
    });
  }

  static Stream<List<Appointment>> appointmentsForPhone(String phone) {
    if (phone.trim().isEmpty) return Stream.value(<Appointment>[]);
    return appts.where('phone', isEqualTo: phone.trim()).snapshots().map((s) {
      final l = s.docs.map(Appointment.fromDoc).toList();
      l.sort((a, b) => b.date.compareTo(a.date));
      return l;
    });
  }

  /// Number of scheduled appointments that are today or overdue (drives the red badge).
  static Stream<int> appointmentAlerts() => appointments().map((l) =>
      l.where((a) => a.scheduled && a.date.compareTo(todayStr()) <= 0).length);

  static Future<void> addAppointment({
    required String name,
    required String phone,
    required String reason,
    required String date,
    required String time,
    required AppUser by,
  }) =>
      appts.add({
        'name': name,
        'phone': phone,
        'reason': reason,
        'date': date,
        'time': time,
        'status': 'scheduled',
        'createdBy': by.uid,
        'createdByName': by.name,
        'createdAt': FieldValue.serverTimestamp(),
      });

  static Future<void> setAppointmentStatus(String id, String status) =>
      appts.doc(id).update({'status': status});
  static Future<void> deleteAppointment(String id) => appts.doc(id).delete();

  // ------------------------------------------------------------ staff
  static Stream<List<AppUser>> staff() => users.snapshots().map((s) {
        final l = s.docs.map(AppUser.fromDoc).toList();
        l.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return l;
      });

  static Future<void> setActive(String uid, bool active) =>
      users.doc(uid).update({'active': active});

  /// Creates a login for a staff member without logging the admin out (uses a secondary Firebase app).
  static Future<void> createStaff({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final app = await Firebase.initializeApp(
        name: 'staffCreator', options: Firebase.app().options);
    try {
      final auth = FirebaseAuth.instanceFor(app: app);
      final cred = await auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await users.doc(cred.user!.uid).set({
        'name': name,
        'email': email,
        'role': role,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await auth.signOut();
    } finally {
      await app.delete();
    }
  }
}
