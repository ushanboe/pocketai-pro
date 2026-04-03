class ModelInfo {
  final String id;
  final String name;
  final int sizeBytes;
  final String description;
  final String parameterCount;
  final String quantization;
  final double minRamGB;
  final String capabilityTag;
  final bool isDownloaded;
  final double downloadProgress;
  final DateTime? downloadedAt;
  final bool isActive;
  final String downloadUrl;
  final String filename;
  final bool isVision;
  final String mmprojUrl;
  final String mmprojFilename;

  const ModelInfo({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.description,
    required this.parameterCount,
    required this.quantization,
    required this.minRamGB,
    required this.capabilityTag,
    this.isDownloaded = false,
    this.downloadProgress = 0.0,
    this.downloadedAt,
    this.isActive = false,
    this.downloadUrl = '',
    this.filename = '',
    this.isVision = false,
    this.mmprojUrl = '',
    this.mmprojFilename = '',
  });

  /// Returns a human-readable file size string.
  String get sizeString {
    const int oneMB = 1000000;
    const int oneGB = 1000000000;

    if (sizeBytes >= oneGB) {
      final gb = sizeBytes / oneGB;
      return '${gb.toStringAsFixed(1)} GB';
    } else {
      final mb = sizeBytes / oneMB;
      if (mb == mb.roundToDouble()) {
        return '${mb.round()} MB';
      } else {
        return '${mb.toStringAsFixed(1)} MB';
      }
    }
  }

  /// Returns a compatibility label based on available RAM vs minimum required RAM.
  String compatibilityForRam(double ramGB) {
    if (ramGB >= minRamGB * 1.5) return 'Compatible';
    if (ramGB >= minRamGB) return 'May be slow';
    return 'Not recommended';
  }

  ModelInfo copyWith({
    String? id,
    String? name,
    int? sizeBytes,
    String? description,
    String? parameterCount,
    String? quantization,
    double? minRamGB,
    String? capabilityTag,
    bool? isDownloaded,
    double? downloadProgress,
    DateTime? downloadedAt,
    bool? clearDownloadedAt,
    bool? isActive,
    String? downloadUrl,
    String? filename,
    bool? isVision,
    String? mmprojUrl,
    String? mmprojFilename,
  }) {
    return ModelInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      description: description ?? this.description,
      parameterCount: parameterCount ?? this.parameterCount,
      quantization: quantization ?? this.quantization,
      minRamGB: minRamGB ?? this.minRamGB,
      capabilityTag: capabilityTag ?? this.capabilityTag,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadedAt: (clearDownloadedAt == true) ? null : (downloadedAt ?? this.downloadedAt),
      isActive: isActive ?? this.isActive,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      filename: filename ?? this.filename,
      isVision: isVision ?? this.isVision,
      mmprojUrl: mmprojUrl ?? this.mmprojUrl,
      mmprojFilename: mmprojFilename ?? this.mmprojFilename,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sizeBytes': sizeBytes,
      'description': description,
      'parameterCount': parameterCount,
      'quantization': quantization,
      'minRamGB': minRamGB,
      'capabilityTag': capabilityTag,
      'isDownloaded': isDownloaded,
      'downloadProgress': downloadProgress,
      'downloadedAt': downloadedAt?.toUtc().toIso8601String(),
      'isActive': isActive,
      'downloadUrl': downloadUrl,
      'filename': filename,
      'isVision': isVision,
      'mmprojUrl': mmprojUrl,
      'mmprojFilename': mmprojFilename,
    };
  }

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      sizeBytes: json['sizeBytes'] as int,
      description: json['description'] as String,
      parameterCount: json['parameterCount'] as String,
      quantization: json['quantization'] as String,
      minRamGB: (json['minRamGB'] as num).toDouble(),
      capabilityTag: json['capabilityTag'] as String,
      isDownloaded: json['isDownloaded'] as bool? ?? false,
      downloadProgress: (json['downloadProgress'] as num?)?.toDouble() ?? 0.0,
      downloadedAt: json['downloadedAt'] != null
          ? DateTime.parse(json['downloadedAt'] as String).toLocal()
          : null,
      isActive: json['isActive'] as bool? ?? false,
      downloadUrl: json['downloadUrl'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      isVision: json['isVision'] as bool? ?? false,
      mmprojUrl: json['mmprojUrl'] as String? ?? '',
      mmprojFilename: json['mmprojFilename'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ModelInfo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ModelInfo(id: $id, name: $name, sizeBytes: $sizeBytes, '
        'parameterCount: $parameterCount, quantization: $quantization, '
        'minRamGB: $minRamGB, capabilityTag: $capabilityTag, '
        'isDownloaded: $isDownloaded, downloadProgress: $downloadProgress, '
        'isActive: $isActive, downloadUrl: $downloadUrl, filename: $filename)';
  }
}
