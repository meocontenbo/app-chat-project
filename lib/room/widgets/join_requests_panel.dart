import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../room_controller.dart';

/// Owner-only stack of "X wants to join" cards with admit / deny buttons.
class JoinRequestsPanel extends StatelessWidget {
  const JoinRequestsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<RoomController>();
    final requests = ctrl.joinRequests;
    if (requests.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360, maxHeight: 320),
      child: Card(
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.person_add_alt_1, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${requests.length} người muốn tham gia', style: theme.textTheme.titleSmall),
                  ),
                  if (requests.length > 1)
                    TextButton(
                      onPressed: () {
                        for (final r in requests) {
                          ctrl.decideJoinRequest(r, approve: true);
                        }
                      },
                      child: const Text('Cho tất cả vào'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final r in requests)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(child: Text(r.name.characters.first.toUpperCase())),
                        title: Text(r.name, overflow: TextOverflow.ellipsis),
                        subtitle: Text('@${r.username}', overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Từ chối',
                              icon: Icon(Icons.close, color: theme.colorScheme.error),
                              onPressed: () => ctrl.decideJoinRequest(r, approve: false),
                            ),
                            IconButton.filled(
                              tooltip: 'Cho vào',
                              icon: const Icon(Icons.check),
                              onPressed: () => ctrl.decideJoinRequest(r, approve: true),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
