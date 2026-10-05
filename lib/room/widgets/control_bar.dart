import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';

import '../room_controller.dart';

class ControlBar extends StatelessWidget {
  final VoidCallback onToggleScreenShare;
  final VoidCallback onToggleChat;
  final VoidCallback onLeave;

  const ControlBar({
    super.key,
    required this.onToggleScreenShare,
    required this.onToggleChat,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<RoomController>();
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: scheme.surfaceContainer,
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ToggleWithDevices(
              on: ctrl.micOn,
              onIcon: Icons.mic,
              offIcon: Icons.mic_off,
              tooltipOn: 'Tắt micro',
              tooltipOff: 'Bật micro',
              onToggle: ctrl.toggleMic,
              devicesTooltip: 'Chọn micro',
              devices: ctrl.audioInputs,
              selected: ctrl.selectedAudioInput,
              onSelect: ctrl.selectAudioInput,
            ),
            _ToggleWithDevices(
              on: ctrl.cameraOn,
              onIcon: Icons.videocam,
              offIcon: Icons.videocam_off,
              tooltipOn: 'Tắt camera',
              tooltipOff: 'Bật camera',
              onToggle: ctrl.toggleCamera,
              devicesTooltip: 'Chọn camera',
              devices: ctrl.videoInputs,
              selected: ctrl.selectedVideoInput,
              onSelect: ctrl.selectVideoInput,
            ),
            if (ctrl.canScreenShare)
              IconButton.filledTonal(
                iconSize: 24,
                tooltip: ctrl.screenShareOn ? 'Dừng chia sẻ màn hình' : 'Chia sẻ màn hình',
                isSelected: ctrl.screenShareOn,
                onPressed: onToggleScreenShare,
                icon: const Icon(Icons.screen_share_outlined),
                selectedIcon: const Icon(Icons.stop_screen_share),
              ),
            _DeviceMenu(
              icon: Icons.volume_up,
              tooltip: 'Chọn loa / tai nghe',
              devices: ctrl.audioOutputs,
              selected: ctrl.selectedAudioOutput,
              onSelect: ctrl.selectAudioOutput,
            ),
            Badge(
              isLabelVisible: ctrl.unread > 0,
              label: Text('${ctrl.unread}'),
              child: IconButton.filledTonal(
                tooltip: 'Tin nhắn',
                isSelected: ctrl.chatVisible,
                onPressed: onToggleChat,
                icon: const Icon(Icons.chat_bubble_outline),
                selectedIcon: const Icon(Icons.chat_bubble),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: onLeave,
              icon: const Icon(Icons.call_end),
              label: const Text('Rời phòng'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round on/off button with a small device picker attached.
class _ToggleWithDevices extends StatelessWidget {
  final bool on;
  final IconData onIcon;
  final IconData offIcon;
  final String tooltipOn;
  final String tooltipOff;
  final VoidCallback onToggle;
  final String devicesTooltip;
  final List<MediaDevice> devices;
  final MediaDevice? selected;
  final ValueChanged<MediaDevice> onSelect;

  const _ToggleWithDevices({
    required this.on,
    required this.onIcon,
    required this.offIcon,
    required this.tooltipOn,
    required this.tooltipOff,
    required this.onToggle,
    required this.devicesTooltip,
    required this.devices,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filled(
            iconSize: 24,
            tooltip: on ? tooltipOn : tooltipOff,
            style: IconButton.styleFrom(
              backgroundColor: on ? scheme.primary : scheme.error,
              foregroundColor: on ? scheme.onPrimary : scheme.onError,
            ),
            onPressed: onToggle,
            icon: Icon(on ? onIcon : offIcon),
          ),
          _DeviceMenu(
            icon: Icons.keyboard_arrow_up,
            tooltip: devicesTooltip,
            devices: devices,
            selected: selected,
            onSelect: onSelect,
          ),
        ],
      ),
    );
  }
}

class _DeviceMenu extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final List<MediaDevice> devices;
  final MediaDevice? selected;
  final ValueChanged<MediaDevice> onSelect;

  const _DeviceMenu({
    required this.icon,
    required this.tooltip,
    required this.devices,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<MediaDevice>(
      tooltip: tooltip,
      enabled: devices.isNotEmpty,
      onSelected: onSelect,
      itemBuilder: (_) => [
        for (final d in devices)
          CheckedPopupMenuItem(
            value: d,
            checked: d.deviceId == selected?.deviceId,
            child: Text(d.label.isNotEmpty ? d.label : 'Thiết bị ${d.deviceId}'),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon),
      ),
    );
  }
}
