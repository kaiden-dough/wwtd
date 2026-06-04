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
            const SizedBox(height: 4),
            Text(
              'Created ${_formatCreatedAt(market.createdAt)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF607182)),
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
            Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _oddsGraph(context, market),
            ),
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
              market.pickHistory.isEmpty
                  ? 'Yes N/A · No N/A'
                  : 'Yes ${market.yesPercent.toStringAsFixed(0)}% · No ${market.noPercent.toStringAsFixed(0)}%',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF526170)),
            ),
            if (market.isResolved) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Resolved: ${market.winningSide?.toUpperCase() ?? '?'} won — picking closed',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF1454A7),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ] else if (!market.bettingOpen) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Picking closed — 24 hours have passed',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF607182),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (market.userYesBet > 0 || market.userNoBet > 0) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Your pick: ${market.userYesBet > 0 ? 'Yes' : 'No'}',
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
                      child: Text(
                        market.userYesBet > 0 ? 'Picked Yes' : 'Pick Yes',
                      ),
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
                      child: Text(
                        market.userNoBet > 0 ? 'Picked No' : 'Pick No',
                      ),
                    ),
                  ),
                ],
              )
            else if (!appState.isLoggedIn)
              Text(
                'Sign in to pick',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF607182),
                ),
              )
            else if (!market.isBettingOpen)
              Text(
                'Picking is locked on this question',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF607182),
                ),
              ),
            if (canResolve) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                market.isResolved
                    ? 'Moderator: change the awarded outcome'
                    : 'Moderator: pick the outcome to award winners',
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
                      child: Text(
                        market.isResolved ? 'Change to Yes' : 'Resolve Yes',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _resolve(context, winningYes: false),
                      child: Text(
                        market.isResolved ? 'Change to No' : 'Resolve No',
                      ),
                    ),
                  ),
                ],
              ),
              if (market.isResolved) ...<Widget>[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _undoResolve(context),
                    icon: const Icon(Icons.undo, size: 18),
                    label: const Text('Undo resolve'),
                  ),
                ),
              ],
            ],
            if (canDelete) ...<Widget>[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline, size: 18),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB24338),
                ),
                label: const Text('Delete question'),
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
      ).showSnackBar(const SnackBar(content: Text('Pick placed')));
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

  Future<void> _undoResolve(BuildContext context) async {
    final AppState appState = context.read<AppState>();
    final bool ok = await appState.undoResolveMarket(marketId: market.id);
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
      ).showSnackBar(const SnackBar(content: Text('Resolve undone')));
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete question?'),
          content: const Text(
            'This question will be removed. This cannot be undone.',
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
              child: const Text('Delete'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Question deleted')));
    } else if (appState.gameError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(appState.gameError!)));
    }
  }

  Widget _oddsGraph(BuildContext context, PredictionMarket market) {
    return _OddsTrendChart(market: market);
  }

  String _formatCreatedAt(DateTime value) {
    final DateTime local = value.toLocal();
    final int hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;
    final String minute = local.minute.toString().padLeft(2, '0');
    final String period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.month}/${local.day}/${local.year} $hour:$minute $period';
  }
}

class _TrendPoint {
  const _TrendPoint({
    required this.timestamp,
    required this.yesPercent,
    required this.pickUnit,
  });

