import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../haptics.dart';

/// Side of the square avatar that gets uploaded. Large enough for the biggest
/// place an avatar is drawn (the profile header at 3x) without shipping a
/// camera-sized photo.
const int _avatarPixels = 512;

/// What the crop screen pops with when the user asks for a different photo,
/// as opposed to `null` for "cancel".
const Object _choseAnother = #choseAnother;

/// Opens the gallery, lets the user frame the photo, and returns a square,
/// backend-ready avatar (JPEG bytes), or null if they backed out.
Future<Uint8List?> pickAndCropAvatar(
  BuildContext context, {
  required Color accent,
}) async {
  while (true) {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 3072,
      maxHeight: 3072,
      imageQuality: 92,
      requestFullMetadata: false,
    );
    if (picked == null || !context.mounted) return null;

    final bytes = await picked.readAsBytes();
    if (!context.mounted) return null;
    final result = await Navigator.of(context).push<Object>(
      PageRouteBuilder<Object>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, animation, __) => AvatarCropperScreen(
          bytes: bytes,
          accent: accent,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(animation),
            child: child,
          ),
        ),
      ),
    );
    if (result is Uint8List) return result;
    if (!identical(result, _choseAnother)) return null;
    if (!context.mounted) return null;
  }
}

/// The region of the source image the user has framed, in source pixels.
///
/// The photo is shown "cover" fitted inside a square viewport of side
/// [viewport] (its shorter side exactly fills it), and the viewer's
/// [transform] pans and zooms that picture. Inverting the transform turns the
/// viewport's corners back into positions on the photo, which is what the
/// user is looking at and therefore what must be saved.
@visibleForTesting
Rect avatarCropRect({
  required Size image,
  required double viewport,
  required Matrix4 transform,
}) {
  final cover = viewport / math.min(image.width, image.height);
  final inverse = Matrix4.tryInvert(transform) ?? Matrix4.identity();
  final topLeft = MatrixUtils.transformPoint(inverse, Offset.zero) / cover;
  final bottomRight =
      MatrixUtils.transformPoint(inverse, Offset(viewport, viewport)) / cover;
  final framed = Rect.fromPoints(topLeft, bottomRight);

  // Float error, or a gesture caught mid-flight, can leave a hair outside the
  // photo. Slide the square back in rather than sampling beyond the edge.
  final side = math.min(framed.width, math.min(image.width, image.height));
  final left = framed.left.clamp(0.0, image.width - side);
  final top = framed.top.clamp(0.0, image.height - side);
  return Rect.fromLTWH(left, top, side, side);
}

/// JPEG quality of the saved avatar. 88 is visually lossless at this size and
/// lands a photo around 40-70 KB, where the same square as a PNG is 10x that.
const int _avatarJpegQuality = 88;

/// Draws [source] from [image] into a [_avatarPixels] square and encodes it as
/// a JPEG.
///
/// A JPEG, not the PNG the engine can write directly: an avatar is a photo, and
/// it is fetched by every list that shows a face (the leaderboard loads dozens
/// at once). The encoder is the pure-Dart one in `package:image`.
@visibleForTesting
Future<Uint8List> renderAvatarJpeg(ui.Image image, Rect source) async {
  final target =
      Rect.fromLTWH(0, 0, _avatarPixels.toDouble(), _avatarPixels.toDouble());
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  // JPEG has no alpha: a transparent source would come out black without this.
  canvas.drawRect(target, Paint()..color = Colors.white);
  canvas.drawImageRect(
    image,
    source,
    target,
    Paint()..filterQuality = FilterQuality.high,
  );
  final picture = recorder.endRecording();
  final output = await picture.toImage(_avatarPixels, _avatarPixels);
  try {
    final pixels = await output.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (pixels == null) throw StateError('Could not read avatar pixels');
    final frame = img.Image.fromBytes(
      width: _avatarPixels,
      height: _avatarPixels,
      bytes: pixels.buffer,
      numChannels: 4,
    );
    return Uint8List.fromList(
      img.encodeJpg(frame, quality: _avatarJpegQuality),
    );
  } finally {
    output.dispose();
    picture.dispose();
  }
}

