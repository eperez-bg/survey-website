// canopy_height_dialog.dart
//
// Responsibility:
// Collects and validates the measured canopy dimensions immediately before
// the map controller commits a previewed canopy rectangle.
//
// Classes and functions:
// - CanopyHeightInput: Typed result containing all measurements in inches.
// - showCanopyHeightDialog: Opens the required modal input flow.
// - _CanopyHeightDialog: Owns temporary text-entry and validation state.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CanopyHeightInput {
  final double heightInches;
  final double lengthInches;
  final double widthInches;

  const CanopyHeightInput({
    required this.heightInches,
    required this.lengthInches,
    required this.widthInches,
  });
}

/// Displays a non-dismissible measurement prompt for a new canopy area.
///
/// Cancel returns null without changing the controller's canopy preview, so
/// the surveyor can confirm again or explicitly cancel the draft afterward.
Future<CanopyHeightInput?> showCanopyHeightDialog(
  BuildContext context, {
  CanopyHeightInput? initialInput,
}) {
  return showDialog<CanopyHeightInput>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _CanopyHeightDialog(initialInput: initialInput),
  );
}

class _CanopyHeightDialog extends StatefulWidget {
  final CanopyHeightInput? initialInput;

  const _CanopyHeightDialog({this.initialInput});

  @override
  State<_CanopyHeightDialog> createState() => _CanopyHeightDialogState();
}

class _CanopyHeightDialogState extends State<_CanopyHeightDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _heightController;
  late final TextEditingController _lengthController;
  late final TextEditingController _widthController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialInput;
    _heightController = TextEditingController(
      text: initial == null ? '' : _format(initial.heightInches),
    );
    _lengthController = TextEditingController(
      text: initial == null ? '' : _format(initial.lengthInches),
    );
    _widthController = TextEditingController(
      text: initial == null ? '' : _format(initial.widthInches),
    );
  }

  @override
  void dispose() {
    _heightController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Canopy dimensions'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the measured height, length, and width in inches.',
            ),
            const SizedBox(height: 16),
            _measurementField(
              key: const ValueKey('canopy-height-inches-field'),
              controller: _heightController,
              label: 'Canopy height',
              hint: 'Example: 120',
              validationLabel: 'height',
              autofocus: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _measurementField(
              key: const ValueKey('canopy-length-inches-field'),
              controller: _lengthController,
              label: 'Canopy length',
              hint: 'Example: 240',
              validationLabel: 'length',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _measurementField(
              key: const ValueKey('canopy-width-inches-field'),
              controller: _widthController,
              label: 'Canopy width',
              hint: 'Example: 180',
              validationLabel: 'width',
              textInputAction: TextInputAction.done,
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
          key: const ValueKey('save-canopy-height-button'),
          onPressed: _save,
          child: Text(
            widget.initialInput == null ? 'Add canopy' : 'Save changes',
          ),
        ),
      ],
    );
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      CanopyHeightInput(
        heightInches: double.parse(_heightController.text.trim()),
        lengthInches: double.parse(_lengthController.text.trim()),
        widthInches: double.parse(_widthController.text.trim()),
      ),
    );
  }

  TextFormField _measurementField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required String hint,
    required String validationLabel,
    required TextInputAction textInputAction,
    bool autofocus = false,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: textInputAction,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: 'in',
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final measurement = double.tryParse(value?.trim() ?? '');
        if (measurement == null ||
            !measurement.isFinite ||
            measurement <= 0) {
          return 'Enter a $validationLabel greater than zero.';
        }
        return null;
      },
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}
