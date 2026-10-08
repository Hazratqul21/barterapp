import json

keys = {
    'actionReportReasonInappropriate': {
        'en': 'Inappropriate',
        'uz': 'Nomaqbul',
        'ru': 'Неприемлемо'
    },
    'actionDeleteListingConfirm': {
        'en': 'Are you sure you want to delete this listing?',
        'uz': 'Ushbu e’lonni o‘chirib tashlashni xohlaysizmi?',
        'ru': 'Вы уверены, что хотите удалить это объявление?'
    },
    'createPreferredCategory': {
        'en': 'Preferred Category (Optional)',
        'uz': 'Afzal toifa (Ixtiyoriy)',
        'ru': 'Предпочтительная категория (Необязательно)'
    },
    'createPreferCash': {
        'en': 'I prefer cash for this item',
        'uz': 'Ushbu narsa uchun naqd pulni afzal ko‘raman',
        'ru': 'Я предпочитаю наличные за этот товар'
    },
    'currencySom': {
        'en': 'so‘m',
        'uz': 'so‘m',
        'ru': 'сум'
    }
}

for lang in ['en', 'uz', 'ru']:
    with open(f'l10n/app_{lang}.arb', 'r', encoding='utf-8') as f:
        data = json.load(f)
    for k, v in keys.items():
        data[k] = v[lang]
    with open(f'l10n/app_{lang}.arb', 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

print("Done arb")
