import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/bus_route_service.dart';
import 'services/google_config.dart';
import 'services/google_places_service.dart';
import 'services/supabase_config.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'widgets/branded_background.dart';
import 'screens/public_map_screen.dart';
import 'screens/music_screen.dart';
import 'screens/news_screen.dart';
import 'screens/more_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/member_signin_screen.dart';
import 'screens/member_signup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  // Bus Routes feature: real-road polylines + Places search. Both
  // services degrade gracefully when the key is empty — the editor
  // falls back to straight-line polylines and search returns nothing.
  BusRouteService.googleDirectionsApiKey = GoogleConfig.apiKey;
  GooglePlacesService.apiKey = GoogleConfig.apiKey;
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const FayhaApp());
}

class FayhaApp extends StatelessWidget {
  const FayhaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fayha National Choir',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(next: _RootScaffold()),
    );
  }
}

class _RootScaffold extends StatefulWidget {
  const _RootScaffold();

  @override
  State<_RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<_RootScaffold> {
  int _index = 0;

  static const _titles = ['Fayha', 'Map', 'Music', 'News', 'More'];

  late final List<Widget> _screens = <Widget>[
    HomeScreen(
      onGoToMusic: () => setState(() => _index = 2),
      onGoToNews: () => setState(() => _index = 3),
    ),
    const PublicMapScreen(),
    const MusicScreen(),
    const NewsScreen(),
    const MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isHome = _index == 0;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.dark,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: AppColors.cream,
        title: isHome ? null : Text(_titles[_index]),
        actions: [
          TextButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MemberSignInScreen())),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Sign In'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: FilledButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MemberSignUpScreen())),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.cream,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: const Size(0, 36),
              ),
              child: const Text('Sign Up'),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: IndexedStack(index: _index, children: _screens),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note_outlined),
            activeIcon: Icon(Icons.music_note),
            label: 'Music',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.newspaper_outlined),
            activeIcon: Icon(Icons.newspaper),
            label: 'News',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz_outlined),
            activeIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
