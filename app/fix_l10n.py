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
    
    # The abstract class L ends right before `class _LDelegate extends LocalizationsDelegate<L> {`
    parts = content.split('class _LDelegate')
    
    new_props = ""
    for k in keys:
        if k['key'] in content: continue
        new_props += f"\n  /// No description provided for @{k['key']}.\n"
        new_props += f"  String get {k['key']};\n"
        
    # we need to insert right before the last closing brace in parts[0]
    subparts = parts[0].rsplit('}', 1)
    new_part0 = subparts[0] + new_props + "}\n\n"
    
    content = new_part0 + 'class _LDelegate' + parts[1]
    
    with open(filepath, 'w') as f:
        f.write(content)

def append_to_impl(filepath, lang):
    with open(filepath, 'r') as f:
        content = f.read()
    
    # there is only one class in the impl files, so we just find the last }
    parts = content.rsplit('}', 1)
    
    new_props = ""
    for k in keys:
        if k['key'] in content: continue
        val = k[lang].replace("'", "\\'")
        new_props += f"\n  @override\n  String get {k['key']} => '{val}';\n"
        
    content = parts[0] + new_props + "}\n"
    
    with open(filepath, 'w') as f:
        f.write(content)

append_to_abstract('lib/l10n/app_localizations.dart')
append_to_impl('lib/l10n/app_localizations_en.dart', 'en')
append_to_impl('lib/l10n/app_localizations_uz.dart', 'uz')
append_to_impl('lib/l10n/app_localizations_ru.dart', 'ru')

print("Done fixing")
