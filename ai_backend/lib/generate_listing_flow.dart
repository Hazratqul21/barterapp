import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:schemantic/schemantic.dart';

// Initialize Genkit instance with Google AI plugin
final ai = Genkit(
  plugins: [googleAI()],
);

/// One field, in the three languages the product ships in.
///
/// The API refuses a listing that is missing any of them — `listing_translations`
/// is keyed on `(listing_id, locale)` and all three rows have to exist. The
/// first version of this flow returned a single Uzbek string, so what it handed
/// back filled one of the three boxes on the form and left the publish button
/// disabled. The person was worse off than if they had typed it themselves:
/// the field looked done and the form would not move.
Map<String, Object> _trilingual(String what) => {
  'type': 'object',
  'properties': {
    'uz': {'type': 'string', 'description': "$what — o'zbek tilida"},
    'ru': {'type': 'string', 'description': '$what — на русском языке'},
    'en': {'type': 'string', 'description': '$what — in English'},
  },
  'required': ['uz', 'ru', 'en'],
};

// Define the Flow
final generateListingFlow = ai.defineFlow(
  name: 'generateListing',
  inputSchema: SchemanticType.string(),
  outputSchema: SchemanticType.from<Map<String, dynamic>>(
    jsonSchema: {
      'type': 'object',
      'properties': {
        'title': _trilingual('Qisqa, aniq sarlavha'),
        'description': _trilingual('Batafsil tavsif'),
        'category': _trilingual('Toifa nomi'),
        'condition': _trilingual('Holati: yangi, ishlatilgan, ta\'mir talab'),
        'quantity': _trilingual('Miqdori, o\'lchov birligi bilan'),
        // The app prices everything in so'm; `value.minor` is tiyin. Asking for
        // dollars — as the first version did — meant a laptop came back as
        // `400`, which the form read as 400 so'm and published as four hundred
        // so'm. Three orders of magnitude is not a rounding error on a
        // marketplace where the number is the whole negotiation.
        'suggested_value_som': {
          'type': 'number',
          'description':
              "Taxminiy bozor qiymati — O'ZBEK SO'MIDA, butun son. "
              'Masalan ishlatilgan noutbuk uchun 5000000.',
        },
        'tag': {
          'type': 'string',
          'enum': [
            'agri',
            'livestock',
            'machinery',
            'transport',
            'electronics',
            'construction',
          ],
          'description': 'Ilovadagi olti toifadan eng mosi',
        },
      },
      'required': [
        'title',
        'description',
        'category',
        'condition',
        'quantity',
        'suggested_value_som',
        'tag',
      ],
    },
    parse: (obj) => Map<String, dynamic>.from(obj as Map),
  ),
  fn: (input, _) async {
    final response = await ai.generate(
      model: googleAI.gemini('gemini-1.5-flash'),
      prompt: '''
Foydalanuvchi quyidagi matnni barter (ayirboshlash) e'loni sifatida
joylashtirmoqchi:

"$input"

Vazifang — buni to'liq e'longa aylantirish. Qoidalar:

1. Har bir matn maydonini UCHALA tilda ber: o'zbek (uz), rus (ru), ingliz (en).
   Bu tarjima emas, har bir tilda tabiiy yozilgan matn bo'lsin.
2. Sarlavha qisqa bo'lsin — 60 belgidan oshmasin.
3. Tavsif faqat foydalanuvchi aytgan narsaga asoslansin. Bilmagan narsangni
   o'ylab topma: kafolat, hujjat, ish soati kabi tafsilotlarni to'qima.
4. Qiymatni O'ZBEK SO'MIDA ber, dollarda emas.
5. Toifani berilgan oltitadan tanla.
''',
    );

    try {
      return response.output as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {};
    }
  },
);
