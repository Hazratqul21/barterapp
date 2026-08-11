import 'package:genkit_shelf/genkit_shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'package:ai_backend/generate_listing_flow.dart';

void main() async {
  // Define your router and map the flow to an endpoint
  final router = Router()
    ..post('/api/generateListing', shelfHandler(generateListingFlow));

  // Start the HTTP server
  final port = 8081;
  await io.serve(router.call, '0.0.0.0', port);
  print('Genkit AI Server running on http://0.0.0.0:$port');
}
