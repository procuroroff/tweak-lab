// TweakLab — учебный твик для iOS 15.x (rootless).
//
// Демонстрирует три техники, которые нужны при разработке и реверсе твиков:
//   1) хук UIKit-иерархии: обход вьюх, подмена текста UILabel, вставка своих карточек;
//   2) хук сетевого слоя: перехват -[NSURLSession dataTaskWith...] и подмена JSON-ответа;
//   3) трассировка через os_log, чтобы видеть в консоли, что и когда вызывается.
//
// Цель — только собственное демо-приложение TweakLabDemo (см. DemoApp/). Имена классов
// и URL-фрагмент вынесены в константы, чтобы их было удобно заменить при экспериментах
// со своим тестовым приложением.

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <os/log.h>

// Класс из DemoApp/DemoApp.m — объявляем заранее, чтобы внутри %hook был доступен self.view
@interface TLDemoViewController : UIViewController
@end

#pragma mark - Логирование

static os_log_t gLog;

#define TLLOG(fmt, ...) os_log_info(gLog, "[TweakLab] " fmt, ##__VA_ARGS__)

// Включается так: defaults write com.example.tweaklabdemo TLLogAllLabels -bool YES
// (читается один раз при загрузке твика; для демо этого достаточно)
static BOOL TLVerboseLabels(void)
{
    static BOOL enabled;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        enabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"TLLogAllLabels"];
    });
    return enabled;
}

%ctor {
    gLog = os_log_create("com.example.tweaklab", "general");
    TLLOG("loaded into %{public}@ (pid %d)",
          NSProcessInfo.processInfo.processName,
          (int)NSProcessInfo.processInfo.processIdentifier);
}

#pragma mark - Помощники

static const NSInteger kTLBannerTag = 0x7E45;

static void TLDumpView(UIView *view, NSUInteger depth)
{
    NSMutableString *pad = [NSMutableString string];
    for (NSUInteger i = 0; i < depth; i++) {
        [pad appendString:@"  "];
    }

    NSString *text = @"-";
    if ([view isKindOfClass:UILabel.class]) {
        text = ((UILabel *)view).text ?: @"(nil)";
    }

    TLLOG("%{public}@%{public}@ frame=%{public}@ text=%{public}@",
          pad, NSStringFromClass(view.class), NSStringFromCGRect(view.frame), text);

    for (UIView *sub in view.subviews) {
        TLDumpView(sub, depth + 1);
    }
}

static UIView *TLMakeBanner(NSString *title, NSString *subtitle, UIColor *background)
{
    UIView *card = [UIView new];
    card.tag = kTLBannerTag;
    card.backgroundColor = background;
    card.layer.cornerRadius = 16.0;
    card.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLabel = [UILabel new];
    titleLabel.text = title;
    titleLabel.font = [UIFont boldSystemFontOfSize:17.0];
    titleLabel.textColor = UIColor.whiteColor;
    titleLabel.numberOfLines = 0;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *subtitleLabel = [UILabel new];
    subtitleLabel.text = subtitle;
    subtitleLabel.font = [UIFont systemFontOfSize:14.0];
    subtitleLabel.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.75];
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UIButton *more = [UIButton buttonWithType:UIButtonTypeSystem];
    [more setTitle:@"подробнее (демо)" forState:UIControlStateNormal];
    more.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [more addAction:[UIAction actionWithHandler:^(__kindof UIAction *_Nonnull action) {
        TLLOG("banner action tapped");
    }] forControlEvents:UIControlEventTouchUpInside];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[ titleLabel, subtitleLabel, more ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 6.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:14.0],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14.0],
    ]];

    return card;
}

// Демо-ответ API: подменяем тело запроса на локальный JSON, сеть не трогаем.
static NSData *TLDemoDebtPayload(void)
{
    NSDictionary *payload = @{
        @"items" : @[
            @{
                @"title" : @"DEMO: тестовая запись",
                @"amount" : @(1234.56),
                @"count" : @3,
                @"source" : @"TweakLab local stub",
            },
        ],
    };

    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
    if (!data) {
        TLLOG("stub JSON failed: %{public}@", error.localizedDescription);
    }
    return data;
}

#pragma mark - 1. Хуки UIKit

%hook UILabel

- (void)setText:(NSString *)text
{
    if (TLVerboseLabels() && text.length > 0) {
        TLLOG("UILabel setText: %{public}@", text);
    }

    // Пример точечной подмены по маркеру, который вы сами положили в демо-приложение
    if ([text isEqualToString:@"__TL_REPLACE_ME__"]) {
        TLLOG("placeholder label rewritten");
        %orig(@"Подменённый текст (демо)");
        return;
    }

    %orig;
}

%end

%hook TLDemoViewController

- (void)viewDidLoad
{
    %orig;

    if ([self.view viewWithTag:kTLBannerTag]) {
        return; // уже вставили
    }

    UIView *banner = TLMakeBanner(@"Демо-плашка",
                                  @"Вставлено твиком из -viewDidLoad",
                                  UIColor.systemIndigoColor);
    [self.view addSubview:banner];

    [NSLayoutConstraint activateConstraints:@[
        [banner.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [banner.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],
        [banner.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12.0],
    ]];

    TLLOG("banner injected into %{public}@", NSStringFromClass(self.class));
}

- (void)viewDidAppear:(BOOL)animated
{
    %orig;

    if (TLVerboseLabels()) {
        TLLOG("--- view hierarchy of %{public}@ ---", NSStringFromClass(self.class));
        TLDumpView(self.view, 0);
    }
}

%end

/*
 * Когда имена своих вью неизвестны (а это всегда первый шаг реверса), удобно
 * ловить их не по классу, а по содержимому: например, перебрать окно и найти
 * UILabel с нужным текстом, затем подняться по superview до карточки.
 *
 *   UIView *root = UIApplication.sharedApplication.keyWindow;
 *   TLDumpView(root, 0);  // смотреть в Console.app / idevicesyslog
 *
 * Дальше в найденный класс добавляется %hook — как у TLDemoViewController выше.
 */

#pragma mark - 2. Хук сетевого слоя

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url
                        completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler
{
    if (completionHandler && [url.absoluteString containsString:@"api.example.test/debts"]) {
        TLLOG("intercepted dataTaskWithURL: %{public}@", url.absoluteString);

        NSHTTPURLResponse *response =
            [[NSHTTPURLResponse alloc] initWithURL:url
                                        statusCode:200
                                       HTTPVersion:@"HTTP/1.1"
                                      headerFields:@{@"Content-Type" : @"application/json"}];
        NSData *body = TLDemoDebtPayload();

        // Колбэк вызываем асинхронно — как это делает настоящая сессия
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(body, response, nil);
        });

        return nil; // задача не создаётся: данные уже отданы выше
    }

    return %orig;
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler
{
    if (completionHandler && [request.URL.absoluteString containsString:@"api.example.test/debts"]) {
        TLLOG("intercepted dataTaskWithRequest: %{public}@", request.URL.absoluteString);

        NSHTTPURLResponse *response =
            [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                        statusCode:200
                                       HTTPVersion:@"HTTP/1.1"
                                      headerFields:@{@"Content-Type" : @"application/json"}];
        NSData *body = TLDemoDebtPayload();

        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(body, response, nil);
        });

        return nil;
    }

    return %orig;
}

%end
