# Benchmarking — Apps de Himnario Adventista (nov. 2026)

Investigación de mercado previa al desarrollo de **Loores al Rey**.
Fuentes: fichas de App Store / Google Play, AppGoblin, Marlvel.ai, AppBrain.

## 1. Competidores principales (español)

| App | Dev | Plataformas | Instalaciones | Rating | Monetización | Diferenciador |
|---|---|---|---|---|---|---|
| **Himnario Adventista** (mx.daro.himnario) | Daro Technologies | Android + iOS | ~3.5 M | 4.6★ (17.8 K) | Ads 45 % + IAP 55 % | Líder absoluto desde 2014. Himnario nuevo (2010) y antiguo (1962), pista cantada y acompañamiento de cada himno, partituras descargables, modo oscuro, controles en pantalla bloqueada |
| **Himnario Adventista** (com.himnarioadv.sld) | SilverAppli / Bleext | Android + iOS | ~31 K | 4.9★ (300) | IAP 100 % (sin ads) | Mejor valorada. Letra + música, librería con favoritos/historial/descargas, sincronización de favoritos entre dispositivos |
| **Himnario Adventista con Música** | VYS | Android | ~245 K | 4.4★ | Ads 100 % | Volumen histórico, en declive (sin actualizar desde 2024) |
| **Antiguo Himnario Adventista** | Advenz | Android | ~122 K | 4.6★ | IAP 77 % + Ads | Nicho: solo himnario 1962. Crecimiento fuerte |
| **Himnario Adventista Plus** | — | iOS | — | — | Gratis | Genérica |
| **Himnario Adventista App** (Hagler Galindo) | indie | iOS | ~72 K usuarios | — | Suscripción anual | Himnario + Biblia + versículo diario, 100 % offline |
| **Cantico: Himnario Adventista** | indie | iOS | — | — | IAP | Letra y música, solo iPhone |
| **Himnario de la fe Adventista** | A. Terrazos | iOS | — | 5.0★ (5) | Gratis | Movimiento de Reforma (otro himnario) |
| **Himnario Adventista Juvenil** | A. Fernández | Android | ~35 K | 3.5★ | Ads | Abandonada (2016) — ejemplo de lo que NO hacer |

## 2. Referentes en inglés (ideas de producto)

| App | Precio | Qué hace bien |
|---|---|---|
| **Advent Hymnal** (SoftMagic) | $9.99 | UI rápida y bonita, pistas de piano HQ, partituras y acordes, exportar PDF, **Apple TV** |
| **Hymnal Adventist / The Hymnal Project** | $14.99 | 9 himnarios en varios idiomas, +9 000 himnos offline, home personalizable |
| **SDA Hymnal MLC** | Freemium | **Herramienta de presentación en vivo** para directores de culto, anotaciones |
| **SDA Hymnal** (Agyl Code, Ogotera) | Gratis | Ligera, MIDI + letra, búsqueda por número/título/contenido |

## 3. Funciones estándar del mercado (obligatorias para competir)

- Himnario **nuevo (2010, 613 himnos)** y **antiguo (1962, 525 himnos)**
- 100 % **offline**
- Búsqueda por **número, título y fragmento de letra**
- Teclado numérico de acceso rápido
- **Favoritos**, historial
- **Audio**: pista cantada + instrumental (descarga por himno)
- Partituras (imagen/PDF)
- Modo oscuro, tamaño de letra ajustable
- Controles de reproducción en la barra de notificaciones

## 4. Quejas recurrentes de usuarios (oportunidades)

1. **Exceso de anuncios** en las apps gratuitas (Daro, VYS).
2. Apps pesadas (hasta 2.2 GB) o con descargas lentas de audio.
3. No se puede ajustar la fuente / letra pequeña al proyectar.
4. Apps abandonadas sin actualización (Juvenil, VYS).
5. Falta de **modo proyección / cast a TV** para el culto (solo Advent Hymnal y MLC lo atacan, en inglés y de pago).

## 5. Posicionamiento propuesto para Loores al Rey

| Eje | Decisión |
|---|---|
| Precio | Gratis, **sin anuncios**; donación opcional / Pro barato (audio HQ + partituras) |
| Núcleo | Letra offline ultraligera (< 20 MB) con ambos himnarios |
| Diferenciador 1 | **Modo proyección**: pantalla completa, letra gigante, estrofa por estrofa, soporte Chromecast / Android TV (conecta con tu app de Versículos TV) |
| Diferenciador 2 | **Listas de culto**: arma el orden del programa (himnos + lecturas) y compártelo por WhatsApp |
| Diferenciador 3 | Acordes y transposición para músicos |
| Diferenciador 4 | Sincronización de favoritos/listas sin cuenta obligatoria (archivo exportable) |
| Stack | Flutter (Android + iOS + TV con una sola base) |

## 6. Roadmap sugerido

- **v0.1 (MVP)**: letras de ambos himnarios, búsqueda, favoritos, tema claro/oscuro, tamaño de letra.
- **v0.2**: modo proyección + listas de culto.
- **v0.3**: audio instrumental por streaming/descarga, controles en notificación.
- **v0.4**: partituras y acordes, transposición.
- **v1.0**: publicación Play Store + App Store, Android TV / Chromecast.
