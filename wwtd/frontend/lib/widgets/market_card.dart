import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:wwtd/models/prediction_market.dart';
import 'package:wwtd/providers/app_state.dart';

class MarketCard extends StatelessWidget {
  const MarketCard({required this.market, super.key});

  final PredictionMarket market;

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final bool canBet = appState.isLoggedIn && market.isBettingOpen;
    final bool canResolve = appState.canResolveMarket(market);
    final bool canDelete = appState.canDeleteQuestion(market);

    return Card(
      elevation: 1,
      shadowColor: Colors.black12,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              market.question,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (market.targetNames.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'For ${market.targetNames.join(', ')}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF1454A7),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _oddsGraph(context, market),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      flex: market.yesPercent.round(),
                      child: const ColoredBox(color: Color(0xFF2FB879)),
                    ),
                    Expanded(
                      flex: market.noPercent.round(),
                      child: const ColoredBox(color: Color(0xFFE97B70)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Yes ${market.yesPercent.toStringAsFixed(0)}% · No ${market.noPercent.toStringAsFixed(0)}%',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF526170)),
            ),
            if (market.isResolved) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Resolved: ${market.winningSide?.toUpperCase() ?? '?'} won — betting closed',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF1454A7),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ] else if (!market.bettingOpen) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Betting closed — 24 hours have passed',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF607182),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (market.userYesBet > 0 || market.userNoBet > 0) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Your picks — Yes: ${market.userYesBet > 0 ? 'picked' : 'none'} | No: ${market.userNoBet > 0 ? 'picked' : 'none'}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF607182)),
              ),
            ],
            const SizedBox(height: 14),
            if (canBet)
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2C9B67),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _placeBet(context, isYes: true),
                      child: const Text('Bet Yes'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF7DEDB),
                        foregroundColor: const Color(0xFFB24338),
                      ),
                      onPressed: () => _placeBet(context, isYes: false),
                      child: const Text('Bet No'),
                    ),
                  ),
                ],
              )
            else if (!appState.isLoggedIn)
              Text(
                'Sign in to bet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF607182),
                ),
              )
            else if (!market.isBettingOpen)
              Text(
                'Betting is locked on this question',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF607182),
                ),
              ),
            if (canResolve) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                'Moderator: pick the outcome to pay winners',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF607182),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _resolve(context, winningYes: true),
                      child: const Text('Resolve Yes'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _resolve(context, winningYes: false),
                      child: const Text('Resolve No'),
                    ),
                  ),
                ],
              ),
            ],
            if (canDelete) ...<Widget>[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline, size: 18),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB24338),
                ),
                label: const Text('Delete question (refund all bets)'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _placeBet(BuildContext context, {required bool isYes}) async {
    final AppState appState = context.read<AppState>();
    final bool ok = await appState.placeBet(marketId: market.id, isYes: isYes);
    if (!context.mounted) {
      return;
    }
    final String? message = appState.gameError;
    if (!ok && message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } else if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bet placed')));
    }
  }

  Future<void> _resolve(
    BuildContext context, {
    required bool winningYes,
  }) async {
    final AppState appState = context.read<AppState>();
    final bool ok = await appState.resolveMarket(
      marketId: market.id,
      winningYes: winningYes,
    );
    if (!context.mounted) {
      return;
    }
    final String? message = appState.gameError;
    if (!ok && message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } else if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Market resolved — ${winningYes ? 'Yes' : 'No'} wins'),
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete question?'),
          content: const Text(
            'All bets on this question will be refunded to players. This cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB24338),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete & refund'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final AppState appState = context.read<AppState>();
    final bool ok = await appState.deleteQuestion(market.id);
    if (!context.mounted) {
      return;
    }
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question deleted — bets refunded')),
      );
    } else if (appState.gameError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(appState.gameError!)));
    }
  }

  Widget _oddsGraph(BuildContext context, PredictionMarket market) {
    return _OddsTrendChart(market: market);
  }
}

class _TrendPoint {
  const _TrendPoint({required this.timestamp, required this.yesPercent});

  final DateTime timestamp;
  final double yesPercent;
  double get noPercent => 100 - yesPercent;
}

class _OddsTrendChart extends StatefulWidget {
  const _OddsTrendChart({required this.market});

  final PredictionMarket market;

  @override
  State<_OddsTrendChart> createState() => _OddsTrendChartState();
}

