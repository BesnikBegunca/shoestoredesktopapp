class Business {
  final int id;
  final String name;
  final String password;
  final String? address;
  final String? city;
  final String? postalCode;
  final String? phone;
  final String? email;
  final String? ownerName;
  final String? taxId;
  final String? registrationNumber;
  final String? contactPerson;
  final String? website;
  final String? notes;
  final int createdByUserId; // ID e superadmin që e krijoi
  final int createdAtMs;
  final bool active;

  const Business({
    required this.id,
    required this.name,
    required this.password,
    this.address,
    this.city,
    this.postalCode,
    this.phone,
    this.email,
    this.ownerName,
    this.taxId,
    this.registrationNumber,
    this.contactPerson,
    this.website,
    this.notes,
    required this.createdByUserId,
    required this.createdAtMs,
    required this.active,
  });

  static Business fromRow(Map<String, Object?> r) => Business(
    id: (r['id'] as int?) ?? 0,
    name: (r['name'] as String?) ?? '',
    password: (r['password'] as String?) ?? '',
    address: r['address'] as String?,
    city: r['city'] as String?,
    postalCode: r['postalCode'] as String?,
    phone: r['phone'] as String?,
    email: r['email'] as String?,
    ownerName: r['ownerName'] as String?,
    taxId: r['taxId'] as String?,
    registrationNumber: r['registrationNumber'] as String?,
    contactPerson: r['contactPerson'] as String?,
    website: r['website'] as String?,
    notes: r['notes'] as String?,
    createdByUserId: (r['createdByUserId'] as int?) ?? 0,
    createdAtMs: (r['createdAtMs'] as int?) ?? 0,
    active: ((r['active'] as int?) ?? 1) == 1,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'password': password,
    'address': address,
    'city': city,
    'postalCode': postalCode,
    'phone': phone,
    'email': email,
    'ownerName': ownerName,
    'taxId': taxId,
    'registrationNumber': registrationNumber,
    'contactPerson': contactPerson,
    'website': website,
    'notes': notes,
    'createdByUserId': createdByUserId,
    'createdAtMs': createdAtMs,
    'active': active ? 1 : 0,
  };
}
