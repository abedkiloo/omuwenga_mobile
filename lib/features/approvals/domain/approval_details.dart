/// Structured checker details from the API (`approval_details` / `details`).

class ApprovalFact {
  const ApprovalFact({
    required this.label,
    required this.value,
    this.kind = 'text',
  });

  final String label;
  final String value;
  final String kind;

  factory ApprovalFact.fromJson(Map<String, dynamic> json) {
    return ApprovalFact(
      label: (json['label'] ?? '').toString(),
      value: (json['value'] ?? '').toString(),
      kind: (json['kind'] ?? 'text').toString(),
    );
  }
}

class ApprovalLine {
  const ApprovalLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.variant = '',
  });

  final String name;
  final String variant;
  final String quantity;
  final String unitPrice;
  final String subtotal;

  factory ApprovalLine.fromJson(Map<String, dynamic> json) {
    return ApprovalLine(
      name: (json['name'] ?? 'Item').toString(),
      variant: (json['variant'] ?? '').toString(),
      quantity: (json['quantity'] ?? '').toString(),
      unitPrice: (json['unit_price'] ?? '0').toString(),
      subtotal: (json['subtotal'] ?? '0').toString(),
    );
  }
}

class ApprovalSection {
  const ApprovalSection({
    required this.title,
    this.facts = const [],
    this.lines = const [],
  });

  final String title;
  final List<ApprovalFact> facts;
  final List<ApprovalLine> lines;

  factory ApprovalSection.fromJson(Map<String, dynamic> json) {
    final facts = <ApprovalFact>[];
    final rawFacts = json['facts'];
    if (rawFacts is List) {
      for (final row in rawFacts) {
        if (row is Map) {
          facts.add(ApprovalFact.fromJson(Map<String, dynamic>.from(row)));
        }
      }
    }
    final lines = <ApprovalLine>[];
    final rawLines = json['lines'];
    if (rawLines is List) {
      for (final row in rawLines) {
        if (row is Map) {
          lines.add(ApprovalLine.fromJson(Map<String, dynamic>.from(row)));
        }
      }
    }
    return ApprovalSection(
      title: (json['title'] ?? '').toString(),
      facts: facts,
      lines: lines,
    );
  }
}

class ApprovalDetails {
  const ApprovalDetails({this.sections = const []});

  final List<ApprovalSection> sections;

  bool get isEmpty => sections.isEmpty;

  factory ApprovalDetails.fromJson(Object? raw) {
    if (raw is! Map) return const ApprovalDetails();
    final map = Map<String, dynamic>.from(raw);
    final sections = <ApprovalSection>[];
    final rawSections = map['sections'];
    if (rawSections is List) {
      for (final row in rawSections) {
        if (row is Map) {
          sections.add(
            ApprovalSection.fromJson(Map<String, dynamic>.from(row)),
          );
        }
      }
    }
    return ApprovalDetails(sections: sections);
  }
}
