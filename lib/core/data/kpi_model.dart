class PeriodeKpi {
  final int id;
  final String bulan;
  final int tahun;
  final String namaPeriode;

  PeriodeKpi({
    required this.id,
    required this.bulan,
    required this.tahun,
    required this.namaPeriode,
  });
}

class IndikatorKpi {
  final int id;
  final String namaIndikator;
  final String satuan;
  final String tipeNilai; // e.g. "Persentase", "Angka", dsb.

  IndikatorKpi({
    required this.id,
    required this.namaIndikator,
    required this.satuan,
    required this.tipeNilai,
  });
}

class CapaianKpi {
  final int id;
  final int targetKpiId;
  final double nilaiCapaian;
  final String catatan;

  CapaianKpi({
    required this.id,
    required this.targetKpiId,
    required this.nilaiCapaian,
    required this.catatan,
  });
}

class TargetKpi {
  final int id;
  final String karyawanId;
  final PeriodeKpi periode;
  final IndikatorKpi indikator;
  final double target;
  final double bobot;
  final String keterangan;
  final CapaianKpi? capaian;

  TargetKpi({
    required this.id,
    required this.karyawanId,
    required this.periode,
    required this.indikator,
    required this.target,
    required this.bobot,
    required this.keterangan,
    this.capaian,
  });
}
