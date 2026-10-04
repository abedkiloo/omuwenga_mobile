/// Parse Daily notes rejection notices and map a returned sale to POS.
class ApprovalRejectionNotice {
  const ApprovalRejectionNotice({
    required this.source,
    required this.id,
    this.saleId,
  });

  final String source;
  final int id;
  final int? saleId;
}

final _sourceRe = RegExp(r'^source:\s*(\S+)', multiLine: true);
final _idRe = RegExp(r'^id:\s*(\d+)', multiLine: true);
final _saleIdRe = RegExp(r'^sale_id:\s*(\d+)', multiLine: true);
final _saleRefRe = RegExp(r'ref:\s*reject/(sale|backfill)/', caseSensitive: false);

ApprovalRejectionNotice? parseApprovalRejectionNotice(String? text) {
  final raw = text ?? '';
  final sourceMatch = _sourceRe.firstMatch(raw);
  final idMatch = _idRe.firstMatch(raw);
  if (sourceMatch == null || idMatch == null) return null;
  final id = int.tryParse(idMatch.group(1) ?? '');
  if (id == null) return null;
  final saleMatch = _saleIdRe.firstMatch(raw);
  final saleId = saleMatch == null ? null : int.tryParse(saleMatch.group(1) ?? '');
  return ApprovalRejectionNotice(
    source: sourceMatch.group(1) ?? '',
    id: id,
    saleId: saleId,
  );
}

bool isReturnedSaleNotice(
  ApprovalRejectionNotice? parsed, {
  String text = '',
  String title = '',
}) {
  if (parsed?.saleId != null) return true;
  if (_saleRefRe.hasMatch(text)) return true;
  return _saleIdRe.hasMatch(text) &&
      title.toLowerCase().contains('approval rejected');
}

bool noticeRequiresSaleFix({String content = '', String title = ''}) {
  return isReturnedSaleNotice(
    parseApprovalRejectionNotice(content),
    text: content,
    title: title,
  );
}

int? returnedSaleId({String content = '', String title = ''}) {
  final parsed = parseApprovalRejectionNotice(content);
  if (parsed?.saleId != null) return parsed!.saleId;
  if (!noticeRequiresSaleFix(content: content, title: title)) return null;
  final match = _saleIdRe.firstMatch(content);
  return match == null ? null : int.tryParse(match.group(1) ?? '');
}

String? rejectedSaleFixPath({String content = '', String title = ''}) {
  final saleId = returnedSaleId(content: content, title: title);
  if (saleId != null) return '/pos?sale=$saleId';
  return null;
}
