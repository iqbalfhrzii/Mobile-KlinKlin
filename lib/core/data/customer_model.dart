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
    this.cabangId,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: 'PLG-${json['id']}',
      cabangId: json['cabang_id'] != null ? int.tryParse(json['cabang_id'].toString()) : null,
      name: json['nama_pelanggan'] ?? '-',
      phone: json['no_wa'] ?? '-',
      address: json['alamat'] ?? '-',
      status: json['status']?.toString() ?? 'UNKNOWN',
      totalOrders: json['total_pesanan'] != null 
          ? (int.tryParse(json['total_pesanan'].toString()) ?? 0)
          : (json['pesanans_count'] != null 
              ? (int.tryParse(json['pesanans_count'].toString()) ?? 0)
              : 0),
      totalSpending: json['total_belanja'] != null ? int.tryParse(json['total_belanja'].toString()) ?? 0 : 0,
      lastOrderDate: json['terakhir_pesan'] ?? '-',
      notes: json['catatan'] ?? '',
      orders: json['pesanans'] != null 
          ? (json['pesanans'] as List).map((e) => CustomerOrder.fromJson(e)).toList() 
          : const [],
    );
  }

  final String id;
  final int? cabangId;
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

  factory CustomerOrder.fromJson(Map<String, dynamic> json) {
    String serviceName = 'Pesanan';
    if (json['details'] != null && (json['details'] as List).isNotEmpty) {
      final details = json['details'] as List;
      final names = details.map((d) {
        if (d['layanan'] != null && d['layanan']['nama_layanan'] != null) {
          return d['layanan']['nama_layanan'].toString();
        }
        return '';
      }).where((s) => s.isNotEmpty).toList();
      
      if (names.isNotEmpty) {
        if (names.length > 2) {
          serviceName = '${names[0]}, ${names[1]} +${names.length - 2} lainnya';
        } else {
          serviceName = names.join(', ');
        }
      }
    }
    
    List<String> cleanerNames = [];
    if (json['cleaners'] != null) {
      for (var c in json['cleaners']) {
        if (c['cleaner'] != null && c['cleaner']['nama'] != null) {
          cleanerNames.add(c['cleaner']['nama']);
        }
      }
    }
    
    int amount = 0;
    if (json['pembayaran'] != null) {
      amount = json['pembayaran']['total_akhir'] ?? json['pembayaran']['total_tagihan'] ?? 0;
    } else {
      amount = json['subtotal'] != null ? int.tryParse(json['subtotal'].toString()) ?? 0 : 0;
    }

    return CustomerOrder(
      id: json['id']?.toString() ?? '',
      service: serviceName,
      date: json['tanggal_input'] ?? '',
      cleaners: cleanerNames,
      amount: amount,
      status: _parseStatus(json['status_pesanan']),
    );
  }

  static OrderStatus _parseStatus(String? status) {
    switch(status) {
      case 'draft': return OrderStatus.draft;
      case 'assigned': return OrderStatus.assigned;
      case 'in_progress': return OrderStatus.inProgress;
      case 'completed': return OrderStatus.completed;
      case 'finished': return OrderStatus.completed;
      case 'cancelled': return OrderStatus.cancelled;
      default: return OrderStatus.draft;
    }
  }
}
