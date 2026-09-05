import 'dart:convert';
import '../utils/timezone_helper.dart';

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

extension CleanerWorkStatusExt on CleanerWorkStatus {
  String get label {
    switch (this) {
      case CleanerWorkStatus.assigned:
        return 'Ditugaskan';
      case CleanerWorkStatus.notified:
        return 'Diberitahu';
      case CleanerWorkStatus.inProgress:
        return 'Sedang Dikerjakan';
      case CleanerWorkStatus.finished:
        return 'Selesai';
    }
  }
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
    case 'waiting_cancel_approval': return OrderStatus.cancelled;
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
    final rawPrice = json['subtotal'] ?? json['harga'] ?? layanan['harga'];
    return ServiceItem(
      id: json['id']?.toString() ?? '',
      layananId: json['layanan_id']?.toString() ?? layanan['id']?.toString(),
      name: layanan['nama_layanan'] ?? json['nama_layanan'] ?? '-',
      price: rawPrice != null 
          ? (double.tryParse(rawPrice.toString())?.toInt() ?? 0)
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
    String jb = '-';
    if (json['jenis_bonus'] is Map) {
      jb = json['jenis_bonus']['nama_bonus']?.toString() ?? '-';
    } else if (json['jenis_bonus'] is String) {
      jb = json['jenis_bonus'].toString();
    } else if (json['tarif_bonus_cabang'] is Map && json['tarif_bonus_cabang']['jenis_bonus'] != null) {
      if (json['tarif_bonus_cabang']['jenis_bonus'] is Map) {
        jb = json['tarif_bonus_cabang']['jenis_bonus']['nama_bonus']?.toString() ?? '-';
      }
    }

    if (jb == '-' || jb.isEmpty) {
      jb = 'Bonus Manual';
    }

    return CleanerBonus(
      id: json['id']?.toString() ?? '',
      jenisBonus: jb,
      nominal: json['nominal'] != null ? (double.tryParse(json['nominal'].toString())?.toInt() ?? 0) : 0,
      keterangan: json['keterangan']?.toString().isNotEmpty == true ? json['keterangan'].toString() : '-',
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
    this.notes = '',
  });

  String id;
  String name;
  String phone;
  String address;
  String area;
  String notes;

  factory OrderCustomer.fromJson(Map<dynamic, dynamic>? json, [Map<dynamic, dynamic>? rootJson]) {
    final cMap = json != null ? Map<String, dynamic>.from(json) : <String, dynamic>{};
    final rMap = rootJson != null ? Map<String, dynamic>.from(rootJson) : cMap;
    final cabang = rMap['cabang'] is Map ? Map<String, dynamic>.from(rMap['cabang']) : <String, dynamic>{};

    return OrderCustomer(
      id: cMap['id']?.toString() ?? '',
      name: cMap['nama_pelanggan']?.toString() ?? '-',
      phone: cMap['no_wa']?.toString() ?? '-',
      address: cMap['alamat']?.toString() ?? '-',
      area: cabang['nama_cabang']?.toString() ?? 'Cabang',
      notes: cMap['catatan']?.toString() ?? '',
    );
  }
}

class CleanerFoto {
  String id;
  String url;
  String path;
  String tipe;
  DateTime? createdAt;

  CleanerFoto({
    required this.id,
    required this.url,
    required this.path,
    required this.tipe,
    this.createdAt,
  });

  factory CleanerFoto.fromJson(Map<String, dynamic> json) {
    String rawPath = json['foto_path']?.toString() ?? json['foto_url']?.toString() ?? json['path']?.toString() ?? json['url']?.toString() ?? '';
    return CleanerFoto(
      id: json['id']?.toString() ?? '',
      url: json['foto_url']?.toString() ?? json['url']?.toString() ?? rawPath,
      path: rawPath,
      tipe: json['tipe']?.toString() ?? 'start',
      createdAt: TimezoneHelper.parseServerTimestamp(json['created_at']),
    );
  }
}

