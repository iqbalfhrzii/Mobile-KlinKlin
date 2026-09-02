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

  DateTime _monthSaya = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _monthTarget = DateTime(DateTime.now().year, DateTime.now().month, 1);

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
      _showError('Pilih tanggal libur Anda yang ingin ditukar pada kalender');
      return;
    }
    if (_selectedRekan == null) {
      _showError('Pilih rekan kerja pengganti');
      return;
    }
    if (_selectedLiburTarget == null) {
      _showError('Pilih tanggal libur rekan kerja pada kalender');
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
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(res['message'] ?? 'Pengajuan tukar libur berhasil dikirim!', style: GoogleFonts.inter())),
              ],
            ),
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
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: GoogleFonts.inter())),
          ],
        ),
        backgroundColor: AppColors.error,
      ),
    );
  }

  String _formatDate(String dateStr, {bool showRelative = true}) {
    if (dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final itemDate = DateTime(dt.year, dt.month, dt.day);
      final diffDays = itemDate.difference(today).inDays;

      final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      final dayName = days[dt.weekday - 1];
      final monthName = months[dt.month - 1];
      final formatted = '$dayName, ${dt.day} $monthName ${dt.year}';

      if (!showRelative) return formatted;

      if (diffDays == 0) {
        return '$formatted (Hari Ini)';
      } else if (diffDays == -1) {
        return '$formatted (Kemarin)';
      } else if (diffDays < -1) {
        return '$formatted (Sudah Lewat)';
      }
      return formatted;
    } catch (_) {
      return dateStr.split('T')[0];
    }
  }

  String _formatMonthYear(DateTime dt) {
    final months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return '${months[dt.month - 1]} ${dt.year}';
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
                Text('Pilih dan tukar jadwal libur dengan kalender interaktif', style: GoogleFonts.inter(
                  fontSize: 13.5, color: Colors.white.withValues(alpha: 0.9),
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
    final bool isSelfSwap = _selectedRekan != null && _selectedRekan['is_self'] == true;
    final List targetLiburs = _selectedRekan != null && _selectedRekan['jadwal_liburs'] is List
        ? (_selectedRekan['jadwal_liburs'] as List)
        : [];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 24 : 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pilih tanggal libur Anda yang ingin ditukar pada kalender, lalu pilih rekan kerja dan tanggal libur penggantinya.',
                    style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF1E40AF), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // ================= STEP 1: KALENDER LIBUR SAYA =================
          _buildStepHeader(
            stepNumber: '1',
            title: 'Pilih Jadwal Libur Anda (Asal)',
            subtitle: 'Tanggal dengan tanda biru adalah jadwal libur Anda di bulan ini',
          ),
          const SizedBox(height: 10),

          _buildCalendarBox(
            currentMonth: _monthSaya,
            onMonthChanged: (newM) => setState(() => _monthSaya = newM),
            scheduleList: _liburSaya,
            selectedDateStr: _selectedLiburSaya?['tanggal'],
            highlightThemeColor: const Color(0xFF0284C7),
            highlightBgColor: const Color(0xFFE0F2FE),
            highlightBorderColor: const Color(0xFF38BDF8),
            badgeLabel: 'Libur Anda',
            onSelectDate: (dateStr, item) {
              setState(() => _selectedLiburSaya = item);
            },
            emptyMessage: 'Belum ada jadwal libur yang terdaftar untuk Anda di bulan ini.',
          ),

          // Selected Card for Step 1
          if (_selectedLiburSaya != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Libur Dipilih: ${_formatDate(_selectedLiburSaya['tanggal'])}',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 26),

          // ================= STEP 2: PILIH REKAN KERJA =================
          _buildStepHeader(
            stepNumber: '2',
            title: 'Pilih Rekan Kerja Pengganti',
            subtitle: 'Pilih Cleaner rekan kerja yang akan diajak bertukar jadwal',
          ),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: const Color(0xFF64748B).withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: DropdownButtonFormField<dynamic>(
              value: _selectedRekan,
              decoration: InputDecoration(
                hintText: 'Pilih rekan kerja Cleaner',
                hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: const Icon(Icons.people_alt_rounded, color: Color(0xFF64748B), size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: _rekan.isEmpty 
                ? [const DropdownMenuItem(value: null, child: Text('Tidak ada rekan kerja'))]
                : _rekan.map((r) {
                    final bool isSelf = r['is_self'] == true;
                    final int countLibur = (r['jadwal_liburs'] as List? ?? []).length;
                    return DropdownMenuItem<dynamic>(
                      value: r,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isSelf ? '🌟 ${r['nama']}' : '${r['nama']} - ${r['jabatan']?['nama_jabatan'] ?? 'Cleaner'}',
                              style: GoogleFonts.inter(
                                fontWeight: isSelf ? FontWeight.bold : FontWeight.w600,
                                color: isSelf ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                                fontSize: 13.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isSelf && countLibur > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Text(
                                '$countLibur Libur',
                                style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                              ),
                            ),
                        ],
                      ),
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
          ),

          // ================= STEP 3: KALENDER LIBUR REKAN =================
          if (_selectedRekan != null) ...[
            const SizedBox(height: 26),
            if (isSelfSwap) ...[
              _buildStepHeader(
                stepNumber: '3',
                title: 'Pilih Tanggal Libur Baru (Pengganti)',
                subtitle: 'Khusus Denpasar/Tabanan: Pilih hari kerja yang ingin dijadikan libur baru',
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: DateTime(now.year, now.month, 1).subtract(const Duration(days: 7)),
                    lastDate: DateTime(now.year, now.month + 1, 7),
                  );
                  if (picked != null) {
                    final formatted = DateFormat('yyyy-MM-dd').format(picked);
                    final isAlreadyOff = _liburSaya.any((l) => l['tanggal'] == formatted);
                    if (isAlreadyOff) {
                      _showError('Tanggal tersebut sudah merupakan hari libur Anda. Pilih tanggal kerja.');
                      return;
                    }
                    setState(() {
                      _selectedLiburTarget = {'tanggal': formatted};
                    });
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF64748B).withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.event_available_rounded, color: Color(0xFF2563EB), size: 22),
                          const SizedBox(width: 10),
                          Text(
                            _selectedLiburTarget != null
                                ? _formatDate(_selectedLiburTarget['tanggal'])
                                : 'Pilih tanggal libur baru pengganti...',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: _selectedLiburTarget != null ? FontWeight.bold : FontWeight.normal,
                              color: _selectedLiburTarget != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ] else ...[
              _buildStepHeader(
                stepNumber: '3',
                title: 'Pilih Jadwal Libur ${_selectedRekan['nama']} (Tujuan)',
                subtitle: 'Tanggal dengan tanda hijau adalah jadwal libur rekan yang dapat ditukar',
              ),
              const SizedBox(height: 10),

              _buildCalendarBox(
                currentMonth: _monthTarget,
                onMonthChanged: (newM) => setState(() => _monthTarget = newM),
                scheduleList: targetLiburs,
                selectedDateStr: _selectedLiburTarget?['tanggal'],
                highlightThemeColor: const Color(0xFF059669),
                highlightBgColor: const Color(0xFFECFDF5),
                highlightBorderColor: const Color(0xFF6EE7B7),
                badgeLabel: 'Libur ${_selectedRekan['nama'].toString().split(' ').first}',
                onSelectDate: (dateStr, item) {
                  setState(() => _selectedLiburTarget = item);
                },
                emptyMessage: '${_selectedRekan['nama']} belum memiliki jadwal libur di bulan ini.',
              ),

              // Selected Card for Step 3
              if (_selectedLiburTarget != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Libur Pengganti: ${_formatDate(_selectedLiburTarget['tanggal'])} (${_selectedRekan['nama']})',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],

          // ================= SUMMARY SWAP CARD =================
          if (_selectedLiburSaya != null && _selectedLiburTarget != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.compare_arrows_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Ringkasan Penukaran Jadwal',
                        style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBAE6FD)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Libur Anda (Asal)', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF0284C7), fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(_selectedLiburSaya['tanggal']),
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2563EB),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Libur Pengganti', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF059669), fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(_selectedLiburTarget['tanggal']),
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ================= STEP 4: ALASAN PENUKARAN =================
          _buildStepHeader(
            stepNumber: '4',
            title: 'Alasan Penukaran',
            subtitle: 'Tuliskan alasan mengapa Anda perlu menukar jadwal libur ini',
          ),
          const SizedBox(height: 10),

          TextFormField(
            controller: _alasanController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Tuliskan alasan penukaran jadwal secara jelas...',
              hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13.5),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
          ),
          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitPengajuan,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              child: _isSubmitting 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Kirim Pengajuan Tukar Libur', style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader({required String stepNumber, required String title, required String subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            stepNumber,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================= REUSABLE MONTHLY CALENDAR BOX =================
  Widget _buildCalendarBox({
    required DateTime currentMonth,
    required Function(DateTime) onMonthChanged,
    required List scheduleList,
    required String? selectedDateStr,
    required Color highlightThemeColor,
    required Color highlightBgColor,
    required Color highlightBorderColor,
    required String badgeLabel,
    required Function(String dateStr, dynamic item) onSelectDate,
    required String emptyMessage,
  }) {
    final firstDayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    final daysInMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    // Monday is 1, Sunday is 7. Offset so Monday is index 0
    final startOffset = firstDayOfMonth.weekday - 1;
    final totalCells = ((daysInMonth + startOffset) / 7).ceil() * 7;

    // Build map of off-day dates: YYYY-MM-DD -> item
    final Map<String, dynamic> scheduleMap = {};
    for (var s in scheduleList) {
      if (s is Map && s['tanggal'] != null) {
        final t = s['tanggal'].toString().split('T')[0];
        scheduleMap[t] = s;
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Month Header & Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 24, color: Color(0xFF475569)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  onMonthChanged(DateTime(currentMonth.year, currentMonth.month - 1, 1));
                },
              ),
              Row(
                children: [
                  Icon(Icons.calendar_month_rounded, size: 18, color: highlightThemeColor),
                  const SizedBox(width: 6),
                  Text(
                    _formatMonthYear(currentMonth),
                    style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 24, color: Color(0xFF475569)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  onMonthChanged(DateTime(currentMonth.year, currentMonth.month + 1, 1));
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Weekdays
          Row(
            children: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'].asMap().entries.map((entry) {
              final isSunday = entry.key == 6;
              return Expanded(
                child: Center(
                  child: Text(
                    entry.value,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSunday ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 5,
              childAspectRatio: 0.90,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - startOffset + 1;
              final isValid = dayNumber >= 1 && dayNumber <= daysInMonth;

              if (!isValid) {
                return const SizedBox();
              }

              final dateStr = '${currentMonth.year}-${currentMonth.month.toString().padLeft(2, '0')}-${dayNumber.toString().padLeft(2, '0')}';
              final isLibur = scheduleMap.containsKey(dateStr);
              final isSelected = selectedDateStr == dateStr;

              final now = DateTime.now();
              final isToday = now.year == currentMonth.year && now.month == currentMonth.month && now.day == dayNumber;

              return InkWell(
                onTap: () {
                  if (isLibur) {
                    onSelectDate(dateStr, scheduleMap[dateStr]);
                  } else {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Tanggal $dayNumber ${_formatMonthYear(currentMonth)} bukan hari libur yang tersedia.', style: GoogleFonts.inter(fontSize: 12.5)),
                        duration: const Duration(seconds: 2),
                        backgroundColor: const Color(0xFF475569),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? highlightThemeColor
                        : (isLibur ? highlightBgColor : Colors.transparent),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? highlightThemeColor
                          : (isLibur ? highlightBorderColor : (isToday ? const Color(0xFFCBD5E1) : Colors.transparent)),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: highlightThemeColor.withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNumber',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isLibur || isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isLibur ? highlightThemeColor : const Color(0xFF64748B)),
                        ),
                      ),
                      if (isLibur) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white.withValues(alpha: 0.25) : highlightThemeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'LIBUR',
                            style: GoogleFonts.inter(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? Colors.white : highlightThemeColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),

          // Quick Chips Selector below calendar
          if (scheduleMap.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.touch_app_rounded, size: 14, color: highlightThemeColor),
                const SizedBox(width: 6),
                Text(
                  'Pilih Cepat Jadwal Libur:',
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: scheduleMap.entries.map((entry) {
                final dateKey = entry.key;
                final item = entry.value;
                final isSelected = selectedDateStr == dateKey;

                return InkWell(
                  onTap: () => onSelectDate(dateKey, item),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected ? highlightThemeColor : highlightBgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? highlightThemeColor : highlightBorderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.beach_access_rounded,
                          size: 13,
                          color: isSelected ? Colors.white : highlightThemeColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _formatDate(dateKey),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : highlightThemeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              emptyMessage,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  // ================= RIWAYAT TAB =================
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
        final bool isSelfSwap = item['pengaju_id'] == item['target_id'];
        
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
                      color: isSelfSwap ? const Color(0xFFEFF6FF) : const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isSelfSwap ? Icons.person_pin_circle_rounded : Icons.event_repeat_rounded,
                      color: isSelfSwap ? const Color(0xFF2563EB) : const Color(0xFF8B5CF6),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSelfSwap ? 'Tukar Libur Mandiri (Diri Sendiri)' : 'Tukar dengan: ${target?['nama'] ?? '-'}', 
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark)
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: #${item['id']} • Diajukan oleh: ${pengaju?['nama'] ?? '-'}',
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
}
