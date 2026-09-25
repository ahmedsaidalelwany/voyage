import 'package:equatable/equatable.dart';

enum SupplierSearchStatus { pending, searching, success, failure, sessionExpired }

class SupplierSearchProgress extends Equatable {
  final String supplierId;
  final String supplierName;
  final SupplierSearchStatus status;
  final int resultsCount;
  final String? errorMessage;

  const SupplierSearchProgress({
    required this.supplierId,
    required this.supplierName,
    this.status = SupplierSearchStatus.pending,
    this.resultsCount = 0,
    this.errorMessage,
  });

  SupplierSearchProgress copyWith({
    SupplierSearchStatus? status,
    int? resultsCount,
    String? errorMessage,
  }) {
    return SupplierSearchProgress(
      supplierId: supplierId,
      supplierName: supplierName,
      status: status ?? this.status,
      resultsCount: resultsCount ?? this.resultsCount,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [supplierId, supplierName, status, resultsCount, errorMessage];
}
