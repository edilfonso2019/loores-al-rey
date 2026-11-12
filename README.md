# Loores al Rey 👑🎶

Himnario Adventista del Séptimo Día para Android e iOS, hecho con **Flutter**.
Himnario **nuevo (2010)** y **antiguo (1962)**, 100 % offline, sin anuncios.

## Funciones (v0.1)

- Búsqueda por número, título o fragmento de letra (ignora tildes)
- Favoritos e historial
- Tamaño de letra ajustable (pellizco o ajustes), tema claro/oscuro
- **Modo proyección**: pantalla completa, estrofa por estrofa, ideal para TV/proyector
- Compartir letra por WhatsApp

Roadmap, competencia y posicionamiento: [`docs/BENCHMARKING.md`](docs/BENCHMARKING.md).

## Empezar

```bash
flutter pub get
flutter run
```

Pruebas y análisis:

```bash
flutter analyze && flutter test
```

## Cargar los himnos

Los archivos `assets/data/nuevo.json` y `assets/data/antiguo.json` traen solo ejemplos.
Prepara un TXT por himnario (formato en `tools/import_hymns.py`) y ejecuta:

```bash
python3 tools/import_hymns.py nuevo   himnos_nuevo.txt   assets/data/nuevo.json
python3 tools/import_hymns.py antiguo himnos_antiguo.txt assets/data/antiguo.json
```

## Estructura

```
lib/
  models/      Hymn, Verse
  data/        HymnRepository (carga + búsqueda)
  services/    AppState (favoritos, historial, tema, fuente)
  screens/     Home, Hymn, Projection, Settings
  widgets/     HymnTile
  theme/       Paleta azul + dorado
assets/data/   JSON de himnarios
tools/         Importador TXT → JSON
docs/          Benchmarking y roadmap
```

## Licencia del contenido

El código es MIT. Las letras de los himnos pertenecen a sus autores y a la
Asociación Publicadora; verifica los derechos antes de publicar en tiendas.
