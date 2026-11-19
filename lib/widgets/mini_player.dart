import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/hymn_screen.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';

/// Barra compacta con el himno que suena; visible en toda la app cuando
/// "Modo minimizado" está activo.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final h = player.current;
    if (h == null) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF1F2A44) : Brand.fondoTarjeta,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => HymnScreen(hymn: h, initialKind: player.kind),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
          child: Row(
            children: [
              const Icon(Icons.music_note_rounded, color: Brand.azulClaro),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${h.number} - ${h.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      player.queueName != null
                          ? '${player.kind.label} · ${player.queueName} (${player.queueIndex + 1}/${player.queue.length})'
                          : player.kind.label,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (player.loading)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  tooltip: player.playing ? 'Pausar' : 'Reproducir',
                  icon: Icon(
                    player.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  onPressed: player.toggle,
                ),
              IconButton(
                tooltip: 'Siguiente',
                icon: const Icon(Icons.skip_next_rounded),
                onPressed: player.next,
              ),
              IconButton(
                tooltip: 'Cerrar',
                icon: const Icon(Icons.close_rounded),
                onPressed: player.stop,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
