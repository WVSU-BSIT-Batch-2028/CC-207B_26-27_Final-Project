import '../models/consultation_detail.dart';
import '../models/health_record.dart';
import '../models/lab_result_detail.dart';
import 'dashboard_service.dart';

/// Thrown when the records could not be loaded. The screen shows [message]
/// in its error state.
class RecordsException implements Exception {
  const RecordsException(this.message);
  final String message;
}

/// Loads the patient's records for the Records tab.
///
/// MOCK for now: it waits a little (to show the loading state) and returns
/// sample data. When the backend is ready, replace only the body of
/// [fetchRecords]; the screen does not need to change.
class RecordsService {
  RecordsService._();
  static final RecordsService instance = RecordsService._();

  /// Returns all records, newest first.
  ///
  /// Reuses the demo switch from patient Home (long-press the avatar) so the
  /// empty and error states can be shown during the presentation.
  Future<List<HealthRecord>> fetchRecords() async {
    // Simulated network delay, so the skeleton is visible.
    await Future<void>.delayed(const Duration(milliseconds: 900));

    switch (DashboardService.instance.scenario) {
      case DemoScenario.error:
        throw const RecordsException(
          "We couldn't load your records. Check your connection and try again.",
        );
      case DemoScenario.empty:
        return const <HealthRecord>[];
      case DemoScenario.normal:
        final records = <HealthRecord>[
          HealthRecord(
            id: 'consult-001',
            type: RecordType.consultation,
            title: 'General Consultation',
            subtitle: 'Dr. Maria Santos',
            date: DateTime(2026, 9, 20),
          ),
          HealthRecord(
            id: 'lab-001',
            type: RecordType.labResult,
            title: 'Laboratory Results',
            subtitle: 'Complete Blood Count',
            date: DateTime(2026, 9, 8),
          ),
          HealthRecord(
            id: 'lab-002',
            type: RecordType.labResult,
            title: 'Laboratory Results',
            subtitle: 'Lipid Profile',
            date: DateTime(2026, 8, 28),
          ),
          HealthRecord(
            id: 'consult-002',
            type: RecordType.consultation,
            title: 'General Consultation',
            subtitle: 'Dr. John Doe',
            date: DateTime(2026, 8, 12),
          ),
        ];
        // Newest first, so the list order never depends on the data order.
        records.sort((a, b) => b.date.compareTo(a.date));
        return records;
    }
  }

  /// Returns only the consultations, newest first (for the Consultations screen).
  Future<List<HealthRecord>> fetchConsultations() async {
    final all = await fetchRecords();
    return all.where((r) => r.type == RecordType.consultation).toList();
  }

  /// Returns only the lab results, newest first (for the Lab Results screen).
  Future<List<HealthRecord>> fetchLabResults() async {
    final all = await fetchRecords();
    return all.where((r) => r.type == RecordType.labResult).toList();
  }

  /// Returns the full medical record of one consultation (for the popup).
  ///
  /// Mock data for now. Throws [RecordsException] in the Error demo scenario,
  /// or if no consultation has that [id].
  Future<ConsultationDetail> fetchConsultationDetail(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (DashboardService.instance.scenario == DemoScenario.error) {
      throw const RecordsException(
        "We couldn't load this medical record. Check your connection and try again.",
      );
    }

    final details = <String, ConsultationDetail>{
      'consult-001': ConsultationDetail(
        id: 'consult-001',
        doctorName: 'Dr. Maria Santos',
        department: 'General Consultation',
        type: 'Consultation',
        date: DateTime(2026, 9, 20),
        diagnosis: 'Patient reported cough, sore throat, and mild fever.',
        treatment: 'Rest, increase fluid intake, and take prescribed medication as directed.',
      ),
      'consult-002': ConsultationDetail(
        id: 'consult-002',
        doctorName: 'Dr. John Doe',
        department: 'General Consultation',
        type: 'Consultation',
        date: DateTime(2026, 8, 12),
        diagnosis: 'Patient reported persistent headache and fatigue for three days.',
        treatment: 'Get enough sleep, drink plenty of water, and return if symptoms last more than a week.',
      ),
    };

    final detail = details[id];
    if (detail == null) {
      throw const RecordsException('This medical record could not be found.');
    }
    return detail;
  }

  /// Returns the full lab result (values, notes) for the popup.
  ///
  /// Mock data for now. 'lab-001' is all normal (as in the prototype);
  /// 'lab-002' has a High and a Low value, to demo the abnormal highlighting.
  /// Throws [RecordsException] in the Error demo scenario or for an unknown [id].
  Future<LabResultDetail> fetchLabResultDetail(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (DashboardService.instance.scenario == DemoScenario.error) {
      throw const RecordsException(
        "We couldn't load this lab result. Check your connection and try again.",
      );
    }

    final details = <String, LabResultDetail>{
      'lab-001': LabResultDetail(
        id: 'lab-001',
        testName: 'CBC - Complete Blood Count',
        patientName: 'Jahna Erika Lagne',
        requestedBy: 'Dr. John Doe',
        status: 'Complete',
        date: DateTime(2026, 9, 8),
        results: const [
          LabValue(name: 'Hemoglobin', value: 14.2, unit: 'g/dL', min: 13.0, max: 17.0),
          LabValue(name: 'Hematocrit', value: 42, unit: '%', min: 40, max: 52, decimals: 0),
          LabValue(name: 'WBC Count', value: 7.5, unit: '×10⁹/L', min: 4.0, max: 11.0),
          LabValue(name: 'RBC Count', value: 4.8, unit: '×10¹²/L', min: 4.5, max: 5.9),
          LabValue(name: 'Platelets', value: 250, unit: '×10⁹/L', min: 150, max: 450, decimals: 0),
        ],
        overallResult: 'Results are within the normal reference range.',
        doctorNotes: 'No significant abnormalities noted.',
      ),
      'lab-002': LabResultDetail(
        id: 'lab-002',
        testName: 'Lipid Profile',
        patientName: 'Jahna Erika Lagne',
        requestedBy: 'Dr. Maria Santos',
        status: 'Complete',
        date: DateTime(2026, 8, 28),
        results: const [
          LabValue(name: 'Total Cholesterol', value: 215, unit: 'mg/dL', min: 125, max: 200, decimals: 0),
          LabValue(name: 'LDL Cholesterol', value: 140, unit: 'mg/dL', min: 0, max: 100, decimals: 0),
          LabValue(name: 'HDL Cholesterol', value: 35, unit: 'mg/dL', min: 40, max: 100, decimals: 0),
          LabValue(name: 'Triglycerides', value: 130, unit: 'mg/dL', min: 0, max: 150, decimals: 0),
        ],
        overallResult: 'Total and LDL cholesterol are above the reference range; HDL is below it.',
        doctorNotes: 'Reduce fatty foods, exercise regularly, and repeat the test in 3 months.',
      ),
    };

    final detail = details[id];
    if (detail == null) {
      throw const RecordsException('This lab result could not be found.');
    }
    return detail;
  }
}
