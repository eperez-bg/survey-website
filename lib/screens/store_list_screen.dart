// store_list_screen.dart
//
// Responsibility:
// Main desktop workspace: business-friendly store list on the left and the
// selected store map/editor on the right. Storage-folder browsing is deliberately
// not the primary UI; version paths remain visible for debugging and history.

import 'package:flutter/material.dart';

import '../controllers/survey_admin_controller.dart';
import '../models/store_record.dart';
import 'store_detail_screen.dart';

class StoreListScreen extends StatelessWidget {
  final SurveyAdminController controller;

  const StoreListScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(controller: controller),
            _MessageBar(controller: controller),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 900) {
                    return _NarrowLayout(controller: controller);
                  }
                  return Row(
                    children: [
                      SizedBox(
                        width: 365,
                        child: _StorePane(controller: controller),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: StoreDetailScreen(controller: controller),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final SurveyAdminController controller;

  const _TopBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.storefront_outlined, size: 30),
            const SizedBox(width: 10),
            Text(
              'Survey Production Admin',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            if (controller.isBusy) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
            ],
            Text('${controller.stores.length} stores'),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: controller.isBusy
                  ? null
                  : () => controller.synchronizeSurveyIndex(),
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Sync index'),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Refresh survey metadata index',
              onPressed: controller.isBusy
                  ? null
                  : () => controller.refreshStoreIndex(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBar extends StatelessWidget {
  final SurveyAdminController controller;

  const _MessageBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final error = controller.errorMessage;
    final status = controller.statusMessage;
    if (error == null && status == null) {
      return const SizedBox.shrink();
    }

    final isError = error != null;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: isError ? scheme.errorContainer : scheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.info_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error ?? status!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: controller.clearMessage,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

class _StorePane extends StatelessWidget {
  final SurveyAdminController controller;

  const _StorePane({required this.controller});

  @override
  Widget build(BuildContext context) {
    final stores = controller.filteredStores;
    final allFilteredSelected = stores.isNotEmpty &&
        stores.every(controller.isStoreSelected);

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  onChanged: controller.setSearchQuery,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search store number or city',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: controller.stateFilter,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'State',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All states'),
                          ),
                          for (final state in controller.availableStates)
                            DropdownMenuItem<String?>(
                              value: state,
                              child: Text(state),
                            ),
                        ],
                        onChanged: controller.setStateFilter,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Checkbox(
                      value: allFilteredSelected,
                      onChanged: stores.isEmpty
                          ? null
                          : (selected) => controller.selectAllFiltered(
                                selected ?? false,
                              ),
                    ),
                    const Text('All'),
                  ],
                ),
                const SizedBox(height: 8),
                _BulkActions(controller: controller),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: stores.isEmpty
                ? const Center(child: Text('No stores match the filters.'))
                : ListView.builder(
                    itemCount: stores.length,
                    itemBuilder: (context, index) => _StoreListTile(
                      controller: controller,
                      store: stores[index],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BulkActions extends StatelessWidget {
  final SurveyAdminController controller;

  const _BulkActions({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        OutlinedButton.icon(
          onPressed:
              controller.isBusy ? null : controller.downloadSelectedExcel,
          icon: const Icon(Icons.table_view, size: 18),
          label: Text('Selected XLSX (${controller.selectedStoreCount})'),
        ),
        OutlinedButton.icon(
          onPressed: controller.isBusy ? null : controller.downloadSelectedPdf,
          icon: const Icon(Icons.picture_as_pdf, size: 18),
          label: const Text('Selected PDF'),
        ),
        OutlinedButton.icon(
          onPressed: controller.isBusy ? null : controller.downloadAllExcel,
          icon: const Icon(Icons.download_for_offline_outlined, size: 18),
          label: const Text('All XLSX'),
        ),
      ],
    );
  }
}

class _StoreListTile extends StatelessWidget {
  final SurveyAdminController controller;
  final StoreRecord store;

  const _StoreListTile({required this.controller, required this.store});

  @override
  Widget build(BuildContext context) {
    final isCurrent = controller.currentStore?.key == store.key;
    return Material(
      color: isCurrent
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
          : Colors.transparent,
      child: InkWell(
        onTap: controller.isBusy ? null : () => controller.openStore(store),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 12, 8),
          child: Row(
            children: [
              Checkbox(
                value: controller.isStoreSelected(store),
                onChanged: (value) =>
                    controller.setStoreSelected(store, value ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Store ${store.storeNumber}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      store.locationLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${store.versionCount} version'
                      '${store.versionCount == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  final SurveyAdminController controller;

  const _NarrowLayout({required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.currentSurvey != null) {
      return Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                // On narrow screens the selected detail remains visible. A full
                // mobile navigation shell can be added later if this is needed.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Use a wider browser window to show list + map together.'),
                  ),
                );
              },
              icon: const Icon(Icons.info_outline),
              label: const Text('Desktop layout recommended'),
            ),
          ),
          Expanded(child: StoreDetailScreen(controller: controller)),
        ],
      );
    }
    return _StorePane(controller: controller);
  }
}
