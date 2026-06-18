enum OrderStatus {
  draft,
  assigned,
  inProgress,
  finishedByCleaner,
  waitingPaymentApproval,
  waitingCancelApproval,
  completed,
  cancelled
}

enum CleanerWorkStatus {
  assigned,
  notified,
  inProgress,
  finished
}

enum ChatSource { organik, ads, lama }
enum CustomerType { lama, baru }

OrderStatus _parseOrderStatus(String? val) {
  switch (val) {
    case 'draft': return OrderStatus.draft;
    case 'assigned': return OrderStatus.assigned;
    case 'in_progress': return OrderStatus.inProgress;
    case 'finished_by_cleaner': return OrderStatus.finishedByCleaner;
    case 'waiting_payment_approval': return OrderStatus.waitingPaymentApproval;
    case 'waiting_cancel_approval': return OrderStatus.waitingCancelApproval;
    case 'completed': return OrderStatus.completed;
    case 'cancelled': return OrderStatus.cancelled;
    default: return OrderStatus.draft;
  }
}

String _orderStatusToString(OrderStatus status) {
  switch (status) {
    case OrderStatus.draft: return 'draft';
    case OrderStatus.assigned: return 'assigned';
    case OrderStatus.inProgress: return 'in_progress';
    case OrderStatus.finishedByCleaner: return 'finished_by_cleaner';
    case OrderStatus.waitingPaymentApproval: return 'waiting_payment_approval';
    case OrderStatus.waitingCancelApproval: return 'waiting_cancel_approval';
    case OrderStatus.completed: return 'completed';
    case OrderStatus.cancelled: return 'cancelled';
  }
}

CleanerWorkStatus _parseCleanerWorkStatus(String? val) {
  switch (val) {
    case 'assigned': return CleanerWorkStatus.assigned;
    case 'notified': return CleanerWorkStatus.notified;
    case 'in_progress': return CleanerWorkStatus.inProgress;
    case 'finished': return CleanerWorkStatus.finished;
    default: return CleanerWorkStatus.assigned;
  }
}

ChatSource _parseChatSource(String? val) {
  switch (val) {
    case 'organik': return ChatSource.organik;
    case 'ads': return ChatSource.ads;
    case 'lama': return ChatSource.lama;
    default: return ChatSource.organik;
  }
}

CustomerType _parseCustomerType(String? val) {
  switch (val) {
    case 'lama': return CustomerType.lama;
    case 'baru': return CustomerType.baru;
    default: return CustomerType.baru;
  }
}

class ServiceItem {
  ServiceItem({
    this.id = '',
    this.layananId,
    required this.name,
    required this.price,
    required this.qty,
    this.tanggalPengerjaan = '',
    this.waktuPengerjaan = '',
    this.bonusLayanan = 0,
  });

  String id;
  String? layananId;
  String name;
  int price;
  String qty;
  String tanggalPengerjaan;
  String waktuPengerjaan;
  int bonusLayanan;
  int get subtotal => price; // Harga is now the total for this item

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    final layanan = json['layanan'] ?? {};
    return ServiceItem(
      id: json['id']?.toString() ?? '',
      layananId: json['layanan_id']?.toString() ?? layanan['id']?.toString(),
      name: layanan['nama_layanan'] ?? json['nama_layanan'] ?? '-',
      price: (json['harga'] ?? layanan['harga'] ?? json['subtotal']) != null 
          ? (double.tryParse((json['harga'] ?? layanan['harga'] ?? json['subtotal']).toString())?.toInt() ?? 0)
          : 0,
      qty: json['qty']?.toString() ?? '1',
      tanggalPengerjaan: json['tanggal_pengerjaan'] ?? '',
      waktuPengerjaan: json['waktu_pengerjaan'] ?? '',
      bonusLayanan: json['bonus_layanan'] != null ? (double.tryParse(json['bonus_layanan'].toString())?.toInt() ?? 0) : 0,
    );
  }

  Map<String, dynamic> toJson() {
    String fDate = tanggalPengerjaan;
    final dParts = fDate.split(' ');
    if (dParts.length >= 4) {
      final day = dParts[1].padLeft(2, '0');
      final mStr = dParts[2].toLowerCase();
      int m = 6;
      if (mStr.contains('jan')) m = 1;
      else if (mStr.contains('feb')) m = 2;
      else if (mStr.contains('mar')) m = 3;
      else if (mStr.contains('apr')) m = 4;
      else if (mStr.contains('mei') || mStr.contains('may')) m = 5;
      else if (mStr.contains('jun')) m = 6;
      else if (mStr.contains('jul')) m = 7;
      else if (mStr.contains('agu') || mStr.contains('aug')) m = 8;
      else if (mStr.contains('sep')) m = 9;
      else if (mStr.contains('okt') || mStr.contains('oct')) m = 10;
      else if (mStr.contains('nov')) m = 11;
      else if (mStr.contains('des') || mStr.contains('dec')) m = 12;
      fDate = '${dParts[3]}-${m.toString().padLeft(2, '0')}-$day';
    }

    String fTime = waktuPengerjaan;
    if (fTime.contains(' - ')) {
      fTime = fTime.split(' - ')[0];
    }
    // Ensure format is HH:mm by splitting and taking first 2 parts
    if (fTime.contains(':')) {
      final tParts = fTime.split(':');
      if (tParts.length >= 2) {
        fTime = '${tParts[0].padLeft(2, '0')}:${tParts[1].padLeft(2, '0')}';
      }
    }

    return {
      'layanan_id': int.tryParse(layananId?.replaceAll(RegExp(r'[^0-9]'), '') ?? id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1, // Usually needed for API
      'qty': qty,
      'harga': price,
      'tanggal_pengerjaan': fDate.isEmpty ? null : fDate,
      'waktu_pengerjaan': fTime.isEmpty ? null : fTime,
      'bonus_layanan': bonusLayanan,
    };
  }
}

