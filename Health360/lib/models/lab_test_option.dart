/// One measured value of a lab test, with its unit and normal range.
/// The range text ("13.0-17.0") is what LabValue uses to flag High / Low.
class LabMeasure {
  const LabMeasure(this.name, this.unit, this.range);

  final String name;
  final String unit;
  final String range;
}

/// A lab test the doctor can enter in Add Lab Result, with the values it
/// measures. Plain data: no widgets and no storage code.
class LabTestOption {
  const LabTestOption({required this.name, required this.measures});

  /// e.g. "Complete Blood Count (CBC)"
  final String name;

  /// The values the form asks for, in order.
  final List<LabMeasure> measures;
}

/// The tests offered in Add Lab Result. Reference ranges are common adult
/// ranges for display only (not medical advice); a real clinic would use
/// the ranges printed by its own laboratory.
const List<LabTestOption> kLabTestCatalog = [
  LabTestOption(
    name: 'Complete Blood Count (CBC)',
    measures: [
      LabMeasure('Hemoglobin', 'g/dL', '12.0-17.5'),
      LabMeasure('Hematocrit', '%', '36-50'),
      LabMeasure('White Blood Cells', 'x10^9/L', '4.0-11.0'),
      LabMeasure('Platelets', 'x10^9/L', '150-450'),
    ],
  ),
  LabTestOption(
    name: 'Fasting Blood Sugar (FBS)',
    measures: [
      LabMeasure('Glucose', 'mg/dL', '70-100'),
    ],
  ),
  LabTestOption(
    name: 'Lipid Profile',
    measures: [
      LabMeasure('Total Cholesterol', 'mg/dL', '0-200'),
      LabMeasure('LDL Cholesterol', 'mg/dL', '0-100'),
      LabMeasure('HDL Cholesterol', 'mg/dL', '40-60'),
      LabMeasure('Triglycerides', 'mg/dL', '0-150'),
    ],
  ),
  LabTestOption(
    name: 'Kidney Function',
    measures: [
      LabMeasure('Creatinine', 'mg/dL', '0.6-1.3'),
      LabMeasure('Blood Urea Nitrogen', 'mg/dL', '7-20'),
      LabMeasure('Uric Acid', 'mg/dL', '3.5-7.2'),
    ],
  ),
  LabTestOption(
    name: 'Urinalysis',
    measures: [
      LabMeasure('pH', '', '4.5-8.0'),
      LabMeasure('Specific Gravity', '', '1.005-1.030'),
    ],
  ),
];
