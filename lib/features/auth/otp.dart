import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/services/api_service.dart';
import '../../core/providers/profile_notifier.dart';
import 'models/auth_session.dart';
import 'providers/auth_provider.dart';
import '../home/main_nav_wrapper.dart';
import '../onboarding/profile_setup.dart';

class Otp extends StatefulWidget {
  final String? phoneNumber;
  final int initialCooldown;
  const Otp({super.key, this.phoneNumber, this.initialCooldown = 60});

  @override
  State<Otp> createState() => _OtpState();
}

class _OtpState extends State<Otp> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool hasError = false;
  bool _isVerifying = false;
  int _secondsLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer(widget.initialCooldown);
  }

  void _startTimer([int? seconds]) {
    _timer?.cancel();
    setState(() => _secondsLeft = seconds ?? widget.initialCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_secondsLeft == 0) {
      final phone = widget.phoneNumber ?? '';
      if (phone.isNotEmpty) {
        try {
          final res = await ApiService.sendOtp(phone);
          final cooldown = (res['cooldownSeconds'] as num?)?.toInt() ?? 60;
          _startTimer(cooldown);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New OTP sent to your number')),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('ValidationFailure: ', '').replaceAll('NetworkFailure: ', ''))),
          );
        }
      }
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) return;

    final phone = widget.phoneNumber ?? '9876543210';
    setState(() {
      _isVerifying = true;
      hasError = false;
    });

    try {
      final res = await ApiService.verifyOtp(phone, code);
      if (!mounted) return;
      
      final isNewUser = res['isNewUser'] as bool?;
      final isRegisteredFlag = res['isRegistered'] as bool?;
      final token = res['token'] as String? ?? '';
      final cust = res['customer'] as Map<String, dynamic>?;
      final rawMongoId = cust?['_id'] as String? ?? cust?['id'] as String? ?? cust?['customerId'] as String? ?? 'u_customer';
      final customerId = rawMongoId;
      if (customerId.isNotEmpty && customerId != 'u_customer') {
        ApiService.setCustomerId(customerId);
      }
      final name = cust?['fullName'] as String? ?? 'User';
      final hasCompletedName = cust != null &&
          (cust['fullName'] as String?)?.trim().isNotEmpty == true &&
          cust['fullName'] != 'User';

      final isRegistered = (isRegisteredFlag == true) ||
          (isNewUser == false) ||
          hasCompletedName;

      // Persist auth session if token is provided
      if (token.isNotEmpty) {
        final session = AuthSession(
          accessToken: token,
          refreshToken: token,
          accessExpiresAt: DateTime.now().toUtc().add(const Duration(days: 30)),
          userId: customerId,
        );
        await context.read<AuthProvider>().onOtpSuccess(session);
      }

      // Update ProfileNotifier with verified customer data
      if (mounted) {
        final profile = context.read<ProfileNotifier>();
        if (cust != null) {
          profile.setName(name);
          profile.setPhone(cust['mobileNumber'] as String? ?? phone);
          if (cust['email'] != null) profile.setEmail(cust['email'] as String);
          if (cust['addresses'] is List && (cust['addresses'] as List).isNotEmpty) {
            final firstAddr = (cust['addresses'] as List).first as Map<String, dynamic>?;
            if (firstAddr != null) {
              final line1 = firstAddr['addressLine1'] ?? '';
              final city = firstAddr['city'] ?? '';
              final fullAddr = [line1, city].where((s) => s.toString().isNotEmpty).join(', ');
              if (fullAddr.isNotEmpty) profile.setAddress(fullAddr);
            }
          }
        } else {
          profile.setPhone(phone);
        }
        setState(() => hasError = false);

        if (isRegistered) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => MainNavWrapper(
                name: name,
                phoneNumber: phone,
              ),
            ),
            (route) => false,
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProfileSetup(phoneNumber: phone)),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => hasError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('ValidationFailure: ', '').replaceAll('NetworkFailure: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.phoneNumber ?? '9876543210';
    // Show only last 3 digits: +91 XXXXXXX543
    final masked = '+91 ${raw.substring(0, raw.length > 3 ? raw.length - 3 : 0).replaceAll(RegExp(r'\d'), 'X')}${raw.substring(raw.length > 3 ? raw.length - 3 : 0)}';
    final phoneDisplay = raw.isNotEmpty ? masked : '+91 XXXXXXX210';
    final timerText = '00:${_secondsLeft.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppTheme.text),
        title: hasError ? const Text('Verification', style: TextStyle(color: AppTheme.text, fontSize: 16)) : null,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!hasError) ...[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                  ),
                  child: const Center(child: Text('✉️', style: TextStyle(fontSize: 24))),
                ),
                const SizedBox(height: 24),
              ],
              const Text('Verify Mobile Number', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.text)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Code sent to ', style: TextStyle(color: Colors.grey)),
                  Text(phoneDisplay, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.edit, size: 16, color: AppTheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            final text = _otpController.text;
                            final char = index < text.length ? text[index] : (index == text.length ? '|' : '•');
                            return Container(
                              width: 42,
                              height: 50,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: hasError
                                      ? AppTheme.error
                                      : (index <= text.length ? AppTheme.primary : Colors.grey.shade300),
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: hasError ? AppTheme.error.withValues(alpha: 0.05) : Colors.white,
                              ),
                              child: Text(
                                char,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: hasError ? AppTheme.error : AppTheme.text,
                                ),
                              ),
                            );
                          }),
                        ),
                        if (hasError) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Invalid OTP. The code entered does not match.',
                              style: TextStyle(color: AppTheme.error, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat, size: 14, color: AppTheme.primary),
                                SizedBox(width: 8),
                                Text('Auto-reading OTP from SMS...', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Invisible input layer for native numeric keyboard
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.0,
                      child: TextField(
                        controller: _otpController,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        autofocus: true,
                        onChanged: (val) {
                          setState(() => hasError = false);
                          if (val.length == 6) _verifyOtp();
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasError) ...[
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          hasError = false;
                          _otpController.clear();
                        });
                        _focusNode.requestFocus();
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.refresh, size: 16, color: AppTheme.error),
                          SizedBox(width: 4),
                          Text('Clear & Try Again', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  const Text('Resend in ', style: TextStyle(color: Colors.grey)),
                  Text(timerText, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                ],
              ),
              const SizedBox(height: 12),
              if (hasError)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _resendOtp,
                      child: Text(
                        'Resend via SMS',
                        style: TextStyle(
                          color: _secondsLeft == 0 ? AppTheme.primary : Colors.grey,
                          fontWeight: _secondsLeft == 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.chat, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    const Text('Get OTP via WhatsApp', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ],
                )
              else
                GestureDetector(
                  onTap: _resendOtp,
                  child: Text(
                    'Resend OTP',
                    style: TextStyle(
                      color: _secondsLeft == 0 ? AppTheme.primary : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isVerifying ? null : _verifyOtp,
                child: _isVerifying
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Verify & Continue'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18),
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
