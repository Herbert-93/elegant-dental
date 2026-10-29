import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'config.dart';
import 'models.dart';
import 'services.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showExpenseDialog(BuildContext context, AppUser user, String date,
        {Expense? expense}) =>
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _ExpenseDialog(user: user, date: date, expense: expense));

class _ExpenseDialog extends StatefulWidget {
  final AppUser user;
  final String date;
  final Expense? expense;
  const _ExpenseDialog({required this.user, required this.date, this.expense});
  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final form = GlobalKey<FormState>();
  late final desc =
      TextEditingController(text: widget.expense?.description ?? '');
  late final amount = TextEditingController(
      text: widget.expense == null
          ? ''
          : widget.expense!.amount
              .toStringAsFixed(widget.expense!.amount % 1 == 0 ? 0 : 2));
  late String category =
      widget.expense?.category ?? Cfg.expenseCategories.first;
  bool busy = false;

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final amt = double.parse(amount.text.trim());
      if (widget.expense == null) {
        await Svc.addExpense(
            date: widget.date,
            description: desc.text.trim(),
            category: category,
            amount: amt,
            by: widget.user);
      } else {
        await Svc.updateExpense(widget.expense!.id,
            description: desc.text.trim(), category: category, amount: amt);
      }
      nav.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Expense saved.')));
    } catch (e) {
      if (mounted) setState(() => busy = false);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = <String>{...Cfg.expenseCategories, category}.toList();
    return appDialog(
      context,
      title: widget.expense == null ? 'Add Expense' : 'Edit Expense',
      subtitle: niceDate(widget.date),
      width: 460,
      content: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            field(desc, 'What was it spent on?',
                icon: Icons.receipt_long_outlined),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<String>(
                value: category,
                decoration: deco('Category', icon: Icons.category_outlined),
                items: cats
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (x) => setState(() => category = x ?? category),
              ),
            ),
            TextFormField(
              controller: amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
              ],
              decoration: deco('Amount (${Cfg.currency})',
                  icon: Icons.payments_outlined),
              validator: (t) => (t == null || double.tryParse(t.trim()) == null)
                  ? 'Enter a valid amount'
                  : null,
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton.icon(
            onPressed: busy ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(busy ? 'Saving...' : 'Save Expense')),
      ],
    );
  }
}

/// Money in (payments) - expenses = NET TOTAL for one day. Shown on Operations AND Admin.
class DailySummaryPanel extends StatefulWidget {
  final AppUser user;
  final String date;
  final List<Visit> visits;
  const DailySummaryPanel(
      {super.key,
      required this.user,
      required this.date,
      required this.visits});
  @override
  State<DailySummaryPanel> createState() => _DailySummaryPanelState();
}

class _DailySummaryPanelState extends State<DailySummaryPanel> {
  late Stream<List<Expense>> stream;

  @override
  void initState() {
    super.initState();
    stream = Svc.expensesForDate(widget.date);
  }

  @override
  void didUpdateWidget(covariant DailySummaryPanel old) {
    super.didUpdateWidget(old);
    if (old.date != widget.date) stream = Svc.expensesForDate(widget.date);
  }

