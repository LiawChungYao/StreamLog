
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../services/google_auth.dart';
import '../screens/home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GoogleAuthService auth = GoogleAuthService.instance;

  bool isLoading = false;
  String status = 'Ready to sign in';

  void logDebug(String message) {
    developer.log(
      message,
      name: 'StreamLog.Auth',
    );
  }

  @override
  void initState() {
    super.initState();
    checkLogin();
  }

  Future<void> checkLogin() async {
    logDebug('Starting silent login');

    if (isLoading) return;

    setState(() {
      isLoading = true;
      status = 'Checking existing Google session...';
    });

    try {
      final user = await auth.silentLogin();

      logDebug(
        'Silent login completed. User returned: ${user != null}',
      );

      if (!mounted) return;

      if (user != null) {
        logDebug('Silent login successful. Navigating to HomeScreen.');
        navigateToHome();
      } else {
        setState(() {
          status = 'No existing Google session. Please sign in.';
        });
      }
    } catch (e, stackTrace) {
      logDebug('Silent login exception: $e');
      developer.log(
        'Silent login stack trace',
        name: 'StreamLog.Auth',
        error: e,
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      setState(() {
        status = 'Silent login failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> handleLogin() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
      status = 'Opening Google Sign-In...';
    });

    logDebug('Manual login started');

    try {
      final user = await auth.login();

      logDebug(
        'Manual login completed. User returned: ${user != null}',
      );

      if (!mounted) return;

      if (user == null) {
        logDebug('WARNING: auth.login() returned NULL');

        setState(() {
          status = 'Google Sign-In returned no user. Check logs.';
        });

        return;
      }

      logDebug('Authentication successful. Navigating to HomeScreen.');

      setState(() {
        status = 'Sign-in successful. Opening StreamLog...';
      });

      navigateToHome();
    } catch (e, stackTrace) {
      logDebug('Manual login exception: $e');

      developer.log(
        'Manual login stack trace',
        name: 'StreamLog.Auth',
        error: e,
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      setState(() {
        status = 'Sign-in failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void navigateToHome() {
    logDebug('pushReplacement to HomeScreen called');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: isLoading ? null : handleLogin,
                child: isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Sign in with Google'),
              ),
              const SizedBox(height: 20),
              Text(
                status,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
