import 'package:flutter/material.dart';

import 'core/router/app_routes.dart';
import 'core/supabase/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/auth/forgot_password_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/shell/main_shell_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();

  runApp(const LosAndesApp());
}

class LosAndesApp extends StatelessWidget {
  const LosAndesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Banco Los Andes',
      theme: AppTheme.light,
      initialRoute:
          SupabaseConfig.isConfigured &&
              Supabase.instance.client.auth.currentSession != null
          ? AppRoutes.dashboard
          : AppRoutes.login,
      routes: {
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.register: (_) => const RegisterScreen(),
        AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
        AppRoutes.dashboard: (_) => const MainShellScreen(),
      },
    );
  }
}
