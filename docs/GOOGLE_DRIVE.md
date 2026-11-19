# Respaldo en Google Drive — configuración

La app guarda el respaldo en la carpeta oculta **appData** de Drive del
usuario (solo esta app la ve). Para que funcione hay que registrar la app en
Google Cloud una sola vez.

## Datos de la app

| Dato | Valor |
|---|---|
| Paquete | `pe.looresalrey.app` |
| SHA-1 (keystore de release) | `09:FF:3B:2B:D6:E1:69:04:6A:59:62:1E:C4:D7:64:11:CC:9B:9F:0B` |
| Alcance (scope) | `https://www.googleapis.com/auth/drive.appdata` |

Para obtener el SHA-1 de nuevo:

```bash
keytool -list -v -keystore C:\Users\LENOVO\LooresAlRey-Keystore\loores-al-rey-release.jks -alias loores
```

## Pasos en console.cloud.google.com

1. Crear un proyecto "Loores al Rey".
2. **APIs y servicios → Biblioteca** → activar **Google Drive API**.
3. **Pantalla de consentimiento OAuth** → tipo *Externo*, nombre "Loores al Rey",
   correo de soporte, y agregar el alcance `drive.appdata`. Mientras esté en
   modo *Prueba*, agregar como usuarios de prueba a quienes la usarán.
4. **Credenciales → Crear ID de cliente OAuth → Android**: paquete y SHA-1 de
   la tabla de arriba.
5. **Credenciales → Crear ID de cliente OAuth → Aplicación web** (nombre
   "Loores al Rey servidor"). Copiar su *ID de cliente* (termina en
   `.apps.googleusercontent.com`; no es secreto).
6. Pegar ese ID en `lib/config.dart` → `kGoogleServerClientId` y recompilar.

Para Play Store: la consola de Play vuelve a firmar la app con su propia
clave; habrá que agregar también el SHA-1 de *App signing* como otro cliente
Android.
