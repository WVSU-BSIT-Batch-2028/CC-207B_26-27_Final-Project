import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/catalogue_providers.dart';
import 'medicine_drawer.dart';

// Resolves the selected catalogue row and hosts [MedicineDrawer] in the admin shell.
class CatalogueMedicineShellDrawer extends ConsumerWidget {
  const CatalogueMedicineShellDrawer({
    super.key,
    required this.selection,
    required this.onClose,
  });

  /// `'new'` to add, otherwise a medicine id.
  final String selection;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(catalogueListProvider).asData?.value;
    final medicine = selection == 'new'
        ? null
        : rows?.where((m) => m.id == selection).firstOrNull;

    return MedicineDrawer(
      key: ValueKey(selection),
      medicine: medicine,
      onClose: onClose,
    );
  }
}