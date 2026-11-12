# Loores al Rey — guía para Claude Code

App Flutter de Himnario Adventista (himnarios 2010 y 1962), offline-first, en español.

## Estructura
- `lib/models/` — `Hymn`, `Verse` (JSON ↔ Dart).
- `lib/data/hymn_repository.dart` — carga `assets/data/*.json`, búsqueda sin tildes.
- `lib/services/app_state.dart` — estado persistido (favoritos, historial, tema, tamaño de letra).
- `lib/screens/` — `home`, `hymn`, `projection` (modo TV), `settings`.
- `tools/import_hymns.py` — convierte TXT → JSON de himnos.
- `docs/BENCHMARKING.md` — análisis de competencia y roadmap.

## Convenciones
- Todo texto de UI en español. Comentarios en español.
- Sin anuncios. Sin dependencias de red para el núcleo (letras).
- Antes de abrir PR: `flutter analyze && flutter test`.
- Los audios no se versionan (ver `.gitignore`); se descargan bajo demanda.

## Siguiente trabajo (ver roadmap en docs/BENCHMARKING.md)
1. Importar los 613 + 525 himnos reales a `assets/data/`.
2. Listas de culto (orden del programa) y compartir por WhatsApp.
3. Audio instrumental con `just_audio` + controles en notificación.
4. Chromecast / Android TV para el modo proyección.
