class ServiceItem {
  const ServiceItem({required this.name, required this.price, required this.qty});
  final String name;
  final int price;
  final int qty;
  int get subtotal => price * qty;
}

class OrderCustomer {
  const OrderCustomer({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.area,
  });
  final String id;
  final String name;
  final String phone;
  final String address;
  final String area;
}

class OrderCleaner {
  const OrderCleaner({required this.id, required this.name, required this.rating});
  final String id;
  final String name;
  final double rating;
}

class OrderModel {
  OrderModel({
    required this.id,
    required this.customer,
    required this.services,
    required this.schedule,
    required this.scheduleDateTime,
    required this.cleaners,
    required this.status,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.notes,
    this.cancelReason,
    this.paymentProof,
  });

  final String id;
  final OrderCustomer customer;
  final List<ServiceItem> services;
  final String schedule; // "Rabu, 11 Jun 2026 · 09:00 - 11:00"
  final DateTime scheduleDateTime; // for date filtering
  final List<OrderCleaner> cleaners;
  String status; // pending | assigned | in_progress | completed | cancelled | paid
  final int total;
  String paymentMethod;
  String paymentStatus; // unpaid | paid | cancelled
  final String notes;
  String? cancelReason;
  String? paymentProof;
}

/// Draft saat membuat pesanan baru (wizard)
class OrderDraft {
  OrderDraft({
    this.customer,
    List<ServiceItem>? services,
    this.scheduleDate,
    this.scheduleTime,
    List<OrderCleaner>? cleaners,
    this.notes = '',
  }) : services = services ?? [],
       cleaners = cleaners ?? [];

  OrderCustomer? customer;
  List<ServiceItem> services;
  String? scheduleDate;
  String? scheduleTime;
  List<OrderCleaner> cleaners;
  String notes;

  int get total => services.fold(0, (sum, s) => sum + s.subtotal);
}
