import 'package:flutter/material.dart';
import 'package:nhap/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:nhap/Services/language_provider.dart';
import 'package:nhap/widgets/lawhubb_brand_icon.dart';
import 'package:nhap/widgets/profile_avatar.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? userImageUrl;
  /// When not logged in: opens sign-in (same as tapping avatar).
  final VoidCallback onGuestAvatarTap;
  /// Logged-in: opens profile sheet / drawer.
  final VoidCallback onOpenProfile;
  /// Logged-in only; when non-null, menu shows "Register as a lawyer".
  final VoidCallback? onRegisterAsLawyer;

  final bool isLoggedIn;

  const CustomAppBar({
    super.key,
    required this.userImageUrl,
    required this.onGuestAvatarTap,
    required this.onOpenProfile,
    this.onRegisterAsLawyer,
    this.isLoggedIn = false,
  });

  String _getLanguageName(
      String languageCode, AppLocalizations? localizations) {
    switch (languageCode) {
      case 'en':
        return localizations?.english ?? 'English';
      case 'es':
        return localizations?.spanish ?? 'Spanish';
      case 'fr':
        return localizations?.french ?? 'French';
      default:
        return 'English';
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        final currentLocale = languageProvider.currentLanguageCode;

        return AppBar(
          elevation: 0,
          backgroundColor: Colors.black,
          title: Row(
            children: [
              const LawHubbBrandIcon(size: 36, borderRadius: 10),
              const SizedBox(width: 12),
              const Text(
                'LawHubb',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          actions: [
            // Language Switcher Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: PopupMenuButton<String>(
                onSelected: (String languageCode) {
                  languageProvider.changeLanguage(languageCode);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${_getLanguageName(languageCode, localizations)} selected'),
                      backgroundColor: Colors.grey[800],
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(milliseconds: 800),
                    ),
                  );
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'en',
                    child: Row(
                      children: [
                        Text(
                          languageProvider.getFlagEmoji('en'),
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(localizations?.english ?? 'English'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'es',
                    child: Row(
                      children: [
                        Text(
                          languageProvider.getFlagEmoji('es'),
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(localizations?.spanish ?? 'Spanish'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'fr',
                    child: Row(
                      children: [
                        Text(
                          languageProvider.getFlagEmoji('fr'),
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(localizations?.french ?? 'French'),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey[800]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        languageProvider.getFlagEmoji(currentLocale),
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        currentLocale.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: isLoggedIn
                  ? PopupMenuButton<String>(
                      offset: const Offset(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: Colors.grey[900],
                      onSelected: (value) {
                        if (value == 'profile') {
                          onOpenProfile();
                        } else if (value == 'lawyer') {
                          onRegisterAsLawyer?.call();
                        }
                      },
                      itemBuilder: (BuildContext context) {
                        final items = <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'profile',
                            child: Row(
                              children: [
                                Icon(Icons.person_outline,
                                    color: Colors.grey[300], size: 22),
                                const SizedBox(width: 12),
                                const Text(
                                  'Profile',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ];
                        if (onRegisterAsLawyer != null) {
                          items.add(
                            PopupMenuItem<String>(
                              value: 'lawyer',
                              child: Row(
                                children: [
                                  Icon(Icons.gavel_rounded,
                                      color: Colors.grey[300], size: 22),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Register as a lawyer',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return items;
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey[800]!,
                            width: 2,
                          ),
                        ),
                        child: ProfileAvatar.circle(
                          imageUrl: userImageUrl,
                          radius: 18,
                          backgroundColor: Colors.grey[850],
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: onGuestAvatarTap,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey[800]!,
                            width: 2,
                          ),
                        ),
                        child: ProfileAvatar.circle(
                          imageUrl: userImageUrl,
                          radius: 18,
                          backgroundColor: Colors.grey[850],
                        ),
                      ),
                    ),
            ),
          ],
          automaticallyImplyLeading: false,
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
