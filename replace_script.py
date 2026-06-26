import re

file_path = r'c:\Users\HP VICTUS\Documents\Mobile\lib\features\orders\screens\order_detail_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

start_marker = '  Future<void> _showAturLayananSingleModal('
end_marker = '  Future<void> _showAssignCleanerModal('

start_index = content.find(start_marker)
end_index = content.find(end_marker)

if start_index != -1 and end_index != -1:
    new_modal = r'''  Future<void> _showAturQtyHargaDropdownModal(OrderModel o) async {
    if (o.services.isEmpty) return;
    
    ServiceItem selectedService = o.services.first;
    final qtyCtrl = TextEditingController(text: selectedService.qty);
    final String initialHarga = selectedService.price > 0 
        ? selectedService.price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')
        : '';
    final hargaCtrl = TextEditingController(text: initialHarga);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(modalContext).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Text('Atur Qty / Harga', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 16),
                  
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ServiceItem>(
                        isExpanded: true,
                        value: selectedService,
                        items: o.services.map((s) {
                          return DropdownMenuItem<ServiceItem>(
                            value: s,
                            child: Text(s.name, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark)),
                          );
                        }).toList(),
                        onChanged: (ServiceItem? val) {
                          if (val != null) {
                            setStateModal(() {
                              selectedService = val;
                              qtyCtrl.text = val.qty;
                              hargaCtrl.text = val.price > 0 
                                  ? val.price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')
                                  : '';
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Qty', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: qtyCtrl,
                          decoration: InputDecoration(
                            hintText: 'Misal: 3 jam 2 cleaner',
                            filled: true, fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Harga Layanan', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: hargaCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [CurrencyInputFormatter()],
                          decoration: InputDecoration(
                            hintText: 'Misal: 150.000',
                            filled: true, fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(modalContext);
                      if (!mounted) return;
                      setState(() => _isLoading = true);
                      try {
                        final updatedServices = o.services.map((s) {
                          if (s.id == selectedService.id && s.name == selectedService.name) {
                            return ServiceItem(
                              id: s.id,
                              layananId: s.layananId,
                              name: s.name,
                              price: int.tryParse(hargaCtrl.text.replace('.', '')) ?? s.price,
                              qty: qtyCtrl.text.isNotEmpty ? qtyCtrl.text : s.qty,
                              tanggalPengerjaan: s.tanggalPengerjaan,
                              waktuPengerjaan: s.waktuPengerjaan,
                              bonusLayanan: s.bonusLayanan,
                            );
                          }
                          return s;
                        }).toList();

                        final draft = OrderDraft(
                          customer: o.customer,
                          chatDari: o.chatDari,
                          tipeCustomer: o.tipeCustomer,
                          services: updatedServices,
                          cleaners: o.cleaners,
                          notes: o.notes,
                        );
                        
                        await _orderService.updateOrder(o.id, draft);
                        if (!mounted) return;
                        _fetchDetail();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Layanan berhasil diperbarui!'), backgroundColor: AppColors.statusDone));
                      } catch (e) {
                        if (!mounted) return;
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Simpan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

'''
    new_content = content[:start_index] + new_modal + content[end_index:]
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("SUCCESS")
else:
    print(f"FAILED TO FIND MARKERS: {start_index} {end_index}")
