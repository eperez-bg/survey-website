// raw_json_editor_dialog.dart
//
// Responsibility:
// Provides a fallback editor for any current or future survey field. This is
// especially useful while the production model and calculation schema evolve.

import 'package:flutter/material.dart';

class RawJsonEditorDialog extends StatefulWidget {
  final String initialJson;
  final ValueChanged<String> onApply;

  const RawJsonEditorDialog({
    super.key,
    required this.initialJson,
    required this.onApply,
  });

  @override
  State<RawJsonEditorDialog> createState() => _RawJsonEditorDialogState();
}

class _RawJsonEditorDialogState extends State<RawJsonEditorDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialJson);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit raw survey JSON'),
      content: SizedBox(
        width: 850,
        height: 620,
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Survey JSON',
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            try {
              widget.onApply(_controller.text);
              Navigator.of(context).pop();
            } catch (error) {
              setState(() => _error = error.toString());
            }
          },
          child: const Text('Apply JSON'),
        ),
      ],
    );
  }
}
