import 'package:flutter/material.dart';
import 'appointments_page.dart';
import 'config.dart';
import 'expenses.dart';
import 'models.dart';
import 'services.dart';
import 'theme.dart';
import 'visit_table.dart';
import 'widgets.dart';

/// Operations screen: today's patients. Used by operations staff AND by admin (Operations tab).
class DayPage extends StatefulWidget {
  final AppUser user;
  const DayPage({super.key, required this.user});
  @override
  State<DayPage> createState() => _DayPageState();
}

class _DayPageState extends State<DayPage> {
  late final Stream<List<Visit>> stream = Svc.visitsForDate(Svc.todayStr());

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Visit>>(
      stream: stream,
      builder: (c, s) {
        if (s.hasError) return Center(child: Text('Error: ${s.error}'));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final list = s.data!;
        final treated = list.where((v) => v.treated).length;
        final next = list.isEmpty
            ? 1
            : list.map((v) => v.number).reduce((a, b) => a > b ? a : b) + 1;
        return PageScroll(children: [
          PageHeader(
            title: "Today's Operations",
            subtitle: niceDate(Svc.todayStr()),
            actions: [
              FilledButton.icon(
                  onPressed: () =>
                      showRegisterDialog(context, widget.user, next),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Register Patient')),
            ],
          ),
          TodayAppointmentsPanel(user: widget.user),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            StatCard('Patients today', '${list.length}', Icons.groups,
                color: AppColors.tealDark),
            StatCard('Treated', '$treated', Icons.check_circle,
                color: AppColors.green),
            StatCard(
                'Waiting', '${list.length - treated}', Icons.hourglass_bottom,
                color: AppColors.amber),
            StatCard(
                'Medicine sold today',
                money(list
                    .where((v) => v.treated)
                    .fold<double>(0, (a, v) => a + v.medicineTotal)),
                Icons.medication,
                color: AppColors.red,
                onTap: () => showMedicineDialog(context, list)),
          ]),
          const SizedBox(height: 16),
          DailySummaryPanel(
              user: widget.user, date: Svc.todayStr(), visits: list),
          const SizedBox(height: 18),
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
  late final Stream<List<Visit>> stream = Svc.allVisits();
  String q = '', status = 'all';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Visit>>(
      stream: stream,
      builder: (c, s) {
        if (s.hasError) return Center(child: Text('Error: ${s.error}'));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final needle = q.trim().toLowerCase();
        final list = s.data!.where((v) {
          if (status == 'treated' && !v.treated) return false;
          if (status == 'waiting' && v.treated) return false;
          if (needle.isEmpty) return true;
          return v.name.toLowerCase().contains(needle) ||
              v.phone.toLowerCase().contains(needle) ||
              v.email.toLowerCase().contains(needle) ||
              v.treatment.toLowerCase().contains(needle) ||
              v.date.contains(needle) ||
              v.receiptNo.toLowerCase().contains(needle);
        }).toList();
        final total = list
            .where((v) => v.treated)
            .fold<double>(0, (a, v) => a + (v.cost ?? 0));
        return PageScroll(children: [
          const PageHeader(
              title: 'Patient Records',
              subtitle:
                  'Click any patient name to open their complete history'),
          Panel(
            child: Wrap(
                spacing: 14,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 380,
                    child: TextField(
                      onChanged: (v) => setState(() => q = v),
                      decoration: deco(
                          'Search name, phone, email, treatment, date, receipt no',
                          icon: Icons.search),
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
                  Pill('${list.length} record(s)', AppColors.tealDark,
                      const Color(0xFFE0F4F3)),
                  if (widget.user.isAdmin)
                    Pill('Revenue: ${money(total)}', AppColors.green,
                        AppColors.greenBg,
                        icon: Icons.payments),
                ]),
          ),
          const SizedBox(height: 16),
          VisitTable(visits: list, user: widget.user, showDate: true),
        ]);
      },
    );
  }
}

/// Admin only: manage staff logins.
class StaffPage extends StatefulWidget {
  final AppUser me;
  const StaffPage({super.key, required this.me});
  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  late final Stream<List<AppUser>> stream = Svc.staff();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: stream,
      builder: (c, s) {
        if (s.hasError) return Center(child: Text('Error: ${s.error}'));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return PageScroll(children: [
          PageHeader(
            title: 'Staff Accounts',
            subtitle: 'Create logins and switch access on or off',
            actions: [
              FilledButton.icon(
                  onPressed: () => showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const _AddStaffDialog()),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Add Staff'))
            ],
          ),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final u in s.data!)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                      border: u == s.data!.first
                          ? null
                          : const Border(
                              top: BorderSide(color: AppColors.border))),
                  child: Row(children: [
                    Avatar(u.name,
                        size: 44,
                        color:
                            u.isAdmin ? AppColors.navy2 : AppColors.tealDark),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(u.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          Text(u.email,
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 13)),
                        ])),
                    u.isAdmin
                        ? const Pill(
                            'Admin', AppColors.navy2, Color(0xFFE3EEF4),
                            icon: Icons.admin_panel_settings)
                        : const Pill(
                            'Operations', AppColors.tealDark, Color(0xFFE0F4F3),
                            icon: Icons.badge),
                    const SizedBox(width: 14),
                    u.uid == widget.me.uid
                        ? const Text('You',
                            style: TextStyle(color: AppColors.muted))
                        : Switch(
                            value: u.active,
                            onChanged: (v) => Svc.setActive(u.uid, v)),
                  ]),
                ),
            ]),
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
  final name = TextEditingController(),
      email = TextEditingController(),
      pass = TextEditingController();
  String role = 'operations';
  bool busy = false;

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await Svc.createStaff(
          name: name.text.trim(),
          email: email.text.trim(),
          password: pass.text,
          role: role);
      nav.pop();
      messenger.showSnackBar(
          SnackBar(content: Text('Account created for ${name.text.trim()}.')));
    } catch (e) {
      if (mounted) setState(() => busy = false);
      messenger.showSnackBar(
          SnackBar(content: Text('Could not create account: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => appDialog(
        context,
        title: 'Add Staff',
        subtitle: 'They will log in with this email and password',
        width: 460,
        content: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              field(name, 'Full name', icon: Icons.person_outline),
              field(email, 'Email',
                  type: TextInputType.emailAddress, icon: Icons.email_outlined),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextFormField(
                  controller: pass,
                  obscureText: true,
                  decoration: deco('Password (min 6 characters)',
                      icon: Icons.lock_outline),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'At least 6 characters'
                      : null,
                ),
              ),
              DropdownButtonFormField<String>(
                value: role,
                decoration: deco('Role', icon: Icons.badge_outlined),
                items: const [
                  DropdownMenuItem(
                      value: 'operations',
                      child: Text('Operations (front desk / dentist)')),
                  DropdownMenuItem(
                      value: 'admin', child: Text('Admin (full access)')),
                ],
                onChanged: (v) => setState(() => role = v ?? role),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: busy ? null : _save,
              child: Text(busy ? 'Creating...' : 'Create account')),
        ],
      );
}
