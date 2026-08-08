// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class LRu extends L {
  LRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'BarterApp';

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
  String get matchesOffer => 'Отправить предложение';

  @override
  String get notificationsTitle => 'Уведомления';

  @override
  String get notificationsEmpty => 'Новых уведомлений нет.';

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
  String get verifyTitle => 'Безопасность и проверка';

  @override
  String get verifyLevel => 'Уровень доверия';

  @override
  String get verifySteps => 'Этапы проверки';

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
}
