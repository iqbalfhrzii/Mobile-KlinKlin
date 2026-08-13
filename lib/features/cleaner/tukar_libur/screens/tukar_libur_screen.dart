import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../services/tukar_libur_service.dart';

class TukarLiburScreen extends StatefulWidget {
  const TukarLiburScreen({super.key});

  @override
  State<TukarLiburScreen> createState() => _TukarLiburScreenState();
}

class _TukarLiburScreenState extends State<TukarLiburScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  bool _isLoading = true;
  String _error = '';
  
  List<dynamic> _rekan = [];
  List<dynamic> _liburSaya = [];
  List<dynamic> _riwayat = [];

  dynamic _selectedRekan;
  dynamic _selectedLiburTarget;
  dynamic _selectedLiburSaya;
  final TextEditingController _alasanController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _alasanController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    
    try {
      final dataRekan = await TukarLiburService.getRekanKerja();
      final riwayat = await TukarLiburService.getRiwayat();
      
      setState(() {
        _rekan = dataRekan['rekan'] ?? [];
        _liburSaya = dataRekan['libur_saya'] ?? [];
        _riwayat = riwayat;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _submitPengajuan() async {
    if (_selectedLiburSaya == null) {
      _showError('Pilih tanggal libur Anda yang ingin ditukar');
      return;
    }
    if (_selectedRekan == null) {
      _showError('Pilih rekan kerja pengganti');
      return;
    }
    if (_selectedLiburTarget == null) {
      _showError('Pilih tanggal libur rekan kerja');
      return;
    }
    if (_alasanController.text.trim().isEmpty) {
      _showError('Alasan penukaran wajib diisi');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final res = await TukarLiburService.ajukanTukarLibur(
        targetId: _selectedRekan['id'],
        tanggalPengaju: _selectedLiburSaya['tanggal'],
        tanggalTarget: _selectedLiburTarget['tanggal'],
        alasan: _alasanController.text.trim(),
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        _alasanController.clear();
        _selectedRekan = null;
        _selectedLiburSaya = null;
        _selectedLiburTarget = null;
        _tabController.animateTo(1); // Ke tab riwayat
        _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Berhasil mengajukan penukaran', style: GoogleFonts.inter()),
            backgroundColor: AppColors.success,
          )
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showError(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: GoogleFonts.inter()), backgroundColor: AppColors.error),
    );
  }


  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      // Gunakan Intl jika tersedia locale id, atau fallback manual
      // Berhubung kita ingin format cepat: Hari, dd Bulan yyyy
      final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      final dayName = days[dt.weekday - 1];
      final monthName = months[dt.month - 1];
      return '$dayName, ${dt.day} $monthName ${dt.year}';
    } catch (_) {
      return dateStr.split('T')[0]; // fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HeaderBackButton(onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 12),
                    Text('Tukar Libur', style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white,
                    )),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Tukar jadwal libur dengan sesama Cleaner', style: GoogleFonts.inter(
                  fontSize: 14, color: Colors.white.withValues(alpha: 0.8),
                )),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: AppColors.primary,
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: const [
                  Tab(text: 'Pengajuan Baru'),
                  Tab(text: 'Riwayat'),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                        const SizedBox(height: 16),
                        Text(_error, style: GoogleFonts.inter(color: AppColors.error), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _fetchData, child: const Text('Coba Lagi')),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildForm(),
                      _buildRiwayat(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceBlue,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Anda hanya dapat bertukar jadwal libur dengan sesama Cleaner di cabang yang sama.',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          Text('Libur Anda (Asal)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const SizedBox(height: 8),
          DropdownButtonFormField<dynamic>(
            value: _selectedLiburSaya,
            decoration: _inputDecoration('Pilih tanggal libur Anda'),
            items: _liburSaya.isEmpty 
              ? [const DropdownMenuItem(value: null, child: Text('Belum ada jadwal libur'))]
              : _liburSaya.map((libur) {
                  return DropdownMenuItem<dynamic>(
                    value: libur,
                    child: Text(_formatDate(libur['tanggal'])),
                  );
                }).toList(),
            onChanged: _liburSaya.isEmpty ? null : (val) {
              setState(() => _selectedLiburSaya = val);
            },
            isExpanded: true,
          ),
          const SizedBox(height: 20),

          Text('Rekan Kerja Pengganti', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const SizedBox(height: 8),
          DropdownButtonFormField<dynamic>(
            value: _selectedRekan,
            decoration: _inputDecoration('Pilih rekan kerja'),
            items: _rekan.isEmpty 
              ? [const DropdownMenuItem(value: null, child: Text('Tidak ada rekan kerja'))]
              : _rekan.map((r) {
                  return DropdownMenuItem<dynamic>(
                    value: r,
                    child: Text('${r['nama']} - ${r['jabatan']?['nama_jabatan'] ?? 'Cleaner'}'),
                  );
                }).toList(),
            onChanged: _rekan.isEmpty ? null : (val) {
              setState(() {
                _selectedRekan = val;
                _selectedLiburTarget = null;
              });
            },
            isExpanded: true,
          ),
          const SizedBox(height: 20),

          if (_selectedRekan != null) ...[
            Text('Libur Rekan Kerja (Tujuan)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            const SizedBox(height: 8),
            DropdownButtonFormField<dynamic>(
              value: _selectedLiburTarget,
              decoration: _inputDecoration('Pilih tanggal libur rekan kerja'),
              items: (_selectedRekan['jadwal_liburs'] as List? ?? []).map((libur) {
                return DropdownMenuItem<dynamic>(
                  value: libur,
                  child: Text(_formatDate(libur['tanggal'])),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedLiburTarget = val);
              },
              isExpanded: true,
            ),
            const SizedBox(height: 20),
          ],

          Text('Alasan Penukaran', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _alasanController,
            maxLines: 3,
            decoration: _inputDecoration('Masukkan alasan Anda menukar libur ini...'),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitPengajuan,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSubmitting 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Kirim Pengajuan', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiwayat() {
    if (_riwayat.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Belum ada riwayat', style: GoogleFonts.inter(fontSize: 16, color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _riwayat.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _riwayat[index];
        final pengaju = item['pengaju'];
        final target = item['target'];
        
        final isPengaju = true; // Wait, we need to check if user is pengaju or target. 
        // For cleaner, if they are target, they might see it pending or approved.
        
        Color statusColor;
        switch (item['status']) {
          case 'approved': statusColor = AppColors.success; break;
          case 'rejected': statusColor = AppColors.error; break;
          default: statusColor = Colors.orange; break;
        }


        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.event_repeat_rounded, color: Color(0xFF8B5CF6), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tukar dengan: ${target['nama']}', 
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark)
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: #${item['id']} • Diajukan oleh: ${pengaju['nama']}',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      item['status'].toString().toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: AppColors.border),
              ),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.event_busy_rounded, size: 14, color: Colors.red.shade400),
                              const SizedBox(width: 4),
                              Text('Libur Asal', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(_formatDate(item['tanggal_pengaju']), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark)),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 28),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.event_available_rounded, size: 14, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text('Libur Pengganti', style: GoogleFonts.inter(fontSize: 11, color: AppColors.primary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(_formatDate(item['tanggal_target']), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.format_quote_rounded, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('Alasan Penukaran', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(item['alasan'] ?? '-', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        );

      },
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }
}
