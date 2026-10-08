import re

keys = [
    {
        'key': 'actionReportReasonInappropriate',
        'en': 'Inappropriate',
        'uz': 'Nomaqbul',
        'ru': 'Неприемлемо'
    },
    {
        'key': 'actionDeleteListingConfirm',
        'en': 'Are you sure you want to delete this listing?',
        'uz': 'Ushbu e’lonni o‘chirib tashlashni xohlaysizmi?',
        'ru': 'Вы уверены, что хотите удалить это объявление?'
    },
    {
        'key': 'createPreferredCategory',
        'en': 'Preferred Category (Optional)',
        'uz': 'Afzal toifa (Ixtiyoriy)',
        'ru': 'Предпочтительная категория (Необязательно)'
    },
    {
        'key': 'createPreferCash',
        'en': 'I prefer cash for this item',
        'uz': 'Ushbu narsa uchun naqd pulni afzal ko‘raman',
        'ru': 'Я предпочитаю наличные за этот товар'
    },
    {
        'key': 'currencySom',
        'en': 'so‘m',
        'uz': 'so‘m',
        'ru': 'сум'
    }
]

def append_to_abstract(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    # insert before the last closing brace
    parts = content.rsplit('}', 1)
    
    new_props = ""
    for k in keys:
        new_props += f"\n  /// No description provided for @{k['key']}.\n"
        new_props += f"  String get {k['key']};\n"
        
    content = parts[0] + new_props + "}\n"
    
    with open(filepath, 'w') as f:
        f.write(content)

def append_to_impl(filepath, lang):
    with open(filepath, 'r') as f:
        content = f.read()
    
    parts = content.rsplit('}', 1)
    
    new_props = ""
    for k in keys:
        val = k[lang].replace("'", "\\'")
        new_props += f"\n  @override\n  String get {k['key']} => '{val}';\n"
        
    content = parts[0] + new_props + "}\n"
    
    with open(filepath, 'w') as f:
        f.write(content)

append_to_abstract('lib/l10n/app_localizations.dart')
append_to_impl('lib/l10n/app_localizations_en.dart', 'en')
append_to_impl('lib/l10n/app_localizations_uz.dart', 'uz')
append_to_impl('lib/l10n/app_localizations_ru.dart', 'ru')

print("Done")
