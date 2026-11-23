import 'package:material_ui/material_ui.dart';

import '../widgets/common.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'recommendations_screen.dart';
import 'search_screen.dart';
import 'tasks_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _titles = ['Buscar libros', 'Favoritos', 'Para ti', 'Tareas (CRUD)', 'Perfil'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: Column(
        children: [
          const StatusBanner(),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [
                SearchScreen(),
                FavoritesScreen(),
                RecommendationsScreen(),
                TasksScreen(),
                ProfileScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(key: Key('nav_search'), icon: Icon(Icons.search), label: 'Buscar'),
          NavigationDestination(
            key: Key('nav_favorites'),
            icon: Icon(Icons.favorite_border),
            label: 'Favoritos',
          ),
          NavigationDestination(key: Key('nav_recs'), icon: Icon(Icons.auto_awesome), label: 'Para ti'),
          NavigationDestination(key: Key('nav_tasks'), icon: Icon(Icons.checklist), label: 'Tareas'),
          NavigationDestination(key: Key('nav_profile'), icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
