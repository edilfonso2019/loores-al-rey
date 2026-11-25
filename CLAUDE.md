# Loores al Rey — guía para Claude Code

App **Android** (primero) de himnario para la **Iglesia Adventista del Séptimo Día Movimiento de Reforma (IASDMR)**, hecha en **Flutter**. Todo en español. Responder al usuario en español, concreto y breve.

## Estado actual (nov. 2026)
- App v0.1 completa y compilando: Inicio, Buscador, Himno (audio, descarga, partitura), Favoritos/Listas/Recientes, Ajustes, Descargas, Respaldo, Proyección. 14 tests.
- Entorno Windows: Flutter en `C:\src\flutter`, JDK 17 (Temurin), Android SDK en `C:\Android\Sdk`.
  `kotlin.incremental=false` en `android/gradle.properties` porque el proyecto (D:) y la caché de pub (C:) están en discos distintos.
- No hay Visual Studio: evitar paquetes con *native assets* (por eso `pdfx` y no `pdfrx`), o `flutter test` falla.
- Keystore en `C:\Users\LENOVO\LooresAlRey-Keystore\` (fuera del repo); `android/key.properties` la referencia y está en .gitignore.
- `package:flutter/material.dart` da avisos de deprecación (Flutter 3.50 sugiere `material_ui`); no migrar mientras pdfx/share_plus sigan usando material.dart.
- Pendiente: probar en celular real, configurar Google Drive (`docs/GOOGLE_DRIVE.md`), autor/tono/compás de los himnos 724–791, pistas cantadas en el servidor.

## Himnarios (datos en `assets/data/`)
- `clasico.json` — **Himnario Clásico "Loores al Rey"**, 791 himnos, 54 categorías (temáticas). `activo: true`.
  Formato: `{id, nombre, activo, categorias:[..], secciones:[{nombre,desde,hasta}], himnos:[{n, t, cat, autor?, tono?, compas?, modula?, creditos?, estrofas:[..], coro?, cita?, versiculo?}]}`.
  `autor`/`tono`/`compas`/`creditos` vienen de las partituras: fuente `tools/fuentes/himnos_autor_tono.json` (del usuario), se fusionan con `node tools/fusionar_autor_tono.js` (repetible; nunca editar esos campos a mano en clasico.json). Faltan los himnos 724–791. `autor: "Desconocido"` = la partitura no lo indica.
  `cat` es el índice en `categorias`. El coro se canta después de cada estrofa.
- `sincronizacion.json` — marcas partitura ↔ audio ("Marcar renglones"): `{ "clasico-131-instrumental": [{t: ms, p: página, x, y}] }` (x/y en 0..1). Las hacen los usuarios en la app y las comparten (menú ⋮ → Compartir mis marcas); se pegan aquí para incluirlas. Las propias del teléfono tienen prioridad y van en el respaldo.
- `cg.json` — **Himnario CG**: vacío y `activo: false`. Aún no hay letras, pistas ni partituras. La app debe soportarlo (selector, búsqueda "Todos/Clásico/CG") pero ocultarlo o mostrarlo como "Próximamente" mientras `activo` sea false. Cuando llegue el material solo se llena el JSON y se pone `activo: true`.
- Origen de los datos: app Candelero (repo privado `edilfonso2019/candelero-app`, `apk/assets/himnario.js`).

## Servidor de pistas y partituras (solo Clásico por ahora)
- Instrumental: `http://192.241.144.242/pista_instrumental/himno_instrumental_{n}.mp3`
- Cantado: `http://192.241.144.242/pista_cantado/himno_cantado_{n}.mp3`
- Partitura: `http://192.241.144.242/partitura/himno_partitura_{n}.pdf`
- Es HTTP (no HTTPS): habilitar cleartext solo para esa IP con `network_security_config.xml`. Para Play Store más adelante convendrá HTTPS.
- Las URLs deben ser configurables (por himnario) para cuando exista el CG.
- Nunca pedir ni guardar la contraseña del servidor.

## Diseño
- Figma: https://www.figma.com/design/bi9y4QOOB5SBahWATflwt5/App-Himnario-Adventista--Loores-al-Rey (página "🎨 Visual"). Si el conector de Figma está disponible, úsalo; las pantallas son:
  - **Inicio/Onboarding** (2415:988): foto de violín, "Himnario *Loores al Rey*", "Asociación Metropolitana UP", botones *Himnario Clásico* y *Himnario CG*; barra inferior: Inicio, Buscar, Favoritos, Ajustes.
  - **Buscador** (2487:345, 2415:1078): campo "Número o texto", desplegable "Temática (todos)", radios *Todos / Clásico / Nuevo(CG)*; resultados "n (C) - Título" + primera línea de la letra, resaltando el texto buscado.
  - **Himno** (2404:255 Instrumental, 2415:821 Cantado, 2415:878 Partitura): barra superior "Himno # n - Clásico" con atrás y buscar; letra; botón flotante de favorito; reproductor fijo (play/pausa, barra de progreso, tiempos, autor, tonalidad "Fa M 4/4", botón descargar); pestañas inferiores *Instrumental | Cantado | Partituras*.
  - **Favoritos** (2467:501): lista "#n - Título" + himnario, menú ⋮.
  - **Configuración** (2472:771): Color de fondo, Tamaño del texto, Modo básico, Administrador de descargas, Sincronizar y respaldar playlists, Donación (oculto en v1), Tocar continuamente, Modo minimizado, Calificar, Acerca de.
- Marca (brandbook en `docs/brand/brandbook_IASDMR.pdf`):
  - Azul principal `#0A245E` (usar siempre), complementarios `#0F3999`, `#3E80F2`.
  - Secundarios: crema `#EFD19F`, dorado `#F1BE48`, coral `#FF8D6D`, gris `#7E7E82`, fondo `#F2F1EF`.
  - Tipografía: Bw Modelica (comercial) → usar **Noto Sans** (alternativa oficial del brandbook). Logo "Loores al Rey" en script como en el Figma.
  - Tono: unido, cálido, respetuoso, claro, formal.

## Alcance v1 (Android)
1. Himnario Clásico completo offline: búsqueda por número/título/letra sin tildes, filtro por temática, favoritos, historial, tamaño de letra, tema claro/oscuro, color de fondo.
2. Audio: **streaming + descarga** para uso sin conexión (just_audio + audio_service, controles en notificación, "tocar continuamente"). Administrador de descargas.
3. Partituras PDF (streaming + descarga), visor con zoom.
4. **Playlists** (listas de culto): crear, ordenar, reproducir seguido, compartir por WhatsApp.
5. **Sincronizar y respaldar**: favoritos + playlists + ajustes. Exportar/importar archivo y respaldo en Google Drive (carpeta appData) con Google Sign-In.
6. Modo proyección (pantalla completa, estrofa por estrofa) — ya existe un borrador.
- Fuera de v1: donación, iOS.

## Distribución
- Primero APK firmado (compartido por WhatsApp), luego Play Store (AAB, targetSdk actual, política de privacidad).
- Paquete: `pe.looresalrey.app`. Guardar la keystore FUERA del repo y avisar al usuario que la respalde.

## Convenciones
- UI y comentarios en español. Sin anuncios.
- Antes de cada commit: `flutter analyze && flutter test`.
- No versionar audios, PDFs descargados ni la keystore.
- Benchmarking y roadmap: `docs/BENCHMARKING.md`.
