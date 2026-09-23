// survey_deletion_card.dart
//
// Responsibility:
// Presents the store-page danger zone and the two-step irreversible-delete
// confirmation flow. Supabase mutations remain in repositories/controller.

import 'package:flutter/material.dart';

import '../controllers/survey_admin_controller.dart';

enum _DeletionTarget { currentSurvey, store }

class SurveyDeletionCard extends StatelessWidget {
  final SurveyAdminController controller;

  const SurveyDeletionCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = controller.currentStore;
    final survey = controller.currentSurvey;
    final objectPath = controller.currentObjectPath;
    if (store == null || survey == null || objectPath == null) {
      return const SizedBox.shrink();
    }

    return Card(
      color: scheme.errorContainer.withOpacity(0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.error.withOpacity(0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: scheme.error),
                const SizedBox(width: 9),
                Text(
                  'Danger zone',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.error,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'These actions permanently remove survey JSON files from '
              'Supabase Storage and their matching metadata index rows.',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error),
                  ),
                  onPressed: controller.isBusy
                      ? null
                      : () => _requestDeletion(
                            context,
                            _DeletionTarget.currentSurvey,
                          ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete current survey'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  ),
                  onPressed: controller.isBusy
                      ? null
                      : () => _requestDeletion(
                            context,
                            _DeletionTarget.store,
                          ),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Delete Store'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestDeletion(
    BuildContext context,
    _DeletionTarget target,
  ) async {
    final store = controller.currentStore;
    final objectPath = controller.currentObjectPath;
    if (store == null || objectPath == null) {
      return;
    }

    final fileName = objectPath.split('/').last;
    final deletingStore = target == _DeletionTarget.store;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(
          deletingStore
              ? 'Delete Store ${store.storeNumber}?'
              : 'Delete current survey?',
        ),
        content: Text(
          deletingStore
              ? 'This is irreversible. All ${store.versionCount} survey '
                  'version${store.versionCount == 1 ? '' : 's'} for Store '
                  '${store.storeNumber} will be permanently deleted from '
                  'Storage and the metadata index.'
              : 'This is irreversible. $fileName will be permanently deleted '
                  'from Storage and the metadata index. If this store has '
                  'another version, its newest remaining survey will become '
                  'the selected version.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              deletingStore ? 'Delete Store' : 'Delete current survey',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final password = await _requestPassword(context);
    if (password == null || !context.mounted) {
      return;
    }

    final result = deletingStore
        ? await controller.deleteCurrentStore(password: password)
        : await controller.deleteCurrentSurvey(password: password);
    if (!context.mounted || result.message == null) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(result.message!),
          backgroundColor: result.succeeded
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
        ),
      );
  }

  Future<String?> _requestPassword(BuildContext context) async {
    final passwordController = TextEditingController();
    String? errorText;
    var obscureText = true;

    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            void submit() {
              final password = passwordController.text;
              if (!controller.isDeletePasswordValid(password)) {
                setDialogState(() {
                  errorText = 'Incorrect delete password.';
                });
                return;
              }
              Navigator.of(dialogContext).pop(password);
            }

            return AlertDialog(
              icon: Icon(
                Icons.lock_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('Enter delete password'),
              content: SizedBox(
                width: 420,
                child: TextField(
                  controller: passwordController,
                  autofocus: true,
                  obscureText: obscureText,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => submit(),
                  decoration: InputDecoration(
                    labelText: 'Delete password',
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: obscureText ? 'Show password' : 'Hide password',
                      onPressed: () {
                        setDialogState(() {
                          obscureText = !obscureText;
                        });
                      },
                      icon: Icon(
                        obscureText
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: submit,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Delete permanently'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      passwordController.dispose();
    }
  }
}
