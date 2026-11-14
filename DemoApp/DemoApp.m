// Минимальное демо-приложение TweakLabDemo — цель для твика TweakLab.
//
// Как собрать:
//   1. Xcode -> File -> New -> Project -> iOS App, имя TweakLabDemo, язык Objective-C.
//   2. Bundle Identifier: com.example.tweaklabdemo (должен совпадать с TweakLab.plist).
//   3. Удалить SceneDelegate/Storyboard-обвязку и положить этот файл вместо AppDelegate.
//   4. Main.storyboard не нужен: окно создаётся вручную.

#import <UIKit/UIKit.h>

#pragma mark - Демо-экран

@interface TLDemoViewController : UIViewController
@end

@implementation TLDemoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"TweakLab Demo";
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    UILabel *status = [UILabel new];
    status.text = @"Статус: без ограничений";
    status.font = [UIFont boldSystemFontOfSize:20.0];
    status.numberOfLines = 0;
    status.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:status];

    UILabel *placeholder = [UILabel new];
    placeholder.text = @"__TL_REPLACE_ME__"; // этот текст подменит хук UILabel
    placeholder.textColor = UIColor.secondaryLabelColor;
    placeholder.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:placeholder];

    UIButton *fetch = [UIButton buttonWithType:UIButtonTypeSystem];
    [fetch setTitle:@"Запросить задолженности (демо)" forState:UIControlStateNormal];
    [fetch addTarget:self action:@selector(loadDebts) forControlEvents:UIControlEventTouchUpInside];
    fetch.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:fetch];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [status.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20.0],
        [status.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20.0],
        [status.topAnchor constraintEqualToAnchor:safe.topAnchor constant:120.0], // оставляем место плашке твика

        [placeholder.leadingAnchor constraintEqualToAnchor:status.leadingAnchor],
        [placeholder.topAnchor constraintEqualToAnchor:status.bottomAnchor constant:16.0],

        [fetch.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [fetch.topAnchor constraintEqualToAnchor:placeholder.bottomAnchor constant:40.0],
    ]];
}

- (void)loadDebts
{
    // Хост заведомо несуществующий: ответ целиком подставляет твик, сеть не нужна
    NSURL *url = [NSURL URLWithString:@"https://api.example.test/debts?user=demo"];

    NSURLSessionDataTask *task =
        [NSURLSession.sharedSession dataTaskWithURL:url
                            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                if (error) {
                                    NSLog(@"[DemoApp] error: %@", error);
                                    return;
                                }
                                NSDictionary *json =
                                    [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                                NSLog(@"[DemoApp] payload: %@", json);
                            }];
    [task resume];
}

@end

#pragma mark - AppDelegate

@interface TLAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation TLAppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UINavigationController *root =
        [[UINavigationController alloc] initWithRootViewController:[TLDemoViewController new]];
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];
    return YES;
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(TLAppDelegate.class));
    }
}
