import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'appointments_page.dart';
import 'config.dart';
import 'models.dart';
import 'services.dart';
import 'theme.dart';
import 'widgets.dart';

class _Ev {
  final DateTime t;
  final IconData icon;
  final Color color;
  final String text;
  _Ev(this.t, this.icon, this.color, this.text);
}

/// ADMIN ONLY. Never built for operations users.
class AdminDashboard extends StatefulWidget {
  final AppUser user;
  const AdminDashboard({super.key, required this.user});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late final Stream<List<Visit>> week = Svc.visitsSince(
      Svc.fmtDate(DateTime.now().subtract(const Duration(days: 6))));
  String date = Svc.todayStr();
  late Stream<List<Visit>> dayStream = Svc.visitsForDate(date);

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12
        ? 'Good morning'
        : (h < 17 ? 'Good afternoon' : 'Good evening');
  }

  Future<void> _pick() async {
    final p = await showDatePicker(
        context: context,
        initialDate: DateTime.parse(date),
        firstDate: DateTime(2020),
        lastDate: DateTime.now());
    if (p != null) {
      setState(() {
        date = Svc.fmtDate(p);
        dayStream = Svc.visitsForDate(date);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Visit>>(
      stream: week,
      builder: (c, s) {
        if (s.hasError) return Center(child: Text('Error: ${s.error}'));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final all = s.data!;
        final today = Svc.todayStr();
        final todayL = all.where((v) => v.date == today).toList();
        double rev(Iterable<Visit> l) => l
            .where((v) => v.treated)
            .fold<double>(0, (a, v) => a + (v.cost ?? 0));

        // last 7 days chart data
        final labels = <String>[];
        final values = <double>[];
        for (var i = 6; i >= 0; i--) {
          final d = DateTime.now().subtract(Duration(days: i));
          labels.add(DateFormat('EEE').format(d));
          values.add(rev(all.where((v) => v.date == Svc.fmtDate(d))));
        }

        // live activity feed
        final events = <_Ev>[];
        for (final v in all) {
          if (v.createdAt != null) {
            events.add(_Ev(v.createdAt!, Icons.person_add, AppColors.tealDark,
                '${v.createdBy.isEmpty ? 'Staff' : v.createdBy} registered ${v.name} (#${v.number}) for ${v.treatment}'));
          }
          if (v.treated && v.treatedAt != null) {
            events.add(_Ev(v.treatedAt!, Icons.payments, AppColors.green,
                '${v.treatedBy.isEmpty ? 'Staff' : v.treatedBy} recorded treatment for ${v.name} - ${money(v.cost ?? 0)} (${v.paymentMethod})'));
          }
        }
        events.sort((a, b) => b.t.compareTo(a.t));

        final header = Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
                colors: [AppColors.navy, AppColors.navy2, AppColors.tealDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('${_greeting()}, ${widget.user.name.split(' ').first}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                      '${niceDate(today)}  -  live overview of ${Cfg.clinicName}',
                      style: const TextStyle(color: Color(0xFFCFE6EA))),
                ])),
            const Icon(Icons.monitor_heart_outlined,
                color: Colors.white24, size: 64),
          ]),
        );

        final stats = Wrap(spacing: 12, runSpacing: 12, children: [
          StatCard('Patients today', '${todayL.length}', Icons.groups,
              color: AppColors.tealDark),
          StatCard('Treated today', '${todayL.where((v) => v.treated).length}',
              Icons.check_circle,
              color: AppColors.green),
          StatCard('Waiting now', '${todayL.where((v) => !v.treated).length}',
              Icons.hourglass_bottom,
              color: AppColors.amber),
          StatCard("Today's revenue", money(rev(todayL)), Icons.payments,
              color: AppColors.navy2),
          StatCard('Revenue (7 days)', money(rev(all)), Icons.trending_up,
              color: AppColors.green),
        ]);

        final chart = Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Revenue - last 7 days',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 16),
            _RevenueChart(labels: labels, values: values),
          ]),
        );

        final activity = Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: const [
              Icon(Icons.bolt, color: AppColors.amber),
              SizedBox(width: 6),
              Text('Live activity from Operations',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
            const SizedBox(height: 10),
            if (events.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No activity yet.',
                      style: TextStyle(color: AppColors.muted))),
            ...events.take(10).map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                                color: e.color.withOpacity(0.12),
                                shape: BoxShape.circle),
                            child: Icon(e.icon, size: 17, color: e.color)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(e.text,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                              Text(DateFormat('EEE d MMM, h:mm a').format(e.t),
                                  style: const TextStyle(
                                      color: AppColors.muted, fontSize: 12)),
                            ])),
                      ]),
                )),
          ]),
        );

        return PageScroll(children: [
          header,
          const SizedBox(height: 18),
          stats,
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, bc) {
            final wide = bc.maxWidth >= 980;
            final appts = TodayAppointmentsPanel(user: widget.user);
            if (!wide)
              return Column(children: [
                chart,
                const SizedBox(height: 16),
                appts,
                const SizedBox(height: 16),
                activity
              ]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  flex: 3,
                  child: Column(
                      children: [chart, const SizedBox(height: 16), activity])),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: appts),
            ]);
          }),
          const SizedBox(height: 26),
          PageHeader(
            title: date == today
                ? "Today's patients"
                : 'Patients on ${niceDate(date)}',
            subtitle: 'Pick any date to review what happened',
            actions: [
              OutlinedButton.icon(
                  onPressed: _pick,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Change date')),
              if (date != today)
                TextButton(
                    onPressed: () => setState(() {
                          date = today;
                          dayStream = Svc.visitsForDate(today);
                        }),
                    child: const Text('Back to today')),
            ],
          ),
          StreamBuilder<List<Visit>>(
            stream: dayStream,
            builder: (c, ds) {
              if (!ds.hasData)
                return const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: CircularProgressIndicator()));
              return VisitTable(visits: ds.data!, user: widget.user);
            },
          ),
        ]);
      },
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  const _RevenueChart({required this.labels, required this.values});

  @override
  Widget build(BuildContext context) {
    final mx = values.fold<double>(0, math.max);
    final last = values.length - 1;
    return SizedBox(
      height: 210,
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(values.length, (i) {
            final h = mx == 0 ? 4.0 : 4 + 140 * values[i] / mx;
            return Expanded(
              child:
                  Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(
                    values[i] == 0
                        ? ''
                        : NumberFormat.compact().format(values[i]),
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  height: h,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(8)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: i == last
                          ? [AppColors.teal, AppColors.tealDark]
                          : [const Color(0xFFA9DDDA), const Color(0xFF74C5C0)],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(labels[i],
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            i == last ? FontWeight.w800 : FontWeight.w500,
                        color: i == last ? AppColors.ink : AppColors.muted)),
              ]),
            );
          })),
    );
  }
}
