enum CaptureSourceKind { avFoundation, directShow, deckLink }

class CaptureDevice {
  const CaptureDevice({
    required this.id,
    required this.name,
    this.audioId,
    this.audioName,
  });

  final String id;
  final String name;
  final String? audioId;
  final String? audioName;

  String get displayLabel {
    if (audioName == null || audioName!.isEmpty) return name;
    return '$name + ${audioName!}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'audioId': audioId,
        'audioName': audioName,
      };

  factory CaptureDevice.fromJson(Map<String, dynamic> json) => CaptureDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        audioId: json['audioId'] as String?,
        audioName: json['audioName'] as String?,
      );
}
