class Address {
  final String formattedAddress;
  final String street;
  final String houseNumber;
  final String neighbourhood;
  final String city;
  final String state;
  final String country;
  final String postcode;
  final double latitude;
  final double longitude;

  Address({
    required this.formattedAddress,
    this.street = '',
    this.houseNumber = '',
    this.neighbourhood = '',
    this.city = '',
    this.state = '',
    this.country = '',
    this.postcode = '',
    required this.latitude,
    required this.longitude,
  });

  /// Cria Address a partir de Map (banco de dados)
  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      formattedAddress: map['formatted_address'] ?? '',
      street: map['street'] ?? '',
      houseNumber: map['house_number'] ?? '',
      neighbourhood: map['neighbourhood'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      country: map['country'] ?? '',
      postcode: map['postcode'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
    );
  }

  /// Converte Address para Map (banco de dados)
  Map<String, dynamic> toMap() {
    return {
      'formatted_address': formattedAddress,
      'street': street,
      'house_number': houseNumber,
      'neighbourhood': neighbourhood,
      'city': city,
      'state': state,
      'country': country,
      'postcode': postcode,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Endereço resumido (rua e bairro)
  String get shortAddress {
    if (street.isNotEmpty && neighbourhood.isNotEmpty) {
      return '$street, $neighbourhood';
    } else if (street.isNotEmpty) {
      return street;
    } else if (neighbourhood.isNotEmpty) {
      return neighbourhood;
    } else if (city.isNotEmpty) {
      return city;
    } else {
      return formattedAddress;
    }
  }

  /// Endereço da cidade
  String get cityAddress {
    if (city.isNotEmpty && state.isNotEmpty) {
      return '$city, $state';
    } else if (city.isNotEmpty) {
      return city;
    } else if (state.isNotEmpty) {
      return state;
    } else {
      return country;
    }
  }

  @override
  String toString() {
    return formattedAddress;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Address &&
        other.formattedAddress == formattedAddress &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode {
    return formattedAddress.hashCode ^ latitude.hashCode ^ longitude.hashCode;
  }
}

