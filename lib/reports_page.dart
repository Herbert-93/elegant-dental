import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'config.dart';
import 'models.dart';
import 'services.dart';
import 'theme.dart';
import 'widgets.dart';

/// ADMIN ONLY. Every financial record of the clinic for ANY dates the admin chooses
/// (yesterday, two weeks ago, last month, a custom range...) - not limited to 7 days.
class ReportsPage extends StatefulWidget {
  final AppUser user;
  const ReportsPage({super.key, required this.user});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  static const presets = [
    'Today',
    'Yesterday',
    'Last 7 days',
    'Last 30 days',
    'This month',
    'Last month',
    'This year',
  ];

  late DateTime from, to;
  String preset = 'This month';

  // month -> day picker
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int? _day; // null = the whole month
  late Stream<List<Visit>> visitStream;
  late Stream<List<Expense>> expenseStream;

  @override
  void initState() {
    super.initState();
    _usePreset('This month', first: true);
  }

  void _setRange(DateTime f, DateTime t, String label, {bool first = false}) {
    from = f;
    to = t;
    preset = label;
    visitStream = Svc.visitsBetween(Svc.fmtDate(f), Svc.fmtDate(t));
    expenseStream = Svc.expensesBetween(Svc.fmtDate(f), Svc.fmtDate(t));
    if (!first) setState(() {});
  }

