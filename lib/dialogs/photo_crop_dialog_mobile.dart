import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

const _cropRatio = 3.0 / 4.0;

Future<Uint8List?> showPhotoCropDialogImpl(
  BuildContext context,
  Uint8List imageBytes,
) {
  return showDialog<Uint8List>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    barrierDismissible: false,
    builder: (_) => _PhotoCropDialog(imageBytes: imageBytes),
  );
}

class _PhotoCropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  const _PhotoCropDialog({required this.imageBytes});

  @override
  State<_PhotoCropDialog> createState() => _PhotoCropDialogState();
}

class _PhotoCropDialogState extends State<_PhotoCropDialog> {
  int _imgW = 0;
  int _imgH = 0;
  bool _loaded = false;
  bool _cropping = false;

  double _cx = 0, _cy = 0, _cw = 1, _ch = 1;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() {
      _imgW = frame.image.width;
      _imgH = frame.image.height;
      _loaded = true;
      _initCropRect();
    });
  }

  void _initCropRect() {
    final imgRatio = _imgW / _imgH;
    if (imgRatio > _cropRatio) {
      _ch = 1.0;
      _cw = (_cropRatio / imgRatio);
      _cx = (1.0 - _cw) / 2;
      _cy = 0;
    } else {
      _cw = 1.0;
      _ch = (imgRatio / _cropRatio);
      _cx = 0;
      _cy = (1.0 - _ch) / 2;
    }
  }

  Future<void> _doCrop() async {
    setState(() => _cropping = true);

    final sx = (_cx * _imgW).round();
    final sy = (_cy * _imgH).round();
    final sw = (_cw * _imgW).round();
    final sh = (_ch * _imgH).round();

    final decoded = img.decodeImage(widget.imageBytes);
    if (decoded == null) {
      if (mounted) Navigator.of(context).pop(null);
      return;
    }
    final cropped = img.copyCrop(decoded, x: sx, y: sy, width: sw, height: sh);
    final bytes = Uint8List.fromList(img.encodeJpg(cropped, quality: 92));

    if (mounted) Navigator.of(context).pop(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final dialogW = (screenW - 40).clamp(280.0, 500.0);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: dialogW,
          height: dialogW * 1.24,
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'CADRER LA PHOTO',
                      style: AppText.sans(
                        color: AppColors.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      icon: const Icon(Icons.close, color: AppColors.text3, size: 20),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _loaded
                      ? _CropArea(
                          imageBytes: widget.imageBytes,
                          imgW: _imgW,
                          imgH: _imgH,
                          cx: _cx, cy: _cy, cw: _cw, ch: _ch,
                          onChanged: (cx, cy, cw, ch) {
                            _cx = cx; _cy = cy; _cw = cw; _ch = ch;
                          },
                        )
                      : const Center(
                          child: CircularProgressIndicator(color: AppColors.gold),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: Text(
                        'Annuler',
                        style: AppText.sans(color: AppColors.text3, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _cropping ? null : _doCrop,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.bg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      ),
                      child: _cropping
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                            )
                          : Text(
                              'Valider',
                              style: AppText.sans(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CropArea extends StatefulWidget {
  final Uint8List imageBytes;
  final int imgW, imgH;
  final double cx, cy, cw, ch;
  final void Function(double cx, double cy, double cw, double ch) onChanged;

  const _CropArea({
    required this.imageBytes,
    required this.imgW, required this.imgH,
    required this.cx, required this.cy, required this.cw, required this.ch,
    required this.onChanged,
  });

  @override
  State<_CropArea> createState() => _CropAreaState();
}

class _CropAreaState extends State<_CropArea> {
  late double _cx, _cy, _cw, _ch;

  @override
  void initState() {
    super.initState();
    _cx = widget.cx; _cy = widget.cy;
    _cw = widget.cw; _ch = widget.ch;
  }

  Rect _imgRect(Size size) {
    final imgRatio = widget.imgW / widget.imgH;
    final boxRatio = size.width / size.height;
    double w, h;
    if (imgRatio > boxRatio) {
      w = size.width;
      h = size.width / imgRatio;
    } else {
      h = size.height;
      w = size.height * imgRatio;
    }
    return Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);
  }

  Rect _cropScreenRect(Rect imgRect) {
    return Rect.fromLTWH(
      imgRect.left + _cx * imgRect.width,
      imgRect.top + _cy * imgRect.height,
      _cw * imgRect.width,
      _ch * imgRect.height,
    );
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    final ir = _imgRect(size);
    final dx = d.delta.dx / ir.width;
    final dy = d.delta.dy / ir.height;
    setState(() {
      _cx = (_cx + dx).clamp(0.0, 1.0 - _cw);
      _cy = (_cy + dy).clamp(0.0, 1.0 - _ch);
    });
    widget.onChanged(_cx, _cy, _cw, _ch);
  }

  void _onCornerDrag(DragUpdateDetails d, Size size, int corner) {
    final ir = _imgRect(size);
    final dx = d.delta.dx / ir.width;
    final minSize = 0.1;

    double nx = _cx, ny = _cy, nw = _cw, nh = _ch;

    if (corner == 0 || corner == 3) {
      nx = (_cx + dx).clamp(0.0, _cx + _cw - minSize);
      nw = _cw - (nx - _cx);
    } else {
      nw = (_cw + dx).clamp(minSize, 1.0 - _cx);
    }

    nh = nw / _cropRatio * (widget.imgW / widget.imgH);

    if (corner == 0 || corner == 1) {
      ny = _cy + _ch - nh;
      if (ny < 0) {
        ny = 0;
        nh = _cy + _ch;
        nw = nh * _cropRatio * (widget.imgH / widget.imgW);
        if (corner == 0) nx = _cx + _cw - nw;
      }
    } else {
      if (ny + nh > 1.0) {
        nh = 1.0 - ny;
        nw = nh * _cropRatio * (widget.imgH / widget.imgW);
        if (corner == 3) nx = _cx + _cw - nw;
      }
    }

    if (nx >= 0 && ny >= 0 && nx + nw <= 1.001 && ny + nh <= 1.001 && nw > minSize && nh > minSize) {
      setState(() { _cx = nx; _cy = ny; _cw = nw; _ch = nh; });
      widget.onChanged(_cx, _cy, _cw, _ch);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final size = constraints.biggest;
      final ir = _imgRect(size);
      final cr = _cropScreenRect(ir);

      return Stack(
        children: [
          Positioned.fill(
            child: Image.memory(widget.imageBytes, fit: BoxFit.contain),
          ),
          ..._buildOverlay(ir, cr),
          Positioned.fromRect(
            rect: cr,
            child: GestureDetector(
              onPanUpdate: (d) => _onPanUpdate(d, size),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.gold, width: 2),
                ),
              ),
            ),
          ),
          ..._buildGrid(cr),
          for (int i = 0; i < 4; i++)
            _cornerHandle(cr, i, size),
        ],
      );
    });
  }

  List<Widget> _buildOverlay(Rect ir, Rect cr) {
    final color = Colors.black.withValues(alpha: 0.6);
    return [
      if (cr.top > ir.top)
        Positioned(left: ir.left, top: ir.top, width: ir.width, height: cr.top - ir.top,
          child: Container(color: color)),
      if (cr.bottom < ir.bottom)
        Positioned(left: ir.left, top: cr.bottom, width: ir.width, height: ir.bottom - cr.bottom,
          child: Container(color: color)),
      Positioned(left: ir.left, top: cr.top, width: cr.left - ir.left, height: cr.height,
        child: Container(color: color)),
      Positioned(left: cr.right, top: cr.top, width: ir.right - cr.right, height: cr.height,
        child: Container(color: color)),
    ];
  }

  List<Widget> _buildGrid(Rect cr) {
    return [
      for (int i = 1; i < 3; i++)
        Positioned(
          left: cr.left, top: cr.top + cr.height * i / 3,
          child: SizedBox(
            width: cr.width,
            child: Divider(height: 0.5, thickness: 0.5, color: Colors.white.withValues(alpha: 0.3)),
          ),
        ),
      for (int i = 1; i < 3; i++)
        Positioned(
          left: cr.left + cr.width * i / 3, top: cr.top,
          child: SizedBox(
            height: cr.height,
            child: VerticalDivider(width: 0.5, thickness: 0.5, color: Colors.white.withValues(alpha: 0.3)),
          ),
        ),
    ];
  }

  Widget _cornerHandle(Rect cr, int corner, Size size) {
    const hs = 28.0;
    double left, top;
    switch (corner) {
      case 0: left = cr.left - hs / 2; top = cr.top - hs / 2;
      case 1: left = cr.right - hs / 2; top = cr.top - hs / 2;
      case 2: left = cr.right - hs / 2; top = cr.bottom - hs / 2;
      default: left = cr.left - hs / 2; top = cr.bottom - hs / 2;
    }
    return Positioned(
      left: left, top: top, width: hs, height: hs,
      child: GestureDetector(
        onPanUpdate: (d) => _onCornerDrag(d, size, corner),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.gold,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}
