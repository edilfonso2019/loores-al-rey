# Loores al Rey 👑🎶

Himnario de la **Iglesia Adventista del Séptimo Día Movimiento de Reforma**
para Android, hecho con **Flutter**. Sin anuncios.

## Funciones (v0.1)

- **Himnario Clásico** completo (791 himnos, 54 temáticas) 100 % offline.
  El **Himnario CG** aparece como "Próximamente" hasta que `cg.json` tenga `activo: true`.
- Búsqueda por número, título o letra (sin tildes), filtro por temática y por himnario.
- Pista **instrumental** y **cantada** por streaming o descargada (controles en la
  notificación, "tocar continuamente"). Si el servidor aún no tiene una pista se
  muestra "aún no disponible".
- **Partituras** PDF con zoom (streaming o descarga). Administrador de descargas.
- **Favoritos**, historial y **listas de culto** (ordenar, reproducir seguido,
  compartir por WhatsApp).
- **Respaldo** de favoritos, listas y ajustes: archivo JSON o Google Drive
  (requiere configuración: [`docs/GOOGLE_DRIVE.md`](docs/GOOGLE_DRIVE.md)).
- Tamaño de letra, color de fondo, tema claro/oscuro, modo básico y **modo proyección**.

Roadmap y competencia: [`docs/BENCHMARKING.md`](docs/BENCHMARKING.md).

## Desarrollo

```bash
flutter pub get
flutter analyze && flutter test
flutter run            # con un celular conectado (depuración USB)
```

APK firmado (requiere `android/key.properties`, que **no** se versiona):

```bash
flutter build apk --release                    # universal
flutter build apk --release --split-per-abi    # uno por arquitectura (más livianos)
```

`android/key.properties`:

```
storePassword=...
keyPassword=...
keyAlias=loores
storeFile=C:/Users/LENOVO/LooresAlRey-Keystore/loores-al-rey-release.jks
```

## Datos

- `assets/data/clasico.json` y `assets/data/cg.json`:
  `{id, nombre, activo, categorias, himnos:[{n, t, cat, estrofas, coro?, cita?, versiculo?, autor?, tono?}]}`.
  `autor` y `tono` son opcionales; mientras no existan la app muestra "no disponible".
- Servidor de pistas y partituras por himnario: `lib/config.dart` (o un bloque
  `"servidor"` dentro del JSON del himnario).
- `tools/import_hymns.py` es del formato anterior (nuevo/antiguo) y está pendiente de adaptar.

## Estructura

```
lib/
  config.dart  Servidor por himnario, Google Drive
  models/      Hymnal, Hymn, Playlist
  data/        HymnRepository (carga + búsqueda sin tildes)
  services/    AppState, MediaService (URLs y descargas), PlayerService, BackupService
  screens/     Inicio, Buscar, Himno, Favoritos/Listas, Ajustes, Descargas, Respaldo, Proyección
  widgets/     Mini reproductor, visor de partitura, utilidades
  theme/       Colores del brandbook IASDMR + Noto Sans
assets/        Datos, fuentes, portada e ícono
tools/         generar_icono.ps1, importador antiguo
docs/          Brandbook, capturas del Figma, Google Drive, benchmarking
```

## Licencia del contenido

El código es MIT. Las letras, pistas y partituras pertenecen a sus autores y
titulares; verifica los derechos antes de publicar en tiendas.
