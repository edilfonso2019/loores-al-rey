import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Permiso "Mostrar notificaciones" (Android 13+). Sin él, Android oculta
/// los controles de reproducción en la notificación y la pantalla de bloqueo.
class NotificationPermission {
  static bool _askedThisSession = false;

  static bool get _applies => !kIsWeb && Platform.isAndroid;

  /// Pide el permiso una vez por sesión, sin insistir si el usuario lo
  /// bloqueó ("no volver a preguntar"). Nunca lanza excepciones.
  static Future<void> ensure() async {
    if (!_applies || _askedThisSession) return;
    _askedThisSession = true;
    try {
      final status = await Permission.notification.status;
      if (status.isDenied) await Permission.notification.request();
    } catch (e) {
      debugPrint('No se pudo pedir el permiso de notificaciones: $e');
    }
  }

  /// true si está concedido (o si la plataforma no lo necesita).
  static Future<bool> granted() async {
    if (!_applies) return true;
    try {
      return (await Permission.notification.status).isGranted;
    } catch (_) {
      return true;
    }
  }

  /// Abre los ajustes de la app para activarlo a mano.
  static Future<void> openSettings() => openAppSettings();
}
