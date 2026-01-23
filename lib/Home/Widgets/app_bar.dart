import 'package:flutter/material.dart';
import 'package:nhap/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:nhap/Services/language_provider.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? userImageUrl;
  final VoidCallback onAvatarTap;
  final VoidCallback? onAIAssistantTap;

  const CustomAppBar({
    super.key,
    required this.userImageUrl,
    required this.onAvatarTap,
    this.onAIAssistantTap,
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.grey[800]!,
                  ),
                ),
                child: const Icon(
                  Icons.balance,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'LawHub',
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
              child: GestureDetector(
                onTap: onAvatarTap,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey[800]!,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[850],
                    backgroundImage:
                        userImageUrl != null && userImageUrl!.isNotEmpty
                            ? NetworkImage(userImageUrl!)
                            : null,
                    child: userImageUrl == null || userImageUrl!.isEmpty
                        ? const Icon(
                            Icons.person_outline,
                            color: Colors.white,
                            size: 20,
                          )
                        : null,
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