class OrderCleaner {
  OrderCleaner({
    required this.id,
    required this.pesananCleanerId,
    required this.name,
    required this.rating,
    this.statusPengerjaan = CleanerWorkStatus.assigned,
    this.bonuses = const [],
    this.totalBonus = 0,
    this.fotoProfil,
    this.showWa = false,
    this.phone = '',
    this.fotosStart = const [],
    this.fotosFinish = const [],
    this.startedAt,
    this.finishedAt,
  });

  String id;
  String pesananCleanerId;
  String name;
  double rating;
  CleanerWorkStatus statusPengerjaan;
  List<CleanerBonus> bonuses;
  int totalBonus;
  String? fotoProfil;
  bool showWa;
  String phone;
  List<CleanerFoto> fotosStart;
  List<CleanerFoto> fotosFinish;
  DateTime? startedAt;
  DateTime? finishedAt;

  factory OrderCleaner.fromJson(Map<String, dynamic> json) {
    final cleaner = json['cleaner'] is Map ? Map<String, dynamic>.from(json['cleaner']) : <String, dynamic>{};
    final bonusesData = json['bonuses'] is List ? json['bonuses'] as List : [];
    final List<CleanerBonus> parsedBonuses = [];
    for (final b in bonusesData) {
      if (b is Map) {
        try {
          parsedBonuses.add(CleanerBonus.fromJson(Map<String, dynamic>.from(b)));
        } catch (_) {}
      }
    }
    final int totalB = parsedBonuses.fold(0, (sum, b) => sum + b.nominal);

    var fotosStartData = json['fotos_start'] is List ? json['fotos_start'] as List : [];
    var fotosFinishData = json['fotos_finish'] is List ? json['fotos_finish'] as List : [];
    if (fotosStartData.isEmpty && fotosFinishData.isEmpty && json['fotos'] is List) {
      final allFotos = json['fotos'] as List;
      fotosStartData = allFotos.where((f) => f is Map && (f['tipe'] == 'start' || f['tipe'] == 'sebelum')).toList();
      fotosFinishData = allFotos.where((f) => f is Map && (f['tipe'] == 'finish' || f['tipe'] == 'sesudah')).toList();
    }

    final List<CleanerFoto> pFotosStart = [];
    for (final f in fotosStartData) {
      if (f is Map) {
        try {
          pFotosStart.add(CleanerFoto.fromJson(Map<String, dynamic>.from(f)));
        } catch (_) {}
      }
    }

    final List<CleanerFoto> pFotosFinish = [];
    for (final f in fotosFinishData) {
      if (f is Map) {
        try {
          pFotosFinish.add(CleanerFoto.fromJson(Map<String, dynamic>.from(f)));
        } catch (_) {}
      }
    }

    return OrderCleaner(
      id: cleaner['id']?.toString() ?? json['id']?.toString() ?? '',
      pesananCleanerId: json['id']?.toString() ?? '',
      name: cleaner['nama']?.toString() ?? '-',
      rating: cleaner['rating'] != null ? double.tryParse(cleaner['rating'].toString()) ?? 0.0 : 0.0,
      statusPengerjaan: _parseCleanerWorkStatus(json['status_pengerjaan']?.toString()),
      bonuses: parsedBonuses,
      totalBonus: totalB,
      fotoProfil: cleaner['foto_profil'] ?? cleaner['foto'] ?? cleaner['foto_url'] ?? cleaner['foto_profil_url'] ?? cleaner['profile_photo_url'] ?? (cleaner['user'] != null && cleaner['user'] is Map ? (cleaner['user']['foto_profil'] ?? cleaner['user']['foto_url'] ?? cleaner['user']['foto'] ?? cleaner['user']['profile_photo_url']) : null),
      showWa: json['show_wa'] == true || json['show_wa'] == 1 || json['show_wa'] == '1',
      phone: cleaner['no_wa']?.toString() ?? cleaner['no_hp']?.toString() ?? cleaner['phone']?.toString() ?? '',
      fotosStart: pFotosStart,
      fotosFinish: pFotosFinish,
      startedAt: TimezoneHelper.parseServerTimestamp(json['started_at']),
      finishedAt: TimezoneHelper.parseServerTimestamp(json['finished_at']),
    );
  }
}

