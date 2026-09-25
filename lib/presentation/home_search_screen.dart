import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:developer' as developer;
import '../domain/search_criteria.dart';
import '../domain/destination.dart';
import '../domain/room_occupancy.dart';
import '../logic/search_cubit.dart';
import '../logic/supplier_connection_cubit.dart';
import '../domain/supplier_connection_status.dart';
import '../data/supplier_connection_repository.dart';
import '../data/destination_service.dart';
import '../bootstrap.dart';

class HomeSearchScreen extends StatefulWidget {
  const HomeSearchScreen({Key? key}) : super(key: key);

  @override
  State<HomeSearchScreen> createState() => _HomeSearchScreenState();
}

class _HomeSearchScreenState extends State<HomeSearchScreen> {
  Destination? _selectedDestination;
  DateTime _checkIn = DateTime.now().add(const Duration(days: 7));
  DateTime _checkOut = DateTime.now().add(const Duration(days: 11));
  List<RoomOccupancy> _rooms = [const RoomOccupancy(adults: 2)];
  String _currency = 'AED';
  String? _hotelName;
  int? _minimumStars;
  double? _maximumPrice;
  String? _mealPlan;
  String? _cancellationPreference;
  bool _availableOnly = false;

  final List<String> _currencies = ['USD', 'EUR', 'GBP', 'AED', 'EGP', 'SAR', 'QAR', 'KWD', 'BHD', 'OMR'];
  final DestinationService _destinationService = DestinationService();


  Future<void> _showAdvancedSearch() async {
    final hotelController = TextEditingController(text: _hotelName ?? '');
    final priceController = TextEditingController(
      text: _maximumPrice?.toStringAsFixed(0) ?? '',
    );
    var stars = _minimumStars;
    var meal = _mealPlan;
    var cancellation = _cancellationPreference;
    var availableOnly = _availableOnly;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                        'Advanced hotel search',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Criteria are passed to the supplier integration when supported and are also applied to returned offers.',
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: hotelController,
                        decoration: const InputDecoration(
                          labelText: 'Hotel name',
                          prefixIcon: Icon(Icons.hotel_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: stars,
                        decoration: const InputDecoration(
                          labelText: 'Minimum stars',
                          prefixIcon: Icon(Icons.star_outline),
                        ),
                        items: [3, 4, 5]
                            .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value.toString() + ' stars & above'),
                                ))
                            .toList(),
                        onChanged: (value) => setSheetState(() => stars = value),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Maximum price per offer',
                          prefixText: _currency + ' ',
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
                          setState(() {
                            _hotelName = hotelController.text.trim().isEmpty
                                ? null
                                : hotelController.text.trim();
                            _minimumStars = stars;
                            _maximumPrice = double.tryParse(priceController.text.trim());
                            _mealPlan = meal;
                            _cancellationPreference = cancellation;
                            _availableOnly = availableOnly;
                          });
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('Apply advanced search'),
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

