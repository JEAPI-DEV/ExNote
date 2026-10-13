class VoiceNote {
  final String id;
  final String? audioPath;
  final String transcript;
  final String transcription;
  final double? transcriptionCost;
  String get searchableText =>
      [transcript, transcription].where((text) => text.isNotEmpty).join('\n');
  final DateTime createdAt;
  const VoiceNote({
    required this.id,
    this.audioPath,
    this.transcript = '',
    this.transcription = '',
    this.transcriptionCost,
    required this.createdAt,
  });
  VoiceNote withTranscription(String text, double? cost) => VoiceNote(
    id: id,
    audioPath: audioPath,
    transcript: transcript,
    createdAt: createdAt,
    transcription: text,
    transcriptionCost: cost,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'audioPath': audioPath,
    'transcript': transcript,
    'transcription': transcription,
    'transcriptionCost': transcriptionCost,
    'createdAt': createdAt.toIso8601String(),
  };
  factory VoiceNote.fromJson(Map<String, dynamic> json) => VoiceNote(
    id: json['id'] as String,
    audioPath: json['audioPath'] as String?,
    transcript: json['transcript'] as String? ?? '',
    transcription: json['transcription'] as String? ?? '',
    transcriptionCost: (json['transcriptionCost'] as num?)?.toDouble(),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
