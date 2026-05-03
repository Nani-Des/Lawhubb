import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nhap/l10n/app_localizations.dart';
import 'package:nhap/main_layout.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';

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
      );
    } else {
      success = await authService.signInUser(
        context: context,
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    }

    if (success && context.mounted) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return PopScope(
      canPop: !_isRegistering && !_isForgotPassword,
      onPopInvoked: (didPop) {
        if (!didPop && (_isRegistering || _isForgotPassword)) {
          setState(() {
            _isRegistering = false;
            _isForgotPassword = false;
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isForgotPassword
                      ? 'Reset Password'
                      : _isRegistering
                          ? AppLocalizations.of(context)!.register
                          : AppLocalizations.of(context)!.login,
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
                          ? AppLocalizations.of(context)!.createAccount
                          : AppLocalizations.of(context)!.welcomeBack,
                  style: TextStyle(color: Colors.grey[400]), // Light grey text
                ),
                const SizedBox(height: 20),
                if (_isRegistering && !_isForgotPassword) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _firstNameController,
                          label: AppLocalizations.of(context)!.firstName,
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
                          label: AppLocalizations.of(context)!.lastName,
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
                  label: AppLocalizations.of(context)!.email,
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
                    label: AppLocalizations.of(context)!.password,
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
                    label: AppLocalizations.of(context)!.phoneNumber,
                    validator: (value) =>
                        value!.isEmpty ? 'Enter phone number' : null,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
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
                              ? AppLocalizations.of(context)!.register
                              : AppLocalizations.of(context)!.login,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black, // Black text for contrast
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
                              bool success =
                                  await authService.signInWithGoogle(context);
                              if (success && context.mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const MainLayout(),
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
                        AppLocalizations.of(context)!.signInWithGoogle,
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
                            AppLocalizations.of(context)!.forgotPassword,
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
                                  ? '${AppLocalizations.of(context)!.alreadyHaveAccount} Sign In'
                                  : '${AppLocalizations.of(context)!.needAnAccount} Register',
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
          if (authService.isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ],
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
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400]), // Light grey label
        prefixIcon: Icon(
          label.contains(AppLocalizations.of(context)!.email)
              ? Icons.email
              : label.contains(AppLocalizations.of(context)!.password)
                  ? Icons.lock
                  : label.contains(AppLocalizations.of(context)!.phoneNumber)
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
