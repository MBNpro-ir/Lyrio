import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../core/models.dart';
import 'home_page.dart';

/// The first-run gate. Android cannot grant special access silently, so this
/// screen stays in front of the app until the required switches are enabled.
class WelcomePage extends StatelessWidget {
  final LyrioController controller;
  const WelcomePage({super.key, required this.controller});

  static const _required = ['listener', 'overlay', 'notifications'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final permissions = controller.snapshot.permissions;
    final ready = controller.snapshot.requiredPermissionsGranted;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 34, 26, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  Icons.graphic_eq_rounded,
                  size: 34,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Welcome to Lyrio',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Bring every lyric with you. Before we open the app, Android needs to know which access Lyrio may use.',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 15,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 24),
              if (controller.loading && !controller.stateLoaded)
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: LinearProgressIndicator(),
                ),
              if (controller.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    controller.error!,
                    style: TextStyle(
                      color: colors.error,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final key in _required)
                      _PermissionTile(
                        title: permissionInfo[key]!.$2,
                        description: permissionInfo[key]!.$3,
                        icon: permissionInfo[key]!.$4,
                        granted: permissions[key] == true,
                        onTap: () => _openPermission(context, key),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: _PermissionTile(
                  title: 'Battery optimization',
                  description:
                      'Optional, but recommended for phones that stop background services aggressively.',
                  icon: permissionInfo['battery']!.$4,
                  granted: permissions['battery'] == true,
                  optional: true,
                  onTap: () => _openPermission(context, 'battery'),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                ready
                    ? 'Everything Lyrio needs is ready. You can change these permissions later in Android Settings.'
                    : 'Enable all three required permissions to continue. Android will show its own confirmation screen for each one.',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: ready ? controller.refresh : null,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Continue to Lyrio'),
                ),
              ),
              if (!ready)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () => _openPermission(
                        context,
                        _required.firstWhere(
                          (key) => permissions[key] != true,
                          orElse: () => _required.first,
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('Open the next permission'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPermission(BuildContext context, String key) async {
    await showPermissionSheet(context, controller, key);
    await controller.refresh();
  }
}

class _PermissionTile extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool granted;
  final bool optional;
  final VoidCallback onTap;

  const _PermissionTile({
    required this.title,
    required this.description,
    required this.icon,
    required this.granted,
    required this.onTap,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      leading: CircleAvatar(
        backgroundColor: granted
            ? colors.secondaryContainer
            : colors.primaryContainer,
        foregroundColor: granted
            ? colors.onSecondaryContainer
            : colors.onPrimaryContainer,
        child: Icon(granted ? Icons.check_rounded : icon, size: 21),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          if (optional)
            const Text(
              'OPTIONAL',
              style: TextStyle(fontSize: 9, letterSpacing: 1),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          description,
          style: const TextStyle(fontSize: 11, height: 1.35),
        ),
      ),
      trailing: Icon(
        granted ? Icons.check_circle_rounded : Icons.arrow_outward_rounded,
        color: granted ? colors.secondary : colors.primary,
      ),
      onTap: granted ? null : onTap,
    );
  }
}
