/// Configuración del servidor de pistas y partituras, por himnario.
///
/// Las plantillas usan `{n}` como número de himno. Para el Himnario CG basta
/// con agregar su entrada aquí (o un bloque `"servidor"` en `cg.json`) cuando
/// exista el material.
class ServerConfig {
  final String instrumental;
  final String cantado;
  final String partitura;

  const ServerConfig({
    required this.instrumental,
    required this.cantado,
    required this.partitura,
  });

  factory ServerConfig.fromJson(Map<String, dynamic> json) => ServerConfig(
    instrumental: json['instrumental'] as String,
    cantado: json['cantado'] as String,
    partitura: json['partitura'] as String,
  );
}

const _base = 'http://192.241.144.242';

/// Servidores por id de himnario. Si un himnario no aparece aquí y su JSON
/// no trae `"servidor"`, la app simplemente no ofrece audio ni partituras.
const Map<String, ServerConfig> kServidores = {
  'clasico': ServerConfig(
    instrumental: '$_base/pista_instrumental/himno_instrumental_{n}.mp3',
    cantado: '$_base/pista_cantado/himno_cantado_{n}.mp3',
    partitura: '$_base/partitura/himno_partitura_{n}.pdf',
  ),
};

/// Nombre del archivo de respaldo (local y en Google Drive, carpeta appData).
const kNombreRespaldo = 'loores_al_rey_respaldo.json';

/// ID de cliente OAuth **Web** de Google Cloud (no es secreto). Necesario para
/// el respaldo en Google Drive; ver docs/GOOGLE_DRIVE.md. Vacío = sin configurar.
const kGoogleServerClientId = '';

// ---------------------------------------------------------------------------
// Familia de apps: Loores al Rey (público) y Acordes IASDMR (músicos) usan el
// mismo código de lib/. Acordes IASDMR cambia estos valores al arrancar.
// ---------------------------------------------------------------------------

/// Nombre de la otra app de la familia (con la que se comparten descargas).
String kOtraApp = 'Acordes IASDMR';
String otherAppName() => kOtraApp;

/// Prefijo de los assets de datos: '' en Loores al Rey y
/// 'packages/loores_al_rey/' cuando otra app usa este código como paquete.
String kAssetPrefix = '';
