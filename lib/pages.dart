import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'config.dart';
import 'models.dart';
import 'services.dart';
import 'widgets.dart';

/// Shared day view.
/// dashboard=false -> Operations screen (today, register patients).
/// dashboard=true  -> Admin dashboard (any date, revenue, no registering).
class DayPage extends StatefulWidget {
  final AppUser user;
  final bool dashboard;
  const DayPage({super.key, required this.user, this.dashboard = false});
  @override
  State<DayPage> createState() => _DayPageState();
}

class _DayPageState extends State<DayPage> {
  String date = Svc.todayStr();

  Future<void> _pick() async {
    final p = await showDatePicker(context: context, initialDate: DateTime.parse(date), firstDate: DateTime(2020), lastDate: DateTime.now());
    if (p != null) setState(() => date = DateFormat('yyyy-MM-dd').format(p));
  }

  @override
  Widget build(BuildContext context) {
    final isDash = widget.dashboard;
    final d = isDash ? date : Svc.todayStr();
    return StreamBuilder<List<Visit>>(
      stream: Svc.visitsForDate(d),
      builder: (c, s) {
        if (s.hasError) return Center(child: Text('Error: ${s.error}'));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final list = s.data!;
        final treated = list.where((v) => v.treated).toList();
        final revenue = treated.fold<double>(0, (a, v) => a + (v.cost ?? 0));
        final next = list.isEmpty ? 1 : list.map((v) => v.number).reduce((a, b) => a > b ? a : b) + 1;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(isDash ? 'Dashboard - ${niceDate(d)}' : "Today's Operations - ${niceDate(d)}",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            if (isDash) OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.calendar_month), label: const Text('Change date')),
            if (isDash && date != Svc.todayStr())
              TextButton(onPressed: () => setState(() => date = Svc.todayStr()), child: const Text('Back to today')),
            if (!isDash)
              FilledButton.icon(onPressed: () => showRegisterDialog(context, widget.user, next), icon: const Icon(Icons.person_add), label: const Text('Register Patient')),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            StatCard('Patients', '${list.length}', Icons.groups),
            StatCard('Treated', '${treated.length}', Icons.check_circle_outline),
            StatCard('Waiting', '${list.length - treated.length}', Icons.hourglass_bottom),
            if (isDash) StatCard('Revenue', money(revenue), Icons.payments_outlined),
          ]),
          const SizedBox(height: 8),
          VisitTable(visits: list, user: widget.user),
        ]);
      },
    );
  }
}

/// All patient records (every visit ever saved), searchable.
class RecordsPage extends StatefulWidget {
  final AppUser user;
  const RecordsPage({super.key, required this.user});
  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  String q = '', status = 'all';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Visit>>(
      stream: Svc.allVisits(),
      builder: (c, s) {
        if (s.hasError) return Center(child: Text('Error: ${s.error}'));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final needle = q.trim().toLowerCase();
        final list = s.data!.where((v) {
          if (status == 'treated' && !v.treated) return false;
          if (status == 'waiting' && v.treated) return false;
          if (needle.isEmpty) return true;
          return v.name.toLowerCase().contains(needle) || v.phone.toLowerCase().contains(needle) ||
              v.treatment.toLowerCase().contains(needle) || v.date.contains(needle) || v.receiptNo.toLowerCase().contains(needle);
        }).toList();
        final total = list.where((v) => v.treated).fold<double>(0, (a, v) => a + (v.cost ?? 0));
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('Patient Records', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 340,
              child: TextField(
                onChanged: (v) => setState(() => q = v),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name, phone, treatment, date (yyyy-mm-dd), receipt no', border: OutlineInputBorder(), isDense: true),
              ),
            ),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('All')),
                ButtonSegment(value: 'waiting', label: Text('Waiting')),
                ButtonSegment(value: 'treated', label: Text('Treated')),
              ],
              selected: {status},
              onSelectionChanged: (x) => setState(() => status = x.first),
            ),
            Text('${list.length} record(s)'),
            if (widget.user.isAdmin) Text('Revenue (shown): ${money(total)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          VisitTable(visits: list, user: widget.user, showDate: true),
        ]);
      },
    );
  }
}

/// Admin only: manage staff logins.
class StaffPage extends StatelessWidget {
  final AppUser me;
  const StaffPage({super.key, required this.me});

  Future<void> _add(BuildContext context) => showDialog(context: context, barrierDismissible: false, builder: (_) => const _AddStaffDialog());

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: Svc.staff(),
      builder: (c, s) {
        if (s.hasError) return Center(child: Text('Error: ${s.error}'));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Expanded(child: Text('Staff Accounts', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
            FilledButton.icon(onPressed: () => _add(context), icon: const Icon(Icons.person_add_alt_1), label: const Text('Add Staff')),
          ]),
          const SizedBox(height: 8),
          Card(
            child: Column(children: s.data!.map((u) => ListTile(
                  leading: CircleAvatar(child: Icon(u.isAdmin ? Icons.admin_panel_settings : Icons.badge)),
                  title: Text(u.name),
                  subtitle: Text('${u.email}  -  ${u.isAdmin ? 'Admin' : 'Operations'}'),
                  trailing: u.uid == me.uid
                      ? const Text('You')
                      : Switch(value: u.active, onChanged: (v) => Svc.setActive(u.uid, v)),
                )).toList()),
          ),
        ]);
      },
    );
  }
}

class _AddStaffDialog extends StatefulWidget {
  const _AddStaffDialog();
  @override
  State<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<_AddStaffDialog> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(), email = TextEditingController(), pass = TextEditingController();
  String role = 'operations';
  bool busy = false;

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await Svc.createStaff(name: name.text.trim(), email: email.text.trim(), password: pass.text, role: role);
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text('Account created for ${name.text.trim()}.')));
    } catch (e) {
      if (mounted) setState(() => busy = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not create account: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add Staff'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                field(name, 'Full name'),
                field(email, 'Email', type: TextInputType.emailAddress),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: pass, obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password (min 6 characters)', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'operations', child: Text('Operations')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => setState(() => role = v ?? role),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: busy ? null : _save, child: Text(busy ? 'Creating...' : 'Create')),
        ],
      );
}
