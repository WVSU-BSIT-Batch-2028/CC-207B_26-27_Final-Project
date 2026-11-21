import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../models/doctor.dart';
import '../../../../services/booking_doctor_service.dart';
import '../../../../widgets/h360_button.dart';

/// Displays the available doctors during patient appointment booking.
///
/// Patients can search doctors, filter by specialty, select a doctor,
/// and continue to the date and time selection stage.
class DoctorSelectionScreen extends StatefulWidget {
  /// Creates the doctor selection screen.
  const DoctorSelectionScreen({
    super.key,
    required this.onNext,
  });

  /// Called when the patient presses Next with a selected doctor.
  final ValueChanged<Doctor> onNext;

  @override
  State<DoctorSelectionScreen> createState() => _DoctorSelectionScreenState();
}

/// Manages doctor loading, searching, filtering, and selection.
class _DoctorSelectionScreenState extends State<DoctorSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Doctor> _doctors = [];
  Doctor? _selectedDoctor;

  String _selectedCategory = 'All';
  bool _isLoading = true;
  String? _errorMessage;

  static const List<String> _categories = [
    'All',
    'General',
    'Pediatrics',
    'Internal',
  ];

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Loads available doctors from the booking service.
  Future<void> _loadDoctors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final doctors = await BookingDoctorService.instance.fetchDoctors();

      if (!mounted) return;

      setState(() {
        _doctors = doctors;
        _isLoading = false;
      });
    } on DoctorBookingException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'Something went wrong while loading doctors. Please try again.';
        _isLoading = false;
      });
    }
  }

  /// Returns doctors matching the search text and selected category.
  List<Doctor> get _filteredDoctors {
    final searchText = _searchController.text.trim().toLowerCase();

    return _doctors.where((doctor) {
      final matchesSearch = doctor.name.toLowerCase().contains(searchText) ||
          doctor.specialty.toLowerCase().contains(searchText);

      final matchesCategory =
          _selectedCategory == 'All' || doctor.category == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  /// Changes the active specialty filter.
  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  /// Selects a doctor from the displayed doctor list.
  void _selectDoctor(Doctor doctor) {
    setState(() {
      _selectedDoctor = doctor;
    });
  }

  /// Passes the selected doctor to the next booking stage.
  void _continueBooking() {
    final doctor = _selectedDoctor;

    if (doctor == null) return;

    widget.onNext(doctor);
  }

  /// Builds the doctor selection screen.
  @override
  Widget build(BuildContext context) {
    final filteredDoctors = _filteredDoctors;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Go back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Book an Appointment'),
      ),

      // Main content: search, specialty filters, and doctor list.
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadDoctors,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    // Search field using the shared application theme.
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: AppTheme.inputDecoration(
                        hint: 'Search doctor or specialty...',
                      ).copyWith(
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Specialty filter chips.
                    Text(
                      'Specialty',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: _categories.map((category) {
                        final isSelected = _selectedCategory == category;

                        return ChoiceChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (_) => _onCategorySelected(category),
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.14),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textMuted,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Doctor list heading.
                    Text(
                      'Available Doctors',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Loading, error, empty, or doctor list.
                    if (_isLoading)
                      _buildLoadingState()
                    else if (_errorMessage != null)
                      _buildErrorState()
                    else if (filteredDoctors.isEmpty)
                      _buildEmptyState()
                    else
                      ...filteredDoctors.map(
                        (doctor) => _buildDoctorCard(doctor),
                      ),
                  ],
                ),
              ),
            ),

            // Next button remains disabled until a doctor is selected.
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: H360Button(
                label: 'Next',
                expanded: true,
                onPressed: _selectedDoctor == null ? null : _continueBooking,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the loading indicator while doctors are retrieved.
  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  /// Builds the error message and retry action.
  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 42,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton.icon(
            onPressed: _loadDoctors,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  /// Builds a message when no doctor matches the search or filter.
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Icon(
            Icons.person_search_rounded,
            size: 42,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No doctors found.',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Try another name or specialty.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Builds one selectable doctor card.
  Widget _buildDoctorCard(Doctor doctor) {
    final isSelected = _selectedDoctor?.id == doctor.id;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => _selectDoctor(doctor),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor profile placeholder.
              CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Doctor information.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      doctor.specialty,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _doctorInfoRow(
                      Icons.calendar_today_rounded,
                      doctor.nextAvailable,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _doctorInfoRow(
                      Icons.medical_services_outlined,
                      doctor.consultationType,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppSpacing.xs),

              // Selection indicator.
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Displays a small icon and a line of doctor information.
  Widget _doctorInfoRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
        ),
      ],
    );
  }
}
