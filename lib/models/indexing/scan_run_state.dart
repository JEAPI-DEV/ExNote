enum ScanRunStatus { idle, running, paused, waiting, completed, stopped }

class ScanRunState {
  final ScanRunStatus status;
  final String? reason;
  final int processed;
  final int total;
  final List<String> pendingIds;
  final Map<String, String> failures;
  final bool resumeAutomatically;
  final bool force;
  final String? checkpointNoteId;
  const ScanRunState({
    required this.status,
    this.reason,
    required this.processed,
    required this.total,
    required this.pendingIds,
    required this.failures,
    required this.resumeAutomatically,
    required this.force,
    this.checkpointNoteId,
  });

  Map<String, dynamic> toJson() => {
    'version': 1,
    'status': status.name,
    'reason': reason,
    'processed': processed,
    'total': total,
    'pendingIds': pendingIds,
    'failures': failures,
    'resumeAutomatically': resumeAutomatically,
    'force': force,
    'checkpointNoteId': checkpointNoteId,
  };
  factory ScanRunState.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported scan progress version');
    }
    return ScanRunState(
      status: ScanRunStatus.values.byName(json['status'] as String),
      reason: json['reason'] as String?,
      processed: (json['processed'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      pendingIds: (json['pendingIds'] as List).cast<String>(),
      failures: (json['failures'] as Map).cast<String, String>(),
      resumeAutomatically: json['resumeAutomatically'] as bool,
      force: json['force'] as bool,
      checkpointNoteId: json['checkpointNoteId'] as String?,
    );
  }
}
