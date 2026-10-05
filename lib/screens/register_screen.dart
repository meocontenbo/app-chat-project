import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../widgets/auth_form_layout.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static final _usernameRe = RegExp(r'^[a-zA-Z0-9_]{3,32}$');
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _displayName = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_username, _email, _displayName, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().register(
            username: _username.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            displayName: _displayName.text.trim(),
          );
      // Auth state switches the root to HomeScreen; drop this pushed route.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
      labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    return Form(
      key: _formKey,
      child: AuthFormLayout(
        title: 'Tạo tài khoản',
        children: [
          TextFormField(
            controller: _username,
            decoration: _deco('Username', Icons.alternate_email),
            textInputAction: TextInputAction.next,
            validator: (v) => _usernameRe.hasMatch(v?.trim() ?? '')
                ? null
                : '3-32 ký tự: chữ, số, dấu gạch dưới',
          ),
          gap,
          TextFormField(
            controller: _email,
            decoration: _deco('Email', Icons.email_outlined),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                _emailRe.hasMatch(v?.trim() ?? '') ? null : 'Email không hợp lệ',
          ),
          gap,
          TextFormField(
            controller: _displayName,
            decoration: _deco('Tên hiển thị (tuỳ chọn)', Icons.badge_outlined),
            textInputAction: TextInputAction.next,
            maxLength: 64,
          ),
          gap,
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: _deco('Mật khẩu', Icons.lock_outline),
            textInputAction: TextInputAction.next,
            validator: (v) => (v?.length ?? 0) < 6 ? 'Tối thiểu 6 ký tự' : null,
          ),
          gap,
          TextFormField(
            controller: _confirm,
            obscureText: true,
            decoration: _deco('Nhập lại mật khẩu', Icons.lock_outline),
            onFieldSubmitted: (_) => _submit(),
            validator: (v) => v != _password.text ? 'Mật khẩu không khớp' : null,
          ),
          const SizedBox(height: 20),
          ErrorText(_error),
          FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: _loading
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Đăng ký'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _loading ? null : () => Navigator.of(context).pop(),
            child: const Text('Đã có tài khoản? Đăng nhập'),
          ),
        ],
      ),
    );
  }
}
