import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/medicine.dart';
import '../services/medicine_service.dart';

// Provides the MedicineService instance (overridable in widget tests)
final medicineServiceProvider = Provider<MedicineService>((ref) {
  return MedicineService();
});

// Holds the active search query, filters, and sort selection
class MedicineSearchFilterState {
  const MedicineSearchFilterState({
    this.query = '',
    this.strength = '',
    this.dosageForm,
    this.location = '',
    this.sort = 'relevance',
    this.latitude,
    this.longitude,
  });

  final String query;
  final String strength;
  final String? dosageForm;
  final String location;
  final String sort;
  final double? latitude;
  final double? longitude;

  // Counts optional advanced filters (strength and location)
  int get activeExtraFilterCount =>
      (strength.trim().isNotEmpty ? 1 : 0) +
      (location.trim().isNotEmpty ? 1 : 0);

  MedicineSearchFilterState copyWith({
    String? query,
    String? strength,
    String? dosageForm,
    bool clearDosageForm = false,
    String? location,
    String? sort,
    double? latitude,
    double? longitude,
  }) {
    return MedicineSearchFilterState(
      query: query ?? this.query,
      strength: strength ?? this.strength,
      dosageForm: clearDosageForm ? null : (dosageForm ?? this.dosageForm),
      location: location ?? this.location,
      sort: sort ?? this.sort,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

// Manages search filter updates from the Search screen
class MedicineSearchFilterNotifier extends Notifier<MedicineSearchFilterState> {
  @override
  MedicineSearchFilterState build() => const MedicineSearchFilterState();

  void setQuery(String value) {
    state = state.copyWith(query: value);
  }

  void setDosageForm(String? form) {
    if (form == null || form.isEmpty) {
      state = state.copyWith(clearDosageForm: true);
    } else {
      state = state.copyWith(dosageForm: form);
    }
  }

  void setStrength(String value) {
    state = state.copyWith(strength: value);
  }

  void setLocation(String value) {
    state = state.copyWith(location: value);
  }

  void setSort(String sortMode) {
    state = state.copyWith(sort: sortMode);
  }

  void clearExtraFilters() {
    state = state.copyWith(strength: '', location: '');
  }

  void resetAll() {
    state = const MedicineSearchFilterState();
  }
}

final medicineSearchFilterProvider =
    NotifierProvider<MedicineSearchFilterNotifier, MedicineSearchFilterState>(
  MedicineSearchFilterNotifier.new,
);

// Loads available dosage forms for the filter chip bar
final dosageFormsProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(medicineServiceProvider);
  return service.getDosageForms();
});

// Fetches matching medicines whenever search filters or sort order change
final medicineSearchResultsProvider =
    FutureProvider<List<MedicineSearchResult>>((ref) async {
  final service = ref.watch(medicineServiceProvider);
  final filter = ref.watch(medicineSearchFilterProvider);

  return service.searchMedicines(
    query: filter.query.trim().isEmpty ? null : filter.query.trim(),
    strength: filter.strength.trim().isEmpty ? null : filter.strength.trim(),
    dosageForm: filter.dosageForm,
    location: filter.location.trim().isEmpty ? null : filter.location.trim(),
    sort: filter.sort,
    latitude: filter.latitude,
    longitude: filter.longitude,
  );
});