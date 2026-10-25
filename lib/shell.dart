import 'package:flutter/material.dart';
import 'config.dart';
import 'models.dart';
import 'pages.dart';
import 'widgets.dart';

class NavItem {
  final String label;
  final IconData icon;
  final Widget page;
  const NavItem(this.label, this.icon, this.page);
}

/// Operations staff: ONLY these two pages exist for them. Admin pages are never built.
class OperationsHome extends StatelessWidget {
  final AppUser user;
  const OperationsHome({super.key, required this.user});
  @override
  Widget build(BuildContext context) => AppShell(user: user, items: [
        NavItem("Today's Patients", Icons.today, DayPage(user: user)),
        NavItem('Patient Records', Icons.folder_shared, RecordsPage(user: user)),
      ]);
}

/// Admin: dashboard + staff, AND full access to the operations side.
class AdminHome extends StatelessWidget {
  final AppUser user;
  const AdminHome({super.key, required this.user});
  @override
  Widget build(BuildContext context) => AppShell(user: user, items: [
        NavItem('Dashboard', Icons.dashboard, DayPage(user: user, dashboard: true)),
        NavItem('Operations', Icons.medical_services, DayPage(user: user)),
        NavItem('Patient Records', Icons.folder_shared, RecordsPage(user: user)),
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

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final wide = w >= 800;
    final items = widget.items;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [const Icon(Icons.medical_services_outlined), const SizedBox(width: 8), Flexible(child: Text(Cfg.clinicName, overflow: TextOverflow.ellipsis))]),
        actions: [
          if (w >= 500) Center(child: Text('${widget.user.name} (${widget.user.isAdmin ? 'Admin' : 'Operations'})')),
          IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: signOut),
        ],
      ),
      body: wide
          ? Row(children: [
              NavigationRail(
                selectedIndex: i, extended: w >= 1100, onDestinationSelected: (x) => setState(() => i = x),
                destinations: items.map((e) => NavigationRailDestination(icon: Icon(e.icon), label: Text(e.label))).toList(),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: KeyedSubtree(key: ValueKey(i), child: items[i].page)),
            ])
          : KeyedSubtree(key: ValueKey(i), child: items[i].page),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: i, onDestinationSelected: (x) => setState(() => i = x),
              destinations: items.map((e) => NavigationDestination(icon: Icon(e.icon), label: e.label)).toList(),
            ),
    );
  }
}
