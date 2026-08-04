import 'package:flutter/material.dart';
import 'package:knowledgetree/core/theme/colors.dart';

const List<String> _kStageOrder = [
  'searching',
  'crawling',
  'indexing',
  'retrieving',
  'generating',
];

const Map<String, String> _kStageLabel = {
  'searching': 'Searching the web',
  'crawling': 'Crawling pages',
  'indexing': 'Building index',
  'retrieving': 'Ranking relevant context',
  'generating': 'Generating answer',
  'retry': 'Retrying',
};

/// Animated banner shown in the chat while the backend RAG pipeline runs.
/// Pulsing radar rings + a spinning compass convey the "searching the web"
/// state, while the stage list ticks off each completed step.
class WebSearchAnimation extends StatefulWidget {
  final String query;
  final String stage;
  final String message;
  final int attempt;
  final VoidCallback? onStop;

  const WebSearchAnimation({
    super.key,
    required this.query,
    required this.stage,
    required this.message,
    required this.attempt,
    this.onStop,
  });

  @override
  State<WebSearchAnimation> createState() => _WebSearchAnimationState();
}

class _WebSearchAnimationState extends State<WebSearchAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _pulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _currentIndex {
    final i = _kStageOrder.indexOf(widget.stage);
    if (i >= 0) return i;
    if (widget.stage == 'retry') return _kStageOrder.length - 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECFEFF), Color(0xFFEEF2FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ai, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _radar(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Searching the web',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.query,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (widget.attempt > 1) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Attempt ${widget.attempt}',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < _kStageOrder.length; i++) _stageRow(i),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              widget.message,
              key: ValueKey('${widget.stage}_${widget.message}'),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          if (widget.onStop != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: widget.onStop,
                icon: const Icon(Icons.stop_rounded, size: 16),
                label: const Text('Stop search'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.urgent,
                  side: const BorderSide(color: AppColors.urgent, width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _radar() {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              return Container(
                width: 30 + _pulse.value * 22,
                height: 30 + _pulse.value * 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.ai.withValues(alpha: 0.4 * (1 - _pulse.value)),
                    width: 2,
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * 6.28318530718,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.aiGradient,
                  ),
                  child: const Icon(
                    Icons.travel_explore,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _stageRow(int index) {
    final isDone = index < _currentIndex;
    final isActive = index == _currentIndex;
    final isRetry = widget.stage == 'retry' && index == _currentIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          _stageIndicator(isDone: isDone, isActive: isActive, isRetry: isRetry),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _kStageLabel[_kStageOrder[index]]!,
              style: TextStyle(
                color: isActive
                    ? AppColors.textPrimary
                    : isDone
                        ? AppColors.textSecondary
                        : AppColors.textQuaternary,
                fontSize: 12.5,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (isDone)
            const Icon(Icons.check_circle, color: AppColors.success, size: 16)
          else if (isRetry)
            const Icon(Icons.refresh, color: AppColors.warning, size: 16),
        ],
      ),
    );
  }

  Widget _stageIndicator({
    required bool isDone,
    required bool isActive,
    required bool isRetry,
  }) {
    if (isDone) {
      return const Icon(Icons.check_circle_outline, color: AppColors.success, size: 16);
    }
    if (isActive) {
      if (isRetry) {
        return const Icon(Icons.refresh, color: AppColors.warning, size: 16);
      }
      return SizedBox(
        width: 16,
        height: 16,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.ai,
          ),
        ),
      );
    }
    return Icon(Icons.circle, color: AppColors.textQuaternary.withValues(alpha: 0.4), size: 8);
  }
}