class OrderPayment {
  OrderPayment({
    required this.id,
    required this.metodePembayaran,
    required this.statusPembayaran,
    this.buktiTransfer,
    this.catatanPembayaran,
    this.total,
    this.ppn,
    this.pph,
    this.diskonPersen,
    this.totalSetelahDiskon,
    this.approvedAt,
  });

  int id;
  String metodePembayaran;
  String statusPembayaran;
  String? buktiTransfer;
  String? catatanPembayaran;
  int? total;
  int? ppn;
  int? pph;
  double? diskonPersen;
  int? totalSetelahDiskon;
  DateTime? approvedAt;

  factory OrderPayment.fromJson(Map<String, dynamic> json) {
    return OrderPayment(
      id: json['id'] != null ? int.parse(json['id'].toString()) : 0,
      metodePembayaran: json['metode_pembayaran'] ?? '-',
      statusPembayaran: json['status_pembayaran'] ?? 'unpaid',
      buktiTransfer: () {
        final raw = json['bukti_transfer'];
        if (raw == null) return null;
        if (raw is List) {
          return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join(',');
        }
        return raw.toString();
      }(),
      catatanPembayaran: json['catatan_pembayaran'],
      total: json['total_akhir'] != null ? (double.tryParse(json['total_akhir'].toString())?.toInt()) : (json['total'] != null ? (double.tryParse(json['total'].toString())?.toInt()) : null),
      ppn: json['ppn'] != null ? (double.tryParse(json['ppn'].toString())?.toInt()) : null,
      pph: json['pph'] != null ? (double.tryParse(json['pph'].toString())?.toInt()) : null,
      diskonPersen: json['diskon_persen'] != null ? double.tryParse(json['diskon_persen'].toString()) : 0.0,
      totalSetelahDiskon: json['total_setelah_diskon'] != null ? (double.tryParse(json['total_setelah_diskon'].toString())?.toInt()) : null,
      approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at'].toString()) : null,
    );
  }
}

class OrderModel {
  OrderModel({
    required this.id,
    this.nomorPesanan = '',
    required this.cabangId,
    this.cabangNama = '',
    required this.customer,
    this.chatDari = ChatSource.organik,
    this.tipeCustomer = CustomerType.baru,
    required this.services,
    required this.cleaners,
    required this.status,
    required this.total,
    required this.subtotal,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.notes,
    required this.tanggalInput,
    this.cancelReason,
    this.cancelProof,
    this.paymentProof,
    this.pembayaran,
    this.pembatalanId,
    this.waktuBatal,
    this.ppn,
    this.pph,
    this.discount = 0,
    this.hasPendingEditRequest = false,
    this.alasanPengajuanEdit = '',
    this.createdByName = '',
    this.pengajuanEditId,
    this.waktuPengajuanEdit,
    this.statusPengerjaan = 'Ditugaskan',
    this.statusBonus = 'Pending',
    this.statusUtamaRaw,
    this.isWajibPpn = false,
  });

  String id;
  String nomorPesanan;
  String cabangId;
  String cabangNama;
  OrderCustomer customer;
  ChatSource chatDari;
  CustomerType tipeCustomer;
  List<ServiceItem> services;
  List<OrderCleaner> cleaners;
  OrderStatus status;
  int total;
  int subtotal;
  String paymentMethod;
  String paymentStatus; // unpaid | paid | cancelled
  String notes;
  DateTime tanggalInput;
  String? cancelReason;
  String? cancelProof;
  String? paymentProof;
  OrderPayment? pembayaran;
  int? pembatalanId;
  DateTime? waktuBatal;
  int? ppn;
  int? pph;
  int? discount;
  bool hasPendingEditRequest;
  String alasanPengajuanEdit;
  String createdByName;
  int? pengajuanEditId;
  DateTime? waktuPengajuanEdit;
  String statusPengerjaan;
  String statusBonus;
  String? statusUtamaRaw;
  bool isWajibPpn;

