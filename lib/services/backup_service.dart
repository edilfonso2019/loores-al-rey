import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../config.dart';
import 'app_state.dart';

/// Respaldo de favoritos, playlists y ajustes: archivo JSON y Google Drive
/// (carpeta oculta appData, solo visible para esta app).
class BackupService {
  BackupService(this._state);
  final AppState _state;

  static const _scopes = [drive.DriveApi.driveAppdataScope];
  bool _signInReady = false;

  Uint8List _encode() => Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent(' ').convert(_state.toBackup())),
      );

  Future<void> _restoreBytes(List<int> bytes) async {
    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Archivo de respaldo inválido.');
    }
    await _state.restoreBackup(data);
  }

  // ---------------- Archivo ----------------

  /// Guarda el respaldo donde elija el usuario. false si canceló.
  Future<bool> exportToFile() async {
    final fecha = DateTime.now().toIso8601String().substring(0, 10);
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Guardar respaldo',
      fileName: 'loores_al_rey_$fecha.json',
      bytes: _encode(),
      mimeType: 'application/json',
    );
    return uri != null;
  }

  /// Restaura desde un archivo elegido. false si canceló.
  Future<bool> importFromFile() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Elegir respaldo',
      type: FileType.any,
    );
    if (files.isEmpty) return false;
    final f = files.first;
    final bytes = await f.xFile.readAsBytes();
    await _restoreBytes(bytes);
    return true;
  }

  // ---------------- Google Drive ----------------

  Future<drive.DriveApi> _driveApi() async {
    final signIn = GoogleSignIn.instance;
    if (!_signInReady) {
      await signIn.initialize();
      _signInReady = true;
    }
    final client = signIn.authorizationClient;
    final authz = await client.authorizationForScopes(_scopes) ??
        await client.authorizeScopes(_scopes);
    return drive.DriveApi(authz.authClient(scopes: _scopes));
  }

  Future<drive.File?> _findBackup(drive.DriveApi api) async {
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$kNombreRespaldo' and trashed = false",
      $fields: 'files(id, name, modifiedTime)',
      orderBy: 'modifiedTime desc',
    );
    final files = list.files ?? const [];
    return files.isEmpty ? null : files.first;
  }

  /// Sube (o reemplaza) el respaldo en Drive.
  Future<void> backupToDrive() async {
    final api = await _driveApi();
    final bytes = _encode();
    final media = drive.Media(Stream.value(bytes), bytes.length,
        contentType: 'application/json');
    final existing = await _findBackup(api);
    if (existing?.id != null) {
      await api.files.update(drive.File(), existing!.id!, uploadMedia: media);
    } else {
      await api.files.create(
        drive.File()
          ..name = kNombreRespaldo
          ..parents = ['appDataFolder'],
        uploadMedia: media,
      );
    }
    _state.markDriveBackup(DateTime.now());
  }

  /// Restaura desde Drive. Devuelve la fecha del respaldo o null si no hay.
  Future<DateTime?> restoreFromDrive() async {
    final api = await _driveApi();
    final existing = await _findBackup(api);
    if (existing?.id == null) return null;
    final media = await api.files.get(
      existing!.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    await _restoreBytes(bytes);
    return existing.modifiedTime ?? DateTime.now();
  }

  /// Mensaje legible para errores de Google.
  static String describeError(Object e) {
    if (e is GoogleSignInException) {
      return switch (e.code) {
        GoogleSignInExceptionCode.canceled => 'Inicio de sesión cancelado.',
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Google Drive aún no está configurado para esta app (ver docs/GOOGLE_DRIVE.md).',
        _ => 'No se pudo iniciar sesión con Google (${e.code.name}).',
      };
    }
    if (e is SocketException) return 'Sin conexión a internet.';
    if (e is FormatException) return e.message;
    return 'Error: $e';
  }
}
