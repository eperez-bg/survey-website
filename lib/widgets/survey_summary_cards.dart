// survey_summary_cards.dart
//
// Responsibility:
// Presents survey, store, and PIC metadata in two readable summary cards.
// Parsing and compatibility fallbacks remain in SurveyDocument.

import 'package:flutter/material.dart';

import '../models/survey_document.dart';

class SurveySummaryCard extends StatelessWidget {
  final SurveyDocument survey;

  const SurveySummaryCard({super.key, required this.survey});

  @override
  Widget build(BuildContext context) {
    final completedAt = survey.completedAt?.toLocal();
    return _InformationSummaryCard(
      title: 'Survey Summary',
      items: [
        _SummaryItem(
          label: 'Date completed',
          value: completedAt == null
              ? 'Not available'
              : _formatDate(completedAt),
        ),
        _SummaryItem(
          label: 'Time completed',
          value: completedAt == null
              ? 'Not available'
              : _formatTime(completedAt),
        ),
        _SummaryItem(
          label: 'Surveyor',
          value: _displayValue(survey.surveyorName),
        ),
        _SummaryItem(
          label: 'Company',
          value: _displayValue(survey.surveyorCompany),
        ),
      ],
    );
  }
}

class StoreSummaryCard extends StatelessWidget {
  final SurveyDocument survey;

  const StoreSummaryCard({super.key, required this.survey});

  @override
  Widget build(BuildContext context) {
    return _InformationSummaryCard(
      title: 'Store Summary',
      items: [
        _SummaryItem(
          label: 'Store number',
          value: _displayValue(survey.storeNumber),
        ),
        _SummaryItem(label: 'City', value: _displayValue(survey.city)),
        _SummaryItem(label: 'State', value: _displayValue(survey.stateCode)),
        _SummaryItem(
          label: 'Address',
          value: _formattedAddress(survey),
        ),
        _SummaryItem(label: 'PIC name', value: _displayValue(survey.picName)),
        _SummaryItem(
          label: 'PIC email',
          value: _displayValue(survey.picEmail),
        ),
        _SummaryItem(
          label: 'PIC phone',
          value: _displayValue(survey.picPhone),
        ),
      ],
    );
  }
}

class _InformationSummaryCard extends StatelessWidget {
  final String title;
  final List<_SummaryItem> items;

  const _InformationSummaryCard({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                for (final item in items)
                  SizedBox(
                    width: 220,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          item.value,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});
}

const _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatDate(DateTime value) =>
    '${_monthNames[value.month - 1]} ${value.day}, ${value.year}';

String _formatTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

String _formattedAddress(SurveyDocument survey) {
  final parts = [survey.shippingAddress, survey.postalCode]
      .where((part) => part.trim().isNotEmpty)
      .toList(growable: false);
  return parts.isEmpty ? '—' : parts.join(', ');
}

String _displayValue(String value) => value.trim().isEmpty ? '—' : value.trim();
