import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:survey_admin_web/map_editor/models/map_editor_models.dart';

/// Collects the persisted label used for a new or selected custom table.
Future<String?> showCustomTableNameDialog(
  BuildContext context, {
  String? initialName,
  int tableCount = 1,
  bool isRenaming = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _CustomTableNameDialog(
      initialName: initialName,
      tableCount: tableCount,
      isRenaming: isRenaming,
    ),
  );
}

class _CustomTableNameDialog extends StatefulWidget {
  final String? initialName;
  final int tableCount;
  final bool isRenaming;

  const _CustomTableNameDialog({
    required this.initialName,
    required this.tableCount,
    required this.isRenaming,
  });

  @override
  State<_CustomTableNameDialog> createState() =>
      _CustomTableNameDialogState();
}

class _CustomTableNameDialogState extends State<_CustomTableNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _nameController.selection = TextSelection.collapsed(
      offset: _nameController.text.length,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMultiple = widget.tableCount > 1;

    return AlertDialog(
      title: Text(
        widget.isRenaming
            ? isMultiple
                  ? 'Rename custom tables'
                  : 'Rename custom table'
            : 'Name custom table',
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isRenaming
                    ? isMultiple
                          ? 'This name will be applied to all '
                                '${widget.tableCount} selected custom tables.'
                          : 'Enter the new name to display on the map.'
                    : 'Enter the name to display inside this table on the map.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('custom-table-name-field'),
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                maxLength: LayoutTable.maxCustomNameLength,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    LayoutTable.maxCustomNameLength,
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Table name',
                  hintText: 'Example: Checkout Table',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a table name.'
                    : null,
                onFieldSubmitted: (_) => _submit(),
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
        FilledButton.icon(
          key: const ValueKey('save-custom-table-name-button'),
          onPressed: _submit,
          icon: Icon(widget.isRenaming ? Icons.edit : Icons.add),
          label: Text(widget.isRenaming ? 'Rename' : 'Add table'),
        ),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    Navigator.of(context).pop(_nameController.text.trim());
  }
}
