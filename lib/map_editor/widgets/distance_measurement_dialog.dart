import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:survey_admin_web/map_editor/models/map_editor_models.dart';

class DistanceMeasurementInput {
  final double measuredDistance;

  const DistanceMeasurementInput({required this.measuredDistance});
}

Future<DistanceMeasurementInput?> showDistanceMeasurementDialog(
  BuildContext context, {
  Distance? initialDistance,
}) {
  return showDialog<DistanceMeasurementInput>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        _DistanceMeasurementDialog(initialDistance: initialDistance),
  );
}

class _DistanceMeasurementDialog extends StatefulWidget {
  final Distance? initialDistance;

  const _DistanceMeasurementDialog({this.initialDistance});

  @override
  State<_DistanceMeasurementDialog> createState() =>
      _DistanceMeasurementDialogState();
}

class _DistanceMeasurementDialogState extends State<_DistanceMeasurementDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _distanceController;

  @override
  void initState() {
    super.initState();
    final initialDistance = widget.initialDistance?.measuredDistance;
    _distanceController = TextEditingController(
      text: initialDistance == null
          ? ''
          : initialDistance == initialDistance.roundToDouble()
          ? initialDistance.toInt().toString()
          : initialDistance.toString(),
    );
  }

  @override
  void dispose() {
    _distanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialDistance != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit distance' : 'Distance'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the total end-to-end distance between the selected '
              'endpoints, in inches.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('distance-inches-field'),
              controller: _distanceController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Total distance',
                hintText: 'Example: 54',
                suffixText: 'in',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final parsed = double.tryParse(value?.trim() ?? '');
                if (parsed == null || !parsed.isFinite || parsed <= 0) {
                  return 'Enter a distance greater than zero.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(isEditing ? 'Save changes' : 'Add distance'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      DistanceMeasurementInput(
        measuredDistance: double.parse(_distanceController.text.trim()),
      ),
    );
  }
}
