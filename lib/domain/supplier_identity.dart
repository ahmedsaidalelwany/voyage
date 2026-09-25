import 'package:equatable/equatable.dart';

class SupplierIdentity extends Equatable {
  final String id;
  final String name;
  final String authUrl;

  const SupplierIdentity({
    required this.id,
    required this.name,
    required this.authUrl,
  });

  @override
  List<Object?> get props => [id, name, authUrl];
}
