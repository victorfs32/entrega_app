class Pacote {
  String codigo;
  String? transportadora;
  DateTime dataLeitura;

  // NOVOS CAMPOS
  String? nomeRecebedor;
  String? fotoPath;
  double? lat;
  double? lng;
  bool entregue;

  Pacote({
    required this.codigo,
    this.transportadora,
    required this.dataLeitura,

    this.nomeRecebedor,
    this.fotoPath,
    this.lat,
    this.lng,
    this.entregue = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'codigo': codigo,
      'transportadora': transportadora,
      'dataLeitura': dataLeitura.toIso8601String(),
      'nomeRecebedor': nomeRecebedor,
      'fotoPath': fotoPath,
      'lat': lat,
      'lng': lng,
      'entregue': entregue,
    };
  }

  factory Pacote.fromMap(Map<String, dynamic> map) {
    return Pacote(
      codigo: map['codigo'] ?? '',
      transportadora: map['transportadora'],
      dataLeitura: DateTime.tryParse(map['dataLeitura'] ?? '') ?? DateTime.now(),
      nomeRecebedor: map['nomeRecebedor'],
      fotoPath: map['fotoPath'],
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      entregue: map['entregue'] ?? false,
    );
  }
}
