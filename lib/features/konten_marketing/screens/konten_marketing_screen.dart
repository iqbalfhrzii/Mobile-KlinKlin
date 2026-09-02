import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
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
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunduh berkas: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
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
        const SnackBar(content: Text('Tidak ada teks deskripsi untuk disalin'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: text.trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Caption berhasil disalin ke clipboard!'),
        backgroundColor: Color(0xFF16A34A),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openUploadSheet(BuildContext context) {
    final currentType = _tabs[_tabController.index]['key']!;
    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UploadKontenSheet(
        initialType: currentType,
        onSuccess: _fetchContents,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openUploadSheet(context),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          'Tambah Konten',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // 1. GRADIENT HEADER WITH SEARCH BAR & ADD BUTTON
          GradientHeader(
            padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 12 : 16),
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
                      icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 24),
                      tooltip: 'Upload Konten Baru',
                      onPressed: () => _openUploadSheet(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                      tooltip: 'Muat Ulang',
                      onPressed: _fetchContents,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // High Contrast Crisp Search Bar with Clear Hint Text
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Cari materi promosi / judul...',
                      hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12.5),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
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

          // 2. CUSTOM MODERN TABBAR
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
                  Tab(text: 'Konten FollowUp'),
                ],
              ),
            ),
          ),

          // 3. CONTENT LIST
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
          // 1. Media Preview Area
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
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
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
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openUploadSheet(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Upload Konten Baru'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
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

// ================= UPLOAD KONTEN MODAL SHEET (MATCHING WEB MODAL) =================
class _UploadKontenSheet extends StatefulWidget {
  final String initialType;
  final VoidCallback onSuccess;

  const _UploadKontenSheet({
    required this.initialType,
    required this.onSuccess,
  });

  @override
  State<_UploadKontenSheet> createState() => _UploadKontenSheetState();
}

class _UploadKontenSheetState extends State<_UploadKontenSheet> {
  final _service = KontenMarketingService();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  late String _selectedType;
  bool _isUploading = false;
  String? _selectedFilePath;
  String? _selectedFileName;
  String? _selectedFileSize;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'avi', 'mkv', 'webm', 'pdf'],
    );
    if (result != null && result.files.single.path != null) {
      final file = result.files.single;
      final sizeMb = (file.size / (1024 * 1024)).toStringAsFixed(2);
      setState(() {
        _selectedFilePath = file.path;
        _selectedFileName = file.name;
        _selectedFileSize = '$sizeMb MB';
      });
    }
  }

  Future<void> _submitUpload() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul konten wajib diisi!'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
      return;
    }

    if (_selectedFilePath == null || _selectedFilePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih file media (Video/Gambar)!'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final res = await _service.uploadContent(
        {
          'title': title,
          'description': _descController.text.trim(),
          'type': _selectedType,
        },
        filePath: _selectedFilePath,
      );

      if (mounted) {
        setState(() => _isUploading = false);
        if (res['status'] == true) {
          Navigator.pop(context);
          widget.onSuccess();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Konten marketing berhasil diunggah!')),
                ],
              ),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Gagal mengunggah konten'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header Title & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upload Konten Baru',
                  style: GoogleFonts.inter(
                    fontSize: 17.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 14),

            // Kategori / Tipe Konten Selector
            Text(
              'Kategori Konten *',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildTypeChip('story', 'Konten Story'),
                const SizedBox(width: 6),
                _buildTypeChip('promo', 'Promo'),
                const SizedBox(width: 6),
                _buildTypeChip('follow_up', 'FollowUp'),
              ],
            ),
            const SizedBox(height: 14),

            // Judul Konten
            Text(
              'Judul Konten *',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Contoh: Promo Kemerdekaan',
                hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),

            // Deskripsi / Teks Promosi
            Text(
              'Deskripsi / Teks Promosi (Caption)',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _descController,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Opsional, teks caption yang bisa disalin oleh CS...',
                hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 14),

            // File (Video/Gambar) Dropzone Picker
            Text(
              'File Media (Video / Gambar) *',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _selectedFileName != null ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedFileName != null ? const Color(0xFFBFDBFE) : const Color(0xFFCBD5E1),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFileName != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                      size: 32,
                      color: _selectedFileName != null ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedFileName ?? 'Upload a file',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _selectedFileName != null ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedFileSize != null ? 'Ukuran: $_selectedFileSize' : 'Video, JPG, PNG up to 45MB',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    if (_selectedFileName != null) ...[
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedFilePath = null;
                            _selectedFileName = null;
                            _selectedFileSize = null;
                          });
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFDC2626)),
                        label: Text(
                          'Ganti File',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFDC2626)),
                        ),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons (Batal & Simpan)
            if (_isUploading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: Color(0xFF0F172A)),
                      SizedBox(height: 8),
                      Text('Sedang mengunggah konten...'),
                    ],
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: _submitUpload,
                      icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                      label: Text(
                        'Simpan',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String typeKey, String label) {
    final isSelected = _selectedType == typeKey;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedType = typeKey),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }
}
