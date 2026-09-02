// store_list_screen.dart
// Admin landing page: storage-backed store list, state filter, store search,
// multi-select, bulk exports, and direct sample-survey access.

import 'package:flutter/material.dart';

import '../controllers/store_list_controller.dart';
import '../models/store_record.dart';
import '../utils/app_config.dart';
import 'survey_editor_screen.dart';

class StoreListScreen extends StatefulWidget {
  const StoreListScreen({super.key});

  @override
  State<StoreListScreen> createState() => _StoreListScreenState();
}

class _StoreListScreenState extends State<StoreListScreen> {
  late final StoreListController controller;

  @override
  void initState() {
    super.initState();
    controller = StoreListController()..addListener(_changed);
    controller.load();
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    controller.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Survey Admin'),
        actions: [
          TextButton.icon(
            onPressed: _openSample,
            icon: const Icon(Icons.science_outlined),
            label: const Text('Open sample 2255'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildToolbar(),
            const SizedBox(height: 12),
            if (controller.error != null)
              _message(controller.error!, Colors.red.shade50),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        SizedBox(
          width: 300,
          child: TextField(
            onChanged: controller.setSearch,
            decoration: const InputDecoration(
              labelText: 'Search store number / city',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            initialValue: controller.stateFilter,
            decoration: const InputDecoration(
              labelText: 'State',
              border: OutlineInputBorder(),
            ),
            items: controller.states
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => controller.setState(v ?? 'ALL'),
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: controller.isLoading ? null : controller.load,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
        FilledButton.tonalIcon(
          onPressed: controller.selectedStoreNumbers.isEmpty
              ? null
              : controller.exportSelectedExcel,
          icon: const Icon(Icons.table_view),
          label: const Text('Selected Excel'),
        ),
        FilledButton.tonalIcon(
          onPressed: controller.selectedStoreNumbers.isEmpty
              ? null
              : controller.exportSelectedPdf,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Selected PDF'),
        ),
        FilledButton.icon(
          onPressed: controller.stores.isEmpty
              ? null
              : () => controller.exportSelectedExcel(all: true),
          icon: const Icon(Icons.download),
          label: const Text('All Stores Excel'),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.filteredStores.isEmpty) {
      return const Center(child: Text('No stores found.'));
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        itemCount: controller.filteredStores.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final store = controller.filteredStores[index];
          return ListTile(
            leading: Checkbox(
              value: controller.isSelected(store),
              onChanged: (v) => controller.toggleSelection(store, v ?? false),
            ),
            title: Text('Store ${store.storeNumber}'),
            subtitle: Text('${store.locationLabel}\n${store.latestObjectPath}'),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openStore(store),
          );
        },
      ),
    );
  }

  Widget _message(String text, Color color) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        color: color,
        child: Text(text),
      );

  void _openStore(StoreRecord store) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SurveyEditorScreen(
          objectPath: store.latestObjectPath,
          storeRecord: store,
        ),
      ),
    );
  }

  void _openSample() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SurveyEditorScreen(
          objectPath: AppConfig.sampleObjectPath,
        ),
      ),
    );
  }
}
