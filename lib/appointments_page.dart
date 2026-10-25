import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'services.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> checkInAppointment(
    BuildContext context, AppUser user, Appointment a) async {
  final next = await Svc.nextNumber();
  if (!context.mounted) return;
  await showRegisterDialog(context, user, next, appt: a);
}

String _niceApptDate(String ymd) {
  final today = Svc.todayStr();
  final tomorrow = Svc.fmtDate(DateTime.now().add(const Duration(days: 1)));
  if (ymd == today) return 'Today';
  if (ymd == tomorrow) return 'Tomorrow';
  return DateFormat('EEE, d MMM').format(DateTime.parse(ymd));
}

// ------------------------------------------------------------------ RED appointment alert panel
/// Shows today's + overdue scheduled appointments in red. Used on Operations page and Admin dashboard.
class TodayAppointmentsPanel extends StatefulWidget {
  final AppUser user;
  const TodayAppointmentsPanel({super.key, required this.user});
  @override
  State<TodayAppointmentsPanel> createState() => _TodayAppointmentsPanelState();
}

class _TodayAppointmentsPanelState extends State<TodayAppointmentsPanel> {
  late final Stream<List<Appointment>> stream = Svc.appointments();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Appointment>>(
      stream: stream,
      builder: (c, s) {
        if (!s.hasData) return const SizedBox.shrink();
        final today = Svc.todayStr();
        final list = s.data!
            .where((a) => a.scheduled && a.date.compareTo(today) <= 0)
            .toList();
        if (list.isEmpty) {
          return const Panel(
            child: Row(children: [
              Icon(Icons.event_available, color: AppColors.green),
              SizedBox(width: 10),
              Expanded(
                  child: Text('No pending appointments for today.',
                      style: TextStyle(fontWeight: FontWeight.w600))),
            ]),
          );
        }
        return Panel(
          color: AppColors.redBg,
          borderColor: AppColors.red,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.notifications_active, color: AppColors.red),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Appointments needing attention (${list.length})',
                      style: const TextStyle(
                          color: AppColors.redDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 16))),
            ]),
            const SizedBox(height: 10),
            ...list.take(6).map((a) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.red.withOpacity(0.35))),
                  child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Pill(fmtTime(a.time), Colors.white, AppColors.red,
                            icon: Icons.access_time),
                        if (a.date != today)
                          const Pill(
                              'OVERDUE', Colors.white, AppColors.redDark),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                              minWidth: 160, maxWidth: 340),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.redDark)),
                                Text('${a.reason}  -  ${a.phone}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12.5)),
                              ]),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.red,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10)),
                          onPressed: () =>
                              checkInAppointment(context, widget.user, a),
                          child: const Text('Check in'),
                        ),
                      ]),
                )),
            if (list.length > 6)
              Text('+ ${list.length - 6} more in the Appointments page',
                  style: const TextStyle(color: AppColors.redDark)),
          ]),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ Appointments page
class AppointmentsPage extends StatefulWidget {
  final AppUser user;
  const AppointmentsPage({super.key, required this.user});
  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  late final Stream<List<Appointment>> stream = Svc.appointments();

  Widget _section(String title, List<Appointment> l, Color accent) {
    if (l.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 10),
        child: Row(children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.ink)),
          const SizedBox(width: 8),
          Pill('${l.length}', Colors.white, accent),
        ]),
      ),
      ...l.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppointmentCard(a: a, user: widget.user))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Appointment>>(
      stream: stream,
      builder: (c, s) {
        if (s.hasError) return Center(child: Text('Error: ${s.error}'));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final today = Svc.todayStr();
        final all = s.data!;
        final overdue = all
            .where((a) => a.scheduled && a.date.compareTo(today) < 0)
            .toList();
        final todayL =
            all.where((a) => a.scheduled && a.date == today).toList();
        final upcoming = all
            .where((a) => a.scheduled && a.date.compareTo(today) > 0)
            .toList();
        final history =
            all.where((a) => !a.scheduled).toList().reversed.take(30).toList();
        return PageScroll(children: [
          PageHeader(
            title: 'Appointments',
            subtitle:
                'Scheduled patients appear in red so they are impossible to miss',
            actions: [
              FilledButton.icon(
                  onPressed: () => showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => _NewAppointmentDialog(user: widget.user)),
                  icon: const Icon(Icons.add),
                  label: const Text('New Appointment'))
            ],
          ),
          Wrap(spacing: 12, runSpacing: 12, children: [
            StatCard('Today', '${todayL.length}', Icons.today,
                color: AppColors.red),
            StatCard(
                'Overdue', '${overdue.length}', Icons.warning_amber_rounded,
                color: AppColors.redDark),
            StatCard('Upcoming', '${upcoming.length}', Icons.event,
                color: AppColors.red),
          ]),
          _section('Overdue - patients who did not come', overdue,
              AppColors.redDark),
          _section('Today', todayL, AppColors.red),
          _section('Upcoming', upcoming, AppColors.red),
          if (overdue.isEmpty && todayL.isEmpty && upcoming.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Panel(
                  padding: EdgeInsets.all(40),
                  child: Center(
                      child: Column(children: [
                    Icon(Icons.event_available,
                        size: 46, color: AppColors.muted),
                    SizedBox(height: 8),
                    Text('No scheduled appointments',
                        style: TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600)),
                  ]))),
            ),
          _section('History (completed / cancelled)', history, AppColors.muted),
        ]);
      },
    );
  }
}