  String get statusPengerjaanLabel {
    if (status == OrderStatus.cancelled || status == OrderStatus.waitingCancelApproval || pembatalanId != null) return 'Dibatalkan';
    if (status == OrderStatus.draft) return 'Draft';
    if (status == OrderStatus.completed) return 'Selesai';
    if (status == OrderStatus.finishedByCleaner) return 'Selesai Cleaner';
    return statusPengerjaan.isNotEmpty ? statusPengerjaan : 'Ditugaskan';
  }

  String get statusPembayaranLabel {
    final p = paymentStatus.toLowerCase();
    final pSub = pembayaran?.statusPembayaran.toLowerCase() ?? '';
    if (status == OrderStatus.cancelled || status == OrderStatus.waitingCancelApproval || pembatalanId != null || p == 'cancelled') return 'Dibatalkan';
    if (p == 'approved' || p == 'paid' || p == 'lunas' || pSub == 'approved') return 'Disetujui';
    if (p == 'pending' || pSub == 'pending' || status == OrderStatus.waitingPaymentApproval) return 'Pending';
    if (p == 'rejected' || pSub == 'rejected') return 'Ditolak';
    return 'Belum Dibayar';
  }

  String get statusBonusLabel {
    if (status == OrderStatus.cancelled || status == OrderStatus.waitingCancelApproval || pembatalanId != null) return 'Dibatalkan';
    if (statusBonus.toLowerCase() == 'selesai') return 'Selesai';
    if (statusBonus.toLowerCase() == 'approved' || statusBonus.toLowerCase() == 'disetujui') return 'Disetujui';
    return 'Pending';
  }

  String get statusUtamaLabel {
    if (status == OrderStatus.cancelled || 
        status == OrderStatus.waitingCancelApproval || 
        paymentStatus.toLowerCase() == 'cancelled' ||
        pembatalanId != null ||
        (cancelReason != null && cancelReason!.trim().isNotEmpty)) {
      return 'Dibatalkan';
    }

    if (statusUtamaRaw != null && statusUtamaRaw!.isNotEmpty) {
      final s = statusUtamaRaw!.toLowerCase();
      if (s == 'done') return 'Done';
      if (s == 'process') return 'Process';
      if (s == 'pending') return 'Pending';
      if (s == 'cancelled') return 'Dibatalkan';
      if (s == 'draft') return 'Draft';
    }

    if (status == OrderStatus.draft) return 'Draft';
    if (status == OrderStatus.completed && statusBonus.toLowerCase() == 'selesai') return 'Done';
    if (status == OrderStatus.finishedByCleaner || 
        status == OrderStatus.waitingPaymentApproval || 
        (status == OrderStatus.completed && statusBonus.toLowerCase() != 'selesai')) {
      return 'Pending';
    }
    return 'Process';
  }

  String get rawStatus => _orderStatusToString(status);

  String get branch => customer.area;

  double get diskonPersen => (discount ?? (pembayaran?.diskonPersen?.toInt() ?? 0)).toDouble();
  int get diskonAmount => ((subtotal * diskonPersen) / 100).round();
  int get totalSetelahDiskon => (subtotal - diskonAmount) > 0 ? (subtotal - diskonAmount) : 0;

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

  DateTime get scheduleFullDateTime {
    final dt = scheduleDateTime;
    if (services.isEmpty || services.first.waktuPengerjaan.isEmpty) {
      return dt;
    }
    final wkt = services.first.waktuPengerjaan;
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(wkt);
    if (match != null) {
      final h = int.tryParse(match.group(1)!) ?? 0;
      final m = int.tryParse(match.group(2)!) ?? 0;
      return DateTime(dt.year, dt.month, dt.day, h, m);
    }
    return dt;
  }

