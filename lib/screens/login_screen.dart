import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../main.dart';
import '../models/account.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _deviceId;
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;

    final version = packageInfo.version;
    final buildNumber = packageInfo.buildNumber;

    String mode = '';
    if (kDebugMode) {
      mode = ' (Debug)';
    } else if (kProfileMode) {
      mode = ' (Profile)';
    }

    setState(() {
      _appVersion = 'v$version+$buildNumber$mode';
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceId() async {
    final deviceId = await apiService.getDeviceId();
    if (!mounted) return;
    setState(() => _deviceId = deviceId);
  }

  Future<bool> _showDeviceDisclaimer(String email) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _DeviceDisclaimerDialog(),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      try {
        String manufacturer = 'Unknown';
        String model = 'Unknown';
        String brand = 'Unknown';

        if (Platform.isAndroid) {
          final android = await DeviceInfoPlugin().androidInfo;
          manufacturer = android.manufacturer;
          model = android.model;
          brand = android.brand;
        } else if (Platform.isIOS) {
          final ios = await DeviceInfoPlugin().iosInfo;
          manufacturer = 'Apple';
          model = ios.model;
          brand = 'iPhone/iPad';
        }

        await apiService.registerDevice(
          RegisterDeviceCommand(
            email: email,
            deviceId: _deviceId ?? 'unknown',
            manufacturer: manufacturer,
            model: model,
            brand: brand,
          ),
        );
        return true;
      } catch (e) {
        if (mounted) {
          final message = await apiService.getErrorMessage(
            e is DioException ? e : DioException(requestOptions: RequestOptions(), error: e),
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Registration failed: $message')),
            );
          }
        }
        return false;
      }
    }
    return false;
  }

  Future<void> _handleLogin() async {
    final email = _usernameController.text.trim();
    final password = _passwordController.text;
    final isUiTestMode = ApiService.usesOfflineUiFakeData;

    if ((email.isEmpty || password.isEmpty) && !isUiTestMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter email and password'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      var response = await apiService.login(
        AppLoginCommand(
          email: email,
          password: password,
          deviceId: _deviceId ?? 'unknown',
        ),
      );

      if (!response.isDeviceRegistered) {
        if (!mounted) return;
        final registered = await _showDeviceDisclaimer(email);
        if (!registered) {
          setState(() => _isLoading = false);
          return;
        }

        // Re-login automatically to get the token now that device is registered
        response = await apiService.login(
          AppLoginCommand(
            email: email,
            password: password,
            deviceId: _deviceId ?? 'unknown',
          ),
        );

        // If still not registered after successful registration call, something is wrong on backend
        if (!response.isDeviceRegistered && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Device registration pending admin approval. Please contact dispatch.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      if (response.token != null) {
        apiService.setToken(response.token!);
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful but no access token received.'),
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    } on DioException catch (e) {
      String message;
      if (e.response?.statusCode == 401) {
        message = 'Invalid email or password';
      } else {
        message = await apiService.getErrorMessage(e);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = await apiService.getErrorMessage(
          e is DioException ? e : DioException(requestOptions: RequestOptions(), error: e),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $message'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [cs.primaryContainer.withValues(alpha: 0.3), cs.surface],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!kReleaseMode)
                        ValueListenableBuilder<bool>(
                          valueListenable: ApiService.offlineUiTestModeNotifier,
                          builder: (context, enabled, _) {
                            if (!enabled) return const SizedBox.shrink();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.amber.shade700),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.science_outlined,
                                    size: 18,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Demo mode is active. System is running on sample data.',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                      // Brand Identity Section
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: cs.primary.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.local_shipping_rounded,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Fleet Driver Demo',
                            style: tt.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                              color: cs.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'FLEET MANAGEMENT SYSTEM',
                            style: tt.labelLarge?.copyWith(
                              letterSpacing: 2,
                              color: cs.primary,
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // Modern Login Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color: cs.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Sign In',
                                style: tt.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Authorized personnel only',
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 24),

                              TextFormField(
                                controller: _usernameController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Work Email',
                                  prefixIcon: const Icon(
                                    Icons.alternate_email_rounded,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleLogin(),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(
                                    Icons.lock_person_outlined,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () =>
                                            _obscurePassword =
                                                !_obscurePassword,
                                      );
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),

                              FilledButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'LOG IN TO SYSTEM',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Access Recovery'),
                                  content: Text(
                                    'Please contact your system administrator or dispatcher to reset your credentials.\n\nRequired Device ID:\n${_deviceId ?? "Detecting..."}',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('DISMISS'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: const Text('Forgot Credentials?'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Technical Footer
                      Column(
                        children: [
                          if (!kReleaseMode)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/admin-tools'),
                              icon: const Icon(
                                Icons.terminal_rounded,
                                size: 16,
                              ),
                              label: const Text('SYSTEM DIAGNOSTICS'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: cs.onSurfaceVariant,
                                side: BorderSide(color: cs.outlineVariant),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          if (!kReleaseMode)
                            const SizedBox(height: 40)
                          else
                            const SizedBox(height: 16),
                          Text(
                            '© 2026 Fleet Driver Demo | ${_appVersion ?? "v..."}',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'SSAID: ${_deviceId ?? "Detecting..."}',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceDisclaimerDialog extends StatefulWidget {
  const _DeviceDisclaimerDialog();

  @override
  State<_DeviceDisclaimerDialog> createState() =>
      _DeviceDisclaimerDialogState();
}

class _DeviceDisclaimerDialogState extends State<_DeviceDisclaimerDialog> {
  int _countdown = 5;
  bool _canContinue = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_countdown > 0) {
            _countdown--;
          } else {
            _canContinue = true;
            _timer?.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.report_problem_rounded, color: cs.error, size: 28),
          const SizedBox(width: 12),
          const Text('Device Security'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'IMPORTANT NOTICE:',
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.error,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'For security and operational integrity, your account will be strictly linked to this device upon registration.',
          ),
          const SizedBox(height: 12),
          const Text(
            '• You cannot sign in using other devices.\n'
            '• To reset your device link, you must contact your system administrator.',
          ),
          const SizedBox(height: 16),
          Text(
            'Do you wish to register this device for your account?',
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: _canContinue ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            backgroundColor:
                _canContinue ? cs.primary : cs.surfaceContainerHighest,
          ),
          child: Text(
            _canContinue ? 'I ACCEPT & REGISTER' : 'WAIT (${_countdown}s)',
          ),
        ),
      ],
    );
  }
}
