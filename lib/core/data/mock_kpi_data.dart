import 'kpi_model.dart';

final PeriodeKpi mockPeriodeKpi = PeriodeKpi(
  id: 1,
  bulan: '05',
  tahun: 2026,
  namaPeriode: 'Mei 2026',
);

final List<IndikatorKpi> mockIndikatorKpi = [
  IndikatorKpi(id: 1, namaIndikator: 'Omzet', satuan: 'Rupiah', tipeNilai: 'Angka'),
  IndikatorKpi(id: 2, namaIndikator: 'Closing Rate', satuan: '%', tipeNilai: 'Persentase'),
  IndikatorKpi(id: 3, namaIndikator: 'Closing Chat', satuan: 'Kali', tipeNilai: 'Angka'),
  IndikatorKpi(id: 4, namaIndikator: 'Stock opname', satuan: 'Kali', tipeNilai: 'Angka'),
  IndikatorKpi(id: 5, namaIndikator: 'Review Maps', satuan: 'Review', tipeNilai: 'Angka'),
];

final List<TargetKpi> mockTargetKpi = [
  TargetKpi(
    id: 1, karyawanId: 'CS-001', periode: mockPeriodeKpi, indikator: mockIndikatorKpi[0],
    target: 15000000, bobot: 40, keterangan: '',
    capaian: CapaianKpi(id: 1, targetKpiId: 1, nilaiCapaian: 7855000, catatan: ''),
  ),
  TargetKpi(
    id: 2, karyawanId: 'CS-001', periode: mockPeriodeKpi, indikator: mockIndikatorKpi[1],
    target: 50, bobot: 20, keterangan: '',
    capaian: CapaianKpi(id: 2, targetKpiId: 2, nilaiCapaian: 41, catatan: ''),
  ),
  TargetKpi(
    id: 3, karyawanId: 'CS-001', periode: mockPeriodeKpi, indikator: mockIndikatorKpi[2],
    target: 1, bobot: 20, keterangan: '',
    capaian: CapaianKpi(id: 3, targetKpiId: 3, nilaiCapaian: 1, catatan: ''),
  ),
  TargetKpi(
    id: 4, karyawanId: 'CS-001', periode: mockPeriodeKpi, indikator: mockIndikatorKpi[3],
    target: 2, bobot: 10, keterangan: '',
    capaian: CapaianKpi(id: 4, targetKpiId: 4, nilaiCapaian: 2, catatan: ''),
  ),
  TargetKpi(
    id: 5, karyawanId: 'CS-001', periode: mockPeriodeKpi, indikator: mockIndikatorKpi[4],
    target: 10, bobot: 10, keterangan: '',
    capaian: CapaianKpi(id: 5, targetKpiId: 5, nilaiCapaian: 1, catatan: ''),
  ),
];
