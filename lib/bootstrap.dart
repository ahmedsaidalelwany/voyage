import 'package:get_it/get_it.dart';
import 'data/bedzinn_adapter.dart';
import 'data/mock_adapters.dart';
import 'data/supplier_connection_repository.dart';

import 'data/search_repository.dart';

final sl = GetIt.instance;

void initDependencies() {
  // Adapters
  final adapters = [
    BedzinnAdapter(),
    TripovoAdapter(),
    EliteBookingsAdapter(),
    MustasharAdapter(),
  ];

  // Repositories
  sl.registerLazySingleton<SupplierConnectionRepository>(
    () => SupplierConnectionRepository(adapters),
  );
  
  sl.registerLazySingleton<SearchRepository>(
    () => SearchRepository(),
  );
}
