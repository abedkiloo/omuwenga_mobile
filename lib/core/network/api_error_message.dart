import 'dart:convert';

/// Friendly labels for common DRF field names on customer / sales forms.
const Map<String, String> kApiFieldLabels = {
  'name': 'Duka name',
  'phone': 'Phone',
  'email': 'Email',
  'owner_name': "Owner's name",
  'contact_person': 'Contact person',
  'address': 'Landmark',
  'city': 'City',
  'county': 'County',
  'sub_county': 'Sub-county',
  'ward': 'Ward',
  'typical_goods': 'Goods',
  'latitude': 'Location',
  'longitude': 'Location',
  'location_accuracy': 'Location',
  'non_field_errors': '',
};

String _stringifyMessage(Object? value) {
  if (value == null) return '';
  if (value is List) {
    return value
        .map(_stringifyMessage)
        .where((part) => part.isNotEmpty)
        .join(' ');
  }
  if (value is Map) {
    return formatApiErrorMap(Map<String, dynamic>.from(value));
  }
  return value.toString().trim();
}

String _labelFor(String field) {
  if (kApiFieldLabels.containsKey(field)) {
    return kApiFieldLabels[field]!;
  }
  return field
      .replaceAll('_', ' ')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// Turn a DRF / API error payload into a short user-facing sentence.
String formatApiErrorMap(Map<String, dynamic> map) {
  final top =
      map['error'] ??
      map['detail'] ??
      map['message'] ??
      map['rejection_reason'] ??
      map['proposal_reason'] ??
      map['reason'];
  if (top != null) {
    final text = _stringifyMessage(top);
    if (text.isNotEmpty) return text;
  }

  final parts = <String>[];
  final seen = <String>{};
  for (final entry in map.entries) {
    final key = entry.key;
    if (key == 'error' || key == 'detail' || key == 'message') continue;
    final message = _stringifyMessage(entry.value);
    if (message.isEmpty) continue;
    final label = _labelFor(key);
    final String part;
    if (label.isEmpty) {
      part = message;
    } else if (message.toLowerCase().startsWith(label.toLowerCase())) {
      part = message;
    } else {
      part = '$label: $message';
    }
    if (seen.add(part)) {
      parts.add(part);
    }
  }
  if (parts.isNotEmpty) return parts.join('\n');
  return '';
}

/// Parse an HTTP error body into a message the user can act on.
String apiErrorMessage(
  String body, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return fallback;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map) {
      final text = formatApiErrorMap(Map<String, dynamic>.from(decoded));
      if (text.isNotEmpty) return text;
    } else if (decoded is List) {
      final text = _stringifyMessage(decoded);
      if (text.isNotEmpty) return text;
    } else if (decoded is String && decoded.trim().isNotEmpty) {
      return decoded.trim();
    }
  } on Object {
    // Non-JSON body — use a short plain snippet when it looks human.
    if (trimmed.length <= 180 &&
        !trimmed.contains('<') &&
        !trimmed.toLowerCase().contains('traceback')) {
      return trimmed;
    }
  }
  return fallback;
}
