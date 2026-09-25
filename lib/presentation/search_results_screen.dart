import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../logic/search_cubit.dart';
import '../domain/search_criteria.dart';
import '../domain/hotel.dart';
import '../domain/hotel_offer.dart';
import '../domain/supplier_search_progress.dart';

class SearchResultsScreen extends StatelessWidget {
  final SearchCriteria? criteria;

  const SearchResultsScreen({super.key, this.criteria});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(criteria?.destination.name ?? 'Search Results'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${criteria?.checkIn.day}/${criteria?.checkIn.month} → ${criteria?.checkOut.day}/${criteria?.checkOut.month}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text(
                  '${criteria?.nights ?? 0} Nights • ${criteria?.rooms.length ?? 0} Rooms • ${criteria?.currency ?? ""}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
      body: BlocBuilder<SearchCubit, SearchState>(
        builder: (context, state) {
          if (state is SearchInitial) {
            return const Center(child: Text('Initialize search...'));
          } else if (state is SearchInProgress) {
            return _buildProgressView(state.progress);
          } else if (state is SearchFailure) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.error_outline, size: 56, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Search failed',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(state.error),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Back to Search'),
                  ),
                ],
              ),
            );
          } else if (state is SearchSuccess) {
            final hotels = state.filteredHotels;
            if (hotels.isEmpty) {
              return Column(
                children: [
                  _buildProgressSummary(state.progress),
                  const Expanded(child: Center(child: Text('No hotels found matching criteria.'))),
                ],
              );
            }
            return Column(
              children: [
                _buildProgressSummary(state.progress),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Text('${hotels.length} Hotels', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.filter_list),
                        label: const Text('Filters'),
                        onPressed: () => _showFilters(context, state),

                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: hotels.length,
                    itemBuilder: (context, index) {
                      return HotelCard(hotel: hotels[index]);
                    },
                  ),
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Future<void> _showFilters(BuildContext context, SearchSuccess state) async {
    var minStars = state.filters.minRating;
    var maxPrice = state.filters.maxPrice;
    var supplier = state.filters.supplierId;
    var meal = state.filters.mealPlan;
    var cancellation = state.filters.cancellationPolicy;
    var availableOnly = state.filters.availableOnly;

    final priceController = TextEditingController(
      text: maxPrice?.toStringAsFixed(0) ?? '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final suppliers = <String>[
              'All',
              ...state.progress
                  .where((p) => p.status == SupplierSearchStatus.success)
                  .map((p) => p.supplierId),
            ];

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Filter results',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: suppliers.contains(supplier) ? supplier : 'All',
                        decoration: const InputDecoration(
                          labelText: 'Supplier',
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                        items: suppliers
                            .map((id) => DropdownMenuItem(
                                  value: id,
                                  child: Text(id == 'All' ? 'All suppliers' : id.toUpperCase()),
                                ))
                            .toList(),
                        onChanged: (value) => setSheetState(() => supplier = value == 'All' ? null : value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: minStars,
                        decoration: const InputDecoration(
                          labelText: 'Minimum stars',
                          prefixIcon: Icon(Icons.star_outline),
                        ),
                        items: const [
                          DropdownMenuItem(value: 3, child: Text('3+ stars')),
                          DropdownMenuItem(value: 4, child: Text('4+ stars')),
                          DropdownMenuItem(value: 5, child: Text('5 stars')),
                        ],
                        onChanged: (value) => setSheetState(() => minStars = value),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Maximum price',
                          prefixText: state.criteria.currency + ' ',
                          prefixIcon: const Icon(Icons.payments_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: meal,
                        decoration: const InputDecoration(
                          labelText: 'Meal plan',
                          prefixIcon: Icon(Icons.restaurant_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Room Only', child: Text('Room Only')),
                          DropdownMenuItem(value: 'Breakfast', child: Text('Breakfast')),
                          DropdownMenuItem(value: 'Half Board', child: Text('Half Board')),
                          DropdownMenuItem(value: 'Full Board', child: Text('Full Board')),
                          DropdownMenuItem(value: 'All Inclusive', child: Text('All Inclusive')),
                        ],
                        onChanged: (value) => setSheetState(() => meal = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: cancellation,
                        decoration: const InputDecoration(
                          labelText: 'Cancellation',
                          prefixIcon: Icon(Icons.event_available_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Free cancellation', child: Text('Free cancellation')),
                          DropdownMenuItem(value: 'Non-refundable', child: Text('Non-refundable')),
                        ],
                        onChanged: (value) => setSheetState(() => cancellation = value),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Available offers only'),
                        value: availableOnly,
                        onChanged: (value) => setSheetState(() => availableOnly = value),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () {
                          context.read<SearchCubit>().applyFilters(
                                ResultFilters(
                                  maxPrice: double.tryParse(priceController.text.trim()),
                                  minRating: minStars,
                                  supplierId: supplier,
                                  mealPlan: meal,
                                  cancellationPolicy: cancellation,
                                  availableOnly: availableOnly,
                                ),
                              );
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('Apply filters'),
                      ),
                      TextButton(
                        onPressed: () {
                          context.read<SearchCubit>().applyFilters(const ResultFilters());
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    priceController.dispose();
  }

  Widget _buildProgressView(List<SupplierSearchProgress> progressList) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text('Searching suppliers...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...progressList.map((p) {
              String statusText = 'Pending...';
              Color color = Colors.grey;
              if (p.status == SupplierSearchStatus.searching) {
                statusText = 'Searching...';
                color = Colors.blue;
              } else if (p.status == SupplierSearchStatus.success) {
                statusText = '${p.resultsCount} results';
                color = Colors.green;
              } else if (p.status == SupplierSearchStatus.failure) {
                statusText = 'Failed';
                color = Colors.red;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(p.supplierName),
                    Text(statusText, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSummary(List<SupplierSearchProgress> progressList) {
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: progressList.map((p) {
            Color color = p.status == SupplierSearchStatus.success ? Colors.green : Colors.red;
            String text = p.status == SupplierSearchStatus.success ? '${p.resultsCount}' : 'Err';
            return Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  Text('${p.supplierName}: ', style: const TextStyle(fontSize: 12)),
                  Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class HotelCard extends StatelessWidget {
  final Hotel hotel;

  const HotelCard({Key? key, required this.hotel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 150,
            color: Colors.grey[300],
            child: const Center(child: Icon(Icons.hotel, size: 64, color: Colors.grey)), // Placeholder for image
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        hotel.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Row(
                      children: List.generate(
                        hotel.stars ?? 0,
                        (index) => const Icon(Icons.star, color: Colors.amber, size: 16),
                      ),
                    ),
                  ],
                ),
                if (hotel.city != null)
                  Text('${hotel.city}, ${hotel.country ?? ""}', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                const Divider(),
                const Text('SUPPLIER OFFERS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                ...hotel.offers.map((offer) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(offer.supplierId.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${offer.currency} ${offer.price}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      // Navigate to details
                    },
                    child: const Text('View All Offers'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

