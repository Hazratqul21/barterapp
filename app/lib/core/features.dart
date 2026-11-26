/// Shaxsni tasdiqlash chaqiriqlari ko'rinadimi.
///
/// O'chiq: hozir hujjat topshirib bo'lmaydi va hech kim ko'rib chiqmaydi,
/// shuning uchun odamni tasdiqlashga chaqirish va "tasdiqlanmagan" deyish
/// noto'g'ri. Qaytarish: `--dart-define=IDENTITY_VERIFICATION=true`.
bool get identityVerificationEnabled =>
    const bool.fromEnvironment('IDENTITY_VERIFICATION');
