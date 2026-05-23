import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shows data from [fetch] and silently re-fetches every [period].
///
/// - First load shows a spinner.
/// - Background polls keep the current data on screen (no spinner flash) and
///   swap in new data when it arrives.
/// - Pull-to-refresh forces an immediate fetch.
/// - If a poll fails but we already have data, the old data stays visible
///   (a transient network blip won't blank the screen).
class PollingView<T> extends StatefulWidget {
  final Future<T> Function() fetch;
  final Duration period;
  final Widget Function(BuildContext context, T data, Future<void> Function() refresh) builder;

  const PollingView({
    super.key,
    required this.fetch,
    required this.builder,
    this.period = const Duration(seconds: 15),
  });

  @override
  State<PollingView<T>> createState() => _PollingViewState<T>();
}

class _PollingViewState<T> extends State<PollingView<T>> {
  T? _data;
  Object? _error;
  Timer? _timer;
  bool _inFlight = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(widget.period, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_inFlight) return; // don't stack requests
    _inFlight = true;
    try {
      final result = await widget.fetch();
      if (!mounted) return;
      setState(() {
        _data = result;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      // Keep showing existing data on a transient failure; only surface the
      // error if we have nothing to show yet.
      setState(() => _error = e);
    } finally {
      _inFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data != null) {
      return RefreshIndicator(
        color: AppColors.brandDark,
        onRefresh: _load,
        child: widget.builder(context, _data as T, _load),
      );
    }
    if (_error != null) {
      return _ErrorView(error: _error.toString(), onRetry: _load);
    }
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.statusRedSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 28, color: AppColors.statusRed),
            ),
            const SizedBox(height: 16),
            const Text(
              "Can't reach the CareVoice server",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.brandDark),
            ),
          ],
        ),
      ),
    );
  }
}
