import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nhap/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'package:nhap/main_layout.dart';
import 'package:nhap/utils/country_utils.dart';
import 'package:nhap/widgets/searchable_country_sheet.dart';
import 'package:nhap/Auth/lawyer_registration_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  bool _isRegistering = false;
  bool _isForgotPassword = false;
  String _selectedCountryCode = kDefaultCountryCode;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isRegistering = !_isRegistering;
      _isForgotPassword = false;
    });
  }

  void _toggleForgotPassword() {
    setState(() {
      _isForgotPassword = !_isForgotPassword;
      _isRegistering = false;
    });
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    bool success;

    if (_isForgotPassword) {
      success = await authService.resetPassword(
        context: context,
        email: _emailController.text.trim(),
      );
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent. Check your inbox.'),
            backgroundColor: Colors.grey, // Grey snackbar background
          ),
        );
        setState(() {
          _isForgotPassword = false;
        });
      }
      return;
    }

    if (_isRegistering) {
      success = await authService.registerUser(
        context: context,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim(),
        countryCode: _selectedCountryCode,
      );
    } else {
      success = await authService.signInUser(
        context: context,
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    }

    if (success) {
      // Navigate back instead of replacing to maintain navigation stack
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black, // Black background
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (Navigator.of(context).canPop())
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.maybePop(context),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                Text(
                  _isForgotPassword
                      ? 'Reset Password'
                      : _isRegistering
                          ? l10n.register
                          : l10n.login,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // White text for contrast
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isForgotPassword
                      ? 'Enter your email to reset password'
                      : _isRegistering
                          ? l10n.createAccount
                          : l10n.welcomeBack,
                  style: TextStyle(color: Colors.grey[400]), // Light grey text
                ),
                const SizedBox(height: 20),
                if (_isRegistering && !_isForgotPassword) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _firstNameController,
                          label: l10n.firstName,
                          validator: (value) =>
                              value!.isEmpty ? 'Enter first name' : null,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z]')),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: _lastNameController,
                          label: l10n.lastName,
                          validator: (value) =>
                              value!.isEmpty ? 'Enter last name' : null,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z]')),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                _buildTextField(
                  controller: _emailController,
                  label: l10n.email,
                  validator: (value) {
                    if (value!.isEmpty) return 'Enter email';
                    if (!AuthService.isValidEmail(value.trim()))
                      return 'Invalid email format';
                    return null;
                  },
                ),
                if (!_isForgotPassword) ...[
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _passwordController,
                    label: l10n.password,
                    obscureText: true,
                    validator: (value) =>
                        value!.isEmpty ? 'Enter password' : null,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(20),
                    ],
                  ),
                ],
                if (_isRegistering && !_isForgotPassword) ...[
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _phoneNumberController,
                    label: l10n.phoneNumber,
                    validator: (value) =>
                        value!.isEmpty ? 'Enter phone number' : null,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: authService.isLoading
                        ? null
                        : () async {
                            final code = await showSearchableCountryPicker(
                              context,
                              title: 'Country',
                            );
                            if (code != null && context.mounted) {
                              setState(() => _selectedCountryCode = code);
                            }
                          },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Country',
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[600]!),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.tealAccent),
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        filled: true,
                        fillColor: Colors.grey[900],
                        suffixIcon:
                            const Icon(Icons.arrow_drop_down, color: Colors.white70),
                      ),
                      child: Text(
                        '${countryNameFromCode(_selectedCountryCode)} ($_selectedCountryCode)',
                        style: const TextStyle(
                            fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (authService.errorMessage != null)
                  Center(
                    child: Text(
                      authService.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.white, // White button for visibility
                      padding: const EdgeInsets.symmetric(
                        horizontal: 80,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed:
                        authService.isLoading ? null : () => _submit(context),
                    child: Text(
                      _isForgotPassword
                          ? 'Send Reset Email'
                          : _isRegistering
                              ? l10n.register
                              : l10n.login,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black, // Black text for contrast
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: FilledButton.icon(
                    onPressed: authService.isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const LawyerRegistrationScreen(),
                              ),
                            );
                          },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shadowColor: const Color(0xFF0D9488).withOpacity(0.45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.gavel_rounded, size: 20),
                    label: const Text(
                      'Register as a lawyer',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (!_isForgotPassword)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Colors.white), // White border
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: authService.isLoading
                          ? null
                          : () async {
                              final outcome =
                                  await authService.signInWithGoogle(context);
                              if (!context.mounted || !outcome.success) return;

                              if (outcome.needsCountrySelection) {
                                final code = await showSearchableCountryPicker(
                                  context,
                                  title: 'Select your country',
                                );
                                if (!context.mounted) return;
                                if (code == null || code.isEmpty) {
                                  await authService.signOut();
                                  return;
                                }
                                final ok = await authService
                                    .completeGoogleCountrySelection(code);
                                if (!ok) {
                                  await authService.signOut();
                                  return;
                                }
                              }

                              if (!context.mounted) return;
                              if (Navigator.of(context).canPop()) {
                                Navigator.pop(context, true);
                              } else {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => const MainLayout(),
                                  ),
                                  (route) => false,
                                );
                              }
                            },
                      icon: Image.network(
                        'https://www.google.com/favicon.ico',
                        height: 24,
                        width: 24,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.g_mobiledata,
                            size: 24,
                            color: Colors.white,
                          );
                        },
                      ),
                      label: Text(
                        l10n.signInWithGoogle,
                        style: TextStyle(
                            fontSize: 16, color: Colors.white), // White text
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!_isRegistering)
                        TextButton(
                          onPressed: _toggleForgotPassword,
                          child: Text(
                            '${l10n.forgotPassword}',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12), // White text
                          ),
                        ),
                      if (!_isRegistering && !_isForgotPassword)
                        const Text(
                          '|',
                          style: TextStyle(
                              color: Colors.white, fontSize: 16), // White text
                        ),
                      TextButton(
                        onPressed:
                            _isForgotPassword ? _toggleMode : _toggleMode,
                        child: Text(
                          _isForgotPassword
                              ? 'Back to Login'
                              : _isRegistering
                                  ? '${l10n.alreadyHaveAccount} Login'
                                  : '${l10n.needAnAccount}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12), // White text
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400]), // Light grey label
        prefixIcon: Icon(
          label.contains(l10n.email)
              ? Icons.email
              : label.contains(l10n.password)
                  ? Icons.lock
                  : label.contains(l10n.phoneNumber)
                      ? Icons.phone
                      : Icons.person,
          color: Colors.white, // White icon for contrast
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.grey[900], // Dark grey fill
        contentPadding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 20,
        ),
      ),
      validator: validator,
      style: const TextStyle(fontSize: 16, color: Colors.white), // White text
    );
  }
}
