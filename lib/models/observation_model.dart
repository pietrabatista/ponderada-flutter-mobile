class ObservationModel {
  final String id;
  final String userId;
  final String titulo;
  final String? fotoUrl;
  final double? lat;
  final double? long;
  final DateTime data;
  final String? descricao;

  const ObservationModel({
    required this.id,
    required this.userId,
    required this.titulo,
    this.fotoUrl,
    this.lat,
    this.long,
    required this.data,
    this.descricao,
  });

  factory ObservationModel.fromJson(Map<String, dynamic> json) => ObservationModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        titulo: json['titulo'] as String,
        fotoUrl: json['foto_url'] as String?,
        lat: (json['lat'] as num?)?.toDouble(),
        long: (json['long'] as num?)?.toDouble(),
        data: DateTime.parse(json['data'] as String),
        descricao: json['descricao'] as String?,
      );
}
