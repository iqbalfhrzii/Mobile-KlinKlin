import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../services/chat_service.dart';

class ChatHarianScreen extends StatefulWidget {
  const ChatHarianScreen({super.key});

  @override
  State<ChatHarianScreen> createState() => _ChatHarianScreenState();
}

class _ChatHarianScreenState extends State<ChatHarianScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cbOrganikCtrl = TextEditingController();
  final _cbIklanCtrl = TextEditingController();
  final _cLamaCtrl = TextEditingController();
  
  final _closingCbOrganikCtrl = TextEditingController();
  final _closingCbIklanCtrl = TextEditingController();
  final _closingCLamaCtrl = TextEditingController();
  
  final _jmlOrderanCtrl = TextEditingController();
  final _telpCtrl = TextEditingController();
  
  final ChatService _service = ChatService();
  
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isLoadingHistory = true;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final data = await _service.getChatHarian();
      if (mounted) {
        setState(() {
          _history = data;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      await _service.submitChatHarian(
        date: _selectedDate,
        custBaruOrganik: int.tryParse(_cbOrganikCtrl.text) ?? 0,
        custBaruIklan: int.tryParse(_cbIklanCtrl.text) ?? 0,
        custLama: int.tryParse(_cLamaCtrl.text) ?? 0,
        closingOrganik: int.tryParse(_closingCbOrganikCtrl.text) ?? 0,
        closingIklan: int.tryParse(_closingCbIklanCtrl.text) ?? 0,
        closingLama: int.tryParse(_closingCLamaCtrl.text) ?? 0,
        jumlahOrderan: int.tryParse(_jmlOrderanCtrl.text) ?? 0,
        telp: int.tryParse(_telpCtrl.text) ?? 0,
      );
      
      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Data chat berhasil disimpan');
        _cbOrganikCtrl.clear();
        _cbIklanCtrl.clear();
        _cLamaCtrl.clear();
        _closingCbOrganikCtrl.clear();
        _closingCbIklanCtrl.clear();
        _closingCLamaCtrl.clear();
        _jmlOrderanCtrl.clear();
        _telpCtrl.clear();
        _loadHistory();
      }
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
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
                    Text('Input Chat Harian', style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white,
                    )),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Masukkan jumlah chat dan orderan yang masuk hari ini', style: GoogleFonts.inter(
                  fontSize: 14, color: Colors.white.withOpacity(0.8),
                )),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildForm(),
                  const SizedBox(height: 30),
                  Text('Riwayat 7 Hari Terakhir', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 16),
                  _buildHistory(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TANGGAL
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tanggal', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd MMM yyyy').format(_selectedDate),
                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark),
                        ),
                      ],
                    ),
                  ),
                ),
              ]
            ),
          ),
          const SizedBox(height: 16),
          
          // CUSTOMER BARU & LAMA
          _buildCard(
            title: 'CUSTOMER BARU & LAMA',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildInputField('Cust Baru Organik', _cbOrganikCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildInputField('Cust Baru Iklan', _cbIklanCtrl)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInputField('Cust Lama', _cLamaCtrl),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // CLOSING
          _buildCard(
            title: 'CLOSING',
            titleColor: const Color(0xFF059669),
            borderColor: const Color(0xFF059669).withOpacity(0.3),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildInputField('Closing Cust Baru Organik', _closingCbOrganikCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildInputField('Closing Cust Baru Iklan', _closingCbIklanCtrl)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInputField('Closing Cust Lama', _closingCLamaCtrl),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // LAINNYA
          _buildCard(
            title: 'LAINNYA',
            child: Row(
              children: [
                Expanded(child: _buildInputField('Jumlah Orderan', _jmlOrderanCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _buildInputField('Telp', _telpCtrl)),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Simpan Data Chat', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCard({String? title, Color? titleColor, Color? borderColor, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: titleColor ?? AppColors.textDark)),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '0',
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
          ),
          validator: (val) => val == null || val.isEmpty ? 'Wajib' : null,
        ),
      ],
    );
  }

  Widget _buildHistory() {
    if (_isLoadingHistory) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
    }
    
    if (_history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Belum ada riwayat', style: GoogleFonts.inter(color: AppColors.textMuted)),
        ),
      );
    }
    
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _history[index];
        final total = (item['cust_baru_organik'] ?? 0) + (item['cust_baru_iklan'] ?? 0) + (item['cust_lama'] ?? 0);
        final date = DateTime.parse(item['tanggal']);
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('dd MMMM yyyy').format(date), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 4),
                  Text('Cust Baru: ${(item['cust_baru_organik'] ?? 0) + (item['cust_baru_iklan'] ?? 0)} | Lama: ${item['cust_lama'] ?? 0}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                  Text('Closing Baru: ${(item['closing_cust_baru_organik'] ?? 0) + (item['closing_cust_baru_iklan'] ?? 0)} | Order: ${item['jumlah_orderan'] ?? 0}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppColors.surfaceBlue, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: [
                    Text('Chat', style: GoogleFonts.inter(fontSize: 10, color: AppColors.primary)),
                    Text('${total}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
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
