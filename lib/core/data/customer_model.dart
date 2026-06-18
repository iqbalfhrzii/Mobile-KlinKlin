import 'order_model.dart';

class CustomerModel {
  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.status,
    required this.totalOrders,
    required this.totalSpending,
    required this.lastOrderDate,
    required this.notes,
    required this.orders,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: 'PLG-${json['id']}',
      name: json['nama_pelanggan'] ?? '-',
      phone: json['no_wa'] ?? '-',
      address: json['alamat'] ?? '-',
      status: json['status']?.toString() ?? 'UNKNOWN',
      totalOrders: 0,
      totalSpending: 0,
      lastOrderDate: '-',
      notes: '',
      orders: const [],
    );
  }

  final String id;
  final String name;
  final String phone;
  final String address;
  final String status; // aktif | non aktif
  final int totalOrders;
  final int totalSpending;
  final String lastOrderDate;
  final String notes;
  final List<CustomerOrder> orders;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }

  int get avgOrder => totalOrders > 0 ? (totalSpending / totalOrders).round() : 0;
}

class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.service,
    required this.date,
    required this.cleaners,
    required this.amount,
    required this.status,
  });

  final String id;
  final String service;
  final String date;
  final List<String> cleaners;
  final int amount;
  final OrderStatus status;
}