class _OddsTrendChartState extends State<_OddsTrendChart> {
  static const Color _yesColor = Color(0xFF2FB879);
  static const Color _noColor = Color(0xFFE97B70);
  static const double _chartHeight = 96;
  static const double _leftPadding = 28;
  static const double _rightPadding = 44;
  List<_TrendPoint> _points = <_TrendPoint>[];
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _points = _generateTrendSeries(widget.market);
  }

  @override
  void didUpdateWidget(covariant _OddsTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.market.id != widget.market.id ||
        (oldWidget.market.yesPercent - widget.market.yesPercent).abs() >
            0.001) {
      _points = _generateTrendSeries(widget.market);
      _hoveredIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final _TrendPoint latest = _points.last;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double plotWidth = math.max(
          1,
          width - _leftPadding - _rightPadding,
        );
        final int hoverIndex = (_hoveredIndex ?? (_points.length - 1)).clamp(
          0,
          _points.length - 1,
        );
        final _TrendPoint hovered = _points[hoverIndex];
        final double hoverX =
            _leftPadding + _xForIndex(hoverIndex, plotWidth, _points.length);
        final double hoverY = _yForPercent(hovered.yesPercent, _chartHeight);

        return MouseRegion(
          onHover: (event) =>
              _updateHoverIndex(event.localPosition.dx, plotWidth),
          onExit: (_) => setState(() => _hoveredIndex = null),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (DragDownDetails details) =>
                _updateHoverIndex(details.localPosition.dx, plotWidth),
            onPanUpdate: (DragUpdateDetails details) =>
                _updateHoverIndex(details.localPosition.dx, plotWidth),
            onPanEnd: (_) => setState(() => _hoveredIndex = null),
            child: SizedBox(
              height: _chartHeight + 32,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _OddsTrendPainter(
                        points: _points,
                        yesColor: _yesColor,
                        noColor: _noColor,
                        leftPadding: _leftPadding,
                        rightPadding: _rightPadding,
                        hoveredIndex: _hoveredIndex,
                      ),
                    ),
                  ),
                  Positioned(
                    top: (hoverY - 40).clamp(2, _chartHeight - 36),
                    left: (hoverX - 48).clamp(4, width - 120),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: _hoveredIndex == null ? 0 : 1,
                      child: _hoverTooltip(context, hovered),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: -4,
                    bottom: 24,
                    child: _yAxisLabels(context),
                  ),
                  Positioned(
                    right: 2,
                    top: (_yForPercent(latest.yesPercent, _chartHeight) - 8)
                        .clamp(0, _chartHeight - 16),
                    child: _lineValueLabel(
                      '${latest.yesPercent.toStringAsFixed(0)}%',
                      _yesColor,
                    ),
                  ),
                  Positioned(
                    right: 2,
                    top: (_yForPercent(latest.noPercent, _chartHeight) - 8)
                        .clamp(0, _chartHeight - 16),
                    child: _lineValueLabel(
                      '${latest.noPercent.toStringAsFixed(0)}%',
                      _noColor,
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

  Widget _hoverTooltip(BuildContext context, _TrendPoint point) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DefaultTextStyle(
        style: Theme.of(
          context,
        ).textTheme.labelSmall!.copyWith(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(_formatTimestamp(point.timestamp)),
            Text('Yes ${point.yesPercent.toStringAsFixed(1)}%'),
            Text('No ${point.noPercent.toStringAsFixed(1)}%'),
          ],
        ),
      ),
    );
  }

  Widget _lineValueLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color.withValues(alpha: 0.9),
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
    );
  }

  Widget _yAxisLabels(BuildContext context) {
    final TextStyle style = Theme.of(context).textTheme.labelSmall!.copyWith(
      color: const Color(0xFF94A3B8),
      fontWeight: FontWeight.w600,
      fontSize: 10,
    );
    return SizedBox(
      width: _leftPadding - 4,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text('100', style: style),
          Text('75', style: style),
          Text('50', style: style),
          Text('25', style: style),
          Text('0', style: style),
        ],
      ),
    );
  }

  void _updateHoverIndex(double localX, double plotWidth) {
    final double clampedX = (localX - _leftPadding).clamp(0, plotWidth);
    final int index = ((clampedX / plotWidth) * (_points.length - 1))
        .round()
        .clamp(0, _points.length - 1);
    if (_hoveredIndex == index) {
      return;
    }
    setState(() => _hoveredIndex = index);
  }

  List<_TrendPoint> _generateTrendSeries(PredictionMarket market) {
    final int seed = market.id.codeUnits.fold<int>(
      0,
      (int sum, int unit) => sum + unit,
    );
    final math.Random random = math.Random(seed);
    const int pointCount = 25;
    final DateTime end = DateTime.now();
    final DateTime start = end.subtract(const Duration(hours: 24));
    final Duration step = Duration(
      minutes: (24 * 60 / (pointCount - 1)).round(),
    );
    final List<double> raw = <double>[];

    double yes = (market.yesPercent + (random.nextDouble() * 16 - 8)).clamp(
      10,
      90,
    );
    raw.add(yes);
    for (int i = 1; i < pointCount; i++) {
      yes = (yes + (random.nextDouble() * 10 - 5)).clamp(5, 95);
      raw.add(yes);
    }

    final double delta = market.yesPercent - raw.last;
    final List<double> shifted = raw
        .map((double value) => (value + delta).clamp(3, 97).toDouble())
        .toList(growable: false);

    final List<double> smoothed = List<double>.generate(shifted.length, (
      int i,
    ) {
      if (i == 0 || i == shifted.length - 1) {
        return shifted[i];
      }
      return (shifted[i - 1] * 0.25) +
          (shifted[i] * 0.5) +
          (shifted[i + 1] * 0.25);
    });
    smoothed[smoothed.length - 1] = market.yesPercent.clamp(0, 100).toDouble();

    return List<_TrendPoint>.generate(pointCount, (int i) {
      return _TrendPoint(
        timestamp: start.add(step * i),
        yesPercent: smoothed[i],
      );
    });
  }

  double _xForIndex(int index, double width, int pointCount) {
    if (pointCount <= 1) {
      return 0;
    }
    return (index / (pointCount - 1)) * width;
  }

  double _yForPercent(double percent, double height) {
    return (1 - (percent.clamp(0, 100) / 100)) * height;
  }

  String _formatTimestamp(DateTime dateTime) {
    final int hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    final String suffix = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}

