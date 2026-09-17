import 'package:flutter/material.dart';

import '../dashboard/dashboard_page.dart';
import '../../features/vocabulary/presentation/pages/language_pages.dart';
import '../settings/settings_page.dart';
import '../home/home_dashboard_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  late int _selectedIndex;
  late final List<Widget?> _pages;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pages = List<Widget?>.filled(4, null);
    _pages[_selectedIndex] = _pageFor(_selectedIndex);
  }

  @override
  void didUpdateWidget(covariant MainNavigationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _selectedIndex = widget.initialIndex;
      _pages[_selectedIndex] ??= _pageFor(_selectedIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(
          4,
          (index) => _pages[index] ?? const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (index == _selectedIndex) return;
          setState(() {
            _selectedIndex = index;
            _pages[index] ??= _pageFor(index);
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Lists',
          ),
          NavigationDestination(
            icon: Icon(Icons.translate_outlined),
            selectedIcon: Icon(Icons.translate),
            label: 'Languages',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _pageFor(int index) => switch (index) {
    0 => const HomeDashboardPage(),
    1 => const DashboardPage(),
    2 => const LanguagesPage(),
    3 => const SettingsPage(),
    _ => const SizedBox.shrink(),
  };
}
