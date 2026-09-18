T _enumFromJson<T>(
  Iterable<T> values,
  String jsonValue,
  String Function(T value) getJsonValue,
  String enumName,
) {
  for (final value in values) {
    if (getJsonValue(value) == jsonValue) {
      return value;
    }
  }

  throw FormatException('Unknown $enumName value: $jsonValue');
}

enum SurveyStatus {
  inProgress('in_progress'),
  completed('completed');

  const SurveyStatus(this.jsonValue);

  final String jsonValue;

  static SurveyStatus fromJson(String value) => _enumFromJson(
        SurveyStatus.values,
        value,
        (status) => status.jsonValue,
        'SurveyStatus',
      );
}

enum UploadStatus {
  notUploaded('not_uploaded'),
  pending('pending'),
  uploading('uploading'),
  uploaded('uploaded'),
  failed('failed');

  const UploadStatus(this.jsonValue);

  final String jsonValue;

  static UploadStatus fromJson(String value) => _enumFromJson(
        UploadStatus.values,
        value,
        (status) => status.jsonValue,
        'UploadStatus',
      );
}

enum TableKind {
  normal('normal'),
  hangingBasket('hanging_basket'),
  custom('custom');

  const TableKind(this.jsonValue);

  final String jsonValue;

  static TableKind fromJson(String value) => _enumFromJson(
        TableKind.values,
        value,
        (kind) => kind.jsonValue,
        'TableKind',
      );
}

/// Horizontal tables occupy 3 columns by 2 rows.
/// Vertical tables occupy 2 columns by 3 rows.
enum TableOrientation {
  horizontal('horizontal'),
  vertical('vertical');

  const TableOrientation(this.jsonValue);

  final String jsonValue;

  static TableOrientation fromJson(String value) => _enumFromJson(
        TableOrientation.values,
        value,
        (orientation) => orientation.jsonValue,
        'TableOrientation',
      );
}

enum WallSide {
  top('top'),
  right('right'),
  bottom('bottom'),
  left('left');

  const WallSide(this.jsonValue);

  final String jsonValue;

  static WallSide fromJson(String value) => _enumFromJson(
        WallSide.values,
        value,
        (side) => side.jsonValue,
        'WallSide',
      );
}

enum EdgeSide {
  top('top'),
  right('right'),
  bottom('bottom'),
  left('left');

  const EdgeSide(this.jsonValue);

  final String jsonValue;

  static EdgeSide fromJson(String value) => _enumFromJson(
        EdgeSide.values,
        value,
        (side) => side.jsonValue,
        'EdgeSide',
      );
}
