import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import '../../core/services/google_auth_service.dart';
import '../../core/themes/app_theme.dart';
import '../../core/errors/app_exception.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      final user = await GoogleAuthService().signInWithGoogle();
      if (user == null || !mounted) {
        setState(() => _isLoading = false);
        return;
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (e.code == 'cancelled') return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unexpected error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) return _buildAndroid(context);
    return _buildWindows(context);
  }

  // ── Windows Layout (unchanged) ──────────────────────────────────────────────

  Widget _buildWindows(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(48.0),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color.fromARGB(
                255,
                255,
                255,
                255,
              ).withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _appLogo(),
              const SizedBox(height: 0),
              Text(
                'Scopus',
                style: theme.textTheme.displayMedium?.copyWith(
                  color: const Color.fromARGB(255, 248, 248, 248),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Academic Workspace',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 48),
              if (_isLoading)
                const CircularProgressIndicator(color: AppTheme.primary)
              else
                _googleSignInButton(Theme.of(context)),
              const SizedBox(height: 24),
              _disclaimer(Theme.of(context)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Android Layout ──────────────────────────────────────────────────────────

  Widget _buildAndroid(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: screenHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // Top spacer — pushes card toward center vertically
                  const Spacer(),

                  // Login card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 40,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color.fromARGB(
                            255,
                            255,
                            255,
                            255,
                          ).withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _appLogo(size: 72),
                          const SizedBox(height: 0),
                          Text(
                            'Scopus',
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: const Color.fromARGB(255, 255, 255, 255),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Academic Workspace',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: AppTheme.textSecondary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 40),
                          if (_isLoading)
                            const SizedBox(
                              height: 52,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primary,
                                ),
                              ),
                            )
                          else
                            _googleSignInButton(Theme.of(context)),
                          const SizedBox(height: 20),
                          _disclaimer(Theme.of(context)),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Shared Widgets ──────────────────────────────────────────────────────────

  Widget _appLogo({double size = 80}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }

  /// The white Google sign-in button with the real 4-color Google G logo.
  /// Matches the style used in most production apps (white bg, dark text).
  Widget _googleSignInButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _signIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF3C4043),
          elevation: 1,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFDADCE0), width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _GoogleLogo(),
            const SizedBox(width: 12),
            Text(
              'Sign in with Google',
              style: theme.textTheme.titleMedium?.copyWith(
                color: const Color(0xFF3C4043),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _disclaimer(ThemeData theme) {
    return Text(
      'Requires Google Drive access to manage your files securely.',
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
    );
  }
}

// ── Google Logo Asset ───────────────────────────────────────────────────────

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/google_logo.png',
      width: 22,
      height: 22,
      fit: BoxFit.contain,
    );
  }
}
