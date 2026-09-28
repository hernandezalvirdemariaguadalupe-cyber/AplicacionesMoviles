import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/file_manager_provider.dart';

class BreadcrumbBar extends StatelessWidget {
  const BreadcrumbBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FileManagerProvider>();
    final rootPath = provider.rootPath;
    final currentPath = provider.currentPath;

    if (rootPath.isEmpty || currentPath.isEmpty) {
      return const SizedBox.shrink();
    }

    final relative = currentPath.length > rootPath.length
        ? currentPath.substring(rootPath.length)
        : '';
    final segments = relative.split('/').where((s) => s.isNotEmpty).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            InkWell(
              onTap: currentPath != rootPath
                  ? () => provider.navigateTo(rootPath)
                  : null,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.home,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Inicio',
                      style: TextStyle(
                        fontWeight: currentPath == rootPath
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (int i = 0; i < segments.length; i++) ...[
              const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              InkWell(
                onTap: i < segments.length - 1
                    ? () {
                        final targetPath =
                            '$rootPath/${segments.sublist(0, i + 1).join('/')}';
                        provider.navigateTo(targetPath);
                      }
                    : null,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    segments[i],
                    style: TextStyle(
                      fontWeight: i == segments.length - 1
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: i == segments.length - 1
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
