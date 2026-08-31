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

  // Segunda foto opcional do mesmo registro (ex: outro ângulo do pacote
  // ou do local de entrega).
  String? fotoPath2;
  String? fotoUrl2;
  String? fotoViewUrl2;
  String? fotoDownloadUrl2;

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
    this.fotoPath2,
    this.fotoUrl2,
    this.fotoViewUrl2,
    this.fotoDownloadUrl2,
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
      'fotoPath2': fotoPath2,
      'fotoUrl2': fotoUrl2,
      'fotoViewUrl2': fotoViewUrl2,
      'fotoDownloadUrl2': fotoDownloadUrl2,
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
      fotoPath2: map['fotoPath2'],
      fotoUrl2: map['fotoUrl2'],
      fotoViewUrl2: map['fotoViewUrl2'],
      fotoDownloadUrl2: map['fotoDownloadUrl2'],
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      entregue: map['entregue'] ?? false,
    );
  }
}