import 'customer_model.dart';
import 'order_model.dart';

/// Mock data — sama persis dengan data di web frontend KlinKlin

final List<CustomerModel> mockCustomers = [
  CustomerModel(
    id: 'CUS-001', name: 'Budi Santoso', phone: '0812-3456-7890',
    address: 'Jl. Raya Darmo No. 45, Wonokromo, Surabaya 60241',
    status: 'aktif', totalOrders: 34, totalSpending: 18750000,
    lastOrderDate: '5 Jun 2026',
    notes: 'Pelanggan setia sejak 2021. Selalu request cleaner Ani Rahayu.',
    orders: [
      CustomerOrder(id: 'ORD-2345', service: 'Deep Cleaning 4BR', date: '5 Jun 2026', cleaners: ['Ani Rahayu'], amount: 650000, status: OrderStatus.completed),
    ],
  ),
  CustomerModel(
    id: 'CUS-002', name: 'Sari Dewi', phone: '0857-9876-5432',
    address: 'Jl. Raya Gubeng No. 12, Surabaya 60281',
    status: 'aktif', totalOrders: 18, totalSpending: 9200000,
    lastOrderDate: '8 Jun 2026',
    notes: 'Suka layanan cepat. Punya 2 anjing.',
    orders: [],
  ),
  CustomerModel(
    id: 'CUS-004', name: 'Rina Wulandari', phone: '0813-5678-9012',
    address: 'Jl. Kenjeran No. 150, Surabaya 60129',
    status: 'aktif', totalOrders: 22, totalSpending: 11500000,
    lastOrderDate: '10 Jun 2026',
    notes: 'Allergik parfum. Minta produk unscented.',
    orders: [],
  ),
];

final List<OrderModel> mockOrders = [
  // 1. Pesanan Draft
  OrderModel(
    id: 'ORD-2356',
    customer: OrderCustomer(id: 'CUS-001', name: 'Budi Santoso', phone: '0812-3456-7890',
      address: 'Jl. Raya Darmo No. 45, Wonokromo, Surabaya 60241', area: 'Wonokromo, Surabaya'),
    chatDari: ChatSource.organik,
    tipeCustomer: CustomerType.lama,
    services: [
      ServiceItem(
        name: 'Deep Cleaning 3BR', price: 550000, qty: '1', 
        tanggalPengerjaan: '2026-06-11', waktuPengerjaan: '09:00',
        bonusLayanan: 15000,
      )
    ],
    cleaners: [],
    status: OrderStatus.draft,
    total: 550000,
    paymentMethod: '-',
    paymentStatus: 'unpaid',
    notes: 'Pesanan baru, belum ada cleaner.',
    tanggalInput: DateTime(2026, 6, 10),
  ),

  // 2. Pesanan Assigned (dengan bonus)
  OrderModel(
    id: 'ORD-2355',
    customer: OrderCustomer(id: 'CUS-004', name: 'Rina Wulandari', phone: '0813-5678-9012',
      address: 'Jl. Kenjeran No. 150, Surabaya 60129', area: 'Kenjeran, Surabaya'),
    chatDari: ChatSource.ads,
    tipeCustomer: CustomerType.baru,
    services: [
      ServiceItem(
        name: 'Deep Cleaning 3BR', price: 550000, qty: '1', 
        tanggalPengerjaan: '2026-06-11', waktuPengerjaan: '09:00',
        bonusLayanan: 15000,
      )
    ],
    cleaners: [
      OrderCleaner(
        id: 'CLN-001', name: 'Ani Rahayu', rating: 4.9,
        statusPengerjaan: CleanerWorkStatus.assigned,
        totalBonus: 25000,
        bonuses: [
          CleanerBonus(id: 'B1', jenisBonus: 'Bonus Layanan', nominal: 15000, keterangan: 'Bonus default dari cabang'),
          CleanerBonus(id: 'B2', jenisBonus: 'Bonus Area Jauh', nominal: 10000, keterangan: 'Bonus tambahan jarak jauh'),
        ]
      )
    ],
    status: OrderStatus.assigned,
    total: 550000,
    paymentMethod: '-',
    paymentStatus: 'unpaid',
    notes: 'Minta produk unscented, ada anjing kecil.',
    tanggalInput: DateTime(2026, 6, 10),
  ),

  // 3. Pesanan Finished by Cleaner (siap lanjut pembayaran)
  OrderModel(
    id: 'ORD-2354',
    customer: OrderCustomer(id: 'CUS-002', name: 'Sari Dewi', phone: '0857-9876-5432',
      address: 'Jl. Raya Gubeng No. 12, Surabaya 60281', area: 'Gubeng, Surabaya'),
    chatDari: ChatSource.organik,
    tipeCustomer: CustomerType.lama,
    services: [
      ServiceItem(
        name: 'Regular Cleaning', price: 280000, qty: '1',
        tanggalPengerjaan: '2026-06-11', waktuPengerjaan: '13:00',
        bonusLayanan: 10000,
      ),
    ],
    cleaners: [
      OrderCleaner(
        id: 'CLN-002', name: 'Dewi Safitri', rating: 4.8,
        statusPengerjaan: CleanerWorkStatus.finished,
        totalBonus: 10000,
        bonuses: [
          CleanerBonus(id: 'B3', jenisBonus: 'Bonus Layanan', nominal: 10000, keterangan: 'Bonus default dari cabang'),
        ]
      )
    ],
    status: OrderStatus.finishedByCleaner,
    total: 280000,
    paymentMethod: '-',
    paymentStatus: 'unpaid',
    notes: '',
    tanggalInput: DateTime(2026, 6, 10),
  ),
];

const List<Map<String, dynamic>> mockServices = [
  {'name': 'Regular Cleaning', 'price': 280000, 'unit': 'per sesi', 'icon': '🧹'},
  {'name': 'Deep Cleaning 2BR', 'price': 420000, 'unit': 'per sesi', 'icon': '✨'},
  {'name': 'Deep Cleaning 3BR', 'price': 550000, 'unit': 'per sesi', 'icon': '✨'},
  {'name': 'AC Cleaning 1 unit', 'price': 200000, 'unit': 'per unit', 'icon': '❄️'},
];

const List<Map<String, dynamic>> mockCleaners = [
  {'id': 'CLN-001', 'name': 'Ani Rahayu', 'rating': 4.9, 'orders': 156, 'status': 'available'},
  {'id': 'CLN-002', 'name': 'Dewi Safitri', 'rating': 4.8, 'orders': 142, 'status': 'available'},
  {'id': 'CLN-003', 'name': 'Rina Wati', 'rating': 4.7, 'orders': 98, 'status': 'busy'},
];

// Dashboard stats
const Map<String, dynamic> mockDashboardStats = {
  'ordersToday': 56,
  'waiting': 12,
  'inProgress': 18,
  'doneToday': 26,
  'omzetToday': 8750000,
  'targetHarian': 10000000,
  'omzetChange': 12.4,
};
