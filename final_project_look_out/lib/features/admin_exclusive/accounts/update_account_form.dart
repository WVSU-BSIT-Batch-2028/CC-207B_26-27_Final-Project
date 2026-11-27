import 'package:flutter/material.dart';

class UpdateAccountFormData {
  const UpdateAccountFormData({required this.fullName, required this.role});

  final String fullName;
  final String role;
}

Future<UpdateAccountFormData?> showUpdateAccountForm(
  BuildContext context, {
  required String fullName,
  required String role,
}) {
  return showDialog<UpdateAccountFormData>(
    context: context,
    builder: (context) => _UpdateAccountDialog(fullName: fullName, role: role),
  );
}

class _UpdateAccountDialog extends StatefulWidget {
  const _UpdateAccountDialog({required this.fullName, required this.role});

  final String fullName;
  final String role;

  @override
  State<_UpdateAccountDialog> createState() => _UpdateAccountDialogState();
}

class _UpdateAccountDialogState extends State<_UpdateAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _role;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.fullName);
    _role = widget.role;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;

    Navigator.of(context).pop(
      UpdateAccountFormData(
        fullName: _nameController.text.trim(),
        role: _role,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final standardRoles = {'commuter', 'driver', 'admin'};
    final roles = [
      if (!standardRoles.contains(_role))
        DropdownMenuItem(value: _role, child: Text(_role)),
      const DropdownMenuItem(value: 'commuter', child: Text('Commuter')),
      const DropdownMenuItem(value: 'driver', child: Text('Driver')),
      const DropdownMenuItem(value: 'admin', child: Text('Admin')),
    ];

    return AlertDialog(
      title: const Text('Update account'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name.'
                    : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: roles,
                onChanged: (value) {
                  if (value != null) setState(() => _role = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
