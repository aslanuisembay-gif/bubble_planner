/// Длинные юридические тексты (RU/EN). Короткие заголовки и кнопки — в [translations.dart].
class AppLegalTexts {
  AppLegalTexts._();

  static const String ruPrivacyBody = '''
1. Общие положения
Настоящая политика описывает, какие данные могут обрабатываться при использовании приложения Bubble Planner («Сервис») и в каких целях. Используя Сервис, вы подтверждаете, что ознакомились с этим документом.

2. Кто отвечает за обработку
Оператором персональных данных в смысле применимого законодательства (в т.ч. ФЗ РФ № 152-ФЗ «О персональных данных») является лицо, указанное владельцем приложения в публичных материалах Сервиса (или вы можете связаться с нами по контактам ниже).

3. Какие данные могут обрабатываться
• Данные учётной записи: идентификатор пользователя, адрес электронной почты или иной логин, а также данные, необходимые для аутентификации (в зависимости от выбранного способа входа).
• Содержимое, которое вы вводите в приложении: задачи, напоминания, тексты, голосовой ввод (если вы включили соответствующую функцию), вложения и изображения.
• Технические данные: тип устройства, версия ОС, диагностические логи, данные о сессии, необходимые для стабильной работы и безопасности.
• Для веб-версии: локальное хранилище браузера (например, localStorage) для сохранения настроек и демо-данных на вашем устройстве.

4. Цели обработки
• Предоставление функций планирования и синхронизации между устройствами.
• Улучшение безопасности, предотвращение злоупотреблений и восстановление доступа.
• Техническая поддержка и исправление ошибок.

5. Передача третьим лицам
Для работы облачных функций могут использоваться сервисы инфраструктуры (например, хостинг провайдер Convex и связанные с ним компоненты). Такие поставщики обрабатывают данные только в объёме, необходимом для работы Сервиса, и согласно их условиям.

6. Срок хранения
Данные хранятся в течение срока, необходимого для целей обработки, либо до удаления вами аккаунта / данных в приложении, если такая функция предусмотрена, либо до отзыва согласия — в пределах, допустимых законом.

7. Ваши права
Вы имеете право запросить доступ к своим данным, уточнение, блокирование или удаление — в объёме, предусмотренном законом. Для этого используйте контакт ниже.

8. Контакт
По вопросам персональных данных и реализации прав: укажите e-mail поддержки в настройках приложения или на сайте проекта (если применимо).
''';

  static const String enPrivacyBody = '''
1. General
This policy describes what data may be processed when you use Bubble Planner (“the Service”) and for what purposes. By using the Service you confirm that you have read this document.

2. Data controller
The controller of personal data under applicable law (including Russian Federal Law No. 152-FZ where it applies) is the person identified by the app owner in public materials (or contact us using the details below).

3. Data that may be processed
• Account data: user identifier, email or other login, and authentication data depending on the sign-in method.
• Content you enter in the app: tasks, reminders, text, voice input if you enable it, attachments and images.
• Technical data: device type, OS version, diagnostic logs, session data needed for stability and security.
• Web version: browser local storage (e.g. localStorage) for settings and demo data on your device.

4. Purposes
• Providing planning and synchronization across devices.
• Security, abuse prevention, and access recovery.
• Support and bug fixes.

5. Third parties
Cloud features may use infrastructure providers (e.g. Convex hosting and related components). They process data only to the extent needed for the Service and under their terms.

6. Retention
Data are kept for as long as needed for these purposes, or until you delete your account or data in the app where that is available, or until you withdraw consent — within what the law allows.

7. Your rights
You may request access, rectification, blocking, or deletion to the extent provided by law. Use the contact below.

8. Contact
For personal data and rights requests: use the support email in app settings or on the project website if applicable.
''';

  static const String ruConsentBody = '''
Нажимая «Принимаю» ниже или продолжая пользоваться Сервисом после ознакомления с политикой конфиденциальности, вы даёте согласие на обработку персональных данных, которые вы вводите в приложении: в том числе задач, напоминаний, текста, голосового ввода (если включён), а также данных учётной записи и технических данных, необходимых для работы Сервиса.

Обработка включает сбор, запись, систематизацию, накопление, хранение, уточнение (обновление, изменение), использование, передачу (предоставление доступа) инфраструктурным поставщикам в объёме, необходимом для работы Сервиса, обезличивание, блокирование, удаление, уничтожение персональных данных — в целях, указанных в политике конфиденциальности.

Вы вправе отозвать согласие, прекратив использование Сервиса и удалив данные там, где это предусмотрено функционалом, либо обратившись по контакту из политики. Отзыв отражается в пределах технической и правовой возможности.

Согласие действует с момента принятия до момента отзыва или удаления данных.
''';

  static const String enConsentBody = '''
By tapping “Accept” below or continuing to use the Service after reading the privacy policy, you consent to the processing of personal data you enter in the app, including tasks, reminders, text, voice input if enabled, account data, and technical data needed for the Service.

Processing includes collection, recording, organization, storage, updating, use, transfer to infrastructure providers to the extent necessary for the Service, anonymization, blocking, deletion, and destruction of personal data — for the purposes set out in the privacy policy.

You may withdraw consent by stopping use of the Service and deleting data where the app allows, or by contacting us via the policy. Withdrawal is applied within technical and legal limits.

Consent is effective from acceptance until withdrawal or deletion of data.
''';
}
