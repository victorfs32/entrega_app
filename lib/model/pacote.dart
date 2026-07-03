class Pacote {
  String codigo;
  String? userId;
  String? transportadora;
  DateTime dataLeitura;

  String? nomeRecebedor;
  String? fotoPath;
  String? fotoUrl;
  String? fotoViewUrl;
  String? fotoDownloadUrl;

  double? lat;
  double? lng;
  bool entregue;

  Pacote({
    required this.codigo,
    this.userId,
    this.transportadora,
    required this.dataLeitura,
    this.nomeRecebedor,
    this.fotoPath,
    this.fotoUrl,
    this.fotoViewUrl,
    this.fotoDownloadUrl,
    this.lat,
    this.lng,
    this.entregue = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'codigo': codigo,
      'userId': userId,
      'transportadora': transportadora,
      'dataLeitura': dataLeitura.toIso8601String(),
      'nomeRecebedor': nomeRecebedor,
      'fotoPath': fotoPath,
      'fotoUrl': fotoUrl,
      'fotoViewUrl': fotoViewUrl,
      'fotoDownloadUrl': fotoDownloadUrl,
      'lat': lat,
      'lng': lng,
      'entregue': entregue,
    };
  }

  factory Pacote.fromMap(Map<String, dynamic> map) {
    return Pacote(
      codigo: map['codigo'] ?? '',
      userId: map['userId'],
      transportadora: map['transportadora'],
      dataLeitura: DateTime.tryParse(map['dataLeitura'] ?? '') ?? DateTime.now(),
      nomeRecebedor: map['nomeRecebedor'],
      fotoPath: map['fotoPath'],
      fotoUrl: map['fotoUrl'],
      fotoViewUrl: map['fotoViewUrl'],
      fotoDownloadUrl: map['fotoDownloadUrl'],
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      entregue: map['entregue'] ?? false,
    );
  }
}