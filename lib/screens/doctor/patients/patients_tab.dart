
import 'package:flutter/material.dart';

import '../../../models/patient.dart';
import '../../../models/patient_lab_result.dart';
import '../../records/lab_result_details_dialog.dart';
import 'patient_details_screen.dart';
import 'add_consultation_note_screen.dart';
import 'add_lab_result_screen.dart';
import 'edit_patient_info_screen.dart';
import 'add_prescription_screen.dart';
import 'patient_lab_results_screen.dart';
import 'patient_prescriptions_screen.dart';
import 'patient_records_screen.dart';
import 'patients_screen.dart';
import 'widgets/patient_record_tab_bar.dart';

/// The screens that live inside the Patients tab.
///
/// The enum order must match the IndexedStack children below.
enum _PatientsPage {
  list,
  details,
  records,
  labResults,
  prescriptions,
  addPrescription,
  addConsultationNote,
  addLabResult,
  editInfo,
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

  /// Bumped after Edit Patient Info saves, so Patient Details reloads.
  int _detailsVersion = 0;

  /// Also bumped after a save, so the Patients list shows the new details
  /// (e.g. a patient moved to History) when the doctor goes back.
  int _listVersion = 0;

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

  /// "View Full Record" was tapped.
  void _openFullRecord() {
    setState(() => _page = _PatientsPage.records);
  }

  /// "Add Consultation Notes" was tapped.
  void _addConsultationNote() {
    setState(() => _page = _PatientsPage.addConsultationNote);
  }

  /// Back from a record screen: show the details again.
  void _backToDetails() {
    setState(() => _page = _PatientsPage.details);
  }

  /// A pill on a Patient Records screen was tapped.
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

  /// "Add Prescription" was tapped.
  void _addPrescription() {
    setState(() => _page = _PatientsPage.addPrescription);
  }

  /// Back from the form, or after a prescription was saved.
  void _backToPrescriptions() {
    setState(() => _page = _PatientsPage.prescriptions);
  }

  /// "Edit Patient Info" was tapped.
  void _editInfo() {
    setState(() => _page = _PatientsPage.editInfo);
  }

  /// Edit Patient Info saved: show the new details right away.
  void _infoSaved(Patient updated) {
    setState(() {
      _selected = updated;
      _detailsVersion++;
      _listVersion++;
      _page = _PatientsPage.details;
    });
  }

  /// "Add Lab Result" was tapped.
  void _addLabResult() {
    setState(() => _page = _PatientsPage.addLabResult);
  }

  /// Back from the lab result form, or after it was saved. The lab results
  /// screen is rebuilt when it opens again, so it reloads the new result.
  void _backToLabResults() {
    setState(() => _page = _PatientsPage.labResults);
  }

  /// Opens the lab result details popup.
  void _openLabResult(PatientLabResult result) {
    showDialog<void>(
      context: context,
      builder: (_) => LabResultDetailsDialog(recordId: result.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    // IndexedStack keeps the list alive while other screens are open.
    return IndexedStack(
      index: _page.index,
      children: [
        PatientsScreen(
          key: ValueKey(_listVersion),
          onBack: widget.onBack,
          onOpenPatient: _openPatient,
        ),
        if (selected == null)
          const SizedBox.shrink()
        else
          PatientDetailsScreen(
            key: ValueKey('${selected.id}-$_detailsVersion'),
            patient: selected,
            onBack: _backToList,
            onViewFullRecord: _openFullRecord,
            onAddConsultationNote: _addConsultationNote,
            onEditInfo: _editInfo,
          ),
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
            onAddLabResult: _addLabResult,
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
        if (selected != null &&
            _page == _PatientsPage.addConsultationNote)
          AddConsultationNoteScreen(
            key: ValueKey(selected.id),
            patient: selected,
            onBack: _backToDetails,
            onSaved: _backToDetails,
          )
        else
          const SizedBox.shrink(),
        if (selected != null && _page == _PatientsPage.addLabResult)
          AddLabResultScreen(
            key: ValueKey(selected.id),
            patient: selected,
            onBack: _backToLabResults,
            onSaved: _backToLabResults,
          )
        else
          const SizedBox.shrink(),
        if (selected != null && _page == _PatientsPage.editInfo)
          EditPatientInfoScreen(
            key: ValueKey(selected.id),
            patient: selected,
            onBack: _backToDetails,
            onSaved: _infoSaved,
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}