    hotelController.dispose();
    priceController.dispose();
  }

  void _performSearch(BuildContext context) {
    if (_selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a destination')));
      return;
    }

    final criteria = SearchCriteria(
      destination: _selectedDestination!,
      checkIn: _checkIn,
      checkOut: _checkOut,
      rooms: _rooms,
      currency: _currency,
      hotelName: _hotelName,
      minimumStars: _minimumStars,
      maximumPrice: _maximumPrice,
      mealPlan: _mealPlan,
      cancellationPreference: _cancellationPreference,
      availableOnly: _availableOnly,
    );
    
    // SAFE DIAGNOSTIC LOGGING (Phase 3)
    developer.log('''
[SEARCH DEBUG]
Search started
destination = ${criteria.destination.name}
currency = ${criteria.currency}
checkIn = ${criteria.checkIn}
checkOut = ${criteria.checkOut}
rooms = ${criteria.rooms.length}
occupancy = ${criteria.rooms.map((r) => '\${r.adults}A, \${r.childrenAges.length}C').join(' | ')}
''');

    final connState = context.read<SupplierConnectionCubit>().state;
    final allAdapters = sl<SupplierConnectionRepository>().adapters;
    
    final connectedAdapters = allAdapters.where((a) {
      return connState.states[a.supplier.id]?.status == SupplierConnectionStatus.connected;
    }).toList();

    context.read<SearchCubit>().search(criteria, connectedAdapters);
    context.push('/results', extra: criteria);
  }

  int get _selectedAdvancedCount {
    var count = 0;
    if (_hotelName != null) count++;
    if (_minimumStars != null) count++;
    if (_maximumPrice != null) count++;
    if (_mealPlan != null) count++;
    if (_cancellationPreference != null) count++;
    if (_availableOnly) count++;
    return count;
  }

  void _editGuests() async {
    final result = await showModalBottomSheet<List<RoomOccupancy>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _GuestEditor(initialRooms: _rooms),
    );
    if (result != null) {
      setState(() {
        _rooms = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalAdults = _rooms.fold(0, (sum, room) => sum + room.adults);
    int totalChildren = _rooms.fold(0, (sum, room) => sum + room.childrenAges.length);

    return Scaffold(
      appBar: AppBar(title: const Text('Search Hotels')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Find hotels',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Search across your connected suppliers.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Autocomplete<Destination>(
              displayStringForOption: (Destination option) => option.name,
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<Destination>.empty();
                }
                return _destinationService.getSuggestions(textEditingValue.text);
              },
              onSelected: (Destination selection) {
                setState(() {
                  _selectedDestination = selection;
                });
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Destination, city, or hotel',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.location_on),
                    suffixIcon: _selectedDestination != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              textEditingController.clear();
                              setState(() {
                                _selectedDestination = null;
                              });
                            },
                          )
                        : null,
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width - 32,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Destination option = options.elementAt(index);
                          return ListTile(
                            leading: Icon(option.type == 'Country' ? Icons.public : Icons.location_city),
                            title: Text(option.name),
                            subtitle: Text(option.countryCode ?? ''),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _checkIn,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          _checkIn = picked;
                          if (_checkOut.isBefore(_checkIn.add(const Duration(days: 1)))) {
                            _checkOut = _checkIn.add(const Duration(days: 1));
                          }
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Check-in',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text('${_checkIn.day}/${_checkIn.month}/${_checkIn.year}'),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _checkOut,
                        firstDate: _checkIn.add(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _checkOut = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Check-out',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text('${_checkOut.day}/${_checkOut.month}/${_checkOut.year}'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _editGuests,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Guests & Rooms',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people),
                ),
                child: Text('${_rooms.length} Rooms • $totalAdults Adults${totalChildren > 0 ? ' • $totalChildren Children' : ''}'),
              ),
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Currency',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.monetization_on),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _currency,
                  isExpanded: true,
                  isDense: true,
                  items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _currency = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _showAdvancedSearch,
              icon: const Icon(Icons.tune),
              label: Text(
                _selectedAdvancedCount == 0
                    ? 'Advanced search'
                    : 'Advanced search (' + _selectedAdvancedCount.toString() + ')',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _performSearch(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              child: const Text('Search Hotels', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestEditor extends StatefulWidget {
  final List<RoomOccupancy> initialRooms;

  const _GuestEditor({Key? key, required this.initialRooms}) : super(key: key);

  @override
  State<_GuestEditor> createState() => _GuestEditorState();
}

class _GuestEditorState extends State<_GuestEditor> {
  late List<RoomOccupancy> rooms;

  @override
  void initState() {
    super.initState();
    rooms = List.from(widget.initialRooms);
  }

  void _addRoom() {
    setState(() {
      rooms.add(const RoomOccupancy(adults: 1));
    });
  }

  void _removeRoom(int index) {
    if (rooms.length > 1) {
      setState(() {
        rooms.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Guests & Rooms', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Room ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                if (rooms.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _removeRoom(index),
                                  )
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Adults'),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: room.adults > 1
                                          ? () => setState(() => rooms[index] = RoomOccupancy(adults: room.adults - 1, childrenAges: room.childrenAges))
                                          : null,
                                    ),
                                    Text('${room.adults}'),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: room.adults < 4
                                          ? () => setState(() => rooms[index] = RoomOccupancy(adults: room.adults + 1, childrenAges: room.childrenAges))
                                          : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Children'),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: room.childrenAges.isNotEmpty
                                          ? () => setState(() {
                                                final ages = List<int>.from(room.childrenAges)..removeLast();
                                                rooms[index] = RoomOccupancy(adults: room.adults, childrenAges: ages);
                                              })
                                          : null,
                                    ),
                                    Text('${room.childrenAges.length}'),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: room.childrenAges.length < 3
                                          ? () => setState(() {
                                                final ages = List<int>.from(room.childrenAges)..add(7); // Default age
                                                rooms[index] = RoomOccupancy(adults: room.adults, childrenAges: ages);
                                              })
                                          : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (room.childrenAges.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text('Child Ages', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                children: List.generate(room.childrenAges.length, (childIndex) {
                                  return DropdownButton<int>(
                                    value: room.childrenAges[childIndex],
                                    items: List.generate(18, (i) => DropdownMenuItem(value: i, child: Text('$i yrs'))),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          final ages = List<int>.from(room.childrenAges);
                                          ages[childIndex] = val;
                                          rooms[index] = RoomOccupancy(adults: room.adults, childrenAges: ages);
                                        });
                                      }
                                    },
                                  );
                                }),
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              OutlinedButton(
                onPressed: _addRoom,
                child: const Text('Add Another Room'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(rooms),
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
