import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'config.dart';
import 'edit_patient.dart';
import 'models.dart';
import 'patient_sheet.dart';
import 'receipt_ui.dart';
import 'services.dart';
import 'theme.dart';
import 'widgets.dart';

class VisitTable extends StatelessWidget {
  final List<Visit> visits;
  final AppUser user;
  final bool showDate;
  const VisitTable(
      {super.key,
      required this.visits,
      required this.user,
      this.showDate = false});

  Widget _status(Visit v) => v.treated
      ? const Pill('Treated', AppColors.green, AppColors.greenBg,
          icon: Icons.check_circle)
      : const Pill('Waiting', AppColors.amber, AppColors.amberBg,
          icon: Icons.schedule);

  Widget _actions(BuildContext c, Visit v) {
    final small = FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12));
    return Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton.outlined(
              tooltip: 'Edit patient details',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () =>
                  showEditPatientDialog(c, v, withTreatment: true)),
          v.treated
              ? OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12)),
                  onPressed: () => showTreatmentDialog(c, v, user),
                  child: const Text('Edit cost'))
              : FilledButton(
                  style: small,
                  onPressed: () => showTreatmentDialog(c, v, user),
                  child: const Text('Record treatment')),
          if (v.treated)
            IconButton.outlined(
                tooltip: 'Receipt',
                icon: const Icon(Icons.receipt_long, size: 20),
                onPressed: () => showReceiptDialog(c, v)),
          if (user.isAdmin)
            IconButton(
              tooltip: 'Delete',
              color: AppColors.red,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirm(c, 'Delete record?',
                    'Permanently delete ${v.name} (#${v.number}, ${v.date})?',
                    yes: 'Delete')) {
                  await Svc.deleteVisit(v.id);
                }
              },
            ),
        ]);
  }

  String _time(Visit v) =>
      v.createdAt == null ? '-' : DateFormat('h:mm a').format(v.createdAt!);

  @override
  Widget build(BuildContext context) {
    if (visits.isEmpty) {
      return const Panel(
        padding: EdgeInsets.all(40),
        child: Center(
            child: Column(children: [
          Icon(Icons.people_outline, size: 46, color: AppColors.muted),
          SizedBox(height: 8),
          Text('No patients found',
              style: TextStyle(
                  color: AppColors.muted, fontWeight: FontWeight.w600)),
        ])),
      );
    }
    return LayoutBuilder(builder: (context, bc) {
      if (bc.maxWidth < 980) {
        return Column(
            children: visits
                .map((v) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Panel(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () =>
                                        showPatientSheet(context, v, user),
                                    child: Row(children: [
                                      Avatar(v.name),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(v.name,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                    color: AppColors.tealDark)),
                                            Text(
                                                '#${v.number} - ${v.age} yrs - ${v.phone}',
                                                style: const TextStyle(
                                                    color: AppColors.muted,
                                                    fontSize: 12.5)),
                                          ])),
                                    ]),
                                  ),
                                ),
                                _status(v),
                              ]),
                              const SizedBox(height: 10),
                              Text(v.treatment),
                              const SizedBox(height: 2),
                              Text(
                                  '${showDate ? '${v.date}  ' : ''}${_time(v)} - ${v.address}',
                                  style: const TextStyle(
                                      color: AppColors.muted, fontSize: 12.5)),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                    child: Text(
                                        v.cost == null
                                            ? 'No cost yet'
                                            : money(v.cost!),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800))),
                                Flexible(child: _actions(context, v)),
                              ]),
                            ]),
                      ),
                    ))
                .toList());
      }
      const hs = TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
          fontSize: 12.5,
          letterSpacing: .4);
      return Panel(
        padding: EdgeInsets.zero,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
                color: Color(0xFFF6F9FB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(children: [
              const SizedBox(width: 48, child: Text('NO.', style: hs)),
              const Expanded(
                  flex: 4,
                  child: Text('PATIENT (click for full history)', style: hs)),
              const Expanded(flex: 3, child: Text('TREATMENT', style: hs)),
              Expanded(
                  flex: 2,
                  child: Text(showDate ? 'DATE / TIME' : 'ARRIVED', style: hs)),
              const Expanded(flex: 2, child: Text('STATUS', style: hs)),
              const Expanded(flex: 2, child: Text('COST', style: hs)),
              const SizedBox(
                  width: 300,
                  child: Align(
                      alignment: Alignment.centerRight,
                      child: Text('ACTIONS', style: hs))),
            ]),
          ),
          ...visits.map((v) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border))),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                          width: 48,
                          child: Text('#${v.number}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.tealDark))),
                      Expanded(
                        flex: 4,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Tooltip(
                            message: 'View full patient history',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => showPatientSheet(context, v, user),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Avatar(v.name),
                                      const SizedBox(width: 10),
                                      Flexible(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(v.name,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.tealDark,
                                                    decoration: TextDecoration
                                                        .underline)),
                                            Text(
                                                '${v.age} yrs - ${v.phone} - ${v.address}',
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    color: AppColors.muted,
                                                    fontSize: 12.5)),
                                          ])),
                                    ]),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                          flex: 3,
                          child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Text(v.treatment,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis))),
                      Expanded(
                          flex: 2,
                          child: Text(
                              showDate ? '${v.date}\n${_time(v)}' : _time(v),
                              style: const TextStyle(color: AppColors.muted))),
                      Expanded(
                          flex: 2,
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: _status(v))),
                      Expanded(
                          flex: 2,
                          child: Text(v.cost == null ? '-' : money(v.cost!),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700))),
                      SizedBox(width: 300, child: _actions(context, v)),
                    ]),
              )),
        ]),
      );
    });
  }
}
