import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:schemantic/schemantic.dart';

// Initialize Genkit instance with Google AI plugin
final ai = Genkit(
  plugins: [googleAI()],
);

// Define the Flow
final generateListingFlow = ai.defineFlow(
  name: 'generateListing',
  inputSchema: SchemanticType.string(),
  outputSchema: SchemanticType.from<Map<String, dynamic>>(
    jsonSchema: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string', 'description': 'Catchy title'},
        'description': {'type': 'string', 'description': 'Detailed description'},
        'category': {'type': 'string', 'description': 'Category e.g. Elektronika, Avto'},
        'suggested_value': {'type': 'number', 'description': 'Approximate USD value'},
      },
      'required': ['title', 'description', 'category', 'suggested_value'],
    },
    parse: (obj) => Map<String, dynamic>.from(obj as Map),
  ),
  fn: (input, _) async {
    final response = await ai.generate(
      model: googleAI.gemini('gemini-1.5-flash'),
      prompt: '''
Foydalanuvchi quyidagi matnni barter e'loni sifatida joylashtirmoqchi:
"$input"

Iltimos, uni chiroyli, professional o'zbek tilidagi barter e'loni ko'rinishida formatlab bering. Sarlavha, batafsil tavsif, va kategoriyasini aniqlang.
Natijani JSON formatida qaytaring: { "title": "...", "description": "...", "category": "...", "suggested_value": 0 }
''',
    );

    try {
      return response.output as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {};
    }
  },
);
