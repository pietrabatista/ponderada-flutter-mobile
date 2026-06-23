class ApodModel {
  final String title;
  final String url;
  final String mediaType;
  final String explanation;
  final String date;

  const ApodModel({
    required this.title,
    required this.url,
    required this.mediaType,
    required this.explanation,
    required this.date,
  });

  factory ApodModel.fromJson(Map<String, dynamic> json) => ApodModel(
        title: json['title'] as String,
        url: json['url'] as String,
        mediaType: json['media_type'] as String,
        explanation: json['explanation'] as String,
        date: json['date'] as String,
      );
}
