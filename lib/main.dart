import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_sentryDsn.isEmpty) {
    runApp(const ReadingPaceApp());
    return;
  }

  await SentryFlutter.init(
    (SentryFlutterOptions options) {
      options.dsn = _sentryDsn;
      options.sendDefaultPii = false;
      options.tracesSampleRate = 0;
      options.profilesSampleRate = 0;
      options.enableAutoSessionTracking = false;
      options.maxBreadcrumbs = 0;
    },
    appRunner: () => runApp(const ReadingPaceApp()),
  );
}

class ReadingPaceApp extends StatelessWidget {
  const ReadingPaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PageRun',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE60023),
        ).copyWith(
          primary: const Color(0xFFE60023),
          onPrimary: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFE60023),
          foregroundColor: Colors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE60023),
            foregroundColor: Colors.white,
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          indicatorColor: Color(0x33E60023),
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class ReadingRecord {
  const ReadingRecord({
    required this.recordedAt,
    required this.duration,
    required this.bookName,
    required this.startPage,
    required this.endPage,
    required this.pagesRead,
    required this.pacePerMinute,
    required this.photoPaths,
    required this.mainPhotoPath,
  });

  final DateTime recordedAt;
  final Duration duration;
  final String? bookName;
  final int startPage;
  final int endPage;
  final int pagesRead;
  final double pacePerMinute;
  final List<String> photoPaths;
  final String? mainPhotoPath;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'recordedAt': recordedAt.toIso8601String(),
      'durationSeconds': duration.inSeconds,
      'bookName': bookName,
      'startPage': startPage,
      'endPage': endPage,
      'pagesRead': pagesRead,
      'pacePerMinute': pacePerMinute,
      'photoPaths': photoPaths,
      'mainPhotoPath': mainPhotoPath,
    };
  }

  factory ReadingRecord.fromJson(Map<String, dynamic> json) {
    final List<dynamic> photoPathValues = (json['photoPaths'] as List<dynamic>? ?? <dynamic>[]);
    return ReadingRecord(
      recordedAt: DateTime.tryParse(json['recordedAt'] as String? ?? '') ?? DateTime.now(),
      duration: Duration(seconds: _asInt(json['durationSeconds'])),
      bookName: json['bookName'] as String?,
      startPage: _asInt(json['startPage']),
      endPage: _asInt(json['endPage']),
      pagesRead: _asInt(json['pagesRead']),
      pacePerMinute: _asDouble(json['pacePerMinute']),
      photoPaths: photoPathValues.map((dynamic value) => value.toString()).toList(),
      mainPhotoPath: json['mainPhotoPath'] as String?,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const String _recordsStorageKey = 'reading_records_v1';
  int _selectedIndex = 0;
  final List<ReadingRecord> _records = <ReadingRecord>[];

  @override
  void initState() {
    super.initState();
    _loadSavedRecords();
  }

  List<String> _bookNameOptions() {
    final Set<String> seen = <String>{};
    final List<String> names = <String>[];

    for (final ReadingRecord record in _records) {
      final String? name = record.bookName;
      if (name == null || name.isEmpty || seen.contains(name)) {
        continue;
      }

      seen.add(name);
      names.add(name);
    }

    return names;
  }

  Map<String, int> _latestEndPageByBook() {
    final Map<String, int> latestEndPageByBook = <String, int>{};

    for (final ReadingRecord record in _records) {
      final String? name = record.bookName;
      if (name == null || name.isEmpty || latestEndPageByBook.containsKey(name)) {
        continue;
      }

      latestEndPageByBook[name] = record.endPage;
    }

    return latestEndPageByBook;
  }

  void _addRecord(ReadingRecord record) {
    setState(() {
      _records.insert(0, record);
      _selectedIndex = 0;
    });
    _saveRecords();
  }

  Future<void> _loadSavedRecords() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_recordsStorageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final List<ReadingRecord> loaded = decoded
          .whereType<Map<String, dynamic>>()
          .map(ReadingRecord.fromJson)
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _records
          ..clear()
          ..addAll(loaded);
      });
    } catch (_) {
      await prefs.remove(_recordsStorageKey);
    }
  }

  Future<void> _saveRecords() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> data =
        _records.map((ReadingRecord record) => record.toJson()).toList();
    await prefs.setString(_recordsStorageKey, jsonEncode(data));
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      HomeTab(
        records: _records,
        isActive: _selectedIndex == 0,
      ),
      MileageTab(records: _records),
      RecordTab(
        onSave: _addRecord,
        suggestedBookNames: _bookNameOptions(),
        lastEndPageByBook: _latestEndPageByBook(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Page Run'),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Mileage',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'Record',
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.records,
    required this.isActive,
  });

  final List<ReadingRecord> records;
  final bool isActive;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  double _dragOffset = 0;
  double _animationFrom = 0;
  double _animationTo = 0;
  VoidCallback? _pendingAnimationComplete;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 260),
      vsync: this,
    );
    _animationController.addListener(() {
      setState(() {
        _dragOffset = ui.lerpDouble(
          _animationFrom,
          _animationTo,
          _animationController.value,
        )!;
      });
    });
    _animationController.addStatusListener((AnimationStatus status) {
      if (status != AnimationStatus.completed) {
        return;
      }

      final VoidCallback? callback = _pendingAnimationComplete;
      _pendingAnimationComplete = null;
      callback?.call();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 탭이 다시 Home으로 전환되면 항상 최신(0번) 카드부터 보여준다.
    if (!oldWidget.isActive && widget.isActive) {
      if (_animationController.isAnimating) {
        _animationController.stop();
      }
      _pendingAnimationComplete = null;

      setState(() {
        _currentIndex = 0;
        _dragOffset = 0;
      });
    }

    // 레코드 수가 줄어 현재 인덱스가 범위를 벗어나면 안전하게 보정한다.
    if (widget.records.isNotEmpty && _currentIndex >= widget.records.length) {
      setState(() {
        _currentIndex = widget.records.length - 1;
        _dragOffset = 0;
      });
    }
  }

  void _animateDragOffsetTo(
    double targetOffset, {
    VoidCallback? onComplete,
  }) {
    final double distance = (targetOffset - _dragOffset).abs();
    final int durationMs = (140 + (distance * 0.7)).clamp(140, 360).round();

    _animationController.duration = Duration(milliseconds: durationMs);
    _animationFrom = _dragOffset;
    _animationTo = targetOffset;
    _pendingAnimationComplete = onComplete;
    _animationController.forward(from: 0);
  }

  void _moveCards(int cardCount) {
    if (cardCount == 0) {
      _snapBack();
      return;
    }

    final int newIndex = (_currentIndex + cardCount).clamp(0, widget.records.length - 1);
    if (newIndex == _currentIndex) {
      _snapBack();
      return;
    }

    final int actualMoveCount = newIndex - _currentIndex;
    final double targetOffset = actualMoveCount * 100.0;

    _animateDragOffsetTo(
      targetOffset,
      onComplete: () {
        if (!mounted) {
          return;
        }

        setState(() {
          _currentIndex = newIndex;
          _dragOffset = 0;
        });
      },
    );
  }

  void _nextCard() {
    _moveCards(1);
  }

  void _prevCard() {
    _moveCards(-1);
  }

  void _snapBack() {
    _animateDragOffsetTo(0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.records.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No records yet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final double totalProgress = _dragOffset / 100.0;
    final List<int> sortedIndices = List<int>.generate(widget.records.length, (int i) => i)
      ..sort((int a, int b) {
        final double aDepth = (a - _currentIndex - totalProgress).abs();
        final double bDepth = (b - _currentIndex - totalProgress).abs();
        return bDepth.compareTo(aDepth);
      });

    return Listener(
      onPointerSignal: (PointerSignalEvent event) {
        if (event is! PointerScrollEvent) {
          return;
        }
        if (event.scrollDelta.dy > 0) {
          _nextCard();
        } else if (event.scrollDelta.dy < 0) {
          _prevCard();
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (DragUpdateDetails details) {
          if (_animationController.isAnimating) {
            _animationController.stop();
            _pendingAnimationComplete = null;
          }

          setState(() {
            _dragOffset += details.delta.dy;
          });
        },
        onVerticalDragEnd: (DragEndDetails details) {
          const double cardDistance = 100.0;
          final int cardsMoved = (_dragOffset.abs() / cardDistance).round();

          if (cardsMoved > 0) {
            if (_dragOffset > 0) {
              _moveCards(cardsMoved);
            } else {
              _moveCards(-cardsMoved);
            }
          } else {
            _snapBack();
          }
        },
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              for (final int i in sortedIndices)
                Builder(
                  builder: (BuildContext context) {
                    final cardIndex = (i - _currentIndex).toDouble();
                    final adjustedIndex = cardIndex - totalProgress;

                    final yOffset = -(adjustedIndex * 100.0);
                    final opacity = (1 - (adjustedIndex.abs() * 0.22)).clamp(0.12, 1.0);

                    return Transform.translate(
                      offset: Offset(0, yOffset),
                      child: Opacity(
                        opacity: opacity,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _RecordCard(
                            record: widget.records[i],
                            margin: EdgeInsets.zero,
                            onTap: () {
                              final ReadingRecord selectedRecord = widget.records[i];
                              final List<String> validPhotoPaths = selectedRecord.photoPaths
                                  .where((String path) => path.isNotEmpty)
                                  .toList();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (BuildContext context) => _RecordPhotosScreen(
                                    record: selectedRecord,
                                    photoPaths: validPhotoPaths,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeRecordFocusScreen extends StatefulWidget {
  const _HomeRecordFocusScreen({
    required this.records,
    required this.initialIndex,
  });

  final List<ReadingRecord> records;
  final int initialIndex;

  @override
  State<_HomeRecordFocusScreen> createState() => _HomeRecordFocusScreenState();
}

class _HomeRecordFocusScreenState extends State<_HomeRecordFocusScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Record ${_currentIndex + 1}/${widget.records.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.records.length,
        onPageChanged: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (BuildContext context, int index) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: _RecordCard(record: widget.records[index], margin: EdgeInsets.zero),
          );
        },
      ),
    );
  }
}

class _RecordCard extends StatefulWidget {
  const _RecordCard({
    required this.record,
    this.onTap,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  final ReadingRecord record;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  @override
  State<_RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<_RecordCard> {
  double? _photoAspectRatio;

  void _openPhotoGallery() {
    final List<String> validPaths = widget.record.photoPaths
        .where((String path) => path.isNotEmpty)
        .toList();

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => _RecordPhotosScreen(
          record: widget.record,
          photoPaths: validPaths,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadPhotoAspectRatio();
  }

  @override
  void didUpdateWidget(covariant _RecordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.mainPhotoPath != widget.record.mainPhotoPath) {
      _photoAspectRatio = null;
      _loadPhotoAspectRatio();
    }
  }

  Future<void> _loadPhotoAspectRatio() async {
    final String? path = widget.record.mainPhotoPath;
    if (path == null || path.isEmpty) {
      return;
    }

    try {
      final imageBytes = await File(path).readAsBytes();
      final image = await decodeImageFromList(imageBytes);
      if (!mounted) {
        return;
      }

      setState(() {
        _photoAspectRatio = image.width / image.height;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _photoAspectRatio = 3 / 4;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ReadingRecord record = widget.record;
    final String pagesValue = '${record.pagesRead}';
    final String paceValue = '${record.pacePerMinute.toStringAsFixed(1)}p/min';
    final String timeValue = _formatHomeDuration(record.duration);
    final int maxMetricLength = <String>[pagesValue, paceValue, timeValue]
      .map((String value) => value.length)
      .fold<int>(0, (int prev, int len) => len > prev ? len : prev);
    final double metricValueFontSize = maxMetricLength >= 9
      ? 27
      : maxMetricLength >= 7
        ? 31
        : 36;
    final bool hasPhoto = record.mainPhotoPath != null && record.mainPhotoPath!.isNotEmpty;
    final double cardAspectRatio = hasPhoto
        ? (_photoAspectRatio ?? (3 / 4)).clamp(0.65, 1.2)
        : 16 / 10;

    return Container(
      margin: widget.margin,
      child: GestureDetector(
        onTap: widget.onTap ?? _openPhotoGallery,
        child: AspectRatio(
          aspectRatio: cardAspectRatio,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              image: hasPhoto
                  ? DecorationImage(
                      image: FileImage(File(record.mainPhotoPath!)),
                      fit: BoxFit.cover,
                    )
                  : null,
              gradient: hasPhoto
                  ? null
                  : const LinearGradient(
                      colors: <Color>[Color(0xFFE60023), Color(0xFFB0001A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: hasPhoto
                      ? <Color>[Color(0x22000000), Color(0xD9000000)]
                      : <Color>[Color(0x22000000), Color(0x66000000)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Stack(
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              _formatDateTime(record.recordedAt),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'PP. ${record.startPage} - ${record.endPage}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Color(0xFFE8EEF2),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: _MetricBlock(
                              label: 'Pages',
                              value: pagesValue,
                              valueFontSize: metricValueFontSize,
                            ),
                          ),
                          Expanded(
                            child: _MetricBlock(
                              label: 'Pace',
                              value: paceValue,
                              valueFontSize: metricValueFontSize,
                              useCompactUnitStyle: true,
                            ),
                          ),
                          Expanded(
                            child: _MetricBlock(
                              label: 'Time',
                              value: timeValue,
                              valueFontSize: metricValueFontSize,
                              useCompactUnitStyle: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'PAGERUN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordPhotosScreen extends StatefulWidget {
  const _RecordPhotosScreen({
    required this.record,
    required this.photoPaths,
  });

  final ReadingRecord record;
  final List<String> photoPaths;

  @override
  State<_RecordPhotosScreen> createState() => _RecordPhotosScreenState();
}

class _RecordPhotosScreenState extends State<_RecordPhotosScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _isSavingPhoto = false;
  final GlobalKey _transparentRecordKey = GlobalKey();

  int get _totalPages => widget.photoPaths.length + 1;

  bool get _isTransparentPageSelected => _currentIndex == 0;

  String _photoPathFromIndex(int pageIndex) {
    return widget.photoPaths[pageIndex - 1];
  }

  Future<Uint8List> _captureTransparentRecordImageBytes() async {
    final RenderRepaintBoundary? boundary =
        _transparentRecordKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('transparent_capture_unavailable');
    }

    final ui.Image image = await boundary.toImage(pixelRatio: 3);
    final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw Exception('transparent_capture_failed');
    }

    return bytes.buffer.asUint8List();
  }

  Future<File> _writeTransparentCaptureToPngFile(Uint8List imageBytes) async {
    final String fileName =
        'pagerun_${widget.record.recordedAt.millisecondsSinceEpoch}_${_currentIndex + 1}.png';
    final String filePath = '${Directory.systemTemp.path}${Platform.pathSeparator}$fileName';
    final File file = File(filePath);
    return file.writeAsBytes(imageBytes, flush: true);
  }

  Uint8List _normalizeImageOrientation(Uint8List imageBytes) {
    final img.Image? decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      return imageBytes;
    }

    final img.Image baked = img.bakeOrientation(decoded);
    return Uint8List.fromList(img.encodeJpg(baked, quality: 100));
  }

  Future<void> _downloadCurrentPhoto() async {
    if (_isSavingPhoto) {
      return;
    }

    setState(() {
      _isSavingPhoto = true;
    });

    try {
      bool success = false;
      if (_isTransparentPageSelected) {
        final Uint8List imageBytes = await _captureTransparentRecordImageBytes();
        final File pngFile = await _writeTransparentCaptureToPngFile(imageBytes);
        final String fileName =
            'pagerun_${widget.record.recordedAt.millisecondsSinceEpoch}_${_currentIndex + 1}';
        final dynamic result = await ImageGallerySaverPlus.saveFile(
          pngFile.path,
          name: fileName,
        );

        if (result is Map) {
          final dynamic isSuccess = result['isSuccess'];
          final dynamic hasPath = result['filePath'];
          success = isSuccess == true || (hasPath is String && hasPath.isNotEmpty);
        }
      } else {
        final String path = _photoPathFromIndex(_currentIndex);
        final File file = File(path);
        if (!await file.exists()) {
          throw Exception('photo_missing');
        }

        final Uint8List rawImageBytes = await file.readAsBytes();
        final Uint8List imageBytes = _normalizeImageOrientation(rawImageBytes);

        final String fileName =
            'pagerun_${widget.record.recordedAt.millisecondsSinceEpoch}_${_currentIndex + 1}';
        final dynamic result = await ImageGallerySaverPlus.saveImage(
          imageBytes,
          quality: 100,
          name: fileName,
        );

        if (result is Map) {
          final dynamic isSuccess = result['isSuccess'];
          final dynamic hasPath = result['filePath'];
          success = isSuccess == true || (hasPath is String && hasPath.isNotEmpty);
        }
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(success ? 'Photo saved' : 'Failed to save photo.'),
          ),
        );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('An error occurred while saving the photo. Please check permissions.')),
        );
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingPhoto = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final String? mainPhotoPath = widget.record.mainPhotoPath;
    final int mainPhotoIndex = mainPhotoPath == null
        ? -1
        : widget.photoPaths.indexOf(mainPhotoPath);
    _currentIndex = mainPhotoIndex >= 0 ? mainPhotoIndex + 1 : 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Page Records ${_currentIndex + 1}/$_totalPages'),
        actions: <Widget>[
          IconButton(
            onPressed: _isSavingPhoto ? null : _downloadCurrentPhoto,
            tooltip: 'Save Photo',
            icon: _isSavingPhoto
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _totalPages,
              onPageChanged: (int index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _CheckerboardBackground(
                        child: RepaintBoundary(
                          key: _transparentRecordKey,
                          child: _TransparentRecordPhoto(record: widget.record),
                        ),
                      ),
                    ),
                  );
                }

                final String path = _photoPathFromIndex(index);
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                        return const Center(child: Text('Unable to load photo.'));
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 78,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _totalPages,
              itemBuilder: (BuildContext context, int index) {
                final bool isSelected = index == _currentIndex;

                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  },
                  child: Container(
                    width: 64,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0x33000000),
                        width: 2,
                      ),
                    ),
                    child: index == 0
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _CheckerboardBackground(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: 90,
                                  height: 160,
                                  child: _TransparentRecordPhoto(record: widget.record),
                                ),
                              ),
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_photoPathFromIndex(index)),
                              fit: BoxFit.cover,
                              errorBuilder: (
                                BuildContext context,
                                Object error,
                                StackTrace? stackTrace,
                              ) {
                                return const ColoredBox(
                                  color: Color(0x22000000),
                                  child: Center(child: Icon(Icons.broken_image_outlined)),
                                );
                              },
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    this.valueFontSize = 36,
    this.useCompactUnitStyle = false,
  });

  final String label;
  final String value;
  final double valueFontSize;
  final bool useCompactUnitStyle;

  List<TextSpan> _buildCompactUnitSpans(TextStyle baseStyle, double unitFontSize) {
    final List<TextSpan> spans = <TextSpan>[];
    final StringBuffer buffer = StringBuffer();
    bool? currentIsUnit;

    bool isUnitChar(String char) {
      return RegExp(r'[A-Za-z/]').hasMatch(char);
    }

    void flush() {
      if (buffer.isEmpty || currentIsUnit == null) {
        return;
      }

      spans.add(
        TextSpan(
          text: buffer.toString(),
          style: currentIsUnit!
              ? baseStyle.copyWith(fontSize: unitFontSize)
              : baseStyle,
        ),
      );
      buffer.clear();
    }

    for (int i = 0; i < value.length; i++) {
      final String char = value[i];
      final bool isUnit = isUnitChar(char);
      if (currentIsUnit == null) {
        currentIsUnit = isUnit;
      }

      if (currentIsUnit != isUnit) {
        flush();
        currentIsUnit = isUnit;
      }

      buffer.write(char);
    }

    flush();
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xD9FFFFFF),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Builder(
            builder: (BuildContext context) {
              final TextStyle valueStyle = TextStyle(
                color: Colors.white,
                fontSize: valueFontSize,
                fontWeight: FontWeight.w900,
                height: 1,
              );

              if (!useCompactUnitStyle) {
                return Text(
                  value,
                  textAlign: TextAlign.center,
                  style: valueStyle,
                );
              }

              final double unitFontSize = valueFontSize < 12 ? valueFontSize : 12;
              return Text.rich(
                TextSpan(
                  children: _buildCompactUnitSpans(valueStyle, unitFontSize),
                ),
                textAlign: TextAlign.center,
              );
            },
          ),
        ),
      ],
    );
  }
}

class MileageTab extends StatefulWidget {
  const MileageTab({super.key, required this.records});

  final List<ReadingRecord> records;

  @override
  State<MileageTab> createState() => _MileageTabState();
}

class _MileageTabState extends State<MileageTab> {
  late DateTime _focusedMonth;
  int? _selectedDay;

  void _openMonthlySummaryPhoto({
    required Duration totalDuration,
    required int totalPages,
    required double averagePace,
    required List<String> monthBookNames,
  }) {
    final ReadingRecord summaryRecord = ReadingRecord(
      recordedAt: DateTime(_focusedMonth.year, _focusedMonth.month, 1),
      duration: totalDuration,
      bookName: monthBookNames.isEmpty ? null : monthBookNames.join(', '),
      startPage: 0,
      endPage: totalPages,
      pagesRead: totalPages,
      pacePerMinute: averagePace,
      photoPaths: const <String>[],
      mainPhotoPath: null,
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => _RecordPhotosScreen(
          record: summaryRecord,
          photoPaths: const <String>[],
        ),
      ),
    );
  }

  void _openRecordPhotos(ReadingRecord record) {
    final List<String> validPaths = record.photoPaths
        .where((String path) => path.isNotEmpty)
        .toList();

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => _RecordPhotosScreen(
          record: record,
          photoPaths: validPaths,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
      _selectedDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<ReadingRecord> monthRecords = widget.records.where((ReadingRecord record) {
      return record.recordedAt.year == _focusedMonth.year &&
          record.recordedAt.month == _focusedMonth.month;
    }).toList();

    final int totalPages = monthRecords.fold<int>(
      0,
      (int sum, ReadingRecord record) => sum + record.pagesRead,
    );

    final Duration totalDuration = monthRecords.fold<Duration>(
      Duration.zero,
      (Duration sum, ReadingRecord record) => sum + record.duration,
    );
    final double averagePace = totalDuration.inSeconds > 0
        ? totalPages / (totalDuration.inSeconds / 60)
        : 0;
    final int totalMinutes = totalDuration.inMinutes;
    final String pageUnit = totalPages <= 1 ? 'page' : 'pages';

    // 책별 통계 계산
    final Map<String?, List<ReadingRecord>> recordsByBook = <String?, List<ReadingRecord>>{};
    for (final ReadingRecord record in monthRecords) {
      final String? bookName = record.bookName ?? 'What did I read?';
      recordsByBook.putIfAbsent(bookName, () => <ReadingRecord>[]).add(record);
    }

    final List<String?> bookNames = recordsByBook.keys.toList();
    final Map<String?, ({Duration duration, int pages, double pace})> bookStats =
        <String?, ({Duration duration, int pages, double pace})>{};

    for (final String? bookName in bookNames) {
      final List<ReadingRecord> bookRecords = recordsByBook[bookName]!;
      final int bookPages = bookRecords.fold<int>(
        0,
        (int sum, ReadingRecord record) => sum + record.pagesRead,
      );
      final Duration bookDuration = bookRecords.fold<Duration>(
        Duration.zero,
        (Duration sum, ReadingRecord record) => sum + record.duration,
      );
      final double bookPace = bookDuration.inSeconds > 0
          ? bookPages / (bookDuration.inSeconds / 60)
          : 0;

      bookStats[bookName] = (duration: bookDuration, pages: bookPages, pace: bookPace);
    }

    final Set<String> seenBookNames = <String>{};
    final List<String> monthBookNames = <String>[];
    for (final String? name in bookNames) {
      if (name == null || name.isEmpty || seenBookNames.contains(name)) {
        continue;
      }

      seenBookNames.add(name);
      monthBookNames.add(name);
    }

    final Set<DateTime> readingDays = monthRecords
        .map((ReadingRecord record) {
          final DateTime dt = record.recordedAt;
          return DateTime(dt.year, dt.month, dt.day);
        })
        .toSet();
    final int totalReadingDays = readingDays.length;
    final String dayUnit = totalReadingDays <= 1 ? 'day' : 'days';

    final Map<int, int> pagesByDay = <int, int>{};
    for (final ReadingRecord record in monthRecords) {
      final int day = record.recordedAt.day;
      pagesByDay[day] = (pagesByDay[day] ?? 0) + record.pagesRead;
    }

    final int maxPagesInDay = pagesByDay.values.isEmpty
        ? 0
        : pagesByDay.values.reduce((int a, int b) => a > b ? a : b);

  final List<Widget> dayHeaders = <String>['S', 'M', 'T', 'W', 'T', 'F', 'S']
        .map(
          (String day) => Center(
            child: Text(
              day,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: const Color(0xFFA06C7E),
              ),
            ),
          ),
        )
        .toList();

    final List<Widget> dayCells = _buildDayCells(
      context: context,
      month: _focusedMonth,
      pagesByDay: pagesByDay,
      maxPagesInDay: maxPagesInDay,
    );

    final List<ReadingRecord> selectedDayRecords = _selectedDay == null
        ? <ReadingRecord>[]
        : monthRecords
            .where((ReadingRecord record) => record.recordedAt.day == _selectedDay)
            .toList()
          ..sort(
            (ReadingRecord a, ReadingRecord b) => b.recordedAt.compareTo(a.recordedAt),
          );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Last month',
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${_focusedMonth.year}. ${_focusedMonth.month}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next month',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatDuration(totalDuration)}  |  ${totalPages}${pageUnit}  |  ${totalReadingDays}${dayUnit}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7F838D),
                ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFE6EF),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 30),
            child: Column(
              children: <Widget>[
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.6,
                  children: dayHeaders,
                ),
                const Divider(color: Color(0xFFF3BDD1), height: 10),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 0.9,
                  children: dayCells,
                ),
              ],
            ),
          ),
          if (monthRecords.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Material(
              color: const Color(0xFFFFF1F7),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openMonthlySummaryPhoto(
                  totalDuration: totalDuration,
                  totalPages: totalPages,
                  averagePace: averagePace,
                  monthBookNames: monthBookNames,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Summary',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: const Color(0xFF7E3C54),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (monthBookNames.isEmpty)
                        Text(
                          '-',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF8F5A6C),
                              ),
                        )
                      else
                        ...monthBookNames.map(
                          (String bookName) {
                            final bookStat = bookStats[bookName] ?? (duration: Duration.zero, pages: 0, pace: 0.0);
                            final Duration bookDuration = bookStat.duration;
                            final double bookPace = bookStat.pace;
                            final int bookMinutes = bookDuration.inMinutes;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      bookName,
                                      style: const TextStyle(
                                        color: Color(0xFF8F5A6C),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '$bookMinutes min',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFF8F5A6C),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${bookPace.toStringAsFixed(1)} p/min',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFF7E3C54),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (_selectedDay != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE6EF),
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Record on ${_focusedMonth.month}/${_selectedDay}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF7E3C54),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  if (selectedDayRecords.isEmpty)
                    Text(
                      'No records found.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF9A6A7B),
                          ),
                    ),
                  if (selectedDayRecords.isNotEmpty)
                    ...selectedDayRecords.map(
                      (ReadingRecord record) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: const Color(0xFFFFF3F8),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _openRecordPhotos(record),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      _formatDateTime(record.recordedAt),
                                      style: const TextStyle(
                                        color: Color(0xFF8F5A6C),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${record.pagesRead}p • ${_formatShortDuration(record.duration)}',
                                    style: const TextStyle(
                                      color: Color(0xFF7E3C54),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildDayCells({
    required BuildContext context,
    required DateTime month,
    required Map<int, int> pagesByDay,
    required int maxPagesInDay,
  }) {
    final DateTime firstDay = DateTime(month.year, month.month, 1);
    final int totalDays = DateTime(month.year, month.month + 1, 0).day;
    final int leadingEmpty = firstDay.weekday % 7;

    final List<Widget> cells = <Widget>[];
    for (int i = 0; i < leadingEmpty; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int day = 1; day <= totalDays; day++) {
      final int pages = pagesByDay[day] ?? 0;
      final bool isReadDay = pages > 0;
      final bool isSelectedDay = _selectedDay == day;
      final double circleSize;
      if (!isReadDay) {
        circleSize = 0;
      } else if (pages <= 10) {
        circleSize = 12;
      } else if (pages <= 99) {
        circleSize = 18;
      } else {
        circleSize = 25;
      }
      final int weekday = DateTime(month.year, month.month, day).weekday;
      final Color dayTextColor = weekday == DateTime.sunday
          ? const Color(0xFFD35A82)
          : const Color(0xFF8F5A6C);

      cells.add(
        GestureDetector(
          onTap: isReadDay
              ? () {
                  setState(() {
                    _selectedDay = day;
                  });
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                SizedBox(
                  height: 42,
                  child: Center(
                    child: isReadDay
                        ? AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: circleSize,
                            height: circleSize,
                            decoration: BoxDecoration(
                              color: isSelectedDay
                                  ? const Color(0xFF31F398)
                                  : const Color(0xFF16D37E),
                              shape: BoxShape.circle,
                              border: isSelectedDay
                                  ? Border.all(
                                      color: Colors.white,
                                      width: 1.4,
                                    )
                                  : null,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 14,
                    color: dayTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return cells;
  }
}

class RecordTab extends StatefulWidget {
  const RecordTab({
    super.key,
    required this.onSave,
    required this.suggestedBookNames,
    required this.lastEndPageByBook,
  });

  final ValueChanged<ReadingRecord> onSave;
  final List<String> suggestedBookNames;
  final Map<String, int> lastEndPageByBook;

  @override
  State<RecordTab> createState() => _RecordTabState();
}

class _RecordTabState extends State<RecordTab> with WidgetsBindingObserver {
  final TextEditingController _startPageController = TextEditingController();
  final TextEditingController _bookNameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  Timer? _timer;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  double? _lastSavedPace;
  int? _lastPagesRead;
  final List<String> _capturedPhotoPaths = <String>[];
  bool _isPaused = false;

  bool get _isRunning => _timer != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isRunning &&
        (state == AppLifecycleState.resumed ||
            state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused)) {
      _syncElapsedFromClock();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _startPageController.dispose();
    _bookNameController.dispose();
    super.dispose();
  }

  void _syncElapsedFromClock() {
    if (_startedAt == null) {
      return;
    }

    setState(() {
      _elapsed = DateTime.now().difference(_startedAt!);
    });
  }

  void _startRecording() {
    final int? startPage = int.tryParse(_startPageController.text.trim());
    if (startPage == null || startPage < 0) {
      _showSnack('Please enter a valid start page.');
      return;
    }

    setState(() {
      _elapsed = Duration.zero;
      _startedAt = DateTime.now();
      _capturedPhotoPaths.clear();
      _isPaused = false;
      _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
        _syncElapsedFromClock();
      });
    });
  }

  void _pauseRecording() {
    if (!_isRunning || _isPaused) {
      return;
    }

    _timer?.cancel();
    _timer = null;
    _syncElapsedFromClock();

    setState(() {
      _isPaused = true;
    });
  }

  void _resumeRecording() {
    if (_isRunning || !_isPaused) {
      return;
    }

    setState(() {
      _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
        _syncElapsedFromClock();
      });
      _isPaused = false;
    });
  }

  Future<void> _stopRecording() async {
    final int? startPage = int.tryParse(_startPageController.text.trim());
    if (startPage == null || startPage < 0) {
      _showSnack('Please check the start page again.');
      return;
    }

    _syncElapsedFromClock();
    _timer?.cancel();
    _timer = null;

    final int? endPage = await _askEndPage(context);
    if (endPage == null) {
      setState(() {});
      return;
    }

    if (endPage < startPage) {
      _showSnack('End page must be greater than or equal to the start page.');
      setState(() {});
      return;
    }

    final String bookName = _bookNameController.text.trim();
    final int pagesRead = endPage - startPage;
    final double minutes = _elapsed.inSeconds / 60;
    final double pace = minutes > 0 ? pagesRead / minutes : 0;
    final String? mainPhotoPath = await _selectMainPhoto(context);

    widget.onSave(
      ReadingRecord(
        recordedAt: DateTime.now(),
        duration: _elapsed,
        bookName: bookName.isEmpty ? null : bookName,
        startPage: startPage,
        endPage: endPage,
        pagesRead: pagesRead,
        pacePerMinute: pace,
        photoPaths: List<String>.from(_capturedPhotoPaths),
        mainPhotoPath: mainPhotoPath,
      ),
    );

    setState(() {
      _elapsed = Duration.zero;
      _startedAt = null;
      _lastSavedPace = pace;
      _lastPagesRead = pagesRead;
      _capturedPhotoPaths.clear();
    });

    _showSnack('You read a lot of books today!');
  }

  Future<void> _capturePhoto() async {
    if (!_isRunning) {
      _showSnack('Want to take a photo? Start reading a book.');
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image == null) {
        return;
      }

      bool gallerySaved = false;
      try {
        final Uint8List rawImageBytes = await File(image.path).readAsBytes();
        Uint8List imageBytes = rawImageBytes;

        final img.Image? decodedImage = img.decodeImage(rawImageBytes);
        if (decodedImage != null) {
          final img.Image orientationBakedImage = img.bakeOrientation(decodedImage);
          imageBytes = Uint8List.fromList(
            img.encodeJpg(orientationBakedImage, quality: 100),
          );
        }

        final String fileName = 'pagerun_capture_${DateTime.now().millisecondsSinceEpoch}';
        final dynamic result = await ImageGallerySaverPlus.saveImage(
          imageBytes,
          quality: 100,
          name: fileName,
        );
        if (result is Map) {
          final dynamic isSuccess = result['isSuccess'];
          final dynamic hasPath = result['filePath'];
          gallerySaved = isSuccess == true || (hasPath is String && hasPath.isNotEmpty);
        }
      } catch (_) {
        gallerySaved = false;
      }

      setState(() {
        _capturedPhotoPaths.add(image.path);
      });
      _showSnack(
        gallerySaved
          ? 'Captured! Check it out in your gallery.'
            : 'Photo captured, but failed to save to gallery.',
      );
    } catch (_) {
      _showSnack('Unable to open camera. Please check permissions or device status.');
    }
  }

  Future<int?> _askEndPage(BuildContext context) async {
    final TextEditingController controller = TextEditingController();
    final int? endPage = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Finish page'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'ex: 58'),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final int? value = int.tryParse(controller.text.trim());
                Navigator.of(context).pop(value);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return endPage;
  }

  Future<String?> _selectMainPhoto(BuildContext context) async {
    if (_capturedPhotoPaths.isEmpty) {
      return null;
    }

    String selectedPath = _capturedPhotoPaths.first;

    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setDialogState) {
            return AlertDialog(
              title: const Text('Select Main Photo'),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 260,
                      child: GridView.builder(
                        shrinkWrap: true,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _capturedPhotoPaths.length,
                        itemBuilder: (BuildContext context, int index) {
                          final String path = _capturedPhotoPaths[index];
                          final bool isSelected = path == selectedPath;

                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedPath = path;
                              });
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: <Widget>[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.file(
                                    File(path),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFE60023), width: 3),
                                      color: const Color(0x330B5563),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(selectedPath),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _elapsed = Duration.zero;
      _startedAt = null;
      _capturedPhotoPaths.clear();
      _isPaused = false;
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final Color inactiveButtonColor = Theme.of(context).colorScheme.surfaceContainer;

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/record_background.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    controller: _bookNameController,
                    enabled: !_isRunning,
                    decoration: InputDecoration(
                      labelText: 'Book Name',
                      hintText: 'Ex. 행복의 기원',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainer,
                      suffixIcon: (!_isRunning && widget.suggestedBookNames.isNotEmpty)
                          ? PopupMenuButton<String>(
                              position: PopupMenuPosition.under,
                              offset: const Offset(0, 8),
                              constraints: BoxConstraints(
                                minWidth: MediaQuery.sizeOf(context).width - 32,
                                maxWidth: MediaQuery.sizeOf(context).width - 32,
                              ),
                              tooltip: 'Book list',
                              icon: const Icon(Icons.arrow_drop_down),
                              onOpened: _dismissKeyboard,
                              onSelected: (String value) {
                                final int? suggestedStartPage = widget.lastEndPageByBook[value];
                                _dismissKeyboard();
                                setState(() {
                                  _bookNameController.text = value;
                                  if (suggestedStartPage != null && suggestedStartPage >= 0) {
                                    _startPageController.text = suggestedStartPage.toString();
                                    _startPageController.selection = TextSelection.collapsed(
                                      offset: _startPageController.text.length,
                                    );
                                  }
                                });
                              },
                              itemBuilder: (BuildContext context) {
                                return widget.suggestedBookNames
                                    .map(
                                      (String name) => PopupMenuItem<String>(
                                        value: name,
                                        child: Text(name, overflow: TextOverflow.ellipsis),
                                      ),
                                    )
                                    .toList();
                              },
                            )
                          : const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _startPageController,
                    enabled: !_isRunning,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Start Page',
                      hintText: 'Ex. 12',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double cardHeight =
                    (constraints.maxWidth * 0.30).clamp(96.0, 128.0);
                final double labelFontSize =
                  (cardHeight * 0.17).clamp(14.0, 20.0);
                final double valueFontSize =
                  (cardHeight * 0.34).clamp(28.0, 44.0);
                final double valueTopSpacing =
                  (cardHeight * 0.07).clamp(6.0, 10.0);

                return SizedBox(
                  width: double.infinity,
                  height: cardHeight,
                  child: Card(
                    margin: EdgeInsets.zero,
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            'Time',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontSize: labelFontSize,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          SizedBox(height: valueTopSpacing),
                          Text(
                            _formatDuration(_elapsed),
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontSize: valueFontSize,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: _isRunning ? _pauseRecording : (_isPaused ? _resumeRecording : _startRecording),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          _isRunning && !_isPaused ? Icons.pause : Icons.play_arrow,
                          size: 18,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _isRunning && !_isPaused ? 'Pause' : (_isPaused ? 'Resume' : 'Start'),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      disabledBackgroundColor: inactiveButtonColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FilledButton(
                    onPressed: (_isRunning || _isPaused) ? _stopRecording : null,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.stop, size: 18),
                        SizedBox(width: 3),
                        Text('Stop', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      disabledBackgroundColor: inactiveButtonColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FilledButton(
                    onPressed: (_isRunning && !_isPaused) ? _capturePhoto : null,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.camera_alt, size: 18),
                        SizedBox(width: 3),
                        Text('Picture', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      disabledBackgroundColor: inactiveButtonColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FilledButton(
                    onPressed: _reset,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.refresh, size: 18),
                        SizedBox(width: 3),
                        Text('Reset', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      disabledBackgroundColor: inactiveButtonColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final String h = duration.inHours.toString().padLeft(2, '0');
  final String m = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final String s = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

String _formatDateTime(DateTime dateTime) {
  const List<String> monthAbbr = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final String month = monthAbbr[dateTime.month - 1];
  return '$month ${dateTime.day}, ${dateTime.year}';
}

String _formatShortDuration(Duration duration) {
  final int totalMinutes = duration.inMinutes;
  final int seconds = duration.inSeconds % 60;
  return '${totalMinutes}m ${seconds.toString().padLeft(2, '0')}s';
}

String _formatHomeDuration(Duration duration) {
  final int hours = duration.inHours;
  final int minutes = duration.inMinutes % 60;
  if (hours > 0) {
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  return '${duration.inMinutes}m';
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is double) {
    return value.round();
  }

  if (value is String) {
    return int.tryParse(value) ?? 0;
  }

  return 0;
}

double _asDouble(dynamic value) {
  if (value is double) {
    return value;
  }

  if (value is int) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value) ?? 0;
  }

  return 0;
}

class _TransparentRecordPhoto extends StatelessWidget {
  const _TransparentRecordPhoto({required this.record});

  final ReadingRecord record;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 16),
            _TransparentMetric(label: 'Pages', value: '${record.pagesRead} p'),
            const SizedBox(height: 35),
            _TransparentMetric(
              label: 'Pace',
              value: '${record.pacePerMinute.toStringAsFixed(1)} p/min',
            ),
            const SizedBox(height: 35),
            _TransparentMetric(label: 'Time', value: _formatShortDuration(record.duration)),
            const Spacer(),
            const Text(
              'PAGERUN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _TransparentMetric extends StatelessWidget {
  const _TransparentMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 50,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckerboardBackground extends StatelessWidget {
  const _CheckerboardBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _CheckerboardPainter(),
      child: child,
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double squareSize = 12;
    const Color colorA = Color(0xFFE7E7E7);
    const Color colorB = Color(0xFFFFFFFF);

    final Paint paintA = Paint()..color = colorA;
    final Paint paintB = Paint()..color = colorB;

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        final int xIndex = (x / squareSize).floor();
        final int yIndex = (y / squareSize).floor();
        final bool useA = (xIndex + yIndex).isEven;
        canvas.drawRect(
          Rect.fromLTWH(x, y, squareSize, squareSize),
          useA ? paintA : paintB,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerboardPainter oldDelegate) => false;
}