class AppointmentCard extends StatelessWidget {
  final Appointment a;
  final AppUser user;
  const AppointmentCard({super.key, required this.a, required this.user});

  @override
  Widget build(BuildContext context) {
    final today = Svc.todayStr();
    final overdue = a.scheduled && a.date.compareTo(today) < 0;
    final isToday = a.scheduled && a.date == today;
    final accent = !a.scheduled
        ? AppColors.muted
        : (overdue ? AppColors.redDark : AppColors.red);
    final bg = a.scheduled ? AppColors.redBg : Colors.white;

    final actions = Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (a.scheduled) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.red,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
              onPressed: () => checkInAppointment(context, user, a),
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Check in'),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: AppColors.red),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
              onPressed: () async {
                if (await confirm(context, 'Cancel appointment?',
                    'Cancel the appointment for ${a.name}?',
                    yes: 'Cancel it')) {
                  await Svc.setAppointmentStatus(a.id, 'cancelled');
                }
              },
              child: const Text('Cancel'),
            ),
          ] else
            Pill(
                a.status == 'completed' ? 'Completed' : 'Cancelled',
                a.status == 'completed' ? AppColors.green : AppColors.muted,
                a.status == 'completed' ? AppColors.greenBg : AppColors.bg),
          if (user.isAdmin)
            IconButton(
              tooltip: 'Delete',
              color: AppColors.red,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirm(context, 'Delete appointment?',
                    'Permanently delete this appointment?',
                    yes: 'Delete')) {
                  await Svc.deleteAppointment(a.id);
                }
              },
            ),
        ]);

    final info =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Flexible(
            child: Text(a.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: a.scheduled ? AppColors.redDark : AppColors.ink,
                    decoration: a.status == 'cancelled'
                        ? TextDecoration.lineThrough
                        : null))),
        const SizedBox(width: 8),
        if (isToday) const Pill('TODAY', Colors.white, AppColors.red),
        if (overdue) const Pill('OVERDUE', Colors.white, AppColors.redDark),
      ]),
      const SizedBox(height: 3),
      Text(a.reason, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 2),
      Text('${a.phone}  -  booked by ${a.createdBy}',
          style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
    ]);

    final timeBlock = SizedBox(
      width: 112,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(fmtTime(a.time),
            style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 21, color: accent)),
        Text(_niceApptDate(a.date),
            style: TextStyle(
                color: accent, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );

    return LayoutBuilder(builder: (context, bc) {
      final narrow = bc.maxWidth < 680;
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
              color: bg,
              border: Border.all(
                  color: a.scheduled
                      ? AppColors.red.withOpacity(0.35)
                      : AppColors.border)),
          child: IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 7, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: narrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              timeBlock,
                              const SizedBox(height: 8),
                              info,
                              const SizedBox(height: 10),
                              actions
                            ])
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                              timeBlock,
                              const SizedBox(width: 10),
                              Expanded(child: info),
                              const SizedBox(width: 12),
                              actions
                            ]),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }
}

class _NewAppointmentDialog extends StatefulWidget {
  final AppUser user;
  const _NewAppointmentDialog({required this.user});
  @override
  State<_NewAppointmentDialog> createState() => _NewAppointmentDialogState();
}

class _NewAppointmentDialogState extends State<_NewAppointmentDialog> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      phone = TextEditingController(),
      reason = TextEditingController();
  DateTime date = DateTime.now();
  TimeOfDay time = const TimeOfDay(hour: 9, minute: 0);
  bool busy = false;

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      String two(int n) => n.toString().padLeft(2, '0');
      await Svc.addAppointment(
        name: name.text.trim(),
        phone: phone.text.trim(),
        reason: reason.text.trim(),
        date: Svc.fmtDate(date),
        time: '${two(time.hour)}:${two(time.minute)}',
        by: widget.user,
      );
      nav.pop();
      messenger.showSnackBar(SnackBar(
          content: Text('Appointment booked for ${name.text.trim()}.')));
    } catch (e) {
      if (mounted) setState(() => busy = false);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return appDialog(
      context,
      title: 'New Appointment',
      subtitle: 'Book a patient for a future visit',
      content: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            field(name, 'Patient name', icon: Icons.person_outline),
            field(phone, 'Phone number',
                type: TextInputType.phone, icon: Icons.phone_outlined),
            field(reason, 'Reason / treatment',
                maxLines: 2, icon: Icons.medical_services_outlined),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final p = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(now.year, now.month, now.day),
                        lastDate: now.add(const Duration(days: 730)));
                    if (p != null) setState(() => date = p);
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text(DateFormat('EEE, d MMM y').format(date)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final p = await showTimePicker(
                        context: context, initialTime: time);
                    if (p != null) setState(() => time = p);
                  },
                  icon: const Icon(Icons.access_time),
                  label: Text(time.format(context)),
                ),
              ),
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.red),
          onPressed: busy ? null : _save,
          icon: const Icon(Icons.event_available),
          label: Text(busy ? 'Saving...' : 'Book Appointment'),
        ),
      ],
    );
  }
}
