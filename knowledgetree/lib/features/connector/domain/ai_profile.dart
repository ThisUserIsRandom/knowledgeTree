class AiProfile {
  final String id;
  final String name;
  final String provider; // 'OpenRouter' | 'Ollama' | 'Custom'
  final String baseUrl; // server the app sends requests to (e.g. http://10.0.2.2:8000)
  final String apiUrl; // upstream base override (e.g. https://openrouter.ai/api/v1)
  final String apiKey;
  final String modelName;

  const AiProfile({
    required this.id,
    required this.name,
    required this.provider,
    this.baseUrl = '',
    this.apiUrl = '',
    this.apiKey = '',
    this.modelName = '',
  });

  AiProfile copyWith({
    String? name,
    String? provider,
    String? baseUrl,
    String? apiUrl,
    String? apiKey,
    String? modelName,
  }) {
    return AiProfile(
      id: id,
      name: name ?? this.name,
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      apiUrl: apiUrl ?? this.apiUrl,
      apiKey: apiKey ?? this.apiKey,
      modelName: modelName ?? this.modelName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'provider': provider,
        'baseUrl': baseUrl,
        'apiUrl': apiUrl,
        'apiKey': apiKey,
        'modelName': modelName,
      };

  factory AiProfile.fromJson(Map<String, dynamic> j) => AiProfile(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        provider: j['provider'] as String? ?? 'OpenRouter',
        baseUrl: j['baseUrl'] as String? ?? '',
        apiUrl: j['apiUrl'] as String? ?? '',
        apiKey: j['apiKey'] as String? ?? '',
        modelName: j['modelName'] as String? ?? '',
      );

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
