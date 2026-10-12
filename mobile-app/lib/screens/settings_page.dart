import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/api/currency_api.dart';
import '../providers/app_config_provider.dart';
import '../providers/translation_provider.dart';
import '../widgets/translated_text.dart';
import 'login_page.dart';
import 'profile_page.dart';
import '../widgets/enterprise_ui_components.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool notificationsEnabled = true;
  bool darkModeEnabled = false;
  String? selectedLanguageId;
  String? selectedLanguageLabel = 'English';
  Map<String, dynamic>? apiTestResult;
  bool isTestingApi = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
      selectedLanguageId = prefs.getString('selected_language_id');
      selectedLanguageLabel =
          prefs.getString('selected_language_label') ?? 'English';
      if (selectedLanguageId != null && (selectedLanguageId!.isEmpty || selectedLanguageId == 'null' || selectedLanguageId == '0')) {
        selectedLanguageId = null;
        selectedLanguageLabel = 'English';
      }
    });
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', notificationsEnabled);
    await prefs.setBool('dark_mode_enabled', darkModeEnabled);
    if (selectedLanguageId != null) {
      await prefs.setString('selected_language_id', selectedLanguageId!);
    }
    if (selectedLanguageLabel != null) {
      await prefs.setString('selected_language_label', selectedLanguageLabel!);
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPageUI()),
        (route) => false,
      );
    }
  }


  Future<void> _changeLanguage(BuildContext context, String? languageId) async {
    if (languageId == null) return;
    final appConfigProvider = Provider.of<AppConfigProvider>(context, listen: false);
    final translationProvider = Provider.of<TranslationProvider>(context, listen: false);
    
    final option = appConfigProvider.languageOptions.firstWhere(
      (lang) => lang['id']?.toString() == languageId,
      orElse: () => {},
    );
    
    final languageName = option['language']?.toString() ?? 'English';
    
    // Get language code for translation
    String languageCode = 'en';
    final languageMap = {
      'Hindi': 'hi',
      'Spanish': 'es',
      'French': 'fr',
      'German': 'de',
      'Arabic': 'ar',
      'Portuguese': 'pt',
      'Portugis': 'pt',
      'Portugise': 'pt',
      'English': 'en',
    };
    
    // Try to match language name to code
    for (final entry in languageMap.entries) {
      if (languageName.toLowerCase().contains(entry.key.toLowerCase())) {
        languageCode = entry.value;
        break;
      }
    }
    
    final success = await CurrencyApi.updateStudentLanguage(languageId: languageId);
    if (success) {
      setState(() {
        selectedLanguageId = languageId;
        selectedLanguageLabel = languageName;
      });
      _saveSettings();
      
      // Update translation provider
      await translationProvider.changeLanguage(languageCode, languageName);
      
      await appConfigProvider.refreshConfig();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Language updated to $languageName')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update language')),
      );
    }
  }



  void _showChangePasswordDialog() {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement password change API
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password change functionality coming soon!'),
                ),
              );
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email address to receive a password reset link.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your email')),
                );
                return;
              }

              // Show loading
              Navigator.pop(context); // Close dialog first
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sending reset link...')),
              );

              try {
                final response = await ApiService.forgotPassword(email);
                
                // Status 1 often means success in this API
                if (response['status'] == '1' || response['status'] == 1 || response['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(response['message'] ?? 'Password reset link sent to your email!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(response['message'] ?? response['error'] ?? 'Failed to send reset link'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  Future<void> testApiConnectivity() async {
    setState(() {
      isTestingApi = true;
      apiTestResult = null;
    });

    try {
      final result = await ApiService.testApiConnectivity();
      setState(() {
        apiTestResult = result;
        isTestingApi = false;
      });
    } catch (e) {
      setState(() {
        apiTestResult = {'success': false, 'error': e.toString()};
        isTestingApi = false;
      });
    }
  }

  Future<void> testCurrencyApi() async {
    setState(() {
      isTestingApi = true;
      apiTestResult = null;
    });

    try {
      final currencies = await CurrencyApi.getCurrencyList();
      setState(() {
        apiTestResult = {
          'success': true,
          'message': 'Currency API test successful',
          'currencies_count': currencies.length,
          'currencies': currencies,
        };
        isTestingApi = false;
      });
    } catch (e) {
      setState(() {
        apiTestResult = {
          'success': false,
          'error': e.toString(),
          'message': 'Currency API test failed'
        };
        isTestingApi = false;
      });
    }
  }

@override
  Widget build(BuildContext context) {
    return Consumer<AppConfigProvider>(
      builder: (context, appConfigProvider, child) {
        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: const TranslatedText(
              'Settings',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            backgroundColor: appConfigProvider.primaryColorObj,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                EnterpriseUIComponents.buildHeaderWithIllustration(
                  title: 'Settings',
                  subtitle: 'App configuration and account settings',
                  illustration: Image.asset(
                    'assets/images/settingpage.jpg',
                    fit: BoxFit.contain,
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
            // Account Settings
            _buildSectionHeader('Account Settings'),
            _buildSettingsTile(
              icon: Icons.person,
              title: 'Profile',
              subtitle: 'View profile',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              },
            ),

            const SizedBox(height: 24),

            // App Settings
            _buildSectionHeader('App Settings'),
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.language, color: Colors.grey[700]),
                title: const TranslatedText('Language'),
                subtitle: Text(selectedLanguageLabel ?? 'Loading...'),
                trailing: appConfigProvider.languageOptions.isEmpty
                    ? const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Builder(
                        builder: (context) {
                          // Filter out null/empty IDs and ensure unique values
                          final validLanguages = <String, String>{};
                          for (final language in appConfigProvider.languageOptions) {
                            final id = language['id']?.toString();
                            if (id != null && id.isNotEmpty && id != 'null') {
                              validLanguages[id] = language['language']?.toString() ?? 'Language';
                            }
                          }

                          // Validate selectedLanguageId exists in valid items
                          final validSelectedId = validLanguages.containsKey(selectedLanguageId)
                              ? selectedLanguageId
                              : null;

                          return DropdownButton<String>(
                            value: validSelectedId,
                            hint: const Text('Select'),
                            underline: const SizedBox(),
                            items: validLanguages.entries.map((entry) {
                              return DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(entry.value),
                              );
                            }).toList(),
                            onChanged: (value) => _changeLanguage(context, value),
                          );
                        },
                      ),
              ),
            ),


            const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogoWidget(String logoUrl) {
    if (logoUrl.isEmpty) {
      return Icon(Icons.school, size: 40, color: Colors.grey[700]);
    }
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          logoUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.school, size: 30, color: Colors.grey[700]),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TranslatedText(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: textColor ?? Colors.grey[700]),
        title: TranslatedText(
          title,
          style: TextStyle(fontWeight: FontWeight.w500, color: textColor),
        ),
        subtitle: TranslatedText(
          subtitle,
          style: TextStyle(
            color: textColor?.withOpacity(0.7) ?? Colors.grey[600],
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey[700]),
        title: TranslatedText(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: TranslatedText(subtitle, style: TextStyle(color: Colors.grey[600])),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Prime School App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('by Primeskill Solutions Private Limited', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            const SizedBox(height: 8),
            Text('Version: 5.0.0', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Build: 7.2.0', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            const Text(
              'A comprehensive school management application for students, parents, and teachers.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
