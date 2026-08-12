# Flutter'ning o'z qoidalari Gradle plagini orqali qo'shiladi — bu yerda faqat
# shu ilovaga xos narsalar bo'lishi kerak.
#
# Hozircha bo'sh, va bu ataylab: ilova kodida runtime'da nom bo'yicha class
# qidiradigan joy yo'q (reflection, `Class.forName`, JSON'ni annotatsiya bilan
# bog'laydigan kutubxona). Modellar qo'lda yozilgan `fromJson` bilan
# ajratiladi, ya'ni R8 nom o'zgartirsa ham hech narsa buzilmaydi.
#
# Agar keyinchalik reflection ishlatadigan kutubxona qo'shilsa, uning
# `-keep` qoidasi shu yerga yoziladi va nega kerakligi izohlanadi.