  bool get hasUploadedTransferProof {
    final proof = paymentProof ?? pembayaran?.buktiTransfer;
    return proof != null && proof.trim().isNotEmpty && proof.trim() != 'null';
  }

  List<String> get proofUrls {
    final proof = paymentProof ?? pembayaran?.buktiTransfer;
    if (proof == null || proof.trim().isEmpty || proof.trim() == 'null') return [];
    final trimmed = proof.trim();
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded.map((p) => p.toString().trim()).where((p) => p.isNotEmpty).toList();
        }
      } catch (_) {}
    }
    if (trimmed.contains(',')) {
      return trimmed.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    }
    return [trimmed];
  }

  bool get isPaymentApproved {
    final p = paymentStatus.toLowerCase();
    final pSub = pembayaran?.statusPembayaran.toLowerCase() ?? '';
    return p == 'approved' || p == 'paid' || p == 'lunas' || pSub == 'approved';
  }

  bool get needsTransferProofUpload {
    if (status == OrderStatus.cancelled || paymentStatus.toLowerCase() == 'cancelled') return false;
    if (isPaymentApproved) return false;
    return !hasUploadedTransferProof;
  }

  int get netTotal {
    if (pembayaran?.total != null && pembayaran!.total! > 0) {
      return pembayaran!.total!;
    }
    if (pembayaran?.totalSetelahDiskon != null && pembayaran!.totalSetelahDiskon! > 0) {
      return pembayaran!.totalSetelahDiskon!;
    }
    return total;
  }

  String get statusPesananRaw => _orderStatusToString(status);

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final orderJson = (json['pesanan'] != null && json['pesanan'] is Map)
        ? json['pesanan'] as Map<String, dynamic>
        : json;
    final customerData = orderJson['pelanggan'];
    final detailsData = orderJson['details'];
    final cleanersData = orderJson['cleaners'] ?? orderJson['pesanan_cleaners'];
    
    final List<ServiceItem> parsedServices = [];
    if (detailsData is List) {
      for (final d in detailsData) {
        if (d is Map) {
          try {
            parsedServices.add(ServiceItem.fromJson(Map<String, dynamic>.from(d)));
          } catch (_) {}
        }
      }
    }

    final List<OrderCleaner> parsedCleaners = [];
    if (cleanersData is List) {
      for (final c in cleanersData) {
        if (c is Map) {
          try {
            parsedCleaners.add(OrderCleaner.fromJson(Map<String, dynamic>.from(c)));
          } catch (_) {}
        }
      }
    }
    
    final int computedTotal = parsedServices.fold(0, (sum, s) => sum + s.subtotal);

    final pendingEdits = orderJson['pending_edit_layanans'] as List? ?? [];
    bool hasPendingEdit = pendingEdits.isNotEmpty;
    String alasanEdit = '';
    String createdByName = '';
    int? pEditId;
    DateTime? wEdit;
    
    if (hasPendingEdit) {
      alasanEdit = pendingEdits.first['keterangan']?.toString() ?? '';
      createdByName = pendingEdits.first['cs']?['nama']?.toString() ?? pendingEdits.first['cs']?['nama_karyawan']?.toString() ?? 'CS';
      pEditId = int.tryParse(pendingEdits.first['id']?.toString() ?? '');
      if (pendingEdits.first['created_at'] != null) {
        wEdit = DateTime.tryParse(pendingEdits.first['created_at'].toString());
      }
    }

    int parseTotal() {
      final p = json['pembayaran'] != null && json['pembayaran'] is Map ? json['pembayaran'] : (json['pesanan'] != null ? json : null);
      if (p != null) {
        if (p['total_akhir'] != null) {
          final v = double.tryParse(p['total_akhir'].toString())?.toInt();
          if (v != null && v > 0) return v;
        }
        if (p['total_setelah_diskon'] != null) {
          final v = double.tryParse(p['total_setelah_diskon'].toString())?.toInt();
          if (v != null && v > 0) return v;
        }
        if (p['total'] != null) {
          final v = double.tryParse(p['total'].toString())?.toInt();
          if (v != null && v > 0) return v;
        }
      }
      if (orderJson['total_akhir'] != null) {
        final v = double.tryParse(orderJson['total_akhir'].toString())?.toInt();
        if (v != null && v > 0) return v;
      }
      if (orderJson['total_setelah_diskon'] != null) {
        final v = double.tryParse(orderJson['total_setelah_diskon'].toString())?.toInt();
        if (v != null && v > 0) return v;
      }
      if (orderJson['total'] != null) {
        final v = double.tryParse(orderJson['total'].toString())?.toInt();
        if (v != null && v > 0) return v;
      }
      if (orderJson['subtotal'] != null) {
        final v = double.tryParse(orderJson['subtotal'].toString())?.toInt();
        if (v != null && v > 0) return v;
      }
      return computedTotal;
    }

    final rawPayment = orderJson['pembayaran'] ?? json['pembayaran'];
    final paymentObj = rawPayment != null && rawPayment is Map
        ? OrderPayment.fromJson(Map<String, dynamic>.from(rawPayment))
        : (json['status_pembayaran'] != null ? OrderPayment.fromJson(json) : null);

    final cabangData = orderJson['cabang'] ?? json['cabang'];
    bool wajibPpn = false;
    if (cabangData is Map) {
      wajibPpn = cabangData['is_ppn_enabled'] == true ||
                 cabangData['is_ppn_enabled'] == 1 ||
                 cabangData['is_ppn_enabled']?.toString() == '1' ||
                 cabangData['is_ppn_enabled']?.toString().toLowerCase() == 'true';
    }

    final rawStatusPesanan = (orderJson['status_pesanan'] ?? json['status_pesanan'] ?? '').toString();
    final hasPembatalan = orderJson['pembatalan'] != null || json['pembatalan'] != null || orderJson['pembatalan_id'] != null || json['pembatalan_id'] != null || (orderJson['alasan_cancel'] != null && orderJson['alasan_cancel'].toString().isNotEmpty) || (json['alasan_cancel'] != null && json['alasan_cancel'].toString().isNotEmpty);
    final isOrderCancelled = rawStatusPesanan == 'cancelled' || rawStatusPesanan == 'waiting_cancel_approval' || (hasPembatalan && rawStatusPesanan != 'completed');

    OrderStatus finalStatus = _parseOrderStatus(rawStatusPesanan);
    final parsedPaymentProof = () {
      final raw = orderJson['pembayaran']?['bukti_transfer'] ?? 
                  orderJson['pembayaran']?['bukti_pembayaran'] ?? 
                  orderJson['file_invoice'] ?? 
                  json['bukti_transfer'] ?? 
                  json['bukti_pembayaran'];
      if (raw == null) return null;
      if (raw is List) {
        return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join(',');
      }
      final s = raw.toString().trim();
      if (s.startsWith('[') && s.endsWith(']')) {
        try {
          final decoded = jsonDecode(s);
          if (decoded is List) {
            return decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join(',');
          }
        } catch (_) {}
      }
      return s;
    }();

    String parsedPaymentStatus = isOrderCancelled ? 'cancelled' : (orderJson['pembayaran']?['status_pembayaran'] ?? orderJson['status_pembayaran'] ?? json['status_pembayaran'] ?? 'unpaid').toString();
    final bool hasValidProof = parsedPaymentProof != null && 
        parsedPaymentProof.trim().isNotEmpty && 
        parsedPaymentProof != '-' && 
        parsedPaymentProof != '[]' && 
        parsedPaymentProof != '""';
    // Jangan timpa status pending jika record pembayaran memang ada di database (misal tunai/cash atau bukti array)
    if (parsedPaymentStatus.toLowerCase() == 'pending' && !hasValidProof && rawPayment == null) {
      parsedPaymentStatus = 'unpaid';
    }

    return OrderModel(
      id: orderJson['id']?.toString() ?? json['pesanan_id']?.toString() ?? json['id']?.toString() ?? '',
      nomorPesanan: orderJson['nomor_pesanan']?.toString() ?? orderJson['id']?.toString() ?? '',
      cabangId: orderJson['cabang_id']?.toString() ?? json['cabang_id']?.toString() ?? '',
      cabangNama: (cabangData is Map ? (cabangData['nama_cabang'] ?? cabangData['nama'])?.toString() : null) ?? orderJson['cabang_nama']?.toString() ?? json['cabang_nama']?.toString() ?? '',
      customer: OrderCustomer.fromJson(customerData, orderJson),
      chatDari: _parseChatSource(orderJson['chat_dari'] ?? json['chat_dari']),
      tipeCustomer: _parseCustomerType(orderJson['tipe_customer'] ?? json['tipe_customer']),
      services: parsedServices,
      cleaners: parsedCleaners,
      status: finalStatus,
      total: parseTotal(),
      subtotal: computedTotal,
      paymentMethod: (orderJson['pembayaran']?['metode_pembayaran'] ?? orderJson['metode_pembayaran'] ?? json['metode_pembayaran'] ?? '-').toString(),
      paymentStatus: parsedPaymentStatus,
      notes: (orderJson['keterangan_order'] ?? json['keterangan_order'] ?? '').toString(),
      tanggalInput: orderJson['tanggal_input'] != null ? (DateTime.tryParse(orderJson['tanggal_input'].toString()) ?? DateTime.now()) : (json['created_at'] != null ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()) : DateTime.now()),
      cancelReason: (orderJson['alasan_batal'] ?? orderJson['pembatalan']?['alasan_batal'] ?? orderJson['pembatalan']?['alasan_cancel'] ?? json['alasan_batal'] ?? json['alasan_cancel'] ?? json['alasan_penolakan'])?.toString(),
      cancelProof: () {
        final raw = orderJson['bukti_batal'] ?? orderJson['pembatalan']?['bukti_batal'] ?? orderJson['pembatalan']?['bukti_cancel'] ?? json['bukti_cancel'];
        if (raw == null) return null;
        if (raw is List) {
          return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join(',');
        }
        return raw.toString();
      }(),
      paymentProof: parsedPaymentProof,
      pembayaran: paymentObj,
      pembatalanId: orderJson['pembatalan']?['id'] ?? json['pembatalan_id'] ?? (json['alasan_cancel'] != null ? json['id'] : null),
      waktuBatal: orderJson['waktu_batal'] != null 
          ? DateTime.tryParse(orderJson['waktu_batal']) 
          : (orderJson['pembatalan']?['waktu_batal'] != null ? DateTime.tryParse(orderJson['pembatalan']['waktu_batal']) : (orderJson['pembatalan']?['created_at'] != null ? DateTime.tryParse(orderJson['pembatalan']['created_at']) : (json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null))),
      ppn: () {
        final raw = orderJson['pembayaran']?['ppn'] ?? orderJson['ppn'] ?? json['pembayaran']?['ppn'] ?? json['ppn'];
        if (raw != null) {
          return double.tryParse(raw.toString())?.toInt();
        }
        return wajibPpn ? 11 : null;
      }(),
      pph: orderJson['pembayaran']?['pph'] != null ? (double.tryParse(orderJson['pembayaran']['pph'].toString())?.toInt()) : (orderJson['pph'] != null ? (double.tryParse(orderJson['pph'].toString())?.toInt()) : (json['pembayaran']?['pph'] != null ? double.tryParse(json['pembayaran']['pph'].toString())?.toInt() : (json['pph'] != null ? double.tryParse(json['pph'].toString())?.toInt() : null))),
      discount: orderJson['diskon_persen'] != null ? (double.tryParse(orderJson['diskon_persen'].toString())?.toInt()) : (orderJson['pembayaran']?['diskon_persen'] != null ? (double.tryParse(orderJson['pembayaran']['diskon_persen'].toString())?.toInt()) : (json['diskon_persen'] != null ? double.tryParse(json['diskon_persen'].toString())?.toInt() : (json['pembayaran']?['diskon_persen'] != null ? double.tryParse(json['pembayaran']['diskon_persen'].toString())?.toInt() : 0))),
      hasPendingEditRequest: hasPendingEdit,
      alasanPengajuanEdit: alasanEdit,
      createdByName: createdByName,
      pengajuanEditId: pEditId,
      waktuPengajuanEdit: wEdit,
      statusBonus: orderJson['status_bonus']?.toString() ?? json['status_bonus']?.toString() ?? 'Pending',
      statusUtamaRaw: orderJson['status_order_utama']?.toString() ?? json['status_order_utama']?.toString(),
      isWajibPpn: wajibPpn,
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
    this.applyPpn = false,
    this.hasUserToggledPpn = false,
    this.applyPph = false,
    this.diskonPersen = 0.0,
    this.tanggalPengerjaan = '',
    this.waktuPengerjaan = '',
  }) : services = services ?? [],
       cleaners = cleaners ?? [];

  OrderCustomer? customer;
  ChatSource chatDari;
  CustomerType tipeCustomer;
  List<ServiceItem> services;
  List<OrderCleaner> cleaners;
  String notes;
  String? paymentMethod;
  bool applyPpn;
  bool hasUserToggledPpn;
  bool applyPph;
  double diskonPersen;
  String tanggalPengerjaan;
  String waktuPengerjaan;

  int get total => services.fold(0, (sum, s) => sum + s.subtotal);
  int get diskonAmount => ((total * diskonPersen) / 100).round();
  int get totalSetelahDiskon => (total - diskonAmount) > 0 ? (total - diskonAmount) : 0;
  int get ppnAmount => applyPpn ? (totalSetelahDiskon * 0.11).round() : 0;
  int get pphAmount => applyPph ? (totalSetelahDiskon * 0.02).round() : 0;
  int get totalAkhir => totalSetelahDiskon + ppnAmount - pphAmount;

  Map<String, dynamic> toJson() {
    final cleanId = customer?.id.replaceAll(RegExp(r'[^0-9]'), '');
    return {
      'pelanggan_id': cleanId != null && cleanId.isNotEmpty ? int.parse(cleanId) : null,
      'chat_dari': chatDari.name,
      'tipe_customer': tipeCustomer.name,
      'keterangan_order': notes,
      'details': services.map((e) {
         final detailJson = e.toJson();
         if (tanggalPengerjaan.isNotEmpty) detailJson['tanggal_pengerjaan'] = _formatDate(tanggalPengerjaan);
         if (waktuPengerjaan.isNotEmpty) detailJson['waktu_pengerjaan'] = _formatTime(waktuPengerjaan);
         return detailJson;
      }).toList(),
      if (paymentMethod != null) 'metode_pembayaran': paymentMethod,
      'ppn': applyPpn ? 11 : 0,
      'pph': applyPph ? 2 : 0,
      'diskon_persen': diskonPersen,
    };
  }

  String _formatDate(String fDate) {
    if (fDate.isEmpty) return '';
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
      return '${dParts[3]}-${m.toString().padLeft(2, '0')}-$day';
    }
    return fDate;
  }

  String _formatTime(String fTime) {
    if (fTime.isEmpty) return '';
    if (fTime.contains(' - ')) {
      fTime = fTime.split(' - ')[0];
    }
    if (fTime.contains(':')) {
      final tParts = fTime.split(':');
      if (tParts.length >= 2) {
        return '${tParts[0].padLeft(2, '0')}:${tParts[1].padLeft(2, '0')}';
      }
    }
    return fTime;
  }
}
