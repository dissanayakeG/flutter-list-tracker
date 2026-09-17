import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:list_tracker/data/repository/repository_providers.dart';
import 'package:list_tracker/features/vocabulary/data/vocabulary_providers.dart';

class HomeDashboardPage extends ConsumerWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(listSummariesProvider);
    final languages = ref.watch(languagesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Continue where you left off',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Lists',
            icon: Icons.list_alt_outlined,
            onTap: () => context.go('/'),
            children: lists.when(
              data: (items) => items
                  .take(4)
                  .map(
                    (item) => _ResumeTile(
                      title: item.list.name,
                      subtitle: item.category.name,
                      onTap: () => context.push('/lists/${item.list.id}'),
                    ),
                  )
                  .toList(),
              loading: () => const [LinearProgressIndicator()],
              error: (_, _) => const [Text('Unable to load lists.')],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Languages',
            icon: Icons.translate_outlined,
            onTap: () => context.go('/languages'),
            children: languages.when(
              data: (items) => items
                  .take(4)
                  .map(
                    (item) => _ResumeTile(
                      title: item.name,
                      subtitle: 'Open dictionary',
                      onTap: () => context.push('/languages/${item.id}'),
                    ),
                  )
                  .toList(),
              loading: () => const [LinearProgressIndicator()],
              error: (_, _) => const [Text('Unable to load languages.')],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    required this.onTap,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            child: Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                const Icon(Icons.arrow_forward),
              ],
            ),
          ),
          const Divider(),
          if (children.isEmpty)
            const Text('Nothing here yet.')
          else
            ...children,
        ],
      ),
    ),
  );
}

class _ResumeTile extends StatelessWidget {
  const _ResumeTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