class _OddsTrendPainter extends CustomPainter {
  const _OddsTrendPainter({
    required this.points,
    required this.yesColor,
    required this.noColor,
    required this.leftPadding,
    required this.rightPadding,
    required this.hoveredIndex,
  });

  final List<_TrendPoint> points;
  final Color yesColor;
  final Color noColor;
  final double leftPadding;
  final double rightPadding;
  final int? hoveredIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final double plotWidth = math.max(
      1,
      size.width - leftPadding - rightPadding,
    );
    final double plotHeight = size.height;
    final List<Offset> yesPoints = _toOffsets(
      values: points
          .map((_TrendPoint point) => point.yesPercent)
          .toList(growable: false),
      width: plotWidth,
      height: plotHeight,
    );
    final List<Offset> noPoints = _toOffsets(
      values: points
          .map((_TrendPoint point) => point.noPercent)
          .toList(growable: false),
      width: plotWidth,
      height: plotHeight,
    );

    _drawGrid(canvas, size);

    final Path yesPath = _smoothPath(yesPoints);
    final Path noPath = _smoothPath(noPoints);
    _drawFill(canvas, yesPath, yesPoints, plotHeight, yesColor);
    _drawFill(canvas, noPath, noPoints, plotHeight, noColor);

    final Paint yesPaint = Paint()
      ..color = yesColor.withValues(alpha: 0.88)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final Paint noPaint = Paint()
      ..color = noColor.withValues(alpha: 0.88)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(yesPath, yesPaint);
    canvas.drawPath(noPath, noPaint);

    if (hoveredIndex != null &&
        hoveredIndex! >= 0 &&
        hoveredIndex! < points.length) {
      final double x =
          leftPadding + (hoveredIndex! / (points.length - 1)) * plotWidth;
      final Paint crosshair = Paint()
        ..color = const Color(0xFF64748B).withValues(alpha: 0.35)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x, 0), Offset(x, plotHeight), crosshair);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (final double p in <double>[25, 50, 75]) {
      final double y = (1 - p / 100) * size.height;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        paint,
      );
    }
  }

  List<Offset> _toOffsets({
    required List<double> values,
    required double width,
    required double height,
  }) {
    if (values.length <= 1) {
      return <Offset>[Offset.zero];
    }
    return List<Offset>.generate(values.length, (int i) {
      final double x = leftPadding + (i / (values.length - 1)) * width;
      final double y = (1 - values[i].clamp(0, 100) / 100) * height;
      return Offset(x, y);
    });
  }

  Path _smoothPath(List<Offset> points) {
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final Offset previous = points[i - 1];
      final Offset current = points[i];
      final Offset midpoint = Offset(
        (previous.dx + current.dx) / 2,
        (previous.dy + current.dy) / 2,
      );
      path.quadraticBezierTo(
        previous.dx,
        previous.dy,
        midpoint.dx,
        midpoint.dy,
      );
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  void _drawFill(
    Canvas canvas,
    Path linePath,
    List<Offset> points,
    double height,
    Color color,
  ) {
    final Path fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, height)
      ..lineTo(points.first.dx, height)
      ..close();
    final Rect bounds = Rect.fromLTWH(0, 0, points.last.dx, height);
    final Paint fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          color.withValues(alpha: 0.16),
          color.withValues(alpha: 0.02),
        ],
      ).createShader(bounds)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fill);
  }

  @override
  bool shouldRepaint(covariant _OddsTrendPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.leftPadding != leftPadding ||
        oldDelegate.rightPadding != rightPadding;
  }
}
