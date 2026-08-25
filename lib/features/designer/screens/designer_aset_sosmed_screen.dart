import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/designer_service.dart';

class DesignerAsetSosmedScreen extends StatefulWidget {
  const DesignerAsetSosmedScreen({super.key});

  @override
  State<DesignerAsetSosmedScreen> createState() => _DesignerAsetSosmedScreenState();
}

class _DesignerAsetSosmedScreenState extends State<DesignerAsetSosmedScreen> {
  final DesignerService _service = DesignerService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<dynamic> _assets = [];
  final Set<int> _visiblePasswords = {};

  @override
  void initState() {
    super.initState();
    _fetchAssets();
  }

  Future<void> _fetchAssets() async {
    setState(() => _isLoading = true);
    try {
      final res = await _service.fetchAsetSosmed(search: _searchController.text.trim());
      if (res['status'] == true && res['data'] != null) {
        final dataObj = res['data'];
        List<dynamic> list = [];
        if (dataObj is Map && dataObj['data'] is List) {
          list = dataObj['data'];
        } else if (dataObj is List) {
          list = dataObj;
        }
        if (mounted) {
          setState(() {
            _assets = list;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openFormSheet({dynamic asset}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AsetSosmedFormSheet(
        asset: asset,
        onSaved: _fetchAssets,
      ),
    );
  }

  Future<void> _deleteAsset(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Aset?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menghapus data aset sosial media ini?', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _service.deleteAsetSosmed(id);
      if (res['status'] == true) {
        _fetchAssets();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aset berhasil dihapus'), backgroundColor: Color(0xFF15803D)),
          );
        }
      }
    }
  }

  IconData _getPlatformIcon(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('instagram') || p.contains('ig')) return Icons.camera_alt_rounded;
    if (p.contains('tiktok')) return Icons.music_note_rounded;
    if (p.contains('youtube') || p.contains('yt')) return Icons.play_circle_fill_rounded;
    if (p.contains('facebook') || p.contains('fb')) return Icons.facebook_rounded;
    if (p.contains('drive') || p.contains('google')) return Icons.add_to_drive_rounded;
    if (p.contains('canva') || p.contains('figma')) return Icons.palette_rounded;
    return Icons.language_rounded;
  }

  Color _getPlatformColor(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('instagram') || p.contains('ig')) return const Color(0xFFE1306C);
    if (p.contains('tiktok')) return const Color(0xFF000000);
    if (p.contains('youtube') || p.contains('yt')) return const Color(0xFFFF0000);
    if (p.contains('facebook') || p.contains('fb')) return const Color(0xFF1877F2);
    if (p.contains('drive') || p.contains('google')) return const Color(0xFF0F9D58);
    if (p.contains('canva')) return const Color(0xFF00C4CC);
    if (p.contains('figma')) return const Color(0xFFF24E1E);
    return const Color(0xFF2563EB);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openFormSheet(),
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Tambah Aset', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: Column(
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(
              children: [
                if (Navigator.canPop(context)) ...[
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Desain & Media',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kelola Aset Sosmed',
                        style: GoogleFonts.inter(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _fetchAssets,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _searchController,
                onSubmitted: (_) => _fetchAssets(),
                decoration: InputDecoration(
                  hintText: 'Cari platform atau username...',
                  hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _fetchAssets();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _assets.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _fetchAssets,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: _assets.length,
                          itemBuilder: (context, index) {
                            return _buildAssetCard(_assets[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetCard(dynamic item) {
    final id = item['id'] ?? 0;
    final platform = item['platform'] ?? 'Platform';
    final username = item['username'] ?? '';
    final password = item['password'] ?? '';
    final url = item['url'] ?? '';
    final keterangan = item['keterangan'] ?? '';

    final isPasswordVisible = _visiblePasswords.contains(id);
    final pColor = _getPlatformColor(platform);
    final pIcon = _getPlatformIcon(platform);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: Platform Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: pColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(pIcon, size: 20, color: pColor),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      platform,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF64748B)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) {
                    if (val == 'edit') _openFormSheet(asset: item);
                    if (val == 'delete') _deleteAsset(id);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                          SizedBox(width: 8),
                          Text('Edit Aset'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                          SizedBox(width: 8),
                          Text('Hapus'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Username
            if (username.isNotEmpty) ...[
              _buildCredentialRow(
                label: 'Username / Email',
                value: username,
                icon: Icons.alternate_email_rounded,
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: username));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Username disalin ke clipboard')),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],

            // Password
            if (password.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 15, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Password', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8))),
                        Text(
                          isPasswordVisible ? password : '••••••••••••',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        if (isPasswordVisible) {
                          _visiblePasswords.remove(id);
                        } else {
                          _visiblePasswords.add(id);
                        }
                      });
                    },
                    icon: Icon(
                      isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                      color: const Color(0xFF64748B),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: password));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password disalin ke clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF2563EB)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // URL
            if (url.isNotEmpty) ...[
              InkWell(
                onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          url,
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF2563EB), fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF2563EB)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Keterangan
            if (keterangan.isNotEmpty) ...[
              Text(
                keterangan,
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialRow({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onCopy,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8))),
              Text(
                value,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onCopy,
          icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF2563EB)),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
            child: const Icon(Icons.inventory_2_outlined, size: 36, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 12),
          Text(
            'Belum Ada Aset Sosial Media',
            style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            'Kelola akun sosial media, Google Drive, atau Canva tim di sini.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

// ================= MODAL FORM SHEET =================
class _AsetSosmedFormSheet extends StatefulWidget {
  final dynamic asset;
  final VoidCallback onSaved;

  const _AsetSosmedFormSheet({
    this.asset,
    required this.onSaved,
  });

  @override
  State<_AsetSosmedFormSheet> createState() => _AsetSosmedFormSheetState();
}

class _AsetSosmedFormSheetState extends State<_AsetSosmedFormSheet> {
  final DesignerService _service = DesignerService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _platformController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();

  bool _isSaving = false;

  final List<String> _commonPlatforms = [
    'Instagram',
    'TikTok',
    'Facebook',
    'YouTube',
    'Google Drive',
    'Canva',
    'Figma',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.asset != null) {
      _platformController.text = widget.asset['platform'] ?? '';
      _usernameController.text = widget.asset['username'] ?? '';
      _passwordController.text = widget.asset['password'] ?? '';
      _urlController.text = widget.asset['url'] ?? '';
      _keteranganController.text = widget.asset['keterangan'] ?? '';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final data = {
      'platform': _platformController.text.trim(),
      'username': _usernameController.text.trim(),
      'password': _passwordController.text.trim(),
      'url': _urlController.text.trim(),
      'keterangan': _keteranganController.text.trim(),
    };

    try {
      final res = widget.asset != null
          ? await _service.updateAsetSosmed(widget.asset['id'], data)
          : await _service.storeAsetSosmed(data);

      if (mounted) {
        setState(() => _isSaving = false);
        if (res['status'] == true) {
          Navigator.pop(context);
          widget.onSaved();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.asset != null ? 'Aset berhasil diperbarui' : 'Aset berhasil ditambahkan'),
              backgroundColor: const Color(0xFF15803D),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Gagal menyimpan data'), backgroundColor: const Color(0xFFDC2626)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.asset != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Edit Aset Sosmed' : 'Tambah Aset Sosmed',
                    style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Quick platform selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _commonPlatforms.map((p) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(p, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                        backgroundColor: const Color(0xFFF1F5F9),
                        onPressed: () => setState(() => _platformController.text = p),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // Platform input
              Text('Platform *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextFormField(
                controller: _platformController,
                validator: (v) => v == null || v.trim().isEmpty ? 'Platform wajib diisi' : null,
                decoration: InputDecoration(
                  hintText: 'Contoh: Instagram, TikTok, Canva...',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),

              // Username
              Text('Username / Akun', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  hintText: 'Username atau email login...',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),

              // Password
              Text('Password', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  hintText: 'Password login akun...',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),

              // URL
              Text('URL / Link', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  hintText: 'https://instagram.com/...',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),

              // Keterangan
              Text('Keterangan / Catatan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextFormField(
                controller: _keteranganController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Catatan tambahan terkait aset ini...',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(isEdit ? 'Simpan Perubahan' : 'Tambah Aset', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