class AvatarCropperScreen extends StatefulWidget {
  const AvatarCropperScreen(
      {super.key, required this.bytes, required this.accent});

  final Uint8List bytes;
  final Color accent;

  @override
  State<AvatarCropperScreen> createState() => _AvatarCropperScreenState();
}

class _AvatarCropperScreenState extends State<AvatarCropperScreen> {
  final TransformationController _transform = TransformationController();
  ui.Image? _image;
  bool _failed = false;
  bool _busy = false;

  /// Side of the crop square as last laid out, needed to read the framing
  /// back out of [_transform].
  double? _viewport;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void dispose() {
    _image?.dispose();
    _transform.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// The picture starts centred, with its shorter side filling the square.
  Matrix4 _centred(ui.Image image, double viewport) {
    final cover = viewport / math.min(image.width, image.height);
    return Matrix4.translationValues(
      -(image.width * cover - viewport) / 2,
      -(image.height * cover - viewport) / 2,
      0,
    );
  }

  void _syncViewport(ui.Image image, double viewport) {
    if (_viewport == viewport) return;
    final first = _viewport == null;
    _viewport = viewport;
    final start = _centred(image, viewport);
    if (first) {
      // Nothing is listening to the controller yet, so this is safe mid-build.
      _transform.value = start;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _transform.value = start;
      });
    }
  }

  void _reset() {
    final image = _image;
    final viewport = _viewport;
    if (image == null || viewport == null) return;
    setState(() => _transform.value = _centred(image, viewport));
  }

  Future<void> _usePhoto() async {
    final image = _image;
    final viewport = _viewport;
    if (_busy || image == null || viewport == null) return;
    setState(() => _busy = true);
    try {
      final source = avatarCropRect(
        image: Size(image.width.toDouble(), image.height.toDouble()),
        viewport: viewport,
        transform: _transform.value,
      );
      final output = await renderAvatarJpeg(image, source);
      if (mounted) Navigator.of(context).pop(output);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("That photo couldn't be opened.")),
        );
      }
    }
  }

  Widget _cropArea() {
    final image = _image;
    if (_failed) {
      return const Center(
        child: Text(
          "That photo couldn't be opened.",
          style: TextStyle(color: Colors.white70, fontSize: 15),
        ),
      );
    }
    if (image == null) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final side =
            (constraints.biggest.shortestSide - 40).clamp(200.0, 420.0);
        _syncViewport(image, side);
        final cover = side / math.min(image.width, image.height);
        return Center(
          child: Semantics(
            label: 'Photo crop area. Drag to move, pinch to zoom.',
            child: SizedBox.square(
              dimension: side,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  InteractiveViewer(
                    transformationController: _transform,
                    constrained: false,
                    minScale: 1,
                    maxScale: 5,
                    // Zero: the photo can never be dragged clear of the crop
                    // square, so the saved avatar is always fully covered.
                    boundaryMargin: EdgeInsets.zero,
                    child: RawImage(
                      image: image,
                      width: image.width * cover,
                      height: image.height * cover,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _CropOverlayPainter(widget.accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final ready = _image != null && !_busy;
    return Scaffold(
      backgroundColor: const Color(0xFF0E1116),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Cancel',
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Adjust photo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: widget.accent),
                    onPressed: ready ? _reset : null,
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            Expanded(child: _cropArea()),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + safe.bottom / 2),
              child: Column(
                children: [
                  const Text(
                    'Drag to move · Pinch to zoom',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.accent,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: ready
                          ? () {
                              HolyHaptics.success();
                              _usePhoto();
                            }
                          : null,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text(
                              'Use photo',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: widget.accent),
                    onPressed: _busy
                        ? null
                        : () => Navigator.pop(context, _choseAnother),
                    child: const Text('Choose a different photo'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dims everything outside the circle the avatar will be shown in and rings
/// it. The saved image is the whole square: apps clip it to a circle.
class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter(this.accent);
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final outside = Path()..addRect(Offset.zero & size);
    final circle = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(
      Path.combine(PathOperation.difference, outside, circle),
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent,
    );
  }

  @override
  bool shouldRepaint(_CropOverlayPainter oldDelegate) =>
      oldDelegate.accent != accent;
}
