import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'models.dart';

class Svc {
  static final db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get visits => db.collection('visits');
  static CollectionReference<Map<String, dynamic>> get users => db.collection('users');

  static String todayStr() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  static Future<AppUser?> loadUser(String uid) async {
    final d = await users.doc(uid).get();
    if (!d.exists) return null;
    return AppUser.fromDoc(d);
  }

  static Stream<List<Visit>> visitsForDate(String date) =>
      visits.where('date', isEqualTo: date).snapshots().map((s) {
        final l = s.docs.map(Visit.fromDoc).toList();
        l.sort((a, b) => a.number.compareTo(b.number));
        return l;
      });

  static Stream<List<Visit>> allVisits() =>
      visits.orderBy('createdAt', descending: true).limit(2000).snapshots().map((s) => s.docs.map(Visit.fromDoc).toList());

  static Future<void> addVisit({
    required int number, required String name, required int age, required String address,
    required String phone, required String treatment, required AppUser by,
  }) async {
    final date = todayStr();
    final dup = await visits.where('date', isEqualTo: date).where('number', isEqualTo: number).limit(1).get();
    if (dup.docs.isNotEmpty) throw 'Patient number $number has already been used today.';
    await visits.add({
      'date': date, 'number': number, 'name': name, 'age': age, 'address': address, 'phone': phone,
      'treatment': treatment, 'status': 'waiting', 'cost': null, 'paymentMethod': '', 'notes': '',
      'createdBy': by.uid, 'createdByName': by.name, 'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> recordTreatment(String id, double cost, String method, String notes, AppUser by) =>
      visits.doc(id).update({
        'status': 'treated', 'cost': cost, 'paymentMethod': method, 'notes': notes,
        'treatedAt': FieldValue.serverTimestamp(), 'treatedBy': by.uid, 'treatedByName': by.name,
      });

  static Future<void> deleteVisit(String id) => visits.doc(id).delete();

  static Stream<List<AppUser>> staff() => users.snapshots().map((s) {
        final l = s.docs.map(AppUser.fromDoc).toList();
        l.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return l;
      });

  static Future<void> setActive(String uid, bool active) => users.doc(uid).update({'active': active});

  /// Creates a login for a staff member without logging the admin out (uses a secondary Firebase app).
  static Future<void> createStaff({
    required String name, required String email, required String password, required String role,
  }) async {
    final app = await Firebase.initializeApp(name: 'staffCreator', options: Firebase.app().options);
    try {
      final auth = FirebaseAuth.instanceFor(app: app);
      final cred = await auth.createUserWithEmailAndPassword(email: email, password: password);
      await users.doc(cred.user!.uid).set({
        'name': name, 'email': email, 'role': role, 'active': true, 'createdAt': FieldValue.serverTimestamp(),
      });
      await auth.signOut();
    } finally {
      await app.delete();
    }
  }
}
