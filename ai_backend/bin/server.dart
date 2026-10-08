import 'dart:io';

import 'package:genkit_shelf/genkit_shelf.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'package:ai_backend/generate_listing_flow.dart';

/// Simple API key middleware. The key is read from the AI_API_KEY environment
/// variable. If the variable is not set, the server refuses to start.
shelf.Middleware apiKeyAuth(String expectedKey) {
  return (shelf.Handler innerHandler) {
    return (shelf.Request request) {
      final auth = request.headers['x-api-key'] ?? '';
      if (auth != expectedKey) {
        return shelf.Response(401,
            body: '{"error":"Unauthorized"}',
            headers: {'content-type': 'application/json'});
      }
      return innerHandler(request);
    };
  };
}

/// Rate limiter: max [limit] requests per [window] from a single IP.
shelf.Middleware rateLimiter({int limit = 30, Duration window = const Duration(minutes: 1)}) {
  final Map<String, List<DateTime>> buckets = {};

  return (shelf.Handler innerHandler) {
    return (shelf.Request request) {
      final ip = request.headers['x-forwarded-for']?.split(',').first.trim()
          ?? request.requestedUri.host;
      final now = DateTime.now();
      final cutoff = now.subtract(window);

      buckets[ip] = (buckets[ip] ?? [])
        ..removeWhere((t) => t.isBefore(cutoff))
        ..add(now);

      if (buckets[ip]!.length > limit) {
        return shelf.Response(429,
            body: '{"error":"Too many requests"}',
            headers: {'content-type': 'application/json'});
      }
      return innerHandler(request);
    };
  };
}

void main() async {
  // Validate API key exists
  final apiKey = Platform.environment['AI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln(
      'ERROR: AI_API_KEY environment variable is required.\n'
      'Set it: export AI_API_KEY=\$(openssl rand -base64 32)',
    );
    exit(1);
  }

  // Build pipeline with security middleware
  final handler = const shelf.Pipeline()
      .addMiddleware(rateLimiter())
      .addMiddleware(apiKeyAuth(apiKey))
      .addHandler(
        (Router()
          ..post('/api/generateListing', shelfHandler(generateListingFlow)))
        .call,
      );

  final port = int.parse(Platform.environment['PORT'] ?? '8081');
  await io.serve(handler, '0.0.0.0', port);
  print('Genkit AI Server running on http://0.0.0.0:$port (authenticated)');
}
