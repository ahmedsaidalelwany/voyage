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
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        routerConfig: _router,
      ),
    );
  }
}