class CleanerBonus {
  CleanerBonus({
    required this.id,
    required this.jenisBonus,
    required this.nominal,
    required this.keterangan,
  });

  String id;
  String jenisBonus;
  int nominal;
  String keterangan;

  factory CleanerBonus.fromJson(Map<String, dynamic> json) {
    final jenis = json['jenis_bonus'] ?? {};
    return CleanerBonus(
      id: json['id']?.toString() ?? '',
      jenisBonus: jenis['nama_bonus'] ?? json['jenis_bonus'] ?? '-',
      nominal: json['nominal'] != null ? (double.tryParse(json['nominal'].toString())?.toInt() ?? 0) : 0,
      keterangan: json['keterangan'] ?? '-',
    );
  }
}

class OrderCustomer {
  OrderCustomer({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.area,
  });

  String id;
  String name;
  String phone;
  String address;
  String area;

  factory OrderCustomer.fromJson(Map<String, dynamic> json) {
    final cabang = json['cabang'] ?? {};
    return OrderCustomer(
      id: json['id']?.toString() ?? '',
      name: json['nama_pelanggan'] ?? '-',
      phone: json['no_wa'] ?? '-',
      address: json['alamat'] ?? '-',
      area: cabang['nama_cabang'] ?? 'Cabang',
    );
  }
}

class OrderCleaner {
  OrderCleaner({
    required this.id,
    required this.name,
    required this.rating,
    this.statusPengerjaan = CleanerWorkStatus.assigned,
    this.bonuses = const [],
    this.totalBonus = 0,
  });

  String id;
  String name;
  double rating;
  CleanerWorkStatus statusPengerjaan;
  List<CleanerBonus> bonuses;
  int totalBonus;

  factory OrderCleaner.fromJson(Map<String, dynamic> json) {
    final cleaner = json['cleaner'] ?? {};
    final bonusesData = json['bonuses'] as List? ?? [];
    final List<CleanerBonus> parsedBonuses = (bonusesData as List).map<CleanerBonus>((e) => CleanerBonus.fromJson(e)).toList();
    final int totalB = parsedBonuses.fold(0, (sum, b) => sum + b.nominal);

    return OrderCleaner(
      id: cleaner['id']?.toString() ?? json['id']?.toString() ?? '',
      name: cleaner['nama'] ?? '-',
      rating: cleaner['rating'] != null ? double.tryParse(cleaner['rating'].toString()) ?? 0.0 : 0.0,
      statusPengerjaan: _parseCleanerWorkStatus(json['status_pengerjaan']),
      bonuses: parsedBonuses,
      totalBonus: totalB,
    );
  }
}

class OrderModel {
  OrderModel({
    required this.id,
    required this.customer,
    this.chatDari = ChatSource.organik,
    this.tipeCustomer = CustomerType.baru,
    required this.services,
    required this.cleaners,
    required this.status,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.notes,
    required this.tanggalInput,
    this.cancelReason,
    this.paymentProof,
  });

