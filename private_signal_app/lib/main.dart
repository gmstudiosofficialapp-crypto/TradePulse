import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const PrivateSignalApp());
}

class PrivateSignalApp extends StatefulWidget {
  const PrivateSignalApp({super.key, this.httpBase = 'http://127.0.0.1:8000'});

  final String httpBase;

  @override
  State<PrivateSignalApp> createState() => _PrivateSignalAppState();
}

class _PrivateSignalAppState extends State<PrivateSignalApp> {
  String asset = 'BTC/USD-OTC';
  Map<String, dynamic>? truth;
  String? error;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _poll;

  static const assets = [
    'BTC/USD-OTC',
    'ETH/USD-OTC',
    'EUR/USD-OTC',
    'GOLD/USD-OTC',
    'NASDAQ-OTC',
  ];

  @override
  void initState() {
    super.initState();
    _connect();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _fetch());
  }

  Future<void> _fetch() async {
    try {
      final uri = Uri.parse('${widget.httpBase}/api/private/reference')
          .replace(queryParameters: {'asset': asset});
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        setState(() {
          truth = jsonDecode(response.body) as Map<String, dynamic>;
          error = null;
        });
      }
    } catch (exc) {
      setState(() => error = 'Reference API unreachable');
    }
  }

  void _connect() {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:8000/ws/private-reference'),
    );
    _sub = _channel!.stream.listen(
      (raw) {
        if (raw is! String) return;
        final message = jsonDecode(raw);
        if (message is Map && message['type'] == 'ground_truth') {
          if (message['asset'] == asset) {
            setState(() => truth = Map<String, dynamic>.from(message));
          }
        }
      },
      onError: (_) {},
    );
    _channel!.sink.add(jsonEncode({'type': 'subscribe', 'asset': asset}));
    unawaited(_fetch());
  }

  @override
  void dispose() {
    _poll?.cancel();
    unawaited(_sub?.cancel());
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = truth ?? {};
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: const Color(0xFF070B14),
        appBar: AppBar(
          title: const Text('PRIVATE TEST / GROUND TRUTH'),
          backgroundColor: const Color(0xFF10182A),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Personal testing/reference only. This is NOT a real prediction and is not a user-facing TradePulse feature.',
              ),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: asset,
                items: [
                  for (final item in assets)
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => asset = value);
                  _channel?.sink.add(jsonEncode({'type': 'subscribe', 'asset': value}));
                  unawaited(_fetch());
                },
              ),
              const SizedBox(height: 24),
              Text(asset, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text('Reference Direction: ${data['reference_direction'] ?? '—'}'),
              Text('Next Candle Result: ${data['next_candle_result'] ?? '—'}'),
              Text(
                'Reference Result: ${data['reference_direction'] == 'BUY' && data['next_candle_result'] == 'UP' ? 'WIN' : data['reference_direction'] == 'SELL' && data['next_candle_result'] == 'DOWN' ? 'WIN' : data.isEmpty ? '—' : 'COMPARE'}',
              ),
              const SizedBox(height: 16),
              const Text('Normal TradePulse users never receive this future/reference feed.'),
              if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ),
    );
  }
}