  void _usePreset(String p, {bool first = false}) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    switch (p) {
      case 'Today':
        _setRange(today, today, p, first: first);
        break;
      case 'Yesterday':
        final y = today.subtract(const Duration(days: 1));
        _setRange(y, y, p, first: first);
        break;
      case 'Last 7 days':
        _setRange(today.subtract(const Duration(days: 6)), today, p,
            first: first);
        break;
      case 'Last 30 days':
        _setRange(today.subtract(const Duration(days: 29)), today, p,
            first: first);
        break;
      case 'Last month':
        _setRange(
            DateTime(n.year, n.month - 1, 1), DateTime(n.year, n.month, 0), p,
            first: first);
        break;
      case 'This year':
        _setRange(DateTime(n.year, 1, 1), today, p, first: first);
        break;
      default: // This month
        _setRange(DateTime(n.year, n.month, 1), today, 'This month',
            first: first);
    }
  }

  bool get _monthMode => preset == 'Month';

  /// Last day we can show for [m]: today for the current month, otherwise the month's last day.
  int _lastDay(DateTime m) {
    final n = DateTime.now();
    if (m.year == n.year && m.month == n.month) return n.day;
    return DateTime(m.year, m.month + 1, 0).day;
  }

  void _pickMonth(DateTime m) {
    _month = m;
    _day = null;
    _setRange(DateTime(m.year, m.month, 1),
        DateTime(m.year, m.month, _lastDay(m)), 'Month');
  }

  void _pickDay(int? d) {
    _day = d;
    if (d == null) {
      _pickMonth(_month);
    } else {
      final day = DateTime(_month.year, _month.month, d);
      _setRange(day, day, 'Month');
    }
  }

  List<DateTime> get _months {
    final n = DateTime.now();
    final l = <DateTime>[];
    for (var m = DateTime(n.year, n.month);
        !m.isBefore(DateTime(2020, 1));
        m = DateTime(m.year, m.month - 1)) {
      l.add(m);
    }
    return l;
  }

  Widget _monthDayPicker() {
    final last = _lastDay(_month);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(height: 28),
      const Text('Or choose a month, then a day',
          style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: DropdownButtonFormField<DateTime>(
          value: _month,
          decoration: deco('Month', icon: Icons.calendar_month_outlined),
          items: _months
              .map((m) => DropdownMenuItem(
                  value: m, child: Text(DateFormat('MMMM y').format(m))))
              .toList(),
          onChanged: (m) {
            if (m != null) _pickMonth(m);
          },
        ),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 6, runSpacing: 6, children: [
        ChoiceChip(
            label: const Text('Whole month'),
            selected: _monthMode && _day == null,
            onSelected: (_) => _pickDay(null)),
        for (var d = 1; d <= last; d++)
          ChoiceChip(
              label: Text('$d'),
              selected: _monthMode && _day == d,
              onSelected: (_) => _pickDay(d)),
      ]),
    ]);
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: DateTimeRange(start: from, end: to),
      helpText: 'Choose dates (tap the same day twice for a single day)',
    );
    if (r != null) _setRange(r.start, r.end, 'Custom');
  }

  String get _rangeLabel {
    final f = DateFormat('d MMM y');
    return Svc.fmtDate(from) == Svc.fmtDate(to)
        ? DateFormat('EEEE, d MMMM y').format(from)
        : '${f.format(from)}  to  ${f.format(to)}';
  }

  Widget _filters() => Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Financial reports',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Choose any period to see the money received and spent.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in presets)
              ChoiceChip(
                  label: Text(p),
                  selected: preset == p,
                  onSelected: (_) => _usePreset(p)),
            ActionChip(
                avatar: const Icon(Icons.date_range, size: 18),
                label: Text(preset == 'Custom' ? 'Custom dates' : 'Pick dates'),
                backgroundColor: preset == 'Custom'
                    ? AppColors.tealDark.withOpacity(.15)
                    : null,
                onPressed: _pickDates),
          ]),
          _monthDayPicker(),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.event_note, size: 18, color: AppColors.tealDark),
            const SizedBox(width: 6),
            Flexible(
                child: Text(_rangeLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.tealDark))),
          ]),
        ]),
      );

  // ---------------------------------------------------------------- small helpers
  static double _sum(Iterable<double> l) => l.fold<double>(0, (a, b) => a + b);

  static Map<String, double> _methods(Iterable<Visit> treated) {
    final m = <String, double>{};
    for (final v in treated) {
      v.paymentSplit.forEach((k, a) => m[k] = (m[k] ?? 0) + a);
    }
    return m;
  }

  Widget _title(String t, {IconData? icon}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon, size: 19, color: AppColors.tealDark),
            const SizedBox(width: 6)
          ],
          Text(t,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
      );

  Widget _line(String left, double amount,
          {String? sub, Color? color, bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(left,
                    style: TextStyle(
                        fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
                if (sub != null && sub.isNotEmpty)
                  Text(sub,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
              ])),
          const SizedBox(width: 10),
          Text(money(amount),
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: color ?? AppColors.ink)),
        ]),
      );

  Widget _dayTile(String date, List<Visit> treated, List<Expense> ex) {
    final income = _sum(treated.map((v) => v.cost ?? 0));
    final spent = _sum(ex.map((e) => e.amount));
    final net = income - spent;
    final methods = _methods(treated);
    final cash = methods[Cfg.payCash] ?? 0;
    final d = DateTime.parse(date);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        title: Text(DateFormat('EEE, d MMM y').format(d),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
            '${treated.length} treated  -  received ${money(income)}  -  spent ${money(spent)}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
        trailing: Text(money(net),
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: net < 0 ? AppColors.red : AppColors.tealDark)),
        children: [
          if (treated.isNotEmpty) ...[
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Payments received',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: AppColors.muted))),
            for (final v in treated)
              _line('#${v.number}  ${v.name}', v.cost ?? 0,
                  sub:
                      '${v.treatment}${v.medicines.isEmpty ? '' : '  +  medicine: ${v.medicineSummary}'}  -  ${v.paymentDetail}'),
          ],
          if (ex.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Expenses',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: AppColors.muted))),
            for (final e in ex)
              _line(e.description, e.amount,
                  sub: e.category, color: AppColors.red),
          ],
          const Divider(height: 20),
          _line('Cash at hand', cash),
          _line('Final Cash at hand (cash - expenses)', cash - spent,
              bold: true,
              color: cash - spent < 0 ? AppColors.red : AppColors.tealDark),
        ],
      ),
    );
  }

  Widget _report(List<Visit> visits, List<Expense> expenses) {
    final treated = visits.where((v) => v.treated).toList();
    final income = _sum(treated.map((v) => v.cost ?? 0));
    final medicine = _sum(treated.map((v) => v.medicineTotal));
    final spent = _sum(expenses.map((e) => e.amount));
    final net = income - spent;
    final methods = _methods(treated);
    final cash = methods[Cfg.payCash] ?? 0;
    final finalCash = cash - spent;

    final methodRows = methods.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final cats = <String, double>{};
    for (final e in expenses) {
      cats[e.category] = (cats[e.category] ?? 0) + e.amount;
    }
    final catRows = cats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final byDay = <String, List<Visit>>{};
    for (final v in treated) {
      byDay.putIfAbsent(v.date, () => []).add(v);
    }
    final exByDay = <String, List<Expense>>{};
    for (final e in expenses) {
      exByDay.putIfAbsent(e.date, () => []).add(e);
    }
    final days = {...byDay.keys, ...exByDay.keys}.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final l in byDay.values) {
      l.sort((a, b) => a.number.compareTo(b.number));
    }

    final stats = Wrap(spacing: 12, runSpacing: 12, children: [
      StatCard('Total received', money(income), Icons.trending_up,
          color: AppColors.green),
      StatCard('Treatment income', money(income - medicine),
          Icons.medical_services_outlined,
          color: AppColors.navy2),
      StatCard('Medicine sold', money(medicine), Icons.medication,
          color: AppColors.red,
          onTap: () =>
              showMedicineDialog(context, visits, periodLabel: _rangeLabel)),
      StatCard('Expenses', money(spent), Icons.shopping_cart_outlined,
          color: AppColors.amber),
      StatCard('Net total', money(net), Icons.account_balance,
          color: net < 0 ? AppColors.red : AppColors.tealDark),
      StatCard('Cash at hand', money(cash), Icons.payments,
          color: AppColors.navy2),
      StatCard('Final Cash at hand', money(finalCash),
          Icons.account_balance_wallet_outlined,
          color: finalCash < 0 ? AppColors.red : AppColors.tealDark),
      StatCard('Patients treated', '${treated.length}', Icons.check_circle,
          color: AppColors.green),
    ]);

    final methodPanel = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title('Money by payment method', icon: Icons.account_balance_wallet),
        if (methodRows.isEmpty)
          const Text('No payments in this period.',
              style: TextStyle(color: AppColors.muted)),
        for (final m in methodRows) _line(m.key, m.value),
        if (methodRows.isNotEmpty) ...[
          const Divider(height: 18),
          _line('Total', income, bold: true),
        ],
      ]),
    );

    final catPanel = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title('Expenses by category', icon: Icons.shopping_cart_outlined),
        if (catRows.isEmpty)
          const Text('No expenses in this period.',
              style: TextStyle(color: AppColors.muted)),
        for (final c in catRows) _line(c.key, c.value, color: AppColors.red),
        if (catRows.isNotEmpty) ...[
          const Divider(height: 18),
          _line('Total expenses', spent, bold: true, color: AppColors.red),
        ],
      ]),
    );

    final dayPanel = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title('Day by day (tap a day to open it)',
            icon: Icons.calendar_month_outlined),
        if (days.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No financial records found for these dates.',
                  style: TextStyle(color: AppColors.muted))),
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          _dayTile(days[i], byDay[days[i]] ?? [], exByDay[days[i]] ?? []),
        ],
      ]),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      stats,
      const SizedBox(height: 18),
      LayoutBuilder(builder: (context, bc) {
        if (bc.maxWidth < 800) {
          return Column(children: [
            methodPanel,
            const SizedBox(height: 16),
            catPanel,
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: methodPanel),
          const SizedBox(width: 16),
          Expanded(child: catPanel),
        ]);
      }),
      const SizedBox(height: 18),
      dayPanel,
    ]);
  }

  @override
  Widget build(BuildContext context) => PageScroll(children: [
        _filters(),
        const SizedBox(height: 18),
        StreamBuilder<List<Visit>>(
          stream: visitStream,
          builder: (c, vs) {
            if (vs.hasError) {
              return Panel(child: Text('Could not load records: ${vs.error}'));
            }
            return StreamBuilder<List<Expense>>(
              stream: expenseStream,
              builder: (c, es) {
                if (es.hasError) {
                  return Panel(
                      child: Text('Could not load expenses: ${es.error}'));
                }
                if (!vs.hasData || !es.hasData) {
                  return const Padding(
                      padding: EdgeInsets.all(50),
                      child: Center(child: CircularProgressIndicator()));
                }
                return _report(vs.data!, es.data!);
              },
            );
          },
        ),
      ]);
}
