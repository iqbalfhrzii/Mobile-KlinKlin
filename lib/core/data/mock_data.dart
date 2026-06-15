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
      CustomerOrder(id: 'ORD-2345', service: 'Deep Cleaning 4BR', date: '5 Jun 2026', cleaners: ['Ani Rahayu'], amount: 650000, status: 'completed'),
      CustomerOrder(id: 'ORD-2201', service: 'Sofa Cleaning', date: '20 Mei 2026', cleaners: ['Ani Rahayu'], amount: 250000, status: 'completed'),
      CustomerOrder(id: 'ORD-2098', service: 'AC Cleaning 2 unit', date: '1 Mei 2026', cleaners: ['Dewi Safitri'], amount: 400000, status: 'completed'),
    ],
  ),
  CustomerModel(
    id: 'CUS-002', name: 'Sari Dewi', phone: '0857-9876-5432',
    address: 'Jl. Raya Gubeng No. 12, Surabaya 60281',
    status: 'aktif', totalOrders: 18, totalSpending: 9200000,
    lastOrderDate: '8 Jun 2026',
    notes: 'Suka layanan cepat. Punya 2 anjing.',
    orders: [
      CustomerOrder(id: 'ORD-2350', service: 'Regular Cleaning', date: '8 Jun 2026', cleaners: ['Dewi Safitri'], amount: 280000, status: 'in_progress'),
      CustomerOrder(id: 'ORD-2210', service: 'Karpet Cleaning', date: '22 Mei 2026', cleaners: ['Dewi Safitri'], amount: 350000, status: 'completed'),
    ],
  ),
  CustomerModel(
    id: 'CUS-003', name: 'Ahmad Fauzi', phone: '0821-1234-5678',
    address: 'Jl. Rungkut Industri No. 88, Surabaya 60293',
    status: 'non aktif', totalOrders: 7, totalSpending: 2800000,
    lastOrderDate: '28 Mei 2026',
    notes: '',
    orders: [
      CustomerOrder(id: 'ORD-2300', service: 'Regular Cleaning', date: '28 Mei 2026', cleaners: ['Rina Wati'], amount: 320000, status: 'completed'),
    ],
  ),
  CustomerModel(
    id: 'CUS-004', name: 'Rina Wulandari', phone: '0813-5678-9012',
    address: 'Jl. Kenjeran No. 150, Surabaya 60129',
    status: 'aktif', totalOrders: 22, totalSpending: 11500000,
    lastOrderDate: '10 Jun 2026',
    notes: 'Allergik parfum. Minta produk unscented.',
    orders: [
      CustomerOrder(id: 'ORD-2355', service: 'Deep Cleaning 3BR', date: '10 Jun 2026', cleaners: ['Ani Rahayu'], amount: 550000, status: 'assigned'),
    ],
  ),
  CustomerModel(
    id: 'CUS-005', name: 'Hendro Prasetyo', phone: '0878-2345-6789',
    address: 'Jl. Tandes Lor No. 23, Surabaya 60186',
    status: 'aktif', totalOrders: 3, totalSpending: 950000,
    lastOrderDate: '1 Jun 2026',
    notes: '',
    orders: [
      CustomerOrder(id: 'ORD-2280', service: 'AC Cleaning 1 unit', date: '1 Jun 2026', cleaners: ['Dewi Safitri'], amount: 200000, status: 'completed'),
    ],
  ),
];

