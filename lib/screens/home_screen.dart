import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/room_info.dart';
import '../services/room_api.dart';
import '../state/auth_provider.dart';
import '../state/deep_link.dart';
import 'room_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _roomName = TextEditingController();
  final _joinInput = TextEditingController();
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final code = pendingJoinCode.value;
    if (code != null) {
      pendingJoinCode.value = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openRoom(code));
    }
  }

  @override
  void dispose() {
    _roomName.dispose();
    _joinInput.dispose();
    super.dispose();
  }

  Future<void> _openRoom(String code) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => RoomScreen(code: code)));

  Future<void> _create() async {
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final room = await context.read<RoomApi>().create(_roomName.text.trim());
      if (mounted) await _openRoom(room.code);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _join() {
    final code = RoomInfo.parseCode(_joinInput.text);
    if (code == null) {
      setState(() => _error = 'Mã phòng hoặc link không hợp lệ (dạng abc-defg-hij)');
      return;
    }
    setState(() => _error = null);
    _openRoom(code);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Chat'),
        actions: [
          Center(child: Text(user.displayName)),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: auth.logout,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Phòng họp', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text('Tạo phòng mới hoặc tham gia bằng mã / link mời.',
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _roomName,
                          decoration: const InputDecoration(
                              labelText: 'Tên phòng (tuỳ chọn)',
                              border: OutlineInputBorder()),
                          onSubmitted: (_) => _create(),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _creating ? null : _create,
                          icon: const Icon(Icons.add_call),
                          label: const Text('Tạo phòng mới'),
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _joinInput,
                          decoration: const InputDecoration(
                              labelText: 'Mã phòng hoặc link',
                              hintText: 'abc-defg-hij',
                              border: OutlineInputBorder()),
                          onSubmitted: (_) => _join(),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _join,
                          icon: const Icon(Icons.login),
                          label: const Text('Tham gia'),
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48)),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
