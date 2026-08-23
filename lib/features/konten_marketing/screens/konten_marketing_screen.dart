import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:printing/printing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/file_attachment_preview.dart';
import '../services/konten_marketing_service.dart';

class KontenMarketingScreen extends StatefulWidget {
  const KontenMarketingScreen({super.key});

  @override
  State<KontenMarketingScreen> createState() => _KontenMarketingScreenState();
}

class _KontenMarketingScreenState extends State<KontenMarketingScreen> with SingleTickerProviderStateMixin {
  final _service = KontenMarketingService();
  final _searchController = TextEditingController();

  late TabController _tabController;
  List<dynamic> _contents = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Timer? _debounce;
  final Set<int> _downloadingIds = {};

  final List<Map<String, String>> _tabs = [
    {'key': 'story', 'label': 'Konten Story', 'icon': 'auto_awesome_motion'},
    {'key': 'promo', 'label': 'Promo', 'icon': 'local_offer'},
    {'key': 'follow_up', 'label': 'Konten FollowUp', 'icon': 'reply_all'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _fetchContents();
      }
    });
    _fetchContents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchContents();
    });
  }

  Future<void> _fetchContents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final currentType = _tabs[_tabController.index]['key']!;
    final res = await _service.getContents(
      type: currentType,
      search: _searchController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['status'] == true && res['data'] != null) {
          final data = res['data'];
          if (data is Map && data['data'] != null) {
            _contents = data['data'];
          } else if (data is List) {
            _contents = data;
          }
        } else {
          _errorMessage = res['message'] ?? 'Gagal memuat konten marketing';
        }
      });
    }
  }

  String _formatFileSize(dynamic bytes) {
    if (bytes == null) return '0 MB';
    final size = double.tryParse(bytes.toString()) ?? 0;
    final mb = size / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }

  String _formatRelativeTime(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr.toString());
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 365) {
        return '${(diff.inDays / 365).floor()} tahun lalu';
      } else if (diff.inDays > 30) {
        return '${(diff.inDays / 30).floor()} bulan lalu';
      } else if (diff.inDays > 0) {
        return '${diff.inDays} hari lalu';
      } else if (diff.inHours > 0) {
        return '${diff.inHours} jam lalu';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes} menit lalu';
      } else {
        return 'Baru saja';
      }
    } catch (_) {
      return dateStr.toString();
    }
  }

  Future<void> _downloadOrShare(dynamic item, {bool isShareOnly = false}) async {
    final int? id = int.tryParse(item['id']?.toString() ?? '');
    final String? filePath = item['file_path']?.toString();
    final String title = item['title']?.toString() ?? 'Konten_Marketing';
    final String fileName = item['file_name']?.toString() ?? 'konten_$id';

    if (filePath == null || filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File tidak tersedia')),
      );
      return;
    }

    if (id != null) {
      setState(() => _downloadingIds.add(id));
    }

    final fullUrl = FileAttachmentPreview.getFullUrl(filePath);

    try {
      final dio = Dio();
      final response = await dio.get<List<int>>(
        fullUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.data != null) {
        final bytes = Uint8List.fromList(response.data!);
        final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
        final cleanFileName = '${title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.$ext';

        await Printing.sharePdf(bytes: bytes, filename: cleanFileName);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isShareOnly ? 'Membagikan berkas...' : 'Berkas siap disimpan / dibagikan'),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunduh berkas: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted && id != null) {
        setState(() => _downloadingIds.remove(id));
      }
    }
  }

  void _copyCaption(String? text) {
    if (text == null || text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada teks deskripsi untuk disalin')),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: text.trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Caption berhasil disalin ke clipboard!'),
        backgroundColor: Color(0xFF16A34A),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Gradient Header
          GradientHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppBackButton(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Konten Marketing',
                            style: GoogleFonts.inter(
                              fontSize: 18.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Materi promosi terbaru dari tim desain.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      tooltip: 'Muat Ulang',
                      onPressed: _fetchContents,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Search Bar
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Cari materi promosi / judul...',
                      hintStyle: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white70),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 16, color: Colors.white70),
                              onPressed: () {
                                _searchController.clear();
                                _fetchContents();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Custom Modern TabBar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primaryMid,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryMid.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Konten Story'),
                  Tab(text: 'Promo'),
                  Tab(text: 'FollowUp'),
                ],
              ),
            ),
          ),

          // Content List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchContents,
              color: AppColors.primaryMid,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                      ? _buildErrorState()
                      : _contents.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                              itemCount: _contents.length,
                              itemBuilder: (context, index) {
                                return _buildContentCard(_contents[index]);
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard(dynamic item) {
    final int? id = int.tryParse(item['id']?.toString() ?? '');
    final String title = item['title']?.toString() ?? '-';
    final String? description = item['description']?.toString();
    final String? filePath = item['file_path']?.toString();
    final String? fileType = item['file_type']?.toString();
    final isVideo = fileType != null && fileType.startsWith('video');
    final isDownloading = id != null && _downloadingIds.contains(id);

    final fullUrl = FileAttachmentPreview.getFullUrl(filePath);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Media Preview Area (Aspect Ratio 4:5 or 16:9)
          GestureDetector(
            onTap: () {
              if (filePath != null && filePath.isNotEmpty) {
                FileAttachmentPreview.showPreview(
                  context,
                  filePath: filePath,
                  title: title,
                );
              }
            },
            child: Container(
              height: 240,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (filePath != null && filePath.isNotEmpty) ...[
                    if (isVideo)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white38),
                              ),
                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ketuk untuk Putar Video',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                            ),
                          ],
                        ),
                      )
                    else
                      Image.network(
                        fullUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                  : null,
                              color: Colors.white70,
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.broken_image_outlined, color: Colors.white38, size: 40),
                              const SizedBox(height: 6),
                              Text(
                                'Pratinjau tidak dapat dimuat',
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ] else ...[
                    const Center(child: Icon(Icons.image_outlined, color: Colors.white24, size: 48)),
                  ],

                  // Top Media Badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isVideo ? Icons.videocam_rounded : Icons.photo_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVideo ? 'Video' : 'Gambar',
                            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tap to zoom badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fullscreen_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 3),
                          Text('Lihat HD', style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Body Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    if (description != null && description.trim().isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primaryMid),
                        tooltip: 'Salin Caption',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _copyCaption(description),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  (description != null && description.trim().isNotEmpty) ? description : 'Tidak ada deskripsi caption.',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),

                // Meta Strip (File Size & Time)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.sd_storage_outlined, size: 13, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          _formatFileSize(item['file_size']),
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          _formatRelativeTime(item['created_at']),
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 3. Action Buttons Row
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isDownloading ? null : () => _downloadOrShare(item),
                        icon: isDownloading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)),
                              )
                            : const Icon(Icons.download_rounded, size: 16, color: Color(0xFF059669)),
                        label: Text(
                          isDownloading ? 'Mengunduh...' : 'Download Asli',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF059669),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFECFDF5),
                          foregroundColor: const Color(0xFF059669),
                          elevation: 0,
                          side: const BorderSide(color: Color(0xFFA7F3D0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () => _downloadOrShare(item, isShareOnly: true),
                      icon: const Icon(Icons.share_rounded, size: 18, color: AppColors.primaryMid),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primaryMid.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.all(12),
                      ),
                      tooltip: 'Bagikan Berkas',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.perm_media_outlined, size: 48, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Konten Marketing',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 6),
            Text(
              'Materi promosi untuk kategori ini belum diunggah oleh tim desain.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'Gagal Memuat Konten',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchContents,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