  String id;
  OrderCustomer customer;
  ChatSource chatDari;
  CustomerType tipeCustomer;
  List<ServiceItem> services;
  List<OrderCleaner> cleaners;
  OrderStatus status;
  int total;
  String paymentMethod;
  String paymentStatus; // unpaid | paid | cancelled
  String notes;
  DateTime tanggalInput;
  String? cancelReason;
  String? paymentProof;

  String get schedule {
    if (services.isEmpty) return "-";
    return '${services.first.tanggalPengerjaan} · ${services.first.waktuPengerjaan}';
  }

  DateTime get scheduleDateTime {
    if (services.isEmpty || services.first.tanggalPengerjaan.isEmpty) {
      return tanggalInput; // Fallback to input date if no service date is set
    }
    try {
      return DateTime.parse(services.first.tanggalPengerjaan);
    } catch (e) {
      return tanggalInput;
    }
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final customerData = json['pelanggan'] ?? {};
    final detailsData = json['details'] as List? ?? [];
    final cleanersData = json['cleaners'] ?? json['pesanan_cleaners'] as List? ?? [];
    
    final List<ServiceItem> parsedServices = (detailsData as List).map<ServiceItem>((e) => ServiceItem.fromJson(e)).toList();
    final List<OrderCleaner> parsedCleaners = (cleanersData as List).map<OrderCleaner>((e) => OrderCleaner.fromJson(e)).toList();
    
    final int computedTotal = parsedServices.fold(0, (sum, s) => sum + s.subtotal);

    return OrderModel(
      id: json['id']?.toString() ?? '',
      customer: OrderCustomer.fromJson(customerData),
      chatDari: _parseChatSource(json['chat_dari']),
      tipeCustomer: _parseCustomerType(json['tipe_customer']),
      services: parsedServices,
      cleaners: parsedCleaners,
      status: _parseOrderStatus(json['status_pesanan']),
      total: json['subtotal'] != null ? (double.tryParse(json['subtotal'].toString())?.toInt() ?? computedTotal) : computedTotal,
      paymentMethod: json['pembayaran']?['metode_pembayaran'] ?? json['metode_pembayaran'] ?? '-',
      paymentStatus: json['pembayaran']?['status_pembayaran'] ?? json['status_pembayaran'] ?? 'unpaid',
      notes: json['keterangan_order'] ?? '',
      tanggalInput: json['tanggal_input'] != null ? DateTime.tryParse(json['tanggal_input']) ?? DateTime.now() : DateTime.now(),
      cancelReason: json['alasan_batal'],
      paymentProof: json['pembayaran']?['bukti_transfer'] ?? json['file_invoice'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pelanggan_id': customer.id,
      'chat_dari': chatDari.name,
      'tipe_customer': tipeCustomer.name,
      'keterangan_order': notes,
      'status_pesanan': _orderStatusToString(status),
      'details': services.map((e) => e.toJson()).toList(),
      // Cleaners assignment happens in a different endpoint usually, but we include if needed
    };
  }
}

/// Draft saat membuat pesanan baru (wizard)
class OrderDraft {
  OrderDraft({
    this.customer,
    this.chatDari = ChatSource.organik,
    this.tipeCustomer = CustomerType.baru,
    List<ServiceItem>? services,
    List<OrderCleaner>? cleaners,
    this.notes = '',
  }) : services = services ?? [],
       cleaners = cleaners ?? [];

  OrderCustomer? customer;
  ChatSource chatDari;
  CustomerType tipeCustomer;
  List<ServiceItem> services;
  List<OrderCleaner> cleaners;
  String notes;
  String? paymentMethod;

  int get total => services.fold(0, (sum, s) => sum + s.subtotal);

  Map<String, dynamic> toJson() {
    final cleanId = customer?.id.replaceAll(RegExp(r'[^0-9]'), '');
    return {
      'pelanggan_id': cleanId != null && cleanId.isNotEmpty ? int.parse(cleanId) : null,
      'chat_dari': chatDari.name,
      'tipe_customer': tipeCustomer.name,
      'keterangan_order': notes,
      'details': services.map((e) => e.toJson()).toList(),
      if (paymentMethod != null) 'metode_pembayaran': paymentMethod,
    };
  }
}
