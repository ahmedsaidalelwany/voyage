import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'bootstrap.dart';
import 'logic/supplier_connection_cubit.dart';
import 'logic/search_cubit.dart';
import 'data/supplier_connection_repository.dart';
import 'data/search_repository.dart';
import 'presentation/supplier_screen.dart';
import 'presentation/home_search_screen.dart';
import 'presentation/search_results_screen.dart';
import 'domain/search_criteria.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initDependencies();
  runApp(const VoyageApp());
}

final GoRouter _router = GoRouter(
  initialLocation: '/suppliers',
  routes: <RouteBase>[
    GoRoute(
      path: '/suppliers',
      builder: (BuildContext context, GoRouterState state) {
        return const SupplierScreen();
      },
    ),
    GoRoute(
      path: '/home',
      builder: (BuildContext context, GoRouterState state) {
        return const HomeSearchScreen();
      },
    ),
    GoRoute(
      path: '/results',
      builder: (BuildContext context, GoRouterState state) {
        final criteria = state.extra as SearchCriteria?;
        return SearchResultsScreen(criteria: criteria);
      },
    ),
  ],
);

class VoyageApp extends StatelessWidget {
  const VoyageApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SupplierConnectionCubit>(
          create: (_) => SupplierConnectionCubit(sl<SupplierConnectionRepository>()),
        ),
        BlocProvider<SearchCubit>(
          create: (_) => SearchCubit(sl<SearchRepository>()),
        ),
      ],
      child: MaterialApp.router(
        title: 'Voyage POC',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF315EF5),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF7F8FC),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(width: 1.4),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        routerConfig: _router,
      ),
    );
  }
}



