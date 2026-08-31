import 'package:geolocator/geolocator.dart';

/// Captura de GPS compartilhada entre a entrega individual e a entrega em
/// massa. Centralizada aqui pra não duplicar a lógica de timeout/fallback
/// em cada tela.
class LocalizacaoService {
  LocalizacaoService._();

  /// Tenta obter a localização atual com a maior precisão disponível,
  /// dando tempo suficiente pro GPS travar num sinal (importante perto de
  /// prédios ou num "cold start" do GPS, que pode levar bem mais que 3
  /// segundos). Se mesmo assim não conseguir a tempo, cai para a última
  /// localização conhecida do aparelho — pode ter alguns minutos, mas
  /// ainda é bem melhor que não registrar nenhuma localização.
  static Future<Position?> obterLocalizacao() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }
}
