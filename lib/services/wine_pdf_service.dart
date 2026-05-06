import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/wine.dart';
import '../models/bottle.dart';

import 'wine_pdf_service_web.dart' if (dart.library.io) 'wine_pdf_service_mobile.dart'
    as platform;

void openWinePrintSheet(Wine wine, List<Bottle> bottles) {
  platform.openWinePrintSheetImpl(wine, bottles);
}

void exportInventoryCsv(List<Wine> wines, List<Bottle> bottles) {
  platform.exportInventoryCsvImpl(wines, bottles);
}

void exportInventoryPdf(List<Wine> wines, List<Bottle> bottles) {
  platform.exportInventoryPdfImpl(wines, bottles);
}
