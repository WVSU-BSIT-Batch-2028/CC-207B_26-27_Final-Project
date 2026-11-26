// Picking one of the 71 crops. The form field shows the chosen crop with its
// photo; tapping it opens a list grouped by the 6 categories with a search
// box and category chips. On a phone the list slides up from the bottom; on
// a laptop it opens as a dialog. Photos load only for rows on screen.

import 'package:flutter/material.dart';

import '../utils/crop_catalog.dart';
import '../utils/paging.dart';
import '../utils/strings.dart';
import '../utils/theme.dart';
import 'crop_thumb.dart';
import 'responsive_body.dart';

/// Opens the crop list and returns the picked crop name (null = cancelled).
Future<String?> showCropPicker(BuildContext context, {String? selected}) {
  final picker = _CropPickerList(selected: selected);
  if (isWideScreen(context)) {
    return showDialog<String>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
          child: picker,
        ),
      ),
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => FractionallySizedBox(heightFactor: 0.85, child: picker),
  );
}

/// A form field for choosing a crop (validated like the other fields).
class CropPickerField extends FormField<String> {
  CropPickerField({
    super.key,
    required String? value,
    required ValueChanged<String> onChanged,
    bool isRequired = true,
  }) : super(
         initialValue: value,
         validator: (crop) =>
             isRequired && crop == null ? AppStrings.selectRequired : null,
         builder: (field) {
           // Keep the field in step when the value is set from outside
           // (e.g. the AI assistant picked the crop).
           if (field.value != value) {
             WidgetsBinding.instance.addPostFrameCallback(
               (_) => field.didChange(value),
             );
           }
           final crop = value == null ? null : cropInfo(value);
           return InkWell(
             borderRadius: BorderRadius.circular(AppSizes.radiusInput),
             onTap: () async {
               final picked = await showCropPicker(
                 field.context,
                 selected: value,
               );
               if (picked != null) {
                 field.didChange(picked);
                 onChanged(picked);
               }
             },
             child: InputDecorator(
               isEmpty: crop == null,
               decoration: InputDecoration(
                 hintText: 'Choose a crop',
                 errorText: field.errorText,
                 suffixIcon: const Icon(Icons.arrow_drop_down),
                 contentPadding: const EdgeInsets.symmetric(
                   horizontal: 12,
                   vertical: 8,
                 ),
               ),
               child: crop == null
                   ? null
                   : Row(
                       children: [
                         CropThumb(crop: crop.name, size: 32),
                         const SizedBox(width: 10),
                         Expanded(
                           child: Text(
                             crop.name,
                             style: const TextStyle(fontSize: 15),
                           ),
                         ),
                         Text(crop.category.label, style: AppTextStyles.meta),
                       ],
                     ),
             ),
           );
         },
       );
}

/// The list inside the sheet or dialog.
class _CropPickerList extends StatefulWidget {
  const _CropPickerList({this.selected});

  final String? selected;

  @override
  State<_CropPickerList> createState() => _CropPickerListState();
}

class _CropPickerListState extends State<_CropPickerList> {
  String _search = '';
  CropCategory? _category; // null = all categories

  @override
  Widget build(BuildContext context) {
    // Rows: a header per category, then its crops that match the search.
    final rows = <Object>[]; // CropCategory (header) or CropInfo (crop)
    for (final category in CropCategory.values) {
      if (_category != null && category != _category) continue;
      final crops = kCropCatalog.where(
        (crop) =>
            crop.category == category &&
            matchesSearch(_search, [crop.name, ...crop.localNames]),
      );
      if (crops.isEmpty) continue;
      rows
        ..add(category)
        ..addAll(crops);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text('Choose a crop', style: AppTextStyles.sectionTitle),
              ),
              IconButton(
                tooltip: AppStrings.cancel,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            autofocus: isWideScreen(context), // phones: keep the keyboard down
            onChanged: (text) => setState(() => _search = text.trim()),
            decoration: const InputDecoration(
              hintText: 'Search, e.g. tomato or kamatis',
              prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final category in [null, ...CropCategory.values])
                Padding(
                  padding: const EdgeInsets.only(right: AppSizes.small),
                  child: ChoiceChip(
                    label: Text(category?.label ?? 'All'),
                    selected: _category == category,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _category = category),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Divider(),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Text(
                    'No crop matches "$_search".',
                    style: AppTextStyles.lead,
                  ),
                )
              // A builder list: rows (and their photos) are only built
              // when they scroll into view.
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    if (row is CropCategory) return _header(row);
                    return _cropRow(row as CropInfo);
                  },
                ),
        ),
      ],
    );
  }

  Widget _header(CropCategory category) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Icon(category.icon, size: 16, color: AppColors.link),
          const SizedBox(width: 6),
          Text(category.label.toUpperCase(), style: AppTextStyles.eyebrow),
        ],
      ),
    );
  }

  Widget _cropRow(CropInfo crop) {
    final isSelected = crop.name == widget.selected;
    return ListTile(
      selected: isSelected,
      selectedTileColor: AppColors.primaryLight,
      leading: CropThumb(crop: crop.name, size: 40),
      title: Text(crop.name, style: AppTextStyles.cardTitle),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppColors.primaryDark)
          : null,
      onTap: () => Navigator.of(context).pop(crop.name),
    );
  }
}
