import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../providers/subscription_provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final TextEditingController _mobile = TextEditingController();
  final TextEditingController _otp = TextEditingController();
  bool _subscribeWithOtp = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_mobile.text.isEmpty) {
      final String? stored = context.read<SubscriptionProvider>().mobile;
      if (stored != null) _mobile.text = stored;
    }
  }

  @override
  void dispose() {
    _mobile.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color terracotta = Color(0xFFA5482A);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFFFFFDFC),
                Color(0xFFF9EDEA),
                Color(0xFFFFF8F3),
              ],
            ),
          ),
          child: SafeArea(
            child: Consumer<SubscriptionProvider>(
              builder: (BuildContext context, SubscriptionProvider state, _) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 28,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Center(
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6E3DE),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: const Icon(
                                Icons.pets,
                                size: 34,
                                color: terracotta,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            AppConstants.appName,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: const Color(0xFF241F1D),
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Subscribe to continue caring for your cats.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: const Color(0xFF5E4942)),
                          ),
                          const SizedBox(height: 26),
                          Card(
                            color: Colors.white.withValues(alpha: 0.88),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                              side: const BorderSide(color: Color(0xFFE8C4B7)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: _content(state),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(SubscriptionProvider state) {
    if (state.stage == SubscriptionStage.checking) {
      return const Column(
        children: <Widget>[
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Checking your subscription…',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      );
    }
    if (state.stage == SubscriptionStage.blocked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Icon(
            Icons.wifi_off_rounded,
            size: 36,
            color: Color(0xFFA5482A),
          ),
          const SizedBox(height: 12),
          _ErrorText(state.error ?? 'Subscription could not be checked.'),
          const SizedBox(height: 18),
          _WarmButton(
            label: 'Retry',
            busy: state.isBusy,
            onPressed: state.retrySubscriptionCheck,
          ),
          TextButton(
            onPressed: state.isBusy ? null : state.useAnotherNumber,
            child: const Text('Use another number'),
          ),
        ],
      );
    }
    if (state.stage == SubscriptionStage.awaitingConfirmation) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Icon(
            Icons.mark_email_read_rounded,
            size: 40,
            color: Color(0xFFA5482A),
          ),
          const SizedBox(height: 14),
          const Text(
            'OTP has been verified, wait for confirmation message.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF3A2924),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          _WarmButton(
            label: 'Back to check subscription',
            busy: state.isBusy,
            onPressed: () {
              setState(() => _subscribeWithOtp = false);
              state.returnToSubscriptionCheck();
            },
          ),
        ],
      );
    }

    final bool otpStage = state.stage == SubscriptionStage.otp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          otpStage
              ? 'Verify your number'
              : _subscribeWithOtp
              ? 'Subscribe with OTP'
              : 'Check your subscription',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF3A2924),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '2.78 TK/day, auto-renew.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF8C341F),
          ),
        ),
        if (state.error != null) ...<Widget>[
          const SizedBox(height: 14),
          _ErrorText(state.error!),
        ],
        const SizedBox(height: 20),
        if (!otpStage)
          TextField(
            controller: _mobile,
            enabled: !state.isBusy,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(13),
            ],
            onSubmitted: (_) {
              if (!state.isBusy) {
                _subscribeWithOtp ? _sendOtp(state) : _checkSubscription(state);
              }
            },
            decoration: _inputDecoration(
              label: 'Mobile number',
              hint: '01XXXXXXXXX',
              icon: Icons.phone_android_rounded,
            ),
          )
        else
          TextField(
            controller: _otp,
            enabled: !state.isBusy,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            onSubmitted: (_) {
              if (!state.isBusy) _verifyOtp(state);
            },
            decoration: _inputDecoration(
              label: 'OTP',
              hint: 'Enter the code',
              icon: Icons.lock_outline_rounded,
            ),
          ),
        const SizedBox(height: 18),
        _WarmButton(
          label: otpStage
              ? 'Verify and continue'
              : _subscribeWithOtp
              ? 'Send OTP to subscribe'
              : 'Check subscription',
          busy: state.isBusy,
          onPressed: () => otpStage
              ? _verifyOtp(state)
              : _subscribeWithOtp
              ? _sendOtp(state)
              : _checkSubscription(state),
        ),
        if (!otpStage && !_subscribeWithOtp) ...<Widget>[
          const SizedBox(height: 6),
          TextButton(
            onPressed: state.isBusy
                ? null
                : () {
                    state.clearError();
                    setState(() => _subscribeWithOtp = true);
                  },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8C341F),
            ),
            child: const Text(
              'Not subscribed yet? Tap here',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
        if (!otpStage && _subscribeWithOtp) ...<Widget>[
          const SizedBox(height: 6),
          TextButton(
            onPressed: state.isBusy
                ? null
                : () {
                    state.clearError();
                    setState(() => _subscribeWithOtp = false);
                  },
            child: const Text('Already subscribed? Check subscription'),
          ),
        ],
        if (otpStage) ...<Widget>[
          const SizedBox(height: 4),
          TextButton(
            onPressed: state.isBusy
                ? null
                : () {
                    _otp.clear();
                    state.useAnotherNumber();
                  },
            child: const Text('Change mobile number'),
          ),
          TextButton(
            onPressed: state.isBusy
                ? null
                : () => state.sendOtp(state.mobile ?? _mobile.text),
            child: const Text('Resend OTP'),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: const Color(0xFFFFFCFA),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE7C8BE)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFA5482A), width: 1.5),
    ),
  );

  void _sendOtp(SubscriptionProvider state) {
    FocusScope.of(context).unfocus();
    state.sendOtp(_mobile.text);
  }

  void _checkSubscription(SubscriptionProvider state) {
    FocusScope.of(context).unfocus();
    state.checkMobileSubscription(_mobile.text);
  }

  void _verifyOtp(SubscriptionProvider state) {
    FocusScope.of(context).unfocus();
    state.verifyOtp(_otp.text);
  }
}

class _WarmButton extends StatelessWidget {
  const _WarmButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF9F4327),
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      child: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8E3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF8C341F),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
