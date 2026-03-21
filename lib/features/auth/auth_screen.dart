import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koememo/core/router.dart';
import 'package:koememo/services/auth_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    final authService = AuthService();
    final success = await authService.authenticate();

    if (mounted) {
      if (success) {
        ref.read(authStateProvider.notifier).authenticate();
      } else {
        setState(() {
          _isAuthenticating = false;
          _errorMessage = '認証に失敗しました';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text('こえメモ', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            if (_isAuthenticating)
              const CircularProgressIndicator()
            else ...[
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint),
                label: const Text('認証する'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