  final DateTime timestamp;
  final double yesPercent;
  final double pickUnit;
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
            0.001 ||
        oldWidget.market.pickHistory.length !=
            widget.market.pickHistory.length ||
        (oldWidget.market.pickHistory.isNotEmpty &&
            widget.market.pickHistory.isNotEmpty &&
            oldWidget.market.pickHistory.last.createdAt !=
                widget.market.pickHistory.last.createdAt)) {
      _points = _generateTrendSeries(widget.market);
      _hoveredIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final bool hasPoints = _points.isNotEmpty;
        final double plotWidth = math.max(
          1,
          width - _leftPadding - _rightPadding,
        );
        final int? hoverIndex = hasPoints
            ? (_hoveredIndex ?? (_points.length - 1)).clamp(
                0,
                _points.length - 1,
              )
            : null;
        final _TrendPoint? hovered = hoverIndex == null
            ? null
            : _points[hoverIndex];
        final double hoverX = hovered == null
            ? 0
            : _leftPadding + _xForPoint(hovered, plotWidth);
        final double hoverY = hovered == null
            ? 0
            : _yForPercent(hovered.yesPercent, _chartHeight);

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
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: _chartHeight,
                    child: CustomPaint(
                      painter: _OddsTrendPainter(
                        points: _points,
                        yesColor: _yesColor,
                        noColor: _noColor,
                        leftPadding: _leftPadding,
                        rightPadding: _rightPadding,
                        hoveredIndex: _hoveredIndex,
                        chartUnits: _chartUnits(),
                      ),
                    ),
                  ),
                  if (hovered != null)
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
                    top: 0,
                    height: _chartHeight,
                    child: _yAxisLabels(context),
                  ),
                  if (hasPoints) ...<Widget>[
                    Positioned(
                      right: 2,
                      top:
                          (_yForPercent(_points.last.yesPercent, _chartHeight) -
                                  8)
                              .clamp(0, _chartHeight - 16),
                      child: _lineValueLabel(
                        '${_points.last.yesPercent.toStringAsFixed(0)}%',
                        _yesColor,
                      ),
                    ),
                    Positioned(
                      right: 2,
                      top:
                          (_yForPercent(_points.last.noPercent, _chartHeight) -
                                  8)
                              .clamp(0, _chartHeight - 16),
                      child: _lineValueLabel(
                        '${_points.last.noPercent.toStringAsFixed(0)}%',
                        _noColor,
                      ),
                    ),
                  ],
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
    if (_points.isEmpty) {
      return;
    }
    final double clampedX = (localX - _leftPadding).clamp(0, plotWidth);
    int index = 0;
    double closestDistance = double.infinity;
    for (int i = 0; i < _points.length; i++) {
      final double distance = (_xForPoint(_points[i], plotWidth) - clampedX)
          .abs();
      if (distance < closestDistance) {
        closestDistance = distance;
        index = i;
      }
    }
    if (_hoveredIndex == index) {
      return;
    }
    setState(() => _hoveredIndex = index);
  }

  List<_TrendPoint> _generateTrendSeries(PredictionMarket market) {
    final List<PickHistoryEntry> history =
        List<PickHistoryEntry>.from(market.pickHistory)
          ..sort((PickHistoryEntry a, PickHistoryEntry b) {
            final int timeCompare = a.createdAt.compareTo(b.createdAt);
            if (timeCompare != 0) {
              return timeCompare;
            }
            return a.side.compareTo(b.side);
          });

    final List<_TrendPoint> points = <_TrendPoint>[];
    double yesTotal = 0;
    double noTotal = 0;
    final double historyUnits = math.max(10, history.length).toDouble();
    for (int i = 0; i < history.length; i++) {
      final PickHistoryEntry pick = history[i];
      if (pick.side.toLowerCase() == 'yes') {
        yesTotal += pick.amount;
      } else {
        noTotal += pick.amount;
      }
      final double total = yesTotal + noTotal;
      points.add(
        _TrendPoint(
          timestamp: pick.createdAt,
          yesPercent: total == 0 ? 50 : (yesTotal / total) * 100,
          pickUnit: ((i + 1) / historyUnits) * 5,
        ),
      );
    }

    if (points.isNotEmpty) {
      points.insert(
        0,
        _TrendPoint(
          timestamp: market.createdAt,
          yesPercent: points.first.yesPercent,
          pickUnit: 0,
        ),
      );
      final double latest = market.yesPercent.clamp(0, 100).toDouble();
      points[points.length - 1] = _TrendPoint(
        timestamp: points.last.timestamp,
        yesPercent: latest,
        pickUnit: points.last.pickUnit,
      );
      final DateTime now = DateTime.now();
      if (now.isAfter(points.last.timestamp)) {
        points.add(
          _TrendPoint(timestamp: now, yesPercent: latest, pickUnit: 10),
        );
      }
    }
    return points;
  }

  double _xForPoint(_TrendPoint point, double width) {
    final double units = _chartUnits();
    if (units <= 0) {
      return 0;
    }
    return (point.pickUnit.clamp(0, units) / units) * width;
  }

  double _chartUnits() {
    return 10;
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
    required this.chartUnits,
  });

  final List<_TrendPoint> points;
  final Color yesColor;
  final Color noColor;
  final double leftPadding;
  final double rightPadding;
  final int? hoveredIndex;
  final double chartUnits;

  @override
  void paint(Canvas canvas, Size size) {
    final double plotWidth = math.max(
      1,
      size.width - leftPadding - rightPadding,
    );
    final double plotHeight = size.height;
    _drawGrid(canvas, size);

    if (points.isEmpty) {
      return;
    }

    final List<Offset> yesPoints = _toOffsets(
      percentForPoint: (_TrendPoint point) => point.yesPercent,
      width: plotWidth,
      height: plotHeight,
    );
    final List<Offset> noPoints = _toOffsets(
      percentForPoint: (_TrendPoint point) => point.noPercent,
      width: plotWidth,
      height: plotHeight,
    );

    final double rightX = leftPadding + plotWidth;
    final Path yesPath = _stepPath(yesPoints, rightX);
    final Path noPath = _stepPath(noPoints, rightX);
    _drawFill(canvas, yesPath, yesPoints, plotHeight, rightX, yesColor);
    _drawFill(canvas, noPath, noPoints, plotHeight, rightX, noColor);

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
      final double x = yesPoints[hoveredIndex!].dx;
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
    required double Function(_TrendPoint point) percentForPoint,
    required double width,
    required double height,
  }) {
    return List<Offset>.generate(points.length, (int i) {
      final _TrendPoint point = points[i];
      final double x =
          leftPadding +
          (chartUnits <= 0
              ? 0
              : (point.pickUnit.clamp(0, chartUnits) / chartUnits) * width);
      final double y =
          (1 - percentForPoint(point).clamp(0, 100) / 100) * height;
      return Offset(x, y);
    });
  }

  Path _stepPath(List<Offset> points, double rightX) {
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final Offset previous = points[i - 1];
      final Offset current = points[i];
      path
        ..lineTo(previous.dx, current.dy)
        ..lineTo(current.dx, current.dy);
    }
    if (points.last.dx < rightX) {
      path.lineTo(rightX, points.last.dy);
    }
    return path;
  }

  void _drawFill(
    Canvas canvas,
    Path linePath,
    List<Offset> points,
    double height,
    double rightX,
    Color color,
  ) {
    final Path fillPath = Path.from(linePath)
      ..lineTo(rightX, height)
      ..lineTo(points.first.dx, height)
      ..close();
    final Rect bounds = Rect.fromLTWH(0, 0, rightX, height);
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
        oldDelegate.rightPadding != rightPadding ||
        oldDelegate.chartUnits != chartUnits;
  }
}
