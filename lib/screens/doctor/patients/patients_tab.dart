// The "Patients" tab of the doctor app.
//
// This widget is only a HOST: it decides which Patients screen is visible
// (the list, the details of the tapped patient, or one of that patient's
// record screens). The bottom navigation bar belongs to DoctorShell, so it
// stays visible on every screen, as in the prototype.
import 'package:flutter/material.dart';

import '../../../models/patient.dart';
import '../../../models/patient_lab_result.dart';
import '../../records/lab_result_details_dialog.dart';
import 'patient_details_screen.dart';
import 'add_prescription_screen.dart';
import 'patient_lab_results_screen.dart';
import 'patient_prescriptions_screen.dart';
import 'patient_records_screen.dart';
import 'patients_screen.dart';
import 'widgets/patient_record_tab_bar.dart';

/// The screens that live inside the Patients tab. The enum order is the same
/// as the IndexedStack children below.
enum _PatientsPage {
  list,
  details,
  records,
  labResults,
  prescriptions,
  addPrescription
}

/// Doctor Patients tab. [onBack] switches the app to the Home tab.
class DoctorPatientsTab extends StatefulWidget {
  const DoctorPatientsTab({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<DoctorPatientsTab> createState() => _DoctorPatientsTabState();
}

class _DoctorPatientsTabState extends State<DoctorPatientsTab> {
  /// The patient that was tapped, or null while the list is showing.
  Patient? _selected;

  /// Which screen is visible.
  _PatientsPage _page = _PatientsPage.list;

  /// A card in the list was tapped: show that patient's details.
  void _openPatient(Patient patient) {
    setState(() {
      _selected = patient;
      _page = _PatientsPage.details;
    });
  }

  /// Back from the details: show the list again.
  void _backToList() {
    setState(() {
      _selected = null;
      _page = _PatientsPage.list;
    });
  }

  /// "View Full Record" was tapped: show the Records pill of Patient Records.
  void _openFullRecord() => setState(() => _page = _PatientsPage.records);

  /// Back from a record screen: show the details again.
  void _backToDetails() => setState(() => _page = _PatientsPage.details);

  /// A pill on a Patient Records screen was tapped: switch to that screen.
  void _onRecordTab(PatientRecordTab tab) {
    switch (tab) {
      case PatientRecordTab.records:
        setState(() => _page = _PatientsPage.records);
      case PatientRecordTab.labResults:
        setState(() => _page = _PatientsPage.labResults);
      case PatientRecordTab.prescriptions:
        setState(() => _page = _PatientsPage.prescriptions);
    }
  }

  /// "Add Prescription" was tapped: show the form.
  void _addPrescription() =>
      setState(() => _page = _PatientsPage.addPrescription);

  /// Back from the form, or after a prescription was saved: show the
  /// prescriptions list again (it loads fresh, so the new one is in it).
  void _backToPrescriptions() =>
      setState(() => _page = _PatientsPage.prescriptions);

  /// A lab result card was tapped: open the "Lab Results" popup (View Lab
  /// Results). It is the same popup the patient sees, so it is reused.
  void _openLabResult(PatientLabResult result) {
    showDialog<void>(
      context: context,
      builder: (_) => LabResultDetailsDialog(recordId: result.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    // IndexedStack keeps the list alive while the other screens are open, so
    // going back keeps the search text, pills and chips as they were.
    return IndexedStack(
      index: _page.index,
      children: [
        PatientsScreen(onBack: widget.onBack, onOpenPatient: _openPatient),
        if (selected == null)
          const SizedBox.shrink()
        else
          PatientDetailsScreen(
            // The key makes Flutter load fresh data for each different patient.
            key: ValueKey(selected.id),
            patient: selected,
            onBack: _backToList,
            onViewFullRecord: _openFullRecord,
          ),
        // The record screens are built only while open, so they load fresh each time.
        if (selected != null && _page == _PatientsPage.records)
          PatientRecordsScreen(
            key: ValueKey(selected.id),
            patient: selected,
            onBack: _backToDetails,
            onTabSelected: _onRecordTab,
          )
        else
          const SizedBox.shrink(),
        if (selected != null && _page == _PatientsPage.labResults)
          PatientLabResultsScreen(
            key: ValueKey(selected.id),
            patient: selected,
            onBack: _backToDetails,
            onTabSelected: _onRecordTab,
            onOpenLabResult: _openLabResult,
          )
        else
          const SizedBox.shrink(),
        if (selected != null && _page == _PatientsPage.prescriptions)
          PatientPrescriptionsScreen(
            key: ValueKey(selected.id),
            patient: selected,
            onBack: _backToDetails,
            onTabSelected: _onRecordTab,
            onAddPrescription: _addPrescription,
          )
        else
          const SizedBox.shrink(),
        if (selected != null && _page == _PatientsPage.addPrescription)
          AddPrescriptionScreen(
            key: ValueKey(selected.id),
            patient: selected,
            onBack: _backToPrescriptions,
            onSaved: _backToPrescriptions,
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}
