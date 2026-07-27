import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/operasional_service.dart';

class OperasionalTargetOmzetScreen extends StatefulWidget {
  const OperasionalTargetOmzetScreen({super.key});

  @override
  State<OperasionalTargetOmzetScreen> createState() => _OperasionalTargetOmzetScreenState();
}

class _OperasionalTargetOmzetScreenState extends State<OperasionalTargetOmzetScreen> {
  final _service = OperasionalService();
  bool _isLoading = true;
  String _error = '';
  List<dynamic> _cabangs = [];
  List<dynamic> _filteredCabangs = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
    _searchController.addListener(() {
      _filterCabangs();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCabangs() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCabangs = List.from(_cabangs);
      } else {
        _filteredCabangs = _cabangs.where((c) {
          final nama = (c['nama_cabang'] ?? '').toString().toLowerCase();
          return nama.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final res = await _service.getCabangs();
      setState(() {
        _cabangs = res['data'] ?? [];
        _filteredCabangs = List.from(_cabangs);
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return 'Rp 0';
    final numVal = num.tryParse(value.toString()) ?? 0;
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(numVal);
  }

  void _showEditDialog(Map<String, dynamic> cabang) {
    final targetController = TextEditingController(
      text: cabang['target_omzet'] != null ? num.parse(cabang['target_omzet'].toString()).toInt().toString() : ''
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.only(left: 24, top: 16, right: 16, bottom: 8),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Edit Target Omzet',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cabang', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(cabang['nama_cabang'], style: GoogleFonts.inter(fontSize: 14)),
              ),
              const SizedBox(height: 16),
              Text('Target Omzet *', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: GoogleFonts.inter(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (targetController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Target Omzet harus diisi')));
                  return;
                }

                try {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (c) => const Center(child: CircularProgressIndicator()),
                  );
                  
                  await _service.updateTargetOmzet(
                    cabang['id'], 
                    double.parse(targetController.text.trim())
                  );
                  
                  if (context.mounted) {
                    Navigator.pop(context); // close loading
                    Navigator.pop(context); // close dialog
                    _fetchData();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Target Omzet berhasil diperbarui')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // close loading
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A), // Dark blue/black color from screenshot
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Simpan Target', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: GradientHeader(
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target Omzet',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Target Omzet',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_cabangs.length} data',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 200,
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari cabang...',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search, size: 16, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error.isNotEmpty
                      ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
                      : _buildTable(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTable() {
    if (_filteredCabangs.isEmpty) return const Center(child: Text('Tidak ada data'));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
          columns: [
            DataColumn(label: Text('CABANG', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted))),
            DataColumn(label: Text('TARGET OMZET', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted))),
            DataColumn(label: Text('AKSI', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted))),
          ],
          rows: _filteredCabangs.map((c) {
            return DataRow(
              cells: [
                DataCell(Text(c['nama_cabang'] ?? '-', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textDark))),
                DataCell(Text(_formatCurrency(c['target_omzet']), style: GoogleFonts.inter(color: AppColors.textDark))),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                    onPressed: () => _showEditDialog(c),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
