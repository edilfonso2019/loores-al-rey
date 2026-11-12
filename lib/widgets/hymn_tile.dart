import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/hymn.dart';
import '../services/app_state.dart';

class HymnTile extends StatelessWidget {
  final Hymn hymn;
  final VoidCallback onTap;

  const HymnTile({super.key, required this.hymn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isFav = context.select<AppState, bool>((s) => s.isFavorite(hymn.id));
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Text(
          '${hymn.number}',
          style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(hymn.title),
      subtitle: hymn.category == null ? null : Text(hymn.category!),
      trailing: IconButton(
        icon: Icon(isFav ? Icons.favorite : Icons.favorite_outline,
            color: isFav ? scheme.secondary : null),
        onPressed: () => context.read<AppState>().toggleFavorite(hymn.id),
      ),
    );
  }
}
