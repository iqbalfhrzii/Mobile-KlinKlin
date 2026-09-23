import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/ceo_service.dart';
import '../services/ceo_privacy_controller.dart';
import '../widgets/ceo_privacy_eye_button.dart';

class CeoSpendAdsScreen extends StatefulWidget {
  const CeoSpendAdsScreen({super.key});

  @override
  State<CeoSpendAdsScreen> createState() => _CeoSpendAdsScreenState();
}

class _CeoSpendAdsScreenState extends State<CeoSpendAdsScreen> {
  final CeoService _service = CeoService();

  bool _isLoading = false;
  String _error = '';
  List<dynamic> _spendAdsList = [];
  Map<String, dynamic>? _spendAdsSummary;

  final TextEditingController _searchController = TextEditingController();
  String _selectedPlatform = ''; // '', 'google', 'meta', 'tiktok'
  String _periode = DateFormat('yyyy-MM').format(DateTime.now());
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _fetchMarketingData();
    CeoPrivacyController.instance.addListener(_onPrivacyChanged);
  }

  void _onPrivacyChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CeoPrivacyController.instance.removeListener(_onPrivacyChanged);
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMarketingData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final res = await _service.getSpendAds(
        periode: _periode,
        search: _searchController.text.trim(),
        platform: _selectedPlatform.isNotEmpty ? _selectedPlatform : null,
      );

      if (mounted) {
        if (res['status'] == true && res['data'] != null) {
          final rawData = res['data'];
          List<dynamic> list = [];
          Map<String, dynamic>? summary;

          if (rawData is Map) {
            if (rawData['spend_ads'] is List) {
              list = rawData['spend_ads'];
            } else if (rawData['data'] is List) {
              list = rawData['data'];
            }
            if (rawData['summary'] is Map) {
              summary = Map<String, dynamic>.from(rawData['summary']);
            }
          } else if (rawData is List) {
            list = rawData;
          }

          setState(() {
            _spendAdsList = list;
            _spendAdsSummary = summary;
          });
        } else {
          setState(() => _error = res['message'] ?? 'Gagal mengambil data spend ads');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double _parseDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    if (val is String) {
      return double.tryParse(val.replaceAll(',', '').replaceAll(' ', '')) ?? fallback;
    }
    return fallback;
  }

  String _formatCurrency(double amount) {
    return CeoPrivacyController.instance.formatCurrency(amount);
  }

  void _pickMarketingMonth() async {
    DateTime current;
    try {
      final parts = _periode.split('-');
      current = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    } catch (_) {
      current = DateTime.now();
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'PILIH PERIODE BULAN',
    );

    if (picked != null) {
      setState(() {
        _periode = DateFormat('yyyy-MM').format(picked);
      });
      _fetchMarketingData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _spendAdsSummary ?? {
      'sum_google': 0.0,
      'sum_meta': 0.0,
      'sum_tiktok': 0.0,
      'total_spend': 0.0,
      'pajak_12': 0.0,
      'total_termasuk_pajak': 0.0,
      'periode': _periode,
    };

    final sumGoogle = _parseDouble(summary['sum_google']);
    final sumMeta = _parseDouble(summary['sum_meta']);
    final sumTiktok = _parseDouble(summary['sum_tiktok']);
    final totalSpend = _parseDouble(summary['total_spend'], sumGoogle + sumMeta + sumTiktok);
    final pajak12 = _parseDouble(summary['pajak_12'], totalSpend * 0.12);
    final totalTermasukPajak = _parseDouble(summary['total_termasuk_pajak'], totalSpend + pajak12);

    DateTime parsedMonth;
    try {
      final parts = _periode.split('-');
      parsedMonth = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    } catch (_) {
      parsedMonth = DateTime.now();
    }
    final formattedMonth = DateFormat('MMMM yyyy', 'id_ID').format(parsedMonth);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchMarketingData,
              color: const Color(0xFF0F172A),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  // 1. Top Hero Summary Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL SPEND MARKETING',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            InkWell(
                              onTap: _pickMarketingMonth,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.calendar_month_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      formattedMonth,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 14,
                                      color: Colors.white70,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text(
                                _formatCurrency(totalTermasukPajak),
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total termasuk PPN 12%',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Spend Net',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatCurrency(totalSpend),
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pajak PPN (12%)',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatCurrency(pajak12),
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF38BDF8),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                  const SizedBox(height: 16),

                  // 2. Platform Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildPlatformMetricCard(
                          title: 'Google',
                          amount: sumGoogle,
                          platformKey: 'google',
                          iconColor: const Color(0xFF10B981),
                          bgColor: const Color(0xFFECFDF5),
                          borderColor: const Color(0xFFA7F3D0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPlatformMetricCard(
                          title: 'Meta',
                          amount: sumMeta,
                          platformKey: 'meta',
                          iconColor: const Color(0xFF2563EB),
                          bgColor: const Color(0xFFEFF6FF),
                          borderColor: const Color(0xFFBFDBFE),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPlatformMetricCard(
                          title: 'TikTok',
                          amount: sumTiktok,
                          platformKey: 'tiktok',
                          iconColor: const Color(0xFF0F172A),
                          bgColor: const Color(0xFFF1F5F9),
                          borderColor: const Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. Search Bar
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 350),
                          _fetchMarketingData,
                        );
                      },
                      decoration: InputDecoration(
                        hintText: 'Cari nama cabang...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  _fetchMarketingData();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4. Platform Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPlatformChip('Semua Platform', ''),
                        _buildPlatformChip('Google Ads', 'google'),
                        _buildPlatformChip('Meta Ads', 'meta'),
                        _buildPlatformChip('TikTok Ads', 'tiktok'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Daftar Spend Ads Cabang',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (!_isLoading && _error.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_spendAdsList.length} Data',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 6. Content / List / Loading / Error
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))),
                    )
                  else if (_error.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            _error,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.error),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _fetchMarketingData,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Muat Ulang'),
                          ),
                        ],
                      ),
                    )
                  else if (_spendAdsList.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.campaign_outlined,
                              size: 28,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Belum Ada Data Spend Ads',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Belum ada catatan spend ads untuk periode atau filter ini.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._spendAdsList.map((ad) => _buildSpendAdCard(ad)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return GradientHeader(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 12,
        16,
        18,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Marketing & Periklanan',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  'Monitoring Spend Ads',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const CeoPrivacyEyeButton(),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _fetchMarketingData,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformMetricCard({
    required String title,
    required double amount,
    required String platformKey,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    final isSelected = _selectedPlatform == platformKey;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPlatform = isSelected ? '' : platformKey;
        });
        _fetchMarketingData();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? iconColor : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: iconColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? iconColor : AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _formatCurrency(amount),
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformChip(String label, String value) {
    final isSelected = _selectedPlatform == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          setState(() => _selectedPlatform = value);
          _fetchMarketingData();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpendAdCard(dynamic ad) {
    final cabangName = ad['cabang']?['nama_cabang']?.toString().toUpperCase() ?? '-';
    final platform = (ad['platform']?.toString() ?? 'google').toLowerCase();
    final nominal = _parseDouble(ad['nominal']);
    final periode = ad['periode']?.toString() ?? '';

    Color badgeBg;
    Color badgeText;
    IconData platformIcon;
    if (platform == 'google') {
      badgeBg = const Color(0xFFECFDF5);
      badgeText = const Color(0xFF059669);
      platformIcon = Icons.campaign_rounded;
    } else if (platform == 'meta') {
      badgeBg = const Color(0xFFEFF6FF);
      badgeText = const Color(0xFF2563EB);
      platformIcon = Icons.share_rounded;
    } else {
      badgeBg = const Color(0xFFF1F5F9);
      badgeText = const Color(0xFF0F172A);
      platformIcon = Icons.music_note_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              platformIcon,
              size: 20,
              color: badgeText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cabangName,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        platform.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: badgeText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      periode,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            _formatCurrency(nominal),
            style: GoogleFonts.inter(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
