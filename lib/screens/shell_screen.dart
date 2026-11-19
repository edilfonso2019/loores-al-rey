import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// Pestaña activa de la barra inferior y filtros que otras pantallas
/// quieren pasarle al buscador.
class NavController extends ChangeNotifier {
  int index = 0;

  /// Himnario a preseleccionar en el buscador ("clasico", "cg" o null=todos).
  String? searchBook;
  int searchRequest = 0;

  void go(int i) {
    index = i;
    notifyListeners();
  }

  /// Abre el buscador con un himnario elegido.
  void openSearch({String? book}) {
    searchBook = book;
    searchRequest++;
    go(1);
  }
}

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key});

  static const _tabs = [
    HomeScreen(),
    SearchScreen(),
    FavoritesScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavController>();
    // El mini reproductor aparece siempre que haya algo cargado, para no
    // dejar música sonando sin controles (Inicio lo muestra por su cuenta).
    final showMini = context.select<PlayerService, bool>((p) => p.current != null);
    return PopScope(
      canPop: nav.index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) nav.go(0);
      },
      child: Scaffold(
        // En Inicio, las esquinas redondeadas de la barra dejan ver el azul.
        backgroundColor: nav.index == 0 ? Brand.azul : null,
        body: IndexedStack(index: nav.index, children: _tabs),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showMini && nav.index != 0) const MiniPlayer(),
            _BottomBar(index: nav.index, onTap: nav.go),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_rounded, 'Inicio'),
    (Icons.search_rounded, 'Buscar'),
    (Icons.favorite_border_rounded, 'Favoritos'),
    (Icons.settings_rounded, 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Colors.white : Colors.black;
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1A2236) : Brand.fondo,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: InkResponse(
                    onTap: () => onTap(i),
                    child: Semantics(
                      label: _items[i].$2,
                      selected: i == index,
                      button: true,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _items[i].$1,
                            size: 28,
                            color: i == index ? (dark ? Brand.azulClaro : Brand.azul) : fg,
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: i == index ? 14 : 0,
                            height: 4,
                            decoration: BoxDecoration(
                              color: dark ? Brand.azulClaro : Brand.azul,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
