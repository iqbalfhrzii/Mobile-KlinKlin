import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/data/customer_model.dart';
import '../../../core/services/customer_service.dart';
import 'customer_detail_screen.dart';
import 'add_customer_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  String _query = '';
  String _filter = 'Semua';
  List<CustomerModel> _customers = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final data = await CustomerService.getCustomers();
      setState(() {
        _customers = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<CustomerModel> get _filtered {
    var list = _customers.where((c) {
      final q = _query.toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          c.phone.contains(q);
    }).toList();
    if (_filter != 'Semua') {
      list = list.where((c) => c.status.toLowerCase().replaceAll(' ', '') == _filter.toLowerCase().replaceAll(' ', '')).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_error, style: GoogleFonts.inter(color: AppColors.statusCancel)),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _fetchData, child: const Text('Coba Lagi')),
                        ],
                      ))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Column(
                          children: [
                            _buildFilter(),
                            const SizedBox(height: 12),
                  ..._filtered.map((c) => _CustomerCard(
                    customer: c,
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(
                        builder: (_) => CustomerDetailScreen(customer: c),
                      ));
                      _fetchData();
                    },
                  )),
                  if (_filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(child: Text('Tidak ada pelanggan', style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                      ))),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'customer_fab',
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(
            builder: (_) => const AddCustomerScreen(),
          ));
          if (result != null) _fetchData();
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: Text('Tambah', style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white,
        )),
      ),
    );
  }


  Widget _buildHeader() {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Manajemen', style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.white.withOpacity(0.7),
                  )),
                  Text('Pelanggan', style: GoogleFonts.inter(
                    fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white,
                  )),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${mockCustomers.length} Total', style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600,
                )),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search
          TextField(
            onChanged: (v) => setState(() => _query = v),
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Cari nama, nomor HP...',
              hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.5), fontSize: 14),
              filled: true,
              fillColor: Colors.white.withOpacity(0.12),
              prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.5), size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilter() {
    const filters = ['Semua', 'Aktif', 'Non Aktif'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final active = _filter == f;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(f, style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.textMuted,
              )),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer, required this.onTap});
  final CustomerModel customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final isAktif = c.status.toLowerCase() == 'aktif';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [AppColors.cardShadow],
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              clipBehavior: Clip.none,
              children: [
                InitialsAvatar(name: c.name, size: 44),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isAktif ? AppColors.statusDone : AppColors.statusCancel,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(c.name, style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark,
                      )),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isAktif ? AppColors.statusDone : AppColors.statusCancel).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isAktif ? 'Aktif' : 'Non Aktif',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isAktif ? AppColors.statusDone : AppColors.statusCancel,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(c.phone, style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textMuted,
                  )),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                Text('${c.totalOrders}x', style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textMuted,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
