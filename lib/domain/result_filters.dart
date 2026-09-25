import 'package:equatable/equatable.dart';

class ResultFilters extends Equatable {
  final double? maxPrice;
  final int? minRating;
  final String? supplierId;
  final String? mealPlan;
  final String? cancellationPolicy;
  final bool availableOnly;

  const ResultFilters({
    this.maxPrice,
    this.minRating,
    this.supplierId,
    this.mealPlan,
    this.cancellationPolicy,
    this.availableOnly = false,
  });

  ResultFilters copyWith({
    double? maxPrice,
    int? minRating,
    String? supplierId,
    String? mealPlan,
    String? cancellationPolicy,
    bool? availableOnly,
  }) {
    return ResultFilters(
      maxPrice: maxPrice ?? this.maxPrice,
      minRating: minRating ?? this.minRating,
      supplierId: supplierId ?? this.supplierId,
      mealPlan: mealPlan ?? this.mealPlan,
      cancellationPolicy: cancellationPolicy ?? this.cancellationPolicy,
      availableOnly: availableOnly ?? this.availableOnly,
    );
  }

  @override
  List<Object?> get props => [
        maxPrice,
        minRating,
        supplierId,
        mealPlan,
        cancellationPolicy,
        availableOnly,
      ];
}
