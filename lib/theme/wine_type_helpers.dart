import 'package:flutter/material.dart';
import '../models/wine.dart';

Color wineTypeColor(WineType t) {
  switch (t) {
    case WineType.rouge:
      return const Color(0xFFB23A48);
    case WineType.blanc:
      return const Color(0xFFE6D27A);
    case WineType.rose:
      return const Color(0xFFE89DA6);
    case WineType.orange:
      return const Color(0xFFE08A3C);
    case WineType.petillant:
      return const Color(0xFFB8C9D9);
  }
}

String wineTypeLabel(WineType t) {
  switch (t) {
    case WineType.rouge:
      return 'ROUGE';
    case WineType.blanc:
      return 'BLANC';
    case WineType.rose:
      return 'ROSÉ';
    case WineType.orange:
      return 'ORANGE';
    case WineType.petillant:
      return 'PÉTILLANT';
  }
}
