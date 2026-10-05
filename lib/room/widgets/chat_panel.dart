import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../room_controller.dart';

class ChatPanel extends StatefulWidget {
  final VoidCallback onClose;
  const ChatPanel({super.key, required this.onClose});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    _focus.requestFocus();
    await context.read<RoomController>().sendChat(text);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<RoomController>();
    final theme = Theme.of(context);
    // Newest first so a reversed list stays pinned to the bottom.
    final messages = ctrl.messages.reversed.toList();

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
            child: Row(
              children: [
                Text('Tin nhắn', style: theme.textTheme.titleMedium),
                const Spacer(),
                IconButton(tooltip: 'Đóng', icon: const Icon(Icons.close), onPressed: widget.onClose),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Tin nhắn chỉ hiển thị với người đang trong phòng và không được lưu lại.',
                style: theme.textTheme.bodySmall),
          ),
          const Divider(),
          Expanded(
            child: messages.isEmpty
                ? Center(child: Text('Chưa có tin nhắn', style: theme.textTheme.bodySmall))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (_, i) => _Bubble(messages[i]),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _focus,
                      maxLength: RoomController.maxChatLength,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        counterText: '',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Gửi',
                    icon: const Icon(Icons.send),
                    onPressed: ctrl.connected ? _send : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage msg;
  const _Bubble(this.msg);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = msg.time;
    final time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: msg.isLocal ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: msg.isLocal ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${msg.isLocal ? 'Bạn' : msg.senderName} · $time',
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 2),
            SelectableText(msg.text),
          ],
        ),
      ),
    );
  }
}
