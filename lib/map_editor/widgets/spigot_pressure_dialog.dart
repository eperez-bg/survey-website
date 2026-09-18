import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum SpigotPressureAction { save, delete }

class SpigotPressureDialogResult {
  final SpigotPressureAction action;
  final double? pressurePsi;

  const SpigotPressureDialogResult.save(double pressurePsi)
    : action = SpigotPressureAction.save,
      pressurePsi = pressurePsi;

  const SpigotPressureDialogResult.delete()
    : action = SpigotPressureAction.delete,
      pressurePsi = null;
}

/// Collects the PSI reading at the same time a map spigot is added or edited.
Future<SpigotPressureDialogResult?> showSpigotPressureDialog(
  BuildContext context, {
  double? initialPressurePsi,
  bool allowDelete = false,
}) {
  return showDialog<SpigotPressureDialogResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _SpigotPressureDialog(
      initialPressurePsi: initialPressurePsi,
      allowDelete: allowDelete,
    ),
  );
}

class _SpigotPressureDialog extends StatefulWidget {
  final double? initialPressurePsi;
  final bool allowDelete;

  const _SpigotPressureDialog({
    required this.initialPressurePsi,
    required this.allowDelete,
  });

  @override
  State<_SpigotPressureDialog> createState() => _SpigotPressureDialogState();
}

class _SpigotPressureDialogState extends State<_SpigotPressureDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _pressureController;

  @override
  void initState() {
    super.initState();
    _pressureController = TextEditingController(
      text: _formatNumber(widget.initialPressurePsi),
    );
  }

  @override
  void dispose() {
    _pressureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.allowDelete;

    return AlertDialog(
      title: Text(isEditing ? 'Edit spigot' : 'Add spigot'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the pressure measured at this spigot.'),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('spigot-pressure-dialog-field'),
              controller: _pressureController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Pressure',
                hintText: 'Example: 52.5',
                suffixText: 'PSI',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final pressure = double.tryParse(value?.trim() ?? '');
                if (pressure == null || !pressure.isFinite || pressure < 0) {
                  return 'Enter a PSI value of zero or greater.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        if (isEditing)
          TextButton.icon(
            key: const ValueKey('delete-spigot-dialog-button'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.of(
              context,
            ).pop(const SpigotPressureDialogResult.delete()),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('save-spigot-dialog-button'),
          onPressed: _save,
          child: Text(isEditing ? 'Save changes' : 'Add spigot'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      SpigotPressureDialogResult.save(
        double.parse(_pressureController.text.trim()),
      ),
    );
  }
}

String _formatNumber(double? value) {
  if (value == null) {
    return '';
  }
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
