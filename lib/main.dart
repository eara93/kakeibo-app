import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // オフラインキャッシュで読み込み高速化
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true, cacheSizeBytes: 50000000);

  runApp(const KakeiboApp());
}

class KakeiboApp extends StatefulWidget {
  const KakeiboApp({super.key});

  static KakeiboAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<KakeiboAppState>();

  @override
  State<KakeiboApp> createState() => KakeiboAppState();
}

class KakeiboAppState extends State<KakeiboApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  ThemeMode get themeMode => _themeMode;

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary =
        isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1C1C1E);
    final textSecondary =
        isDark ? const Color(0xFF98989D) : const Color(0xFF8E8E93);
    final border = isDark ? const Color(0xFF38383A) : const Color(0xFFD1D1D6);
    final divider = isDark ? const Color(0xFF38383A) : const Color(0xFFC6C6C8);

    return ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF007AFF),
        brightness: brightness,
        surfaceContainerHighest: cardColor,
        surfaceContainerHigh: cardColor,
        surfaceContainer: cardColor,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      canvasColor: cardColor,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: cardColor,
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: bg,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.4,
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28, fontWeight: FontWeight.bold,
          color: textPrimary, letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 22, fontWeight: FontWeight.bold,
          color: textPrimary, letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w600,
          color: textPrimary, letterSpacing: -0.4,
        ),
        bodyLarge: TextStyle(
          fontSize: 17, color: textPrimary, letterSpacing: -0.4, height: 1.4,
        ),
        bodyMedium: TextStyle(
          fontSize: 15, color: textPrimary, letterSpacing: -0.2, height: 1.4,
        ),
        bodySmall: TextStyle(
          fontSize: 13, color: textSecondary, letterSpacing: -0.1, height: 1.3,
        ),
        labelLarge: const TextStyle(
          fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF007AFF), width: 2),
        ),
        labelStyle: TextStyle(fontSize: 15, color: textSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(fontSize: 17, letterSpacing: -0.4),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 56,
        elevation: 0,
        backgroundColor: cardColor,
        indicatorColor: const Color(0xFF007AFF).withValues(alpha: 0.12),
        labelTextStyle: WidgetStatePropertyAll(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
      dividerTheme: DividerThemeData(
        thickness: 0.5, color: divider, space: 0,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(fontSize: 15, color: textPrimary),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(cardColor),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '家計簿',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _themeMode,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
