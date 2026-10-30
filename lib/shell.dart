import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'appointments_page.dart';
import 'config.dart';
import 'dashboard.dart';
import 'logo.dart';
import 'models.dart';
import 'pages.dart';
import 'services.dart';
import 'theme.dart';
import 'widgets.dart';

class NavItem {
  final String label;
  final IconData icon;
  final Widget page;
  final bool alerts; // shows the red appointment badge
  const NavItem(this.label, this.icon, this.page, {this.alerts = false});
}

/// Operations staff: ONLY these three pages exist for them. Admin pages are never built for them.
class OperationsHome extends StatelessWidget {
  final AppUser user;
  const OperationsHome({super.key, required this.user});
  @override
  Widget build(BuildContext context) => AppShell(user: user, items: [
        NavItem("Today's Patients", Icons.today, DayPage(user: user)),
        NavItem('Appointments', Icons.event, AppointmentsPage(user: user),
            alerts: true),
        NavItem(
            'Patient Records', Icons.folder_shared, RecordsPage(user: user)),
      ]);
}

/// Admin: dashboard + staff, AND full access to everything on the operations side.
class AdminHome extends StatelessWidget {
  final AppUser user;
  const AdminHome({super.key, required this.user});
  @override
  Widget build(BuildContext context) => AppShell(user: user, items: [
        NavItem(
            'Dashboard', Icons.dashboard_rounded, AdminDashboard(user: user)),
        NavItem('Operations', Icons.medical_services, DayPage(user: user)),
        NavItem('Appointments', Icons.event, AppointmentsPage(user: user),
            alerts: true),
        NavItem(
            'Patient Records', Icons.folder_shared, RecordsPage(user: user)),
        NavItem('Staff', Icons.manage_accounts, StaffPage(me: user)),
      ]);
}

class AppShell extends StatefulWidget {
  final AppUser user;
  final List<NavItem> items;
  const AppShell({super.key, required this.user, required this.items});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int i = 0;
  late final Stream<int> alerts = Svc.appointmentAlerts();

  Widget _sidebar({required bool inDrawer}) {
    final u = widget.user;
    return Container(
      decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [AppColors.navy, Color(0xFF0E3447)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter)),
      child: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(children: [
              const LogoBadge(size: 48),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text(Cfg.clinicName,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            height: 1.15)),
                    Text(u.isAdmin ? 'ADMIN CONSOLE' : 'OPERATIONS',
                        style: const TextStyle(
                            color: Color(0xFF7FD6D1),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1)),
                  ])),
            ]),
          ),
          Expanded(
            child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (var k = 0; k < widget.items.length; k++)
                    _navTile(k, inDrawer),
                ]),
          ),
          Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Avatar(u.name, size: 38, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(u.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    Text(u.isAdmin ? 'Administrator' : 'Operations',
                        style: const TextStyle(
                            color: Color(0xFF9FB8C4), fontSize: 12)),
                  ])),
              IconButton(
                  tooltip: 'Sign out',
                  onPressed: signOut,
                  icon: const Icon(Icons.logout, color: Colors.white70)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _navTile(int k, bool inDrawer) {
    final item = widget.items[k];
    final sel = k == i;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: sel ? Colors.white.withOpacity(0.13) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => i = k);
            if (inDrawer) Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(children: [
              Icon(item.icon,
                  size: 21,
                  color:
                      sel ? const Color(0xFF7FD6D1) : const Color(0xFFA9C0CB)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(item.label,
                      style: TextStyle(
                          color: sel ? Colors.white : const Color(0xFFC9D8DF),
                          fontWeight:
                              sel ? FontWeight.w700 : FontWeight.w500))),
              if (item.alerts)
                StreamBuilder<int>(
                  stream: alerts,
                  builder: (c, s) {
                    final n = s.data ?? 0;
                    if (n == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.red,
                          borderRadius: BorderRadius.circular(12)),
                      child: Text('$n',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    );
                  },
                ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final item = widget.items[i];
    final page = KeyedSubtree(key: ValueKey(i), child: item.page);

    if (!wide) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          title: Text(item.label,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        drawer: Drawer(
            width: 290,
            backgroundColor: AppColors.navy,
            child: _sidebar(inDrawer: true)),
        body: page,
      );
    }
    return Scaffold(
      body: Row(children: [
        SizedBox(width: 268, child: _sidebar(inDrawer: false)),
        Expanded(
          child: Column(children: [
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 26),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: AppColors.border))),
              child: Row(children: [
                Text(item.label,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
                const Spacer(),
                Pill(DateFormat('EEE, d MMM y').format(DateTime.now()),
                    AppColors.tealDark, const Color(0xFFE0F4F3),
                    icon: Icons.calendar_today),
                const SizedBox(width: 14),
                Avatar(widget.user.name, size: 36),
                const SizedBox(width: 8),
                Text(widget.user.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ),
            Expanded(child: page),
          ]),
        ),
      ]),
    );
  }
}
