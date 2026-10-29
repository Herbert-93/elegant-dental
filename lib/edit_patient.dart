import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'services.dart';
import 'theme.dart';
import 'widgets.dart';

/// Lets staff correct a patient's details after they were entered.
/// The correction is applied to every record of that patient (visits, medical forms, appointments),
/// so the history, receipts and medical forms all show the corrected details.
/// [withTreatment] also lets the "Treatment the patient came for" of this one visit be corrected.
/// Returns true when the changes were saved.
Future<bool> showEditPatientDialog(BuildContext context, Visit v,
    {required bool withTreatment}) async {
  final r = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditPatientDialog(v: v, withTreatment: withTreatment));
  return r == true;
}

class _EditPatientDialog extends StatefulWidget {
  final Visit v;
  final bool withTreatment;
  const _EditPatientDialog({required this.v, required this.withTreatment});
  @override
  State<_EditPatientDialog> createState() => _EditPatientDialogState();
}

class _EditPatientDialogState extends State<_EditPatientDialog> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.v.name);
  late final age = TextEditingController(text: '${widget.v.age}');
  late final phone = TextEditingController(text: widget.v.phone);
  late final email = TextEditingController(text: widget.v.email);
  late final address = TextEditingController(text: widget.v.address);
  late final nextOfKin = TextEditingController(text: widget.v.nextOfKin);
  late final treatment = TextEditingController(text: widget.v.treatment);
  bool busy = false;
  late bool _minor = _isMinor();

  bool _isMinor() {
    final a = int.tryParse(age.text.trim());
    return a != null && a < 18;
  }

  @override
  void initState() {
    super.initState();
    age.addListener(() {
      final m = _isMinor();
      if (m != _minor && mounted) setState(() => _minor = m);
    });
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await Svc.updatePatient(
        widget.v,
        name: name.text.trim(),
        age: int.parse(age.text.trim()),
        phone: phone.text.trim(),
        email: email.text.trim(),
        address: address.text.trim(),
        nextOfKin: _minor ? nextOfKin.text.trim() : '',
        treatment: widget.withTreatment ? treatment.text.trim() : null,
      );
      nav.pop(true);
      messenger.showSnackBar(SnackBar(
          content: Text('${name.text.trim()}: patient details updated.')));
    } catch (e) {
      if (mounted) setState(() => busy = false);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return appDialog(
      context,
      title: 'Edit patient details',
      subtitle: 'Correct any mistake - it updates all records of this patient',
      content: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            field(name, 'Full name', icon: Icons.person_outline),
            field(age, 'Age',
                type: TextInputType.number,
                fmt: [FilteringTextInputFormatter.digitsOnly],
                icon: Icons.cake_outlined),
            field(phone, 'Phone number',
                type: TextInputType.phone, icon: Icons.phone_outlined),
            field(email, 'Email address (optional)',
                type: TextInputType.emailAddress,
                required: false,
                icon: Icons.email_outlined),
            field(address, 'Address', icon: Icons.location_on_outlined),
            if (_minor)
              field(nextOfKin, 'Next of kin (patient is under 18)',
                  required: false, icon: Icons.family_restroom_outlined),
            if (widget.withTreatment)
              field(treatment, 'Treatment the patient came for',
                  maxLines: 2, icon: Icons.medical_services_outlined),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: busy ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton.icon(
            onPressed: busy ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(busy ? 'Saving...' : 'Save changes')),
      ],
    );
  }
}