  Widget _tile(String label, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.25))),
        child: Row(children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 13)),
                FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: color))),
              ])),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final canAdd = widget.user.isAdmin || widget.date == Svc.todayStr();
    return StreamBuilder<List<Expense>>(
      stream: stream,
      builder: (c, s) {
        if (s.hasError)
          return Panel(child: Text('Could not load expenses: ${s.error}'));
        final ex = s.data ?? <Expense>[];
        final treated = widget.visits.where((v) => v.treated).toList();
        final income = treated.fold<double>(0, (a, v) => a + (v.cost ?? 0));
        final spent = ex.fold<double>(0, (a, e) => a + e.amount);
        final net = income - spent;
        final methods = <String, double>{};
        for (final v in treated) {
          final k = v.paymentMethod.isEmpty ? 'Other' : v.paymentMethod;
          methods[k] = (methods[k] ?? 0) + (v.cost ?? 0);
        }
        final cashAtHand = methods[Cfg.payCash] ?? 0;
        final finalCash = cashAtHand - spent;
        final otherMethods = methods.entries
            .where((e) =>
                e.key != Cfg.payCash &&
                e.key != Cfg.payMtn &&
                e.key != Cfg.payAirtel)
            .toList();
        final otherTotal = otherMethods.fold<double>(0, (a, e) => a + e.value);

        final netTile = Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
                colors: [AppColors.navy, AppColors.navy2, AppColors.tealDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
          child: Row(children: [
            const Icon(Icons.account_balance_wallet,
                color: Color(0xFF7FD6D1), size: 30),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('NET TOTAL FOR THE DAY',
                      style: TextStyle(
                          color: Color(0xFFCFE6EA),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                  FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(money(net),
                          style: TextStyle(
                              color: net < 0
                                  ? const Color(0xFFFFB3BA)
                                  : Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900))),
                ])),
          ]),
        );

        return Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 10,
                spacing: 12,
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Daily Financial Summary',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(niceDate(widget.date),
                            style: const TextStyle(color: AppColors.muted)),
                      ]),
                  if (canAdd)
                    OutlinedButton.icon(
                        onPressed: () => showExpenseDialog(
                            context, widget.user, widget.date),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Expense')),
                ]),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, bc) {
              final a = _tile('Money in (payments)', money(income),
                  Icons.arrow_downward, AppColors.green);
              final b = _tile('Expenses', '- ${money(spent)}',
                  Icons.arrow_upward, AppColors.amber);
              if (bc.maxWidth < 760)
                return Column(children: [
                  a,
                  const SizedBox(height: 10),
                  b,
                  const SizedBox(height: 10),
                  netTile
                ]);
              return Row(children: [
                Expanded(child: a),
                const SizedBox(width: 12),
                Expanded(child: b),
                const SizedBox(width: 12),
                Expanded(child: netTile)
              ]);
            }),
            const SizedBox(height: 10),
            Text(
                'Net total = Money in (${money(income)}) - Expenses (${money(spent)}) = ${money(net)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            const SizedBox(height: 10),
            _tile(
                'Final Cash at hand',
                money(finalCash),
                Icons.account_balance_wallet_outlined,
                finalCash < 0 ? AppColors.red : AppColors.tealDark),
            const SizedBox(height: 6),
            Text(
                'Final Cash at hand = Cash at hand (${money(cashAtHand)}) - Expenses (${money(spent)}) = ${money(finalCash)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            const SizedBox(height: 16),
            const Text('Cash and mobile money (all company money)',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (context, bc) {
              final cash = _tile(
                  'Cash at hand',
                  money(methods[Cfg.payCash] ?? 0),
                  Icons.payments_outlined,
                  AppColors.tealDark);
              final mtn = _tile(
                  'MTN Mobile Money',
                  money(methods[Cfg.payMtn] ?? 0),
                  Icons.phone_android,
                  AppColors.amber);
              final airtel = _tile(
                  'Airtel Money',
                  money(methods[Cfg.payAirtel] ?? 0),
                  Icons.smartphone,
                  AppColors.red);
              if (bc.maxWidth < 760)
                return Column(children: [
                  cash,
                  const SizedBox(height: 10),
                  mtn,
                  const SizedBox(height: 10),
                  airtel
                ]);
              return Row(children: [
                Expanded(child: cash),
                const SizedBox(width: 12),
                Expanded(child: mtn),
                const SizedBox(width: 12),
                Expanded(child: airtel)
              ]);
            }),
            if (otherMethods.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: otherMethods
                      .map((e) => Pill('${e.key}: ${money(e.value)}',
                          AppColors.tealDark, const Color(0xFFE0F4F3)))
                      .toList()),
            ],
            const SizedBox(height: 10),
            Text(
                'Total company money for the day = Cash (${money(methods[Cfg.payCash] ?? 0)}) + MTN (${money(methods[Cfg.payMtn] ?? 0)}) + Airtel (${money(methods[Cfg.payAirtel] ?? 0)})${otherMethods.isEmpty ? '' : ' + Other (${money(otherTotal)})'} = ${money(income)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            const SizedBox(height: 16),
            const Text('Expenses recorded',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            if (ex.isEmpty)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No expenses recorded for this day.',
                      style: TextStyle(color: AppColors.muted))),
            for (final e in ex)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border))),
                child: Row(children: [
                  Pill(e.category, AppColors.amber, AppColors.amberBg),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(e.description,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                            'Recorded by ${e.createdBy}${e.createdAt == null ? '' : ' at ${DateFormat('h:mm a').format(e.createdAt!)}'}',
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12)),
                      ])),
                  Text('- ${money(e.amount)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: AppColors.amber)),
                  IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => showExpenseDialog(
                          context, widget.user, e.date,
                          expense: e)),
                  if (widget.user.isAdmin)
                    IconButton(
                      tooltip: 'Delete',
                      color: AppColors.red,
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () async {
                        if (await confirm(context, 'Delete expense?',
                            'Delete "${e.description}"?', yes: 'Delete'))
                          await Svc.deleteExpense(e.id);
                      },
                    ),
                ]),
              ),
          ]),
        );
      },
    );
  }
}
