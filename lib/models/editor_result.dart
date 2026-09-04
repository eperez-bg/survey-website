// editor_result.dart
//
// Responsibility:
// Gives controller and map widgets one small result type for safe edit attempts.

class EditorResult {
  final bool succeeded;
  final String? message;

  const EditorResult.success([this.message]) : succeeded = true;
  const EditorResult.failure(this.message) : succeeded = false;
}
