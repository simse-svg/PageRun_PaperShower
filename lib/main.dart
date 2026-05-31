import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const ReadingPaceApp());
}

class ReadingPaceApp extends StatelessWidget {
  const ReadingPaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Page Run',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE60023)),
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
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final List<ReadingRecord> _records = <ReadingRecord>[];

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

  void _addRecord(ReadingRecord record) {
    setState(() {
      _records.insert(0, record);
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      HomeTab(records: _records),
      RecordTab(
        onSave: _addRecord,
        suggestedBookNames: _bookNameOptions(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Page Run'),
      ),
      body: pages[_selectedIndex],
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
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'Record',
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.records});

  final List<ReadingRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '아직 기록이 없습니다.\nRecord 탭에서 페이지를 입력하고 측정을 시작하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      itemBuilder: (BuildContext context, int index) {
        return _RecordCard(record: records[index]);
      },
    );
  }
}

class _RecordCard extends StatefulWidget {
  const _RecordCard({required this.record});

  final ReadingRecord record;

  @override
  State<_RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<_RecordCard> {
  double? _photoAspectRatio;

  void _openPhotoGallery() {
    final List<String> validPaths = widget.record.photoPaths
        .where((String path) => path.isNotEmpty)
        .toList();

    if (validPaths.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('이 기록에는 사진이 없습니다.')));
      return;
    }

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
    final bool hasPhoto = record.mainPhotoPath != null && record.mainPhotoPath!.isNotEmpty;
    final double cardAspectRatio = hasPhoto
        ? (_photoAspectRatio ?? (3 / 4)).clamp(0.65, 1.2)
        : 16 / 10;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: _openPhotoGallery,
        child: AspectRatio(
          aspectRatio: cardAspectRatio,
          child: Container(
            borderRadius: BorderRadius.circular(24),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _formatDateTime(record.recordedAt),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: _MetricBlock(label: 'Pages', value: '${record.pagesRead}'),
                      ),
                      Expanded(
                        child: _MetricBlock(
                          label: 'Pace',
                          value: '${record.pacePerMinute.toStringAsFixed(1)} pages/min',
                        ),
                      ),
                      Expanded(
                        child: _MetricBlock(
                          label: 'Time',
                          value: _formatShortDuration(record.duration),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'PAGERUN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${record.startPage} -> ${record.endPage}  |  사진 ${record.photoPaths.length}장',
                    style: const TextStyle(
                      color: Color(0xFFE8EEF2),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
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

  @override
  void initState() {
    super.initState();
    final String? mainPhotoPath = widget.record.mainPhotoPath;
    final int initialIndex = mainPhotoPath == null
        ? 0
        : widget.photoPaths.indexOf(mainPhotoPath);
    _currentIndex = initialIndex >= 0 ? initialIndex : 0;
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
        title: Text('기록 사진 ${_currentIndex + 1}/${widget.photoPaths.length}'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.photoPaths.length,
              onPageChanged: (int index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (BuildContext context, int index) {
                final String path = widget.photoPaths[index];
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                        return const Center(child: Text('사진을 불러올 수 없습니다.'));
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 78,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: widget.photoPaths.length,
              itemBuilder: (BuildContext context, int index) {
                final String path = widget.photoPaths[index];
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
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
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
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: Color(0xD9FFFFFF),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class RecordTab extends StatefulWidget {
  const RecordTab({
    super.key,
    required this.onSave,
    required this.suggestedBookNames,
  });

  final ValueChanged<ReadingRecord> onSave;
  final List<String> suggestedBookNames;

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
      _showSnack('시작 페이지를 올바르게 입력해 주세요.');
      return;
    }

    setState(() {
      _elapsed = Duration.zero;
      _startedAt = DateTime.now();
      _capturedPhotoPaths.clear();
      _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
        _syncElapsedFromClock();
      });
    });
  }

  Future<void> _stopRecording() async {
    final int? startPage = int.tryParse(_startPageController.text.trim());
    if (startPage == null || startPage < 0) {
      _showSnack('시작 페이지를 다시 확인해 주세요.');
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
      _showSnack('종료 페이지는 시작 페이지보다 크거나 같아야 합니다.');
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

    _showSnack('기록이 저장되었습니다.');
  }

  Future<void> _capturePhoto() async {
    if (!_isRunning) {
      _showSnack('기록 중일 때만 사진을 찍을 수 있습니다.');
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

      setState(() {
        _capturedPhotoPaths.add(image.path);
      });
      _showSnack('사진이 추가되었습니다.');
    } catch (_) {
      _showSnack('카메라를 열 수 없습니다. 권한 또는 기기 상태를 확인해 주세요.');
    }
  }

  Future<int?> _askEndPage(BuildContext context) async {
    final TextEditingController controller = TextEditingController();
    final int? endPage = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('종료 페이지 입력'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '예: 58'),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                final int? value = int.tryParse(controller.text.trim());
                Navigator.of(context).pop(value);
              },
              child: const Text('저장'),
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
              title: const Text('메인 사진 선택'),
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
                                      border: Border.all(color: Colors.white, width: 3),
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
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_capturedPhotoPaths.first),
                  child: const Text('첫 사진 사용'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(selectedPath),
                  child: const Text('선택 완료'),
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
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showBookDialog() {
    final TextEditingController tempController = TextEditingController(
      text: _bookNameController.text,
    );

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('책 이름 입력'),
          content: TextField(
            controller: tempController,
            decoration: const InputDecoration(
              hintText: '예: Flutter Guide',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _bookNameController.text = tempController.text;
                });
                Navigator.of(context).pop();
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
    tempController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/record_background.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _startPageController,
              enabled: !_isRunning,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '시작 페이지',
                hintText: '예: 12',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainer,
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _bookNameController,
            enabled: !_isRunning,
            decoration: InputDecoration(
              labelText: '책 이름',
              hintText: '예: Flutter Guide',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: widget.suggestedBookNames.contains(_bookNameController.text.trim())
                ? _bookNameController.text.trim()
                : null,
            decoration: InputDecoration(
              labelText: '이전 책 이름',
              hintText: widget.suggestedBookNames.isEmpty ? '이전 입력 없음' : '선택해서 채우기',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
            ),
            items: widget.suggestedBookNames
                .map(
                  (String name) => DropdownMenuItem<String>(
                    value: name,
                    child: Text(name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: widget.suggestedBookNames.isEmpty
                ? null
                : (String? value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _bookNameController.text = value;
                    });
                  },
          ),
          const SizedBox(height: 18),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('측정 시간', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    _formatDuration(_elapsed),
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _startedAt == null ? '대기 중' : '시작: ${_formatTime(_startedAt!)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _lastSavedPace == null
                        ? 'Pace: 저장된 기록이 없습니다.'
                        : 'Pace(최근): ${_lastSavedPace!.toStringAsFixed(2)} p/min (${_lastPagesRead ?? 0}p)',
                  ),
                  const SizedBox(height: 8),
                  Text('사진 기록: ${_capturedPhotoPaths.length}장'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: _isRunning ? null : _startRecording,
                icon: const Icon(Icons.play_arrow),
                label: const Text('시작'),
              ),
              FilledButton.icon(
                onPressed: _isRunning ? _stopRecording : null,
                icon: const Icon(Icons.stop),
                label: const Text('정지/저장'),
              ),
              FilledButton.icon(
                onPressed: _isRunning ? _capturePhoto : null,
                icon: const Icon(Icons.camera_alt),
                label: const Text('촬영'),
              ),
              OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh),
                label: const Text('리셋'),
              ),
            ],
          ),
        ],
      ),
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

String _formatTime(DateTime dateTime) {
  final String h = dateTime.hour.toString().padLeft(2, '0');
  final String m = dateTime.minute.toString().padLeft(2, '0');
  final String s = dateTime.second.toString().padLeft(2, '0');
  return '$h:$m:$s';
}

String _formatDateTime(DateTime dateTime) {
  final String y = dateTime.year.toString();
  final String m = dateTime.month.toString().padLeft(2, '0');
  final String d = dateTime.day.toString().padLeft(2, '0');
  final String h = dateTime.hour.toString().padLeft(2, '0');
  final String min = dateTime.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$min';
}

String _formatShortDuration(Duration duration) {
  final int totalMinutes = duration.inMinutes;
  final int seconds = duration.inSeconds % 60;
  return '${totalMinutes}m ${seconds.toString().padLeft(2, '0')}s';
}