final List<OrderModel> mockOrders = [
  OrderModel(
    id: 'ORD-2355',
    customer: const OrderCustomer(id: 'CUS-004', name: 'Rina Wulandari', phone: '0813-5678-9012',
      address: 'Jl. Kenjeran No. 150, Surabaya 60129', area: 'Kenjeran, Surabaya'),
    services: const [ServiceItem(name: 'Deep Cleaning 3BR', price: 550000, qty: 1)],
    schedule: 'Rabu, 11 Jun 2026 · 09:00 - 12:00',
    scheduleDateTime: DateTime(2026, 6, 11),
    cleaners: const [OrderCleaner(id: 'CLN-001', name: 'Ani Rahayu', rating: 4.9)],
    status: 'assigned',
    total: 550000,
    paymentMethod: 'Transfer Bank',
    paymentStatus: 'unpaid',
    notes: 'Minta produk unscented, ada anjing kecil.',
  ),
  OrderModel(
    id: 'ORD-2354',
    customer: const OrderCustomer(id: 'CUS-002', name: 'Sari Dewi', phone: '0857-9876-5432',
      address: 'Jl. Raya Gubeng No. 12, Surabaya 60281', area: 'Gubeng, Surabaya'),
    services: const [
      ServiceItem(name: 'Regular Cleaning', price: 280000, qty: 1),
      ServiceItem(name: 'Sofa Cleaning', price: 200000, qty: 1),
    ],
    schedule: 'Rabu, 11 Jun 2026 · 13:00 - 15:00',
    scheduleDateTime: DateTime(2026, 6, 11),
    cleaners: const [OrderCleaner(id: 'CLN-002', name: 'Dewi Safitri', rating: 4.8)],
    status: 'in_progress',
    total: 480000,
    paymentMethod: 'QRIS',
    paymentStatus: 'unpaid',
    notes: '',
  ),
  OrderModel(
    id: 'ORD-2353',
    customer: const OrderCustomer(id: 'CUS-001', name: 'Budi Santoso', phone: '0812-3456-7890',
      address: 'Jl. Raya Darmo No. 45, Wonokromo, Surabaya 60241', area: 'Wonokromo, Surabaya'),
    services: const [ServiceItem(name: 'Deep Cleaning 4BR', price: 650000, qty: 1)],
    schedule: 'Selasa, 10 Jun 2026 · 09:00 - 13:00',
    scheduleDateTime: DateTime(2026, 6, 10),
    cleaners: const [OrderCleaner(id: 'CLN-001', name: 'Ani Rahayu', rating: 4.9)],
    status: 'completed',
    total: 650000,
    paymentMethod: 'Transfer Bank',
    paymentStatus: 'paid',
    notes: '',
  ),
  OrderModel(
    id: 'ORD-2352',
    customer: const OrderCustomer(id: 'CUS-003', name: 'Ahmad Fauzi', phone: '0821-1234-5678',
      address: 'Jl. Rungkut Industri No. 88, Surabaya 60293', area: 'Rungkut, Surabaya'),
    services: const [ServiceItem(name: 'AC Cleaning 2 unit', price: 200000, qty: 2)],
    schedule: 'Selasa, 10 Jun 2026 · 14:00 - 16:00',
    scheduleDateTime: DateTime(2026, 6, 10),
    cleaners: const [],
    status: 'pending',
    total: 400000,
    paymentMethod: '-',
    paymentStatus: 'unpaid',
    notes: 'AC di kamar dan ruang tamu.',
  ),
  OrderModel(
    id: 'ORD-2351',
    customer: const OrderCustomer(id: 'CUS-005', name: 'Hendro Prasetyo', phone: '0878-2345-6789',
      address: 'Jl. Tandes Lor No. 23, Surabaya 60186', area: 'Tandes, Surabaya'),
    services: const [ServiceItem(name: 'Regular Cleaning', price: 280000, qty: 1)],
    schedule: 'Senin, 9 Jun 2026 · 10:00 - 12:00',
    scheduleDateTime: DateTime(2026, 6, 9),
    cleaners: const [OrderCleaner(id: 'CLN-003', name: 'Rina Wati', rating: 4.7)],
    status: 'completed',
    total: 280000,
    paymentMethod: 'QRIS',
    paymentStatus: 'paid',
    notes: '',
  ),
];

const List<Map<String, dynamic>> mockServices = [
  {'name': 'Regular Cleaning', 'price': 280000, 'unit': 'per sesi', 'icon': '🧹'},
  {'name': 'Deep Cleaning 2BR', 'price': 420000, 'unit': 'per sesi', 'icon': '✨'},
  {'name': 'Deep Cleaning 3BR', 'price': 550000, 'unit': 'per sesi', 'icon': '✨'},
  {'name': 'Deep Cleaning 4BR', 'price': 650000, 'unit': 'per sesi', 'icon': '✨'},
  {'name': 'AC Cleaning 1 unit', 'price': 200000, 'unit': 'per unit', 'icon': '❄️'},
  {'name': 'AC Cleaning 2 unit', 'price': 200000, 'unit': 'per unit', 'icon': '❄️'},
  {'name': 'Sofa Cleaning', 'price': 200000, 'unit': 'per sofa', 'icon': '🛋️'},
  {'name': 'Karpet Cleaning', 'price': 350000, 'unit': 'per karpet', 'icon': '🪥'},
  {'name': 'Pembersihan Kamar Mandi', 'price': 150000, 'unit': 'per toilet', 'icon': '🚿'},
];

const List<Map<String, dynamic>> mockCleaners = [
  {'id': 'CLN-001', 'name': 'Ani Rahayu', 'rating': 4.9, 'orders': 156, 'status': 'available'},
  {'id': 'CLN-002', 'name': 'Dewi Safitri', 'rating': 4.8, 'orders': 142, 'status': 'available'},
  {'id': 'CLN-003', 'name': 'Rina Wati', 'rating': 4.7, 'orders': 98, 'status': 'available'},
  {'id': 'CLN-004', 'name': 'Sri Mulyani', 'rating': 4.6, 'orders': 87, 'status': 'busy'},
  {'id': 'CLN-005', 'name': 'Yuni Astuti', 'rating': 4.5, 'orders': 72, 'status': 'available'},
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
