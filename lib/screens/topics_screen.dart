import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/hymn_repository.dart';
import '../models/hymn.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import 'hymn_screen.dart';

/// Índice por temática: secciones (Adoración, Jesucristo…) con sus
/// temáticas, el rango de números y cuántos himnos tiene cada una.
class TopicsScreen extends StatelessWidget {
  const TopicsScreen({super.key, this.book = 'clasico'});
  final String book;

  @override
  Widget build(BuildContext context) {
    final repo = HymnRepository.instance;
    final hymnal = repo.hymnal(book);
    final groups = repo.topicIndex(book);
    final secondary = Brand.textoSecundario(context);
    return Scaffold(
      appBar: AppBar(title: Text('Temáticas · ${hymnal?.nombreCorto ?? ''}')),
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
      body: groups.every((g) => g.topics.isEmpty)
          ? const Center(child: Text('Este himnario aún no tiene himnos.'))
          : CustomScrollView(
              slivers: [
                for (final g in groups) ...[
                  if (g.name != null)
                    SliverToBoxAdapter(
                      child: _SectionHeader(
                        title: g.name!,
                        count: g.hymnCount,
                        color: secondary,
                      ),
                    ),
                  SliverList.separated(
                    itemCount: g.topics.length,
                    separatorBuilder: (_, _) => const Divider(
                      indent: Space.gutter,
                      endIndent: Space.gutter,
                    ),
                    itemBuilder: (context, i) => _TopicTile(topic: g.topics[i]),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: Space.l)),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });
  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Más aire arriba que abajo: el título se agrupa con su sección.
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.l,
        Space.gutter,
        Space.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: FontSizes.caption,
                fontWeight: FontWeight.w700,
                letterSpacing: .6,
                color: color,
              ),
            ),
          ),
          Text(
            '$count himnos',
            style: TextStyle(fontSize: FontSizes.caption, color: color),
          ),
        ],
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.topic});
  final Topic topic;

  @override
  Widget build(BuildContext context) {
    final n = topic.hymns.length;
    return ListTile(
      minTileHeight: Space.touch + Space.xs,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      title: Text(
        topic.name,
        style: const TextStyle(
          fontSize: FontSizes.body,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        n == 1 ? 'Himno ${topic.range}' : 'Himnos ${topic.range} · $n himnos',
        style: TextStyle(
          fontSize: FontSizes.caption,
          color: Brand.textoSecundario(context),
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => TopicScreen(topic: topic)),
      ),
    );
  }
}

/// Himnos de una temática, con "Reproducir todos" (útil para el culto).
class TopicScreen extends StatelessWidget {
  const TopicScreen({super.key, required this.topic});
  final Topic topic;

  @override
  Widget build(BuildContext context) {
    final secondary = Brand.textoSecundario(context);
    final hymns = topic.hymns;
    return Scaffold(
      appBar: AppBar(title: Text(topic.name)),
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
      body: ListView.separated(
        padding: const EdgeInsets.only(bottom: Space.l),
        itemCount: hymns.length + 1,
        separatorBuilder: (_, i) => i == 0
            ? const SizedBox.shrink()
            : const Divider(indent: Space.gutter, endIndent: Space.gutter),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.m,
                Space.gutter,
                Space.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hymns.length == 1
                          ? '1 himno · #${topic.range}'
                          : '${hymns.length} himnos · #${topic.range}',
                      style: TextStyle(
                        fontSize: FontSizes.small,
                        color: secondary,
                      ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, Space.touch - Space.xxs),
                    ),
                    onPressed: () => context.read<PlayerService>().playQueue([
                      for (final h in hymns) h.id,
                    ], name: topic.name),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Reproducir todos'),
                  ),
                ],
              ),
            );
          }
          final h = hymns[i - 1];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Space.gutter,
            ),
            leading: SizedBox(
              width: 40,
              child: Text(
                '${h.number}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: FontSizes.body,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            title: Text(
              h.title,
              style: const TextStyle(
                fontSize: FontSizes.body,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              h.firstLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: FontSizes.caption, color: secondary),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => HymnScreen(hymn: h)),
            ),
          );
        },
      ),
    );
  }
}
