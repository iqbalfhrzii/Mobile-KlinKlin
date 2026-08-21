import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class EditKpiCsBottomSheet extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final Function(Map<String, dynamic>) onSave;

  const EditKpiCsBottomSheet({
    super.key,
    required this.initialData,
    required this.onSave,
  });

  @override
  State<EditKpiCsBottomSheet> createState() => _EditKpiCsBottomSheetState();
}

class _EditKpiCsBottomSheetState extends State<EditKpiCsBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _targetNilaiKpiCtrl;
  
  late TextEditingController _targetOmzetCtrl;
  late TextEditingController _bobotOmzetCtrl;
  
  late TextEditingController _targetClosingRateCtrl;
  late TextEditingController _bobotClosingRateCtrl;
  
  late TextEditingController _targetClosingChatCtrl;
  late TextEditingController _bobotClosingChatCtrl;
  
  late TextEditingController _targetStockOpnameCtrl;
  late TextEditingController _bobotStockOpnameCtrl;
  late TextEditingController _nilaiStockOpnameCtrl;
  
  late TextEditingController _targetReviewMapsCtrl;
  late TextEditingController _bobotReviewMapsCtrl;
  late TextEditingController _nilaiReviewMapsCtrl;
  
  late TextEditingController _strategiTgl7Ctrl;
  late TextEditingController _strategiTgl14Ctrl;
  late TextEditingController _strategiTgl21Ctrl;
  late TextEditingController _strategiTgl28Ctrl;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;

    _targetNilaiKpiCtrl = TextEditingController(text: d['target_nilai_kpi']?.toString() ?? '100');
    
    _targetOmzetCtrl = TextEditingController(text: d['target_omzet']?.toString() ?? '0');
    _bobotOmzetCtrl = TextEditingController(text: d['bobot_omzet']?.toString() ?? '40');
    
    _targetClosingRateCtrl = TextEditingController(text: d['target_closing_rate']?.toString() ?? '0');
    _bobotClosingRateCtrl = TextEditingController(text: d['bobot_closing_rate']?.toString() ?? '20');
    
    _targetClosingChatCtrl = TextEditingController(text: d['target_closing_chat']?.toString() ?? '0');
    _bobotClosingChatCtrl = TextEditingController(text: d['bobot_closing_chat']?.toString() ?? '20');
    
    _targetStockOpnameCtrl = TextEditingController(text: d['target_stock_opname']?.toString() ?? '0');
    _bobotStockOpnameCtrl = TextEditingController(text: d['bobot_stock_opname']?.toString() ?? '10');
    _nilaiStockOpnameCtrl = TextEditingController(text: d['nilai_stock_opname']?.toString() ?? '0');
    
    _targetReviewMapsCtrl = TextEditingController(text: d['target_review_maps']?.toString() ?? '0');
    _bobotReviewMapsCtrl = TextEditingController(text: d['bobot_review_maps']?.toString() ?? '10');
    _nilaiReviewMapsCtrl = TextEditingController(text: d['nilai_review_maps']?.toString() ?? '0');
    
    _strategiTgl7Ctrl = TextEditingController(text: d['strategi_tgl_7']?.toString() ?? '');
    _strategiTgl14Ctrl = TextEditingController(text: d['strategi_tgl_14']?.toString() ?? '');
    _strategiTgl21Ctrl = TextEditingController(text: d['strategi_tgl_21']?.toString() ?? '');
    _strategiTgl28Ctrl = TextEditingController(text: d['strategi_tgl_28']?.toString() ?? '');
  }

  @override
  void dispose() {
    _targetNilaiKpiCtrl.dispose();
    _targetOmzetCtrl.dispose();
    _bobotOmzetCtrl.dispose();
    _targetClosingRateCtrl.dispose();
    _bobotClosingRateCtrl.dispose();
    _targetClosingChatCtrl.dispose();
    _bobotClosingChatCtrl.dispose();
    _targetStockOpnameCtrl.dispose();
    _bobotStockOpnameCtrl.dispose();
    _nilaiStockOpnameCtrl.dispose();
    _targetReviewMapsCtrl.dispose();
    _bobotReviewMapsCtrl.dispose();
    _nilaiReviewMapsCtrl.dispose();
    _strategiTgl7Ctrl.dispose();
    _strategiTgl14Ctrl.dispose();
    _strategiTgl21Ctrl.dispose();
    _strategiTgl28Ctrl.dispose();
    super.dispose();
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isPercent = false, bool isCurrency = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            suffixText: isPercent ? '%' : (isCurrency ? 'Rp' : null),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
        ),
        ...children,
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onSave({
        'target_nilai_kpi': _targetNilaiKpiCtrl.text,
        
        'target_omzet': _targetOmzetCtrl.text,
        'bobot_omzet': _bobotOmzetCtrl.text,
        
        'target_closing_rate': _targetClosingRateCtrl.text,
        'bobot_closing_rate': _bobotClosingRateCtrl.text,
        
        'target_closing_chat': _targetClosingChatCtrl.text,
        'bobot_closing_chat': _bobotClosingChatCtrl.text,
        
        'target_stock_opname': _targetStockOpnameCtrl.text,
        'bobot_stock_opname': _bobotStockOpnameCtrl.text,
        'nilai_stock_opname': _nilaiStockOpnameCtrl.text,
        
        'target_review_maps': _targetReviewMapsCtrl.text,
        'bobot_review_maps': _bobotReviewMapsCtrl.text,
        'nilai_review_maps': _nilaiReviewMapsCtrl.text,
        
        'strategi_tgl_7': _strategiTgl7Ctrl.text,
        'strategi_tgl_14': _strategiTgl14Ctrl.text,
        'strategi_tgl_21': _strategiTgl21Ctrl.text,
        'strategi_tgl_28': _strategiTgl28Ctrl.text,
      });
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cabangName = widget.initialData['nama_cabang'] ?? 'Cabang';
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Edit KPI Cabang - $cabangName',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    _buildSection('Target Nilai KPI (Total)', [
                      _buildTextField('Target Total Nilai KPI', _targetNilaiKpiCtrl),
                    ]),
                    
                    _buildSection('Omzet (AUTO Dari Order)', [
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Target Omzet (Rp)', _targetOmzetCtrl)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Bobot Omzet (%)', _bobotOmzetCtrl, isPercent: true)),
                        ],
                      ),
                    ]),

                    _buildSection('Closing Rate (AUTO Dari Chat)', [
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Target Closing Rate (%)', _targetClosingRateCtrl, isPercent: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Bobot Closing Rate (%)', _bobotClosingRateCtrl, isPercent: true)),
                        ],
                      ),
                    ]),

                    _buildSection('Closing Chat (AUTO Dari Chat)', [
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Target Closing Chat', _targetClosingChatCtrl)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Bobot Closing Chat (%)', _bobotClosingChatCtrl, isPercent: true)),
                        ],
                      ),
                    ]),

                    _buildSection('Stock Opname (Manual)', [
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Target', _targetStockOpnameCtrl)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Bobot (%)', _bobotStockOpnameCtrl, isPercent: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Nilai Capaian', _nilaiStockOpnameCtrl)),
                        ],
                      ),
                    ]),

                    _buildSection('Review Maps (Manual)', [
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Target', _targetReviewMapsCtrl)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Bobot (%)', _bobotReviewMapsCtrl, isPercent: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Nilai Capaian', _nilaiReviewMapsCtrl)),
                        ],
                      ),
                    ]),

                    _buildSection('Strategi Pencapaian', [
                      _buildTextField('Tgl 7 (25%)', _strategiTgl7Ctrl),
                      const SizedBox(height: 12),
                      _buildTextField('Tgl 14 (50%)', _strategiTgl14Ctrl),
                      const SizedBox(height: 12),
                      _buildTextField('Tgl 21 (75%)', _strategiTgl21Ctrl),
                      const SizedBox(height: 12),
                      _buildTextField('Tgl 28 (100%)', _strategiTgl28Ctrl),
                    ]),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Simpan KPI',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
