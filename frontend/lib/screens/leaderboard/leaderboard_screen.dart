import 'package:flutter/material.dart';

import '../../core/services/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../widgets/layout/responsive_body.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>> _entries = [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final rows = await AppScope.trading(context).loadLeaderboard();
    if (!mounted) return;
    setState(() {
      _entries = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Leaderboard')),
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Text(
                    'Leaderboard',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  Chip(
                    label: const Text('TOP 100'),
                    visualDensity: VisualDensity.compact,
                    color: WidgetStatePropertyAll(
                      colors.accent.withValues(alpha: 0.16),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text('Rank', style: _headStyle(context)),
                  ),
                  Expanded(child: Text('Name', style: _headStyle(context))),
                  Text("Today's Win", style: _headStyle(context)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: _entries.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: colors.cardBorder.withValues(alpha: 0.5),
                      ),
                      itemBuilder: (context, index) {
                        final row = _entries[index];
                        final rank = row['rank'] as int? ?? index + 1;
                        final name = row['name'] as String? ?? '';
                        final win = (row['todays_win'] as num?)?.toDouble() ?? 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 56,
                                child: Text(
                                  '#$rank',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                AppUtils.formatMoney(win).replaceAll('.00', ''),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: colors.accent,
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
    );
  }

  TextStyle? _headStyle(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
          color: context.tpColors.mutedText,
          fontWeight: FontWeight.w700,
        );
  }
}
