enum CaptureSourceKind { avFoundation, directShow, deckLink }
enum DeviceType { video, audio }

class CaptureDevice {
  const CaptureDevice({
    required this.id,
    required this.name,
    this.audioId,
    this.audioName,
    required this.type,
  });

  final String id;
  final String name;
  final String? audioId;
  final String? audioName;
  final DeviceType type;

  String get displayLabel => name;

  factory CaptureDevice.videoDevice({required String id, required String name}){
    return CaptureDevice(
      id: id, 
      name: name, 
      audioId: null, 
      audioName: null,
      type: DeviceType.video,
      );
  }

  factory CaptureDevice.audioDevice({required String id, required String name}){
    return CaptureDevice(
      id: id, 
      name: name, 
      audioId: id, 
      audioName: name,
      type: DeviceType.audio,
      );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'audioId': audioId,
        'audioName': audioName,
        'type': type.index,
      };

  factory CaptureDevice.fromJson(Map<String, dynamic> json) {
    final type = DeviceType.values[json['type'] as int]; 

    if (type == DeviceType.video) {
        return CaptureDevice.videoDevice(id: json['id'] as String, name: json['name'] as String);
    } else {
        return CaptureDevice.audioDevice(id: json['id'] as String, name: json['name'] as String);
    }
  }
}
