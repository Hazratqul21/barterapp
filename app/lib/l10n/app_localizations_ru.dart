// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class LRu extends L {
  LRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'MAB';

  @override
  String get back => 'Назад';

  @override
  String get retry => 'Повторить';

  @override
  String get clear => 'Сбросить';

  @override
  String get introTitle1 => 'Не продавайте — обменивайте';

  @override
  String get introBody1 =>
      '«У меня есть лишнее X, мне нужно Y.» Искать наличные не нужно — товар за товар.';

  @override
  String get introTitle2 => 'Мы сами найдём нужного человека';

  @override
  String get introBody2 =>
      'Скажите, что отдаёте и что ищете. Покажем подходящих партнёров по стоимости, региону и рейтингу.';

  @override
  String get introTitle3 => 'Торгуйтесь спокойно';

  @override
  String get introBody3 =>
      'Проверенные профили, настоящие отзывы и панель сделки. Каждый обмен проходит на виду.';

  @override
  String get introSkip => 'Пропустить';

  @override
  String get introNext => 'Далее';

  @override
  String get introStart => 'Начать';

  @override
  String get navHome => 'Главная';

  @override
  String get navMatches => 'Совпадения';

  @override
  String get navChat => 'Чат';

  @override
  String get navProfile => 'Профиль';

  @override
  String get navCreate => 'Создать объявление для обмена';

  @override
  String get navSettings => 'Настройки';

  @override
  String get settingsGeneral => 'Общие';

  @override
  String get settingsSecurity => 'Безопасность и платежи';

  @override
  String get feedTradingIn => 'Регион обмена';

  @override
  String get feedSearchHint => 'Товар, услуга, техника…';

  @override
  String get feedHeading => 'Готово к обмену';

  @override
  String feedNearby(int count) {
    return '$count рядом';
  }

  @override
  String feedResults(int count) {
    return 'Найдено объявлений: $count';
  }

  @override
  String get feedEmpty => 'Ничего не найдено';

  @override
  String get feedEmptyHint => 'Попробуйте другое слово или сбросьте фильтр.';

  @override
  String get feedPremium => 'Премиум';

  @override
  String get feedLookingFor => 'Нужно:';

  @override
  String get feedEstValue => 'примерная стоимость';

  @override
  String get feedRegionAny => 'Весь Узбекистан';

  @override
  String get feedCategories => 'Что вы ищете?';

  @override
  String get feedLoadMore => 'Загрузить ещё';

  @override
  String get feedEnd => 'Это все';

  @override
  String get bannerVerifyTitle => 'Повысьте уровень доверия';

  @override
  String get bannerVerifyBody =>
      'Проверенный профиль получает вдвое больше ответов.';

  @override
  String get bannerVerifyAction => 'Пройти проверку';

  @override
  String get bannerCreateTitle => 'Есть что-то лишнее?';

  @override
  String get bannerCreateBody =>
      'Разместите объявление — подходящих партнёров найдём сами.';

  @override
  String get bannerCreateAction => 'Разместить';

  @override
  String get bannerDismiss => 'Закрыть';

  @override
  String get feedPostedAt => 'Опубликовано';

  @override
  String get feedNotifications => 'Уведомления';

  @override
  String get filterAll => 'Все';

  @override
  String get filterAgri => 'Сельское хозяйство';

  @override
  String get filterLivestock => 'Скот';

  @override
  String get filterMachinery => 'Техника';

  @override
  String get filterTransport => 'Транспорт';

  @override
  String get filterElectronics => 'Электроника';

  @override
  String get filterConstruction => 'Стройматериалы';

  @override
  String get listingGives => 'Владелец отдаёт';

  @override
  String get listingWants => 'Хочет получить';

  @override
  String get listingAbout => 'Описание';

  @override
  String get listingSpecs => 'Характеристики';

  @override
  String get listingOwner => 'Владелец объявления';

  @override
  String get listingSimilar => 'Похожие объявления';

  @override
  String get listingMessage => 'Написать';

  @override
  String get listingOffer => 'Отправить предложение';

  @override
  String get listingSave => 'Сохранить';

  @override
  String get listingSaved => 'Сохранено';

  @override
  String get listingCashOk => 'Согласен на доплату';

  @override
  String get listingCashNo => 'Только товар на товар';

  @override
  String get listingSafety =>
      'Осмотрите товар до передачи. Доплату проводите через escrow.';

  @override
  String listingTrades(int count) {
    return '$count сделок';
  }

  @override
  String get specCategory => 'Категория';

  @override
  String get specCondition => 'Состояние';

  @override
  String get specQuantity => 'Количество';

  @override
  String get specPosted => 'Опубликовано';

  @override
  String get specLocation => 'Расположение';

  @override
  String get specValue => 'Примерная стоимость';

  @override
  String get authTitle => 'Ваш номер телефона';

  @override
  String get authSubtitle => 'Отправим SMS-код для входа.';

  @override
  String get authPhoneLabel => 'Номер телефона';

  @override
  String get authSendCode => 'Отправить код';

  @override
  String get authCodeTitle => 'Введите код';

  @override
  String authCodeSubtitle(String phone) {
    return '6-значный код, отправленный на $phone.';
  }

  @override
  String get authVerify => 'Подтвердить';

  @override
  String get authInvalidPhone => 'Введите номер полностью, начиная с +998.';

  @override
  String get authSignedOut => 'Вы не вошли в аккаунт';

  @override
  String get authSignIn => 'Войти';

  @override
  String get authSignOut => 'Выйти';

  @override
  String get authChangeNumber => 'Изменить номер';

  @override
  String authOtpDebug(String code) {
    return 'SMS-провайдер ещё не подключён. Тестовый код: $code';
  }

  @override
  String get authResend => 'Отправить код ещё раз';

  @override
  String get authWithApple => 'Продолжить с Apple';

  @override
  String get authWithGoogle => 'Продолжить с Google';

  @override
  String get authWithFacebook => 'Продолжить с Facebook';

  @override
  String get authOrPhone => 'Или по номеру телефона';

  @override
  String get profileSetupTitle => 'О себе';

  @override
  String get profileEditTitle => 'Редактировать профиль';

  @override
  String get profileSetupLede =>
      'Ваше имя видно в каждом объявлении и предложении. Регион помогает находить партнёров поблизости.';

  @override
  String get profileFirstName => 'Имя';

  @override
  String get profileLastName => 'Фамилия';

  @override
  String get profileHandle => 'Название компании';

  @override
  String get profileHandleHint => 'Необязательно — для бизнес-аккаунтов';

  @override
  String get profileRegion => 'Регион';

  @override
  String get profileRegionHint => 'Регион даёт 30% оценки совпадения';

  @override
  String get profilePhoto => 'Фото';

  @override
  String get profilePhotoPick => 'Выбрать фото';

  @override
  String get profilePhotoChange => 'Заменить фото';

  @override
  String get profileSave => 'Сохранить';

  @override
  String get profileRequired => 'Обязательное поле';

  @override
  String get uploading => 'Загрузка…';

  @override
  String get photoCamera => 'Камера';

  @override
  String get photoGallery => 'Галерея';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileTrustLabel => 'Уровень доверия';

  @override
  String get profileStatActive => 'Активных объявлений';

  @override
  String get profileStatCompleted => 'Завершённых сделок';

  @override
  String get profileStatCompletion => 'Доля завершённых';

  @override
  String get profileLanguage => 'Язык';

  @override
  String get profileMyListings => 'Мои объявления';

  @override
  String get profileReviews => 'Отзывы';

  @override
  String get profileNoReviews => 'Отзывов пока нет.';

  @override
  String get traderVerified => 'Документы подтверждены';

  @override
  String get traderUnverified => 'Аккаунт не подтверждён';

  @override
  String get traderListings => 'Активные объявления';

  @override
  String get traderListingsEmpty => 'Активных объявлений пока нет.';

  @override
  String get traderReviews => 'Отзывы партнёров';

  @override
  String get traderReviewsEmpty => 'Отзывов партнёров пока нет.';

  @override
  String get traderMemberSince => 'В сервисе с';

  @override
  String get traderRating => 'Рейтинг';

  @override
  String get traderDeals => 'Закрытых сделок';

  @override
  String get traderCompletion => 'Доля завершённых';

  @override
  String get traderMessage => 'Написать сообщение';

  @override
  String get traderOnline => 'В сети';

  @override
  String get errorNetwork =>
      'Не удалось связаться с сервером. Проверьте интернет.';

  @override
  String get errorGeneric => 'Что-то пошло не так.';

  @override
  String get comingSoon => 'Этот раздел подключим на следующем этапе.';

  @override
  String get offerTitle => 'Предложить сделку';

  @override
  String get offerYouWant => 'Вам нужно';

  @override
  String get offerSelectItems => 'Выберите своё объявление для обмена';

  @override
  String get offerAddCash => 'Добавить деньги';

  @override
  String get offerAddCashHint => 'чтобы уравнять сделку';

  @override
  String get offerSend => 'Отправить предложение';

  @override
  String get offerNoItems => 'Сначала опубликуйте своё объявление.';

  @override
  String get offerSent => 'Предложение отправлено';

  @override
  String get offerMessage => 'Сообщение';

  @override
  String get offerMessageHint =>
      'Добавьте комментарий к предложению — необязательно';

  @override
  String get offerYouGive => 'Вы отдаёте';

  @override
  String get offerCreateFirst => 'Сначала разместите объявление';

  @override
  String get confirmRemoveCard => 'Удалить эту карту?';

  @override
  String get notFound => 'Не найдено';

  @override
  String get inboxTitle => 'Чаты';

  @override
  String get inboxEmpty => 'Диалогов пока нет.';

  @override
  String inboxUnread(int count) {
    return '$count непрочитанных';
  }

  @override
  String get chatPlaceholder => 'Напишите сообщение…';

  @override
  String get chatSend => 'Отправить';

  @override
  String get chatTyping => 'печатает…';

  @override
  String chatExpiresIn(int hours) {
    return 'Истекает через $hours ч';
  }

  @override
  String get chatExpiresSoon => 'Осталось меньше часа';

  @override
  String get dealCounterTitle => 'Встречное предложение';

  @override
  String get dealCounterCash => 'Доплата';

  @override
  String get dealCounterSend => 'Отправить встречное';

  @override
  String get dealCounterHint =>
      'После отправки очередь отвечать переходит другой стороне.';

  @override
  String get dealYouGive => 'Вы отдаёте';

  @override
  String get dealYouGet => 'Вы получаете';

  @override
  String get dealPending => 'Сделка на рассмотрении';

  @override
  String get dealAccept => 'Принять';

  @override
  String get dealDecline => 'Отклонить';

  @override
  String get dealCounter => 'Встречное предложение';

  @override
  String get dealComplete => 'Завершить сделку';

  @override
  String get dealCompleted => 'Сделка завершена';

  @override
  String get reviewTitle => 'Как прошёл обмен?';

  @override
  String reviewLede(String name) {
    return 'Обмен с $name завершён. Ваш отзыв помогает другим доверять.';
  }

  @override
  String get reviewBody => 'Что напишете?';

  @override
  String get reviewSend => 'Оставить отзыв';

  @override
  String get reviewLater => 'Позже';

  @override
  String get reviewThanks => 'Спасибо за отзыв';

  @override
  String get reviewDone => 'Вы оставили отзыв';

  @override
  String get dealDeclined => 'Отклонено';

  @override
  String get dealAccepted => 'Принято';

  @override
  String get dealTalking => 'Обсуждается';

  @override
  String get dealExpired => 'Истекло';

  @override
  String get matchesTitle => 'Умные совпадения';

  @override
  String get matchesLede =>
      'Совпадения между вашими объявлениями и запросами других.';

  @override
  String get matchesEmpty =>
      'Совпадений пока нет. Появятся, когда вы опубликуете объявление.';

  @override
  String get matchesYours => 'Ваше';

  @override
  String get matchesTheirs => 'Их';

  @override
  String get matchesSkip => 'Пропустить';

  @override
  String get matchesScore => 'совпадение';

  @override
  String get matchesEmptyHint =>
      'Разместите объявление — подходящих партнёров найдём сами.';

  @override
  String get matchesCreate => 'Разместить объявление';

  @override
  String get inboxEmptyHint =>
      'Разговор начинается с предложения. Отправьте его на понравившееся объявление.';

  @override
  String get inboxPickThread => 'Выберите разговор слева.';

  @override
  String get inboxSignIn => 'Войдите, чтобы увидеть свои разговоры.';

  @override
  String get accountSignIn =>
      'Этот раздел привязан к вашему аккаунту. Войдите, чтобы продолжить.';

  @override
  String get matchesSignIn =>
      'Совпадения ищутся по вашим объявлениям — сначала войдите.';

  @override
  String get agoNow => 'сейчас';

  @override
  String agoMinutes(int count) {
    return '$count мин';
  }

  @override
  String agoHours(int count) {
    return '$count ч';
  }

  @override
  String agoDays(int count) {
    return '$count дн';
  }

  @override
  String get matchesOffer => 'Отправить предложение';

  @override
  String get notificationsTitle => 'Уведомления';

  @override
  String get notificationsEmpty => 'Новых уведомлений нет.';

  @override
  String get notifyToday => 'Сегодня';

  @override
  String get notifyEarlier => 'Ранее';

  @override
  String get notificationsEmptyHint =>
      'Предложения, совпадения и сообщения появятся здесь.';

  @override
  String get notificationsMarkAll => 'Отметить всё прочитанным';

  @override
  String get createTitle => 'Создать обмен';

  @override
  String get createGive => 'Что я отдаю';

  @override
  String get createTake => 'Что я хочу получить';

  @override
  String get createFieldTitle => 'Заголовок';

  @override
  String get createFieldDesc => 'Описание';

  @override
  String get createFieldCategory => 'Категория';

  @override
  String get createFieldValue => 'Примерная стоимость';

  @override
  String get createFieldCondition => 'Состояние';

  @override
  String get createFieldQuantity => 'Количество';

  @override
  String get createFieldWants => 'На что меняете';

  @override
  String get createPhotos => 'Фото (URL, по одному в строке)';

  @override
  String get createPublish => 'Опубликовать объявление';

  @override
  String get createLangHint =>
      'Заполните на всех трёх языках — иначе опубликовать нельзя.';

  @override
  String get createRequired => 'Это поле не может быть пустым';

  @override
  String get createPublished => 'Объявление опубликовано';

  @override
  String get createStepPhotos => 'Фотографии';

  @override
  String get createStepGive => 'Что вы отдаёте?';

  @override
  String get createStepTake => 'Что вам нужно?';

  @override
  String get createStepValue => 'Стоимость';

  @override
  String get createNext => 'Далее';

  @override
  String get createBack => 'Назад';

  @override
  String get createPhotosHint =>
      'Первое фото появится в ленте. Нужно хотя бы одно.';

  @override
  String get createGiveHint =>
      'Заполните на всех трёх языках — чтобы читающий по-русски не увидел сломанное приложение.';

  @override
  String get createTakeHint =>
      'Что хотите получить взамен? Это помогает находить совпадения.';

  @override
  String get createValueHint =>
      'Примерная стоимость нужна, чтобы находить равные обмены.';

  @override
  String get createFieldDescription => 'Описание';

  @override
  String get createFieldTag => 'Раздел';

  @override
  String get createWantCategory => 'Из какого раздела?';

  @override
  String get createWantAny => 'Не важно';

  @override
  String get createCashAdd => 'Могу доплатить';

  @override
  String get createCashWant => 'Нужна доплата';

  @override
  String get createQuotaTitle => 'Бесплатные объявления закончились';

  @override
  String get createQuotaBody =>
      'Выберите тариф или перейдите на бизнес-аккаунт.';

  @override
  String get createQuotaOk => 'Понятно';

  @override
  String get cancel => 'Отмена';

  @override
  String get aiTitle => 'ИИ-помощник';

  @override
  String get aiIntro =>
      'Что вы хотите обменять? Напишите коротко — остальное допишет ИИ.';

  @override
  String get aiHint =>
      'Например: У меня iPhone 13 Pro в хорошем состоянии. Меняю на велосипед.';

  @override
  String get aiGenerate => 'Написать';

  @override
  String get aiDone => 'Текст готов. Проверьте и при необходимости поправьте.';

  @override
  String get aiFailed => 'ИИ не ответил. Поля можно заполнить вручную.';

  @override
  String get verifyTitle => 'Безопасность и проверка';

  @override
  String get verifyLevel => 'Уровень доверия';

  @override
  String get verifySteps => 'Этапы проверки';

  @override
  String get verifyStepPhone => 'Номер телефона';

  @override
  String get verifyStepPhoneHint => 'Подтверждается по SMS';

  @override
  String get verifyStepPassport => 'Паспорт';

  @override
  String get verifyStepPassportHint => 'Паспорт или ПИНФЛ';

  @override
  String get verifyStepBusiness => 'Компания';

  @override
  String get verifyStepBusinessHint => 'Документы компании';

  @override
  String get verifyStepBank => 'Банковский счёт';

  @override
  String get verifyStepBankHint => 'Для эскроу-платежей';

  @override
  String get verifyStepVideo => 'Видеоселфи';

  @override
  String get verifyStepVideoHint => 'Селфи-видео на 30 секунд';

  @override
  String verifyProgress(int score) {
    return '$score из 100';
  }

  @override
  String get verifyHeadline => 'Ваш уровень доверия';

  @override
  String get verifyIntro =>
      'Каждый подтверждённый шаг повышает балл доверия — чем он выше, тем чаще отвечают на ваши предложения.';

  @override
  String get verifySubmit => 'Отправить';

  @override
  String get verifyDone => 'Подтверждено';

  @override
  String get verifyPending => 'На проверке';

  @override
  String get verifyTodo => 'Не начато';

  @override
  String get paymentsTitle => 'Способы оплаты';

  @override
  String get paymentsPrimary => 'Основная';

  @override
  String get paymentsMakePrimary => 'Сделать основной';

  @override
  String get paymentsRemove => 'Удалить';

  @override
  String get paymentsHistory => 'Последние платежи';

  @override
  String get paymentsEmpty => 'Платежей пока не было.';

  @override
  String get paymentsCards => 'Карты';

  @override
  String get paymentsNoCards => 'Карта не привязана';

  @override
  String get paymentsNoCardsHint => 'Карта понадобится для эскроу и доплаты.';

  @override
  String get paymentsEmptyHint =>
      'Движение денег появится здесь после завершения сделки.';

  @override
  String get paymentsIn => 'Поступление';

  @override
  String get paymentsOut => 'Списание';

  @override
  String get settingsDarkMode => 'Темная тема';

  @override
  String get errorLoadingCategories => 'Ошибка загрузки категорий';

  @override
  String get matchLabel => 'СОВПАДЕНИЕ';

  @override
  String get okLabel => 'ОК';

  @override
  String get notificationSettings => 'Настройки уведомлений';

  @override
  String get pushNotifications => 'Push уведомления';

  @override
  String get pushNotificationsDesc =>
      'Получайте уведомления о совпадениях и сообщениях';

  @override
  String get editListing => 'Редактировать объявление';

  @override
  String get deleteListing => 'Удалить объявление';

  @override
  String get savedListings => 'Сохраненные объявления';

  @override
  String get reportUser => 'Пожаловаться на пользователя';

  @override
  String get blockUser => 'Заблокировать пользователя';

  @override
  String get saveChanges => 'Сохранить изменения';

  @override
  String get filterTitle => 'Фильтры';

  @override
  String get filterMinPrice => 'Мин. цена (сум)';

  @override
  String get filterMaxPrice => 'Макс. цена (сум)';

  @override
  String get filterRegion => 'Регион';

  @override
  String get filterApply => 'Применить';

  @override
  String get filterClear => 'Очистить';

  @override
  String get errorNoImage => 'Нет изображения';

  @override
  String get errorCategoryLoad => 'Ошибка загрузки категорий';

  @override
  String get actionEdit => 'Редактировать';

  @override
  String get actionDelete => 'Удалить';

  @override
  String get actionCancel => 'Отмена';

  @override
  String get actionOk => 'ОК';

  @override
  String get actionDeleteListing => 'Удалить объявление';

  @override
  String get actionReportUser => 'Пожаловаться на пользователя';

  @override
  String get actionBlockUser => 'Заблокировать';

  @override
  String get actionDeleteAccount => 'Удалить аккаунт';

  @override
  String get actionDarkMode => 'Темная тема';

  @override
  String get emptyMyListings => 'Пока нет объявлений';

  @override
  String get blockedTitle => 'Заблокированные';

  @override
  String get blockedEmpty => 'Нет заблокированных пользователей';

  @override
  String get blockedUnblock => 'Разблокировать';

  @override
  String get notifOffers => 'Предложения';

  @override
  String get notifOffersDesc => 'Уведомление при новом предложении';

  @override
  String get notifMatches => 'Совпадения (Matches)';

  @override
  String get notifMatchesDesc => 'Уведомление, когда найден нужный предмет';

  @override
  String get notifMessages => 'Сообщения';

  @override
  String get notifMessagesDesc => 'Уведомление при новом сообщении';

  @override
  String get notifSystem => 'Системные сообщения';

  @override
  String get notifSystemDesc => 'Важные системные уведомления';

  @override
  String get notifQuietHours => 'Тихие часы';

  @override
  String get notifOff => 'Отключено';

  @override
  String get notifQuietHoursStart => 'Начало тихих часов';

  @override
  String get notifQuietHoursEnd => 'Конец тихих часов';

  @override
  String get notifQuietHoursDisable => 'Отключить тихие часы';

  @override
  String get favSavedListings => 'Сохраненные объявления';

  @override
  String get favNoSavedListings => 'Пока нет сохраненных';

  @override
  String get legalTitle => 'ПРАВОВАЯ ИНФОРМАЦИЯ';

  @override
  String get legalPrivacy => 'Политика конфиденциальности';

  @override
  String get legalTerms => 'Условия использования';

  @override
  String get deleteAccountConfirm =>
      'Вы уверены, что хотите удалить свой аккаунт? Это действие нельзя отменить, и ваши данные будут безвозвратно удалены.';

  @override
  String get profileVerifyAccount => 'Подтвердите свой аккаунт';

  @override
  String get profileVerifyDesc =>
      'Подтвердите свою личность для повышения доверия.';

  @override
  String get actionReportReasonInappropriate => 'Неприемлемо';

  @override
  String get actionDeleteListingConfirm =>
      'Вы уверены, что хотите удалить это объявление?';

  @override
  String get createPreferredCategory =>
      'Предпочтительная категория (Необязательно)';

  @override
  String get createPreferCash => 'Я предпочитаю наличные за этот товар';

  @override
  String get currencySom => 'сум';

  @override
  String get filterSort => 'Сортировка';

  @override
  String get sortNewest => 'Сначала новые';

  @override
  String get sortCheapest => 'По возрастанию стоимости';

  @override
  String get sortExpensive => 'По убыванию стоимости';

  @override
  String get filterInvalidPrice => 'Введите корректную неотрицательную сумму';

  @override
  String get filterInvalidRange =>
      'Минимальная сумма не должна превышать максимальную.';

  @override
  String get navPost => 'Подать';

  @override
  String get reportSent => 'Жалоба отправлена модератору';

  @override
  String get userBlocked => 'Пользователь заблокирован';

  @override
  String get draftFoundTitle => 'Найден черновик';

  @override
  String get draftFoundBody =>
      'Ваше незаконченное объявление сохранено. Продолжить?';

  @override
  String get draftContinue => 'Продолжить';

  @override
  String get draftDiscard => 'Начать заново';

  @override
  String get draftPhotosExpired =>
      'Фото в черновике устарели — добавьте их заново.';

  @override
  String get photoCover => 'Обложка';

  @override
  String get photoUploadFailed => 'Не загрузилось';

  @override
  String get photoReorderHint =>
      'Чтобы изменить порядок, нажмите и перетащите фото. Первое показывается в ленте.';

  @override
  String get createShortPhotos => 'Фото';

  @override
  String get createShortGive => 'Отдаю';

  @override
  String get createShortTake => 'Хочу';

  @override
  String get createShortValue => 'Цена';

  @override
  String get createPreviewTitle => 'Так объявление выглядит в ленте';

  @override
  String get traderNew => 'Новый участник';

  @override
  String get matchMutual => 'Взаимное совпадение';

  @override
  String get matchMutualHint =>
      'Ему тоже нужно то, что есть у вас, — можно обменяться напрямую.';

  @override
  String get matchReasonNamedCategory => 'Нужная вам категория';

  @override
  String get matchReasonValueClose => 'Близкая стоимость';

  @override
  String get matchReasonNearby => 'Рядом';

  @override
  String get matchReasonVerified => 'Проверенный продавец';

  @override
  String get createFieldDistrict => 'Район (необязательно)';

  @override
  String get specRegion => 'Местоположение';

  @override
  String get inboxArchive => 'В архив';

  @override
  String get inboxArchived => 'Архив';

  @override
  String get inboxArchivedDone => 'Чат перенесён в архив';

  @override
  String get inboxUndo => 'Отменить';

  @override
  String get inboxUnarchive => 'Вернуть из архива';

  @override
  String get inboxArchivedEmpty => 'Архив пуст';

  @override
  String get inboxArchivedHint =>
      'Если в архивный чат придёт новое сообщение, он сам вернётся во входящие.';

  @override
  String get dealConfirm => 'Передал и получил';

  @override
  String get dealProblem => 'Есть проблема';

  @override
  String get dealDisputed => 'Спор';

  @override
  String get dealCancelled => 'Отменено';

  @override
  String get dealDisputedOperator =>
      'Открыт спор — его рассматривает оператор. Вещи остаются забронированы.';

  @override
  String get dealCancelledInfo => 'Сделка отменена — вещи снова в продаже.';

  @override
  String get dealResolvedComplete => 'Спор решён: сделка в силе.';

  @override
  String get disputeTitle => 'Что случилось?';

  @override
  String get disputeNoShow => 'Вторая сторона не пришла';

  @override
  String get disputeNotReceived => 'Я отдал, но не получил';

  @override
  String get disputeNotAsDescribed => 'Вещь не соответствует описанию';

  @override
  String get disputeOther => 'Другая причина';

  @override
  String get disputeNote => 'Комментарий (необязательно)';

  @override
  String get disputeSend => 'Открыть спор';

  @override
  String get disputeHint =>
      'Небольшие сделки решаются по правилу сразу, крупные — оператором.';

  @override
  String dealReservedUntil(String date) {
    return 'Вещи забронированы до $date';
  }

  @override
  String dealWaitingPeer(String name) {
    return 'Вы подтвердили. Ждём подтверждения от $name.';
  }

  @override
  String get listingShare => 'Поделиться';

  @override
  String get listingGoneTitle => 'Объявление больше недоступно';

  @override
  String get listingGoneHint =>
      'Владелец удалил его или обмен завершён. В ленте есть похожие.';

  @override
  String get listingGoneBack => 'Вернуться в ленту';

  @override
  String get timelineOffered => 'Предложение';

  @override
  String get timelineAgreed => 'Договорились';

  @override
  String get timelineHandedOver => 'Передано';

  @override
  String get timelineDone => 'Завершено';

  @override
  String timelineSemantics(int step, int total, String name) {
    return 'Сделка: шаг $step из $total, $name';
  }
}
