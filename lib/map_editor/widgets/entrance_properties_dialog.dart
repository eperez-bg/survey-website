// entrance_properties_dialog.dart
//
// Responsibility:
// Collects the editable wall, offset, width, and clearance values for one
// entrance. Geometry validation remains in MapEditorController so the dialog
// only owns temporary form input.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/map_editor_models.dart';

class EntrancePropertiesInput {
  final WallSide wallSide;
  final int offsetCells;
  final int widthCells;
  final int clearanceDepthCells;

  const EntrancePropertiesInput({
    required this.wallSide,
    required this.offsetCells,
    required this.widthCells,
    required this.clearanceDepthCells,
  });
}

Future<EntrancePropertiesInput?> showEntrancePropertiesDialog(
  BuildContext context, {
  required Entrance entrance,
}) {
  return showDialog<EntrancePropertiesInput>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _EntrancePropertiesDialog(entrance: entrance),
  );
}

class _EntrancePropertiesDialog extends StatefulWidget {
  final Entrance entrance;

  const _EntrancePropertiesDialog({required this.entrance});

  @override
  State<_EntrancePropertiesDialog> createState() =>
      _EntrancePropertiesDialogState();
}

class _EntrancePropertiesDialogState
    extends State<_EntrancePropertiesDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late WallSide _wallSide;
  late final TextEditingController _offsetController;
  late final TextEditingController _widthController;
  late final TextEditingController _clearanceController;

  @override
  void initState() {
    super.initState();
    _wallSide = widget.entrance.wallSide;
    _offsetController = TextEditingController(
      text: widget.entrance.offsetCells.toString(),
    );
    _widthController = TextEditingController(
      text: widget.entrance.widthCells.toString(),
    );
    _clearanceController = TextEditingController(
      text: widget.entrance.clearanceDepthCells.toString(),
    );
  }

  @override
  void dispose() {
    _offsetController.dispose();
    _widthController.dispose();
    _clearanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Edit entrance'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<WallSide>(
                value: _wallSide,
                decoration: const InputDecoration(
                  labelText: 'Wall',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final side in WallSide.values)
                    DropdownMenuItem(
                      value: side,
                      child: Text(_wallLabel(side)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _wallSide = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              _integerField(
                controller: _offsetController,
                label: 'Offset cells',
                minimum: 0,
              ),
              const SizedBox(height: 12),
              _integerField(
                controller: _widthController,
                label: 'Width cells',
                minimum: 1,
              ),
              const SizedBox(height: 12),
              _integerField(
                controller: _clearanceController,
                label: 'Clearance depth cells',
                minimum: 0,
                onSubmitted: (_) => _save(),
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
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Apply changes'),
        ),
      ],
    );
  }

  TextFormField _integerField({
    required TextEditingController controller,
    required String label,
    required int minimum,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final parsed = int.tryParse(value?.trim() ?? '');
        if (parsed == null || parsed < minimum) {
          return minimum == 0
              ? 'Enter zero or a larger whole number.'
              : 'Enter a whole number of at least $minimum.';
        }
        return null;
      },
      onFieldSubmitted: onSubmitted,
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      EntrancePropertiesInput(
        wallSide: _wallSide,
        offsetCells: int.parse(_offsetController.text.trim()),
        widthCells: int.parse(_widthController.text.trim()),
        clearanceDepthCells: int.parse(_clearanceController.text.trim()),
      ),
    );
  }

  String _wallLabel(WallSide side) => switch (side) {
        WallSide.top => 'Top',
        WallSide.right => 'Right',
        WallSide.bottom => 'Bottom',
        WallSide.left => 'Left',
      };
}
