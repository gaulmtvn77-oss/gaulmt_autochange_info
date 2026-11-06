#import "ChangeInfoRootViewController.h"
#import "ChangeInfoDeviceDatabase.h"
#import "ChangeInfoLicenseManager.h"
#import "ChangeInfoVectorIcons.h"
#import "ChangeInfoDiagnostics.h"
#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <objc/runtime.h>
#import <objc/message.h>

static inline NSString *ChangeInfoReadClipboardSafely(void) {
    @try {
        UIPasteboard *pb = [UIPasteboard generalPasteboard];
        if (pb && pb.string && pb.string.length > 0) {
            return pb.string;
        }
    } @catch (NSException *e) {}
    return @"";
}

@interface ChangeInfoSafeTextField : UITextField
@property (nonatomic, assign) UIEdgeInsets textInsets;
@end

@implementation ChangeInfoSafeTextField

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.textInsets = UIEdgeInsetsMake(0, 14, 0, 14);
        if (@available(iOS 11.0, *)) {
            self.pasteConfiguration = nil;
            if (self.textDragInteraction) {
                self.textDragInteraction.enabled = NO;
            }
        }
        if (@available(iOS 15.0, *)) {
            self.inputAssistantItem.leadingBarButtonGroups = @[];
            self.inputAssistantItem.trailingBarButtonGroups = @[];
        }
    }
    return self;
}

- (CGRect)textRectForBounds:(CGRect)bounds {
    return UIEdgeInsetsInsetRect(bounds, self.textInsets);
}

- (CGRect)editingRectForBounds:(CGRect)bounds {
    return UIEdgeInsetsInsetRect(bounds, self.textInsets);
}

- (CGRect)placeholderRectForBounds:(CGRect)bounds {
    return UIEdgeInsetsInsetRect(bounds, self.textInsets);
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(paste:) || action == @selector(copy:) || action == @selector(cut:) || action == @selector(selectAll:)) {
        return YES;
    }
    return NO;
}

- (void)paste:(id)sender {
    NSString *clip = ChangeInfoReadClipboardSafely();
    if (clip.length > 0) {
        self.text = clip;
        [self sendActionsForControlEvents:UIControlEventEditingChanged];
    }
}

@end

typedef NS_ENUM(NSInteger, ChangeInfoMainTab) {
    ChangeInfoMainTabFeatures = 0,
    ChangeInfoMainTabLicense = 1
};

@interface ChangeInfoRootViewController () <UITextFieldDelegate>

@property (nonatomic, strong) ChangeInfoDeviceProfile *currentProfile;
@property (nonatomic, assign) ChangeInfoModelTierFilter currentModelTier;
@property (nonatomic, assign) ChangeInfoMainTab activeTab;
@property (nonatomic, assign) BOOL isLightMode;
@property (nonatomic, assign) BOOL isPerformingAction;

// Top Bar & Toast Banner
@property (nonatomic, strong) UIView *topHeaderBar;
@property (nonatomic, strong) UIButton *themeToggleButton;
@property (nonatomic, strong) UIView *headerLicenseBadge;
@property (nonatomic, strong) UIImageView *headerLicenseIcon;
@property (nonatomic, strong) UILabel *headerLicenseText;
@property (nonatomic, strong) UIView *toastBannerView;
@property (nonatomic, strong) UILabel *toastBannerLabel;

// Loading HUD Overlay
@property (nonatomic, strong) UIView *loadingOverlayView;
@property (nonatomic, strong) UIActivityIndicatorView *loadingSpinner;
@property (nonatomic, strong) UILabel *loadingTitleLabel;
@property (nonatomic, strong) UILabel *loadingSubLabel;

// ScrollView & Tab Containers
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIStackView *tabFeaturesStack;
@property (nonatomic, strong) UIStackView *tabLicenseStack;
@property (nonatomic, strong) NSArray<UIButton *> *tabNavButtons;

// Hero Profile Labels
@property (nonatomic, strong) UILabel *modelHeroLabel;
@property (nonatomic, strong) UILabel *machineBadgeLabel;
@property (nonatomic, strong) UILabel *iosBadgeLabel;
@property (nonatomic, strong) UILabel *uuidMonoLabel;
@property (nonatomic, strong) UILabel *specChipValueLabel;
@property (nonatomic, strong) UILabel *specScreenValueLabel;
@property (nonatomic, strong) UILabel *specNetValueLabel;
@property (nonatomic, strong) UILabel *specBatValueLabel;
@property (nonatomic, strong) UIButton *configProxyButton;

// Action Buttons
@property (nonatomic, strong) UIButton *btnRandomDevice;
@property (nonatomic, strong) UIButton *btnRespring;
@property (nonatomic, strong) UIButton *btnCopyProfile;
@property (nonatomic, strong) UIButton *btnDiagnostics;

// Hardware Constraint Switches
@property (nonatomic, strong) UISwitch *lockModelSwitch;
@property (nonatomic, strong) UISwitch *sameScreenSwitch;
@property (nonatomic, strong) UISwitch *matchChipSwitch;
@property (nonatomic, strong) NSArray<UIButton *> *tierSegmentButtons;

// License UI
@property (nonatomic, strong) UIView *licenseStatusCard;
@property (nonatomic, strong) UILabel *licenseStatusTitle;
@property (nonatomic, strong) UILabel *licenseStatusSub;
@property (nonatomic, strong) UILabel *licenseHwidLabel;
@property (nonatomic, strong) ChangeInfoSafeTextField *licenseKeyField;
@property (nonatomic, strong) UIButton *btnActivateLicense;
@property (nonatomic, strong) UIButton *btnRefreshLicense;

// Modals
@property (nonatomic, strong) UIView *proxyModalOverlay;
@property (nonatomic, strong) ChangeInfoSafeTextField *proxyInputField;

@end

@implementation ChangeInfoRootViewController

#pragma mark - Theme Palette Colors

- (UIColor *)appBackgroundColor {
    return self.isLightMode
        ? [UIColor colorWithRed:0.96 green:0.96 blue:0.97 alpha:1.0]
        : [UIColor colorWithRed:0.04 green:0.04 blue:0.05 alpha:1.0];
}

- (UIColor *)surfaceCardColor {
    return self.isLightMode
        ? [UIColor colorWithWhite:1.0 alpha:0.95]
        : [UIColor colorWithRed:0.07 green:0.07 blue:0.09 alpha:0.95];
}

- (UIColor *)surfaceInsetColor {
    return self.isLightMode
        ? [UIColor colorWithRed:0.93 green:0.93 blue:0.95 alpha:1.0]
        : [UIColor colorWithRed:0.09 green:0.09 blue:0.12 alpha:1.0];
}

- (UIColor *)borderSubtleColor {
    return self.isLightMode
        ? [UIColor colorWithWhite:0.0 alpha:0.08]
        : [UIColor colorWithWhite:1.0 alpha:0.08];
}

- (UIColor *)primaryTextColor {
    return self.isLightMode ? [UIColor colorWithWhite:0.10 alpha:1.0] : [UIColor whiteColor];
}

- (UIColor *)secondaryTextColor {
    return self.isLightMode
        ? [UIColor colorWithRed:0.35 green:0.38 blue:0.42 alpha:1.0]
        : [UIColor colorWithRed:0.75 green:0.78 blue:0.82 alpha:1.0];
}

- (UIColor *)mutedTextColor {
    return self.isLightMode
        ? [UIColor colorWithWhite:0.55 alpha:1.0]
        : [UIColor colorWithWhite:0.50 alpha:1.0];
}

- (UIColor *)goldAccentColor {
    return [UIColor colorWithRed:0.96 green:0.62 blue:0.04 alpha:1.0];
}

- (UIColor *)goldBadgeBgColor {
    return [UIColor colorWithRed:0.96 green:0.62 blue:0.04 alpha:0.15];
}

- (UIColor *)emeraldColor {
    return [UIColor colorWithRed:0.06 green:0.78 blue:0.51 alpha:1.0];
}

- (UIColor *)emeraldBadgeBgColor {
    return [UIColor colorWithRed:0.06 green:0.78 blue:0.51 alpha:0.15];
}

- (UIColor *)darkInkColor {
    return [UIColor colorWithRed:0.04 green:0.04 blue:0.05 alpha:1.0];
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    self.isLightMode = [prefs boolForKey:@"ChangeInfo_LightMode"];

    if ([prefs objectForKey:@"ChangeInfo_ModelTier"] == nil) {
        [prefs setBool:NO forKey:@"ChangeInfo_LockModel"];
        [prefs setBool:NO forKey:@"ChangeInfo_SameScreen"];
        [prefs setBool:NO forKey:@"ChangeInfo_MatchChip"];
        [prefs setInteger:ChangeInfoModelTierNativeCompatible forKey:@"ChangeInfo_ModelTier"];
        [prefs synchronize];
        self.currentModelTier = ChangeInfoModelTierNativeCompatible;
        self.currentProfile = [ChangeInfoDeviceDatabase generateProfileWithLockRealModel:NO
                                                                             sameScreen:NO
                                                                              matchChip:NO
                                                                              modelTier:ChangeInfoModelTierNativeCompatible
                                                                            currentCity:nil];
    } else {
        self.currentModelTier = (ChangeInfoModelTierFilter)[prefs integerForKey:@"ChangeInfo_ModelTier"];
        self.currentProfile = [ChangeInfoDeviceDatabase loadOrCreateDefaultProfile];
    }

    self.activeTab = ChangeInfoMainTabFeatures;
    [self buildCompleteInterface];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAppBecameActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    [self onAppBecameActive];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return self.isLightMode ? UIStatusBarStyleDarkContent : UIStatusBarStyleLightContent;
}

- (void)onAppBecameActive {
    [self refreshLicenseStateUI];
    [ChangeInfoLicenseManager refreshSavedLicenseInBackgroundWithCompletion:^(BOOL isValid, NSString *statusText) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshLicenseStateUI];
        });
    }];
}

#pragma mark - UI Building

- (void)buildCompleteInterface {
    for (UIView *sub in [self.view.subviews copy]) {
        [sub removeFromSuperview];
    }

    self.view.backgroundColor = [self appBackgroundColor];

    [self setupHeaderBar];
    [self setupToastBanner];
    [self setupScrollAndContainers];
    [self setupHeroProfileCard];
    [self setupPrimaryActions];
    [self setupModelTierSelector];
    [self setupHardwareConstraintToggles];
    [self setupLicenseTab];
    [self setupLoadingOverlay];

    [self switchTab:self.activeTab];
    [self refreshUIWithCurrentProfile];
    [self refreshLicenseStateUI];
}

#pragma mark - Top Header Bar

- (void)setupHeaderBar {
    self.topHeaderBar = [[UIView alloc] init];
    self.topHeaderBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.topHeaderBar.backgroundColor = [self surfaceCardColor];
    self.topHeaderBar.layer.borderColor = [self borderSubtleColor].CGColor;
    self.topHeaderBar.layer.borderWidth = 1.0;
    [self.view addSubview:self.topHeaderBar];

    [NSLayoutConstraint activateConstraints:@[
        [self.topHeaderBar.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.topHeaderBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.topHeaderBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];

    UIView *safeTopWrap = [[UIView alloc] init];
    safeTopWrap.translatesAutoresizingMaskIntoConstraints = NO;
    [self.topHeaderBar addSubview:safeTopWrap];

    [NSLayoutConstraint activateConstraints:@[
        [safeTopWrap.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:4.0],
        [safeTopWrap.leadingAnchor constraintEqualToAnchor:self.topHeaderBar.leadingAnchor constant:16.0],
        [safeTopWrap.trailingAnchor constraintEqualToAnchor:self.topHeaderBar.trailingAnchor constant:-16.0],
        [safeTopWrap.bottomAnchor constraintEqualToAnchor:self.topHeaderBar.bottomAnchor constant:-10.0],
        [safeTopWrap.heightAnchor constraintEqualToConstant:46.0]
    ]];

    // App Crest Logo
    UIImageView *logoImg = [[UIImageView alloc] init];
    logoImg.translatesAutoresizingMaskIntoConstraints = NO;
    logoImg.image = [ChangeInfoVectorIcons brandCrestLogoWithSize:30.0];
    logoImg.contentMode = UIViewContentModeScaleAspectFit;
    [safeTopWrap addSubview:logoImg];

    // Titles Stack
    UIStackView *titleStack = [[UIStackView alloc] init];
    titleStack.translatesAutoresizingMaskIntoConstraints = NO;
    titleStack.axis = UILayoutConstraintAxisVertical;
    titleStack.spacing = 1.0;
    [safeTopWrap addSubview:titleStack];

    UILabel *appTitle = [[UILabel alloc] init];
    appTitle.translatesAutoresizingMaskIntoConstraints = NO;
    appTitle.text = @"CHANGE INFO";
    appTitle.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightBlack];
    appTitle.textColor = [self primaryTextColor];
    [titleStack addArrangedSubview:appTitle];

    UILabel *appSub = [[UILabel alloc] init];
    appSub.translatesAutoresizingMaskIntoConstraints = NO;
    appSub.text = @"Identity & Hardware Spoofing • v1.0.0";
    appSub.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightMedium];
    appSub.textColor = [self mutedTextColor];
    [titleStack addArrangedSubview:appSub];

    // Right Controls
    UIStackView *rightStack = [[UIStackView alloc] init];
    rightStack.translatesAutoresizingMaskIntoConstraints = NO;
    rightStack.axis = UILayoutConstraintAxisHorizontal;
    rightStack.spacing = 8.0;
    rightStack.alignment = UIStackViewAlignmentCenter;
    [safeTopWrap addSubview:rightStack];

    // Theme Toggle Button
    self.themeToggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.themeToggleButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.themeToggleButton.layer.cornerRadius = 17.0;
    self.themeToggleButton.layer.borderWidth = 1.0;
    self.themeToggleButton.layer.borderColor = [self borderSubtleColor].CGColor;
    self.themeToggleButton.backgroundColor = [self surfaceInsetColor];
    [self.themeToggleButton setTitle:(self.isLightMode ? @"🌙" : @"☀️") forState:UIControlStateNormal];
    [self.themeToggleButton addTarget:self action:@selector(onTapToggleTheme) forControlEvents:UIControlEventTouchUpInside];
    [rightStack addArrangedSubview:self.themeToggleButton];

    // License Badge Pill
    self.headerLicenseBadge = [[UIView alloc] init];
    self.headerLicenseBadge.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerLicenseBadge.layer.cornerRadius = 14.0;
    self.headerLicenseBadge.layer.borderWidth = 1.0;
    self.headerLicenseBadge.backgroundColor = [self emeraldBadgeBgColor];
    self.headerLicenseBadge.layer.borderColor = [self emeraldColor].CGColor;
    self.headerLicenseBadge.userInteractionEnabled = YES;
    UITapGestureRecognizer *tapLic = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapHeaderLicenseBadge)];
    [self.headerLicenseBadge addGestureRecognizer:tapLic];
    [rightStack addArrangedSubview:self.headerLicenseBadge];

    UIStackView *licInner = [[UIStackView alloc] init];
    licInner.translatesAutoresizingMaskIntoConstraints = NO;
    licInner.axis = UILayoutConstraintAxisHorizontal;
    licInner.spacing = 5.0;
    licInner.alignment = UIStackViewAlignmentCenter;
    [self.headerLicenseBadge addSubview:licInner];

    self.headerLicenseIcon = [[UIImageView alloc] init];
    self.headerLicenseIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerLicenseIcon.image = [ChangeInfoVectorIcons iconWithType:ChangeInfoIconShieldCheck size:14.0 color:[self emeraldColor]];
    [licInner addArrangedSubview:self.headerLicenseIcon];

    self.headerLicenseText = [[UILabel alloc] init];
    self.headerLicenseText.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerLicenseText.text = @"VIP Active";
    self.headerLicenseText.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
    self.headerLicenseText.textColor = [self emeraldColor];
    [licInner addArrangedSubview:self.headerLicenseText];

    [NSLayoutConstraint activateConstraints:@[
        [logoImg.leadingAnchor constraintEqualToAnchor:safeTopWrap.leadingAnchor],
        [logoImg.centerYAnchor constraintEqualToAnchor:safeTopWrap.centerYAnchor],
        [logoImg.widthAnchor constraintEqualToConstant:30.0],
        [logoImg.heightAnchor constraintEqualToConstant:30.0],

        [titleStack.leadingAnchor constraintEqualToAnchor:logoImg.trailingAnchor constant:10.0],
        [titleStack.centerYAnchor constraintEqualToAnchor:safeTopWrap.centerYAnchor],

        [rightStack.trailingAnchor constraintEqualToAnchor:safeTopWrap.trailingAnchor],
        [rightStack.centerYAnchor constraintEqualToAnchor:safeTopWrap.centerYAnchor],

        [self.themeToggleButton.widthAnchor constraintEqualToConstant:34.0],
        [self.themeToggleButton.heightAnchor constraintEqualToConstant:34.0],

        [self.headerLicenseBadge.heightAnchor constraintEqualToConstant:28.0],
        [licInner.topAnchor constraintEqualToAnchor:self.headerLicenseBadge.topAnchor constant:4.0],
        [licInner.bottomAnchor constraintEqualToAnchor:self.headerLicenseBadge.bottomAnchor constant:-4.0],
        [licInner.leadingAnchor constraintEqualToAnchor:self.headerLicenseBadge.leadingAnchor constant:8.0],
        [licInner.trailingAnchor constraintEqualToAnchor:self.headerLicenseBadge.trailingAnchor constant:-8.0],
        [self.headerLicenseIcon.widthAnchor constraintEqualToConstant:14.0],
        [self.headerLicenseIcon.heightAnchor constraintEqualToConstant:14.0]
    ]];
}

#pragma mark - Toast Banner

- (void)setupToastBanner {
    self.toastBannerView = [[UIView alloc] init];
    self.toastBannerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.toastBannerView.backgroundColor = [self emeraldColor];
    self.toastBannerView.layer.cornerRadius = 14.0;
    self.toastBannerView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.toastBannerView.layer.shadowOffset = CGSizeMake(0, 4);
    self.toastBannerView.layer.shadowRadius = 8.0;
    self.toastBannerView.layer.shadowOpacity = 0.3;
    self.toastBannerView.alpha = 0.0;
    [self.view addSubview:self.toastBannerView];

    self.toastBannerLabel = [[UILabel alloc] init];
    self.toastBannerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.toastBannerLabel.textColor = [self darkInkColor];
    self.toastBannerLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightBold];
    self.toastBannerLabel.textAlignment = NSTextAlignmentCenter;
    self.toastBannerLabel.numberOfLines = 2;
    [self.toastBannerView addSubview:self.toastBannerLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.toastBannerView.topAnchor constraintEqualToAnchor:self.topHeaderBar.bottomAnchor constant:8.0],
        [self.toastBannerView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.toastBannerView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24.0],
        [self.toastBannerView.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-24.0],

        [self.toastBannerLabel.topAnchor constraintEqualToAnchor:self.toastBannerView.topAnchor constant:10.0],
        [self.toastBannerLabel.bottomAnchor constraintEqualToAnchor:self.toastBannerView.bottomAnchor constant:-10.0],
        [self.toastBannerLabel.leadingAnchor constraintEqualToAnchor:self.toastBannerView.leadingAnchor constant:16.0],
        [self.toastBannerLabel.trailingAnchor constraintEqualToAnchor:self.toastBannerView.trailingAnchor constant:-16.0]
    ]];
}

- (void)showToast:(NSString *)msg isError:(BOOL)isError {
    self.toastBannerLabel.text = msg;
    self.toastBannerView.backgroundColor = isError ? [UIColor colorWithRed:0.94 green:0.27 blue:0.27 alpha:1.0] : [self emeraldColor];
    self.toastBannerLabel.textColor = isError ? [UIColor whiteColor] : [self darkInkColor];

    [UIView animateWithDuration:0.25 animations:^{
        self.toastBannerView.alpha = 1.0;
        self.toastBannerView.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.25 animations:^{
                self.toastBannerView.alpha = 0.0;
                self.toastBannerView.transform = CGAffineTransformMakeTranslation(0, -10);
            }];
        });
    }];
}

#pragma mark - Scroll & Tab Bar

- (void)setupScrollAndContainers {
    // 2-Button Segmented Navigation Bar
    UIView *tabBarWrap = [[UIView alloc] init];
    tabBarWrap.translatesAutoresizingMaskIntoConstraints = NO;
    tabBarWrap.backgroundColor = [self surfaceCardColor];
    tabBarWrap.layer.borderColor = [self borderSubtleColor].CGColor;
    tabBarWrap.layer.borderWidth = 1.0;
    tabBarWrap.layer.cornerRadius = 16.0;
    [self.view addSubview:tabBarWrap];

    UIStackView *tabSegStack = [[UIStackView alloc] init];
    tabSegStack.translatesAutoresizingMaskIntoConstraints = NO;
    tabSegStack.axis = UILayoutConstraintAxisHorizontal;
    tabSegStack.distribution = UIStackViewDistributionFillEqually;
    tabSegStack.spacing = 8.0;
    [tabBarWrap addSubview:tabSegStack];

    [NSLayoutConstraint activateConstraints:@[
        [tabBarWrap.topAnchor constraintEqualToAnchor:self.topHeaderBar.bottomAnchor constant:10.0],
        [tabBarWrap.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [tabBarWrap.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],
        [tabBarWrap.heightAnchor constraintEqualToConstant:46.0],

        [tabSegStack.topAnchor constraintEqualToAnchor:tabBarWrap.topAnchor constant:4.0],
        [tabSegStack.bottomAnchor constraintEqualToAnchor:tabBarWrap.bottomAnchor constant:-4.0],
        [tabSegStack.leadingAnchor constraintEqualToAnchor:tabBarWrap.leadingAnchor constant:4.0],
        [tabSegStack.trailingAnchor constraintEqualToAnchor:tabBarWrap.trailingAnchor constant:-4.0]
    ]];

    NSArray<NSString *> *tabTitles = @[@"CẤU HÌNH", @"BẢN QUYỀN"];
    NSArray<NSNumber *> *tabIcons = @[@(ChangeInfoIconTabSpoof), @(ChangeInfoIconTabLicense)];
    NSMutableArray<UIButton *> *tabBtns = [NSMutableArray array];

    for (NSInteger i = 0; i < tabTitles.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = i;
        btn.layer.cornerRadius = 12.0;
        [btn setTitle:tabTitles[i] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightBold];
        UIImage *ic = [ChangeInfoVectorIcons iconWithType:[tabIcons[i] integerValue] size:16.0 color:[self mutedTextColor]];
        [btn setImage:ic forState:UIControlStateNormal];
        btn.imageEdgeInsets = UIEdgeInsetsMake(0, -6, 0, 6);
        [btn addTarget:self action:@selector(onTapTabButton:) forControlEvents:UIControlEventTouchUpInside];
        [self attachSpringTouchFeedbackToButton:btn];
        [tabSegStack addArrangedSubview:btn];
        [tabBtns addObject:btn];
    }
    self.tabNavButtons = tabBtns;

    // ScrollView
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:self.scrollView];

    UITapGestureRecognizer *dismissTap = [[UITapGestureRecognizer alloc] initWithTarget:self.view action:@selector(endEditing:)];
    dismissTap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:dismissTap];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:tabBarWrap.bottomAnchor constant:10.0],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 16.0;
    [self.scrollView addSubview:self.contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.contentStack.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor constant:4.0],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:-40.0],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor constant:16.0],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor constant:-16.0],
        [self.contentStack.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor constant:-32.0]
    ]];

    self.tabFeaturesStack = [[UIStackView alloc] init];
    self.tabFeaturesStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabFeaturesStack.axis = UILayoutConstraintAxisVertical;
    self.tabFeaturesStack.spacing = 16.0;
    [self.contentStack addArrangedSubview:self.tabFeaturesStack];

    self.tabLicenseStack = [[UIStackView alloc] init];
    self.tabLicenseStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabLicenseStack.axis = UILayoutConstraintAxisVertical;
    self.tabLicenseStack.spacing = 16.0;
    [self.contentStack addArrangedSubview:self.tabLicenseStack];
}

- (void)onTapTabButton:(UIButton *)sender {
    [self switchTab:(ChangeInfoMainTab)sender.tag];
}

- (void)switchTab:(ChangeInfoMainTab)tab {
    self.activeTab = tab;
    for (UIButton *btn in self.tabNavButtons) {
        BOOL active = (btn.tag == tab);
        btn.backgroundColor = active ? [self goldAccentColor] : [UIColor clearColor];
        [btn setTitleColor:(active ? [self darkInkColor] : [self mutedTextColor]) forState:UIControlStateNormal];
        UIImage *ic = [ChangeInfoVectorIcons iconWithType:(btn.tag == 0 ? ChangeInfoIconTabSpoof : ChangeInfoIconTabLicense)
                                                     size:16.0
                                                    color:(active ? [self darkInkColor] : [self mutedTextColor])];
        [btn setImage:ic forState:UIControlStateNormal];
    }

    self.tabFeaturesStack.hidden = (tab != ChangeInfoMainTabFeatures);
    self.tabLicenseStack.hidden = (tab != ChangeInfoMainTabLicense);
}

#pragma mark - Hero Profile Card

- (void)setupHeroProfileCard {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [self surfaceCardColor];
    card.layer.cornerRadius = 20.0;
    card.layer.borderColor = [self borderSubtleColor].CGColor;
    card.layer.borderWidth = 1.0;
    [self.tabFeaturesStack addArrangedSubview:card];

    UIStackView *cardStack = [[UIStackView alloc] init];
    cardStack.translatesAutoresizingMaskIntoConstraints = NO;
    cardStack.axis = UILayoutConstraintAxisVertical;
    cardStack.spacing = 12.0;
    [card addSubview:cardStack];

    [NSLayoutConstraint activateConstraints:@[
        [cardStack.topAnchor constraintEqualToAnchor:card.topAnchor constant:18.0],
        [cardStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18.0],
        [cardStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [cardStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0]
    ]];

    // Top Row: Model Name & Badges
    self.modelHeroLabel = [[UILabel alloc] init];
    self.modelHeroLabel.text = @"iPhone 7";
    self.modelHeroLabel.font = [UIFont systemFontOfSize:23.0 weight:UIFontWeightBlack];
    self.modelHeroLabel.textColor = [self primaryTextColor];
    [cardStack addArrangedSubview:self.modelHeroLabel];

    UIStackView *badgeRow = [[UIStackView alloc] init];
    badgeRow.axis = UILayoutConstraintAxisHorizontal;
    badgeRow.spacing = 8.0;
    badgeRow.alignment = UIStackViewAlignmentCenter;
    [cardStack addArrangedSubview:badgeRow];

    self.machineBadgeLabel = [[UILabel alloc] init];
    self.machineBadgeLabel.backgroundColor = [self surfaceInsetColor];
    self.machineBadgeLabel.textColor = [self goldAccentColor];
    self.machineBadgeLabel.font = [UIFont monospacedSystemFontOfSize:11.5 weight:UIFontWeightBold];
    self.machineBadgeLabel.layer.cornerRadius = 6.0;
    self.machineBadgeLabel.layer.masksToBounds = YES;
    self.machineBadgeLabel.text = @"  iPhone9,3  ";
    [badgeRow addArrangedSubview:self.machineBadgeLabel];

    self.iosBadgeLabel = [[UILabel alloc] init];
    self.iosBadgeLabel.backgroundColor = [self emeraldBadgeBgColor];
    self.iosBadgeLabel.textColor = [self emeraldColor];
    self.iosBadgeLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
    self.iosBadgeLabel.layer.cornerRadius = 6.0;
    self.iosBadgeLabel.layer.masksToBounds = YES;
    self.iosBadgeLabel.text = @"  iOS 15.8.4  ";
    [badgeRow addArrangedSubview:self.iosBadgeLabel];

    UIView *badgeSpacer = [[UIView alloc] init];
    [badgeRow addArrangedSubview:badgeSpacer];

    // UUID Label with 1-tap copy
    UIView *uuidWrap = [[UIView alloc] init];
    uuidWrap.backgroundColor = [self surfaceInsetColor];
    uuidWrap.layer.cornerRadius = 9.0;
    uuidWrap.layer.borderWidth = 1.0;
    uuidWrap.layer.borderColor = [self borderSubtleColor].CGColor;
    uuidWrap.userInteractionEnabled = YES;
    UITapGestureRecognizer *tapUuid = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapCopyUUID)];
    [uuidWrap addGestureRecognizer:tapUuid];
    [cardStack addArrangedSubview:uuidWrap];

    UIStackView *uuidStack = [[UIStackView alloc] init];
    uuidStack.translatesAutoresizingMaskIntoConstraints = NO;
    uuidStack.axis = UILayoutConstraintAxisHorizontal;
    uuidStack.spacing = 6.0;
    uuidStack.alignment = UIStackViewAlignmentCenter;
    [uuidWrap addSubview:uuidStack];

    [NSLayoutConstraint activateConstraints:@[
        [uuidStack.topAnchor constraintEqualToAnchor:uuidWrap.topAnchor constant:7.0],
        [uuidStack.bottomAnchor constraintEqualToAnchor:uuidWrap.bottomAnchor constant:-7.0],
        [uuidStack.leadingAnchor constraintEqualToAnchor:uuidWrap.leadingAnchor constant:10.0],
        [uuidStack.trailingAnchor constraintEqualToAnchor:uuidWrap.trailingAnchor constant:-10.0]
    ]];

    self.uuidMonoLabel = [[UILabel alloc] init];
    self.uuidMonoLabel.text = @"UUID: 7BD46FDA-D93D-45BD-9158-7178669502DD";
    self.uuidMonoLabel.font = [UIFont monospacedSystemFontOfSize:10.5 weight:UIFontWeightMedium];
    self.uuidMonoLabel.textColor = [self secondaryTextColor];
    self.uuidMonoLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [uuidStack addArrangedSubview:self.uuidMonoLabel];

    UIImageView *copyIcon = [[UIImageView alloc] init];
    copyIcon.translatesAutoresizingMaskIntoConstraints = NO;
    copyIcon.image = [ChangeInfoVectorIcons iconWithType:ChangeInfoIconCopyClone size:13.0 color:[self mutedTextColor]];
    [copyIcon.widthAnchor constraintEqualToConstant:13.0].active = YES;
    [copyIcon.heightAnchor constraintEqualToConstant:13.0].active = YES;
    [uuidStack addArrangedSubview:copyIcon];

    // 4-Cell Spec Grid
    UIStackView *specRow1 = [[UIStackView alloc] init];
    specRow1.axis = UILayoutConstraintAxisHorizontal;
    specRow1.distribution = UIStackViewDistributionFillEqually;
    specRow1.spacing = 8.0;

    UIStackView *specRow2 = [[UIStackView alloc] init];
    specRow2.axis = UILayoutConstraintAxisHorizontal;
    specRow2.distribution = UIStackViewDistributionFillEqually;
    specRow2.spacing = 8.0;

    [cardStack addArrangedSubview:specRow1];
    [cardStack addArrangedSubview:specRow2];

    self.specChipValueLabel = [self createSpecCellInRow:specRow1 title:@"CHIP & RAM" icon:ChangeInfoIconChipCpu];
    self.specScreenValueLabel = [self createSpecCellInRow:specRow1 title:@"MÀN HÌNH" icon:ChangeInfoIconDisplayScreen];
    self.specNetValueLabel = [self createSpecCellInRow:specRow2 title:@"MẠNG & VỊ TRÍ" icon:ChangeInfoIconSignalRadar];
    self.specBatValueLabel = [self createSpecCellInRow:specRow2 title:@"PIN & DANH BẠ" icon:ChangeInfoIconBatteryBolt];

    // Proxy Status Button
    self.configProxyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.configProxyButton.layer.cornerRadius = 10.0;
    self.configProxyButton.layer.borderWidth = 1.0;
    self.configProxyButton.layer.borderColor = [self borderSubtleColor].CGColor;
    self.configProxyButton.backgroundColor = [self surfaceInsetColor];
    [self.configProxyButton setTitle:@"🌐 Mạng trực tiếp (Không Proxy / 4G)" forState:UIControlStateNormal];
    [self.configProxyButton setTitleColor:[self secondaryTextColor] forState:UIControlStateNormal];
    self.configProxyButton.titleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
    [self.configProxyButton addTarget:self action:@selector(onTapOpenProxyModal) forControlEvents:UIControlEventTouchUpInside];
    [self.configProxyButton.heightAnchor constraintEqualToConstant:34.0].active = YES;
    [cardStack addArrangedSubview:self.configProxyButton];
}

- (UILabel *)createSpecCellInRow:(UIStackView *)row title:(NSString *)title icon:(ChangeInfoCustomIconType)iconType {
    UIView *wrap = [[UIView alloc] init];
    wrap.backgroundColor = [self surfaceInsetColor];
    wrap.layer.cornerRadius = 10.0;
    wrap.layer.borderWidth = 1.0;
    wrap.layer.borderColor = [self borderSubtleColor].CGColor;
    [row addArrangedSubview:wrap];

    UIStackView *st = [[UIStackView alloc] init];
    st.translatesAutoresizingMaskIntoConstraints = NO;
    st.axis = UILayoutConstraintAxisVertical;
    st.spacing = 2.0;
    [wrap addSubview:st];

    [NSLayoutConstraint activateConstraints:@[
        [st.topAnchor constraintEqualToAnchor:wrap.topAnchor constant:8.0],
        [st.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor constant:-8.0],
        [st.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor constant:10.0],
        [st.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor constant:-10.0]
    ]];

    UIStackView *topH = [[UIStackView alloc] init];
    topH.axis = UILayoutConstraintAxisHorizontal;
    topH.spacing = 4.0;
    topH.alignment = UIStackViewAlignmentCenter;
    [st addArrangedSubview:topH];

    UIImageView *icView = [[UIImageView alloc] init];
    icView.translatesAutoresizingMaskIntoConstraints = NO;
    icView.image = [ChangeInfoVectorIcons iconWithType:iconType size:11.0 color:[self mutedTextColor]];
    [icView.widthAnchor constraintEqualToConstant:11.0].active = YES;
    [icView.heightAnchor constraintEqualToConstant:11.0].active = YES;
    [topH addArrangedSubview:icView];

    UILabel *tLabel = [[UILabel alloc] init];
    tLabel.text = title;
    tLabel.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightBold];
    tLabel.textColor = [self mutedTextColor];
    [topH addArrangedSubview:tLabel];

    UILabel *valLabel = [[UILabel alloc] init];
    valLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
    valLabel.textColor = [self primaryTextColor];
    valLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [st addArrangedSubview:valLabel];

    return valLabel;
}

#pragma mark - Primary Action Buttons

- (void)setupPrimaryActions {
    UIStackView *actStack = [[UIStackView alloc] init];
    actStack.axis = UILayoutConstraintAxisVertical;
    actStack.spacing = 10.0;
    [self.tabFeaturesStack addArrangedSubview:actStack];

    // 1. RANDOM IDENTITY BUTTON (PROMINENT GOLD GRADIENT)
    self.btnRandomDevice = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnRandomDevice.layer.cornerRadius = 16.0;
    self.btnRandomDevice.backgroundColor = [self goldAccentColor];
    [self.btnRandomDevice setTitle:@"🎲  ĐỔI CẤU HÌNH MỚI" forState:UIControlStateNormal];
    [self.btnRandomDevice setTitleColor:[self darkInkColor] forState:UIControlStateNormal];
    self.btnRandomDevice.titleLabel.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightBlack];
    [self.btnRandomDevice.heightAnchor constraintEqualToConstant:50.0].active = YES;
    [self attachSpringTouchFeedbackToButton:self.btnRandomDevice];
    [self.btnRandomDevice addTarget:self action:@selector(onTapRandomDevice) forControlEvents:UIControlEventTouchUpInside];
    [actStack addArrangedSubview:self.btnRandomDevice];

    // 2. RESPRING & FAST ACTIONS ROW
    UIStackView *row2 = [[UIStackView alloc] init];
    row2.axis = UILayoutConstraintAxisHorizontal;
    row2.distribution = UIStackViewDistributionFillEqually;
    row2.spacing = 10.0;
    [actStack addArrangedSubview:row2];

    self.btnRespring = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnRespring.layer.cornerRadius = 14.0;
    self.btnRespring.backgroundColor = [self emeraldBadgeBgColor];
    self.btnRespring.layer.borderWidth = 1.0;
    self.btnRespring.layer.borderColor = [self emeraldColor].CGColor;
    [self.btnRespring setTitle:@"⚡ Áp Dụng & Respring" forState:UIControlStateNormal];
    [self.btnRespring setTitleColor:[self emeraldColor] forState:UIControlStateNormal];
    self.btnRespring.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold];
    [self.btnRespring.heightAnchor constraintEqualToConstant:44.0].active = YES;
    [self attachSpringTouchFeedbackToButton:self.btnRespring];
    [self.btnRespring addTarget:self action:@selector(onTapRespring) forControlEvents:UIControlEventTouchUpInside];
    [row2 addArrangedSubview:self.btnRespring];

    self.btnCopyProfile = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnCopyProfile.layer.cornerRadius = 14.0;
    self.btnCopyProfile.backgroundColor = [self surfaceInsetColor];
    self.btnCopyProfile.layer.borderWidth = 1.0;
    self.btnCopyProfile.layer.borderColor = [self borderSubtleColor].CGColor;
    [self.btnCopyProfile setTitle:@"📋 Sao Chép Cấu Hình" forState:UIControlStateNormal];
    [self.btnCopyProfile setTitleColor:[self primaryTextColor] forState:UIControlStateNormal];
    self.btnCopyProfile.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold];
    [self.btnCopyProfile.heightAnchor constraintEqualToConstant:44.0].active = YES;
    [self attachSpringTouchFeedbackToButton:self.btnCopyProfile];
    [self.btnCopyProfile addTarget:self action:@selector(onTapCopyProfileText) forControlEvents:UIControlEventTouchUpInside];
    [row2 addArrangedSubview:self.btnCopyProfile];

    // 3. DIAGNOSTICS BUTTON
    self.btnDiagnostics = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnDiagnostics.layer.cornerRadius = 12.0;
    self.btnDiagnostics.backgroundColor = [self surfaceCardColor];
    self.btnDiagnostics.layer.borderWidth = 1.0;
    self.btnDiagnostics.layer.borderColor = [self borderSubtleColor].CGColor;
    [self.btnDiagnostics setTitle:@"🔍 Kiểm Tra Hệ Thống & Chẩn Đoán Dylib" forState:UIControlStateNormal];
    [self.btnDiagnostics setTitleColor:[self mutedTextColor] forState:UIControlStateNormal];
    self.btnDiagnostics.titleLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    [self.btnDiagnostics.heightAnchor constraintEqualToConstant:38.0].active = YES;
    [self attachSpringTouchFeedbackToButton:self.btnDiagnostics];
    [self.btnDiagnostics addTarget:self action:@selector(onTapOpenDiagnostics) forControlEvents:UIControlEventTouchUpInside];
    [actStack addArrangedSubview:self.btnDiagnostics];
}

#pragma mark - Model Tier Selector

- (void)setupModelTierSelector {
    UIView *wrap = [[UIView alloc] init];
    wrap.backgroundColor = [self surfaceCardColor];
    wrap.layer.cornerRadius = 16.0;
    wrap.layer.borderWidth = 1.0;
    wrap.layer.borderColor = [self borderSubtleColor].CGColor;
    [self.tabFeaturesStack addArrangedSubview:wrap];

    UIStackView *st = [[UIStackView alloc] init];
    st.translatesAutoresizingMaskIntoConstraints = NO;
    st.axis = UILayoutConstraintAxisVertical;
    st.spacing = 10.0;
    [wrap addSubview:st];

    [NSLayoutConstraint activateConstraints:@[
        [st.topAnchor constraintEqualToAnchor:wrap.topAnchor constant:14.0],
        [st.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor constant:-14.0],
        [st.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor constant:14.0],
        [st.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor constant:-14.0]
    ]];

    UILabel *caption = [[UILabel alloc] init];
    caption.text = @"CHỌN PHÂN KHÚC ĐỜI MÁY KHI RANDOM:";
    caption.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
    caption.textColor = [self mutedTextColor];
    [st addArrangedSubview:caption];

    UIStackView *segRow = [[UIStackView alloc] init];
    segRow.axis = UILayoutConstraintAxisHorizontal;
    segRow.distribution = UIStackViewDistributionFillEqually;
    segRow.spacing = 6.0;
    [segRow.heightAnchor constraintEqualToConstant:36.0].active = YES;
    [st addArrangedSubview:segRow];

    NSArray<NSString *> *segTitles = @[@"⭐ Chuẩn 7/8 (Sống 100%)", @"Tất cả (6s–16)", @"Đời Cao 14–16"];
    NSArray<NSNumber *> *segTags = @[@(ChangeInfoModelTierNativeCompatible), @(ChangeInfoModelTierAll), @(ChangeInfoModelTierHighEnd)];
    NSMutableArray<UIButton *> *segBtns = [NSMutableArray array];

    for (NSInteger i = 0; i < segTitles.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.tag = [segTags[i] integerValue];
        b.layer.cornerRadius = 9.0;
        b.layer.borderWidth = 1.0;
        [b setTitle:segTitles[i] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
        [self attachSpringTouchFeedbackToButton:b];
        [b addTarget:self action:@selector(onTapSelectModelTierSegment:) forControlEvents:UIControlEventTouchUpInside];
        [segRow addArrangedSubview:b];
        [segBtns addObject:b];
    }
    self.tierSegmentButtons = segBtns;
    [self refreshModelTierSegments];
}

- (void)refreshModelTierSegments {
    for (UIButton *b in self.tierSegmentButtons) {
        BOOL active = (b.tag == self.currentModelTier);
        b.backgroundColor = active ? [self goldAccentColor] : [self surfaceInsetColor];
        b.layer.borderColor = active ? [self goldAccentColor].CGColor : [self borderSubtleColor].CGColor;
        [b setTitleColor:(active ? [self darkInkColor] : [self primaryTextColor]) forState:UIControlStateNormal];
    }
}

- (void)onTapSelectModelTierSegment:(UIButton *)sender {
    self.currentModelTier = (ChangeInfoModelTierFilter)sender.tag;
    [[NSUserDefaults standardUserDefaults] setInteger:self.currentModelTier forKey:@"ChangeInfo_ModelTier"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self refreshModelTierSegments];
    [self onTapRandomDevice];
}

#pragma mark - Hardware Constraint Toggles

- (void)setupHardwareConstraintToggles {
    UIView *wrap = [[UIView alloc] init];
    wrap.backgroundColor = [self surfaceCardColor];
    wrap.layer.cornerRadius = 16.0;
    wrap.layer.borderWidth = 1.0;
    wrap.layer.borderColor = [self borderSubtleColor].CGColor;
    [self.tabFeaturesStack addArrangedSubview:wrap];

    UIStackView *st = [[UIStackView alloc] init];
    st.translatesAutoresizingMaskIntoConstraints = NO;
    st.axis = UILayoutConstraintAxisVertical;
    st.spacing = 14.0;
    [wrap addSubview:st];

    [NSLayoutConstraint activateConstraints:@[
        [st.topAnchor constraintEqualToAnchor:wrap.topAnchor constant:14.0],
        [st.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor constant:-14.0],
        [st.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor constant:14.0],
        [st.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor constant:-14.0]
    ]];

    UILabel *header = [[UILabel alloc] init];
    header.text = @"TÙY CHỌN KHÓA THÔNG SỐ VẬT LÝ:";
    header.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
    header.textColor = [self mutedTextColor];
    [st addArrangedSubview:header];

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

    UISwitch *sw1 = nil;
    UIView *row1 = [self createToggleRowWithTitle:@"Khóa Model Máy Thật"
                                         subtitle:@"Chỉ đổi Serial, UUID, MAC. Giữ nguyên đời máy thật"
                                          prefKey:@"ChangeInfo_LockModel"
                                        outSwitch:&sw1];
    _lockModelSwitch = sw1;

    UISwitch *sw2 = nil;
    UIView *row2 = [self createToggleRowWithTitle:@"Trùng Cỡ Màn Hình Thật"
                                         subtitle:@"Chỉ random các máy có cùng tỷ lệ hiển thị màn hình"
                                          prefKey:@"ChangeInfo_SameScreen"
                                        outSwitch:&sw2];
    _sameScreenSwitch = sw2;

    UISwitch *sw3 = nil;
    UIView *row3 = [self createToggleRowWithTitle:@"Trùng Dung Lượng RAM & Chip"
                                         subtitle:@"Chỉ random các máy có cùng dung lượng bộ nhớ RAM"
                                          prefKey:@"ChangeInfo_MatchChip"
                                        outSwitch:&sw3];
    _matchChipSwitch = sw3;

    [st addArrangedSubview:row1];
    [st addArrangedSubview:row2];
    [st addArrangedSubview:row3];
}

- (UIView *)createToggleRowWithTitle:(NSString *)title
                            subtitle:(NSString *)subtitle
                             prefKey:(NSString *)prefKey
                           outSwitch:(UISwitch * __strong *)outSwitch {
    UIView *row = [[UIView alloc] init];

    UIStackView *leftSt = [[UIStackView alloc] init];
    leftSt.translatesAutoresizingMaskIntoConstraints = NO;
    leftSt.axis = UILayoutConstraintAxisVertical;
    leftSt.spacing = 2.0;
    [row addSubview:leftSt];

    UILabel *tLabel = [[UILabel alloc] init];
    tLabel.text = title;
    tLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightBold];
    tLabel.textColor = [self primaryTextColor];
    [leftSt addArrangedSubview:tLabel];

    UILabel *sLabel = [[UILabel alloc] init];
    sLabel.text = subtitle;
    sLabel.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightMedium];
    sLabel.textColor = [self mutedTextColor];
    sLabel.numberOfLines = 2;
    [leftSt addArrangedSubview:sLabel];

    UISwitch *sw = [[UISwitch alloc] init];
    sw.translatesAutoresizingMaskIntoConstraints = NO;
    sw.onTintColor = [self goldAccentColor];
    sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:prefKey];
    [sw addTarget:self action:@selector(onToggleSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    objc_setAssociatedObject(sw, "kPrefKey", prefKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [row addSubview:sw];

    [NSLayoutConstraint activateConstraints:@[
        [leftSt.topAnchor constraintEqualToAnchor:row.topAnchor],
        [leftSt.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [leftSt.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [leftSt.trailingAnchor constraintEqualToAnchor:sw.leadingAnchor constant:-10.0],

        [sw.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [sw.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]
    ]];

    if (outSwitch) *outSwitch = sw;
    return row;
}

- (void)onToggleSwitchChanged:(UISwitch *)sender {
    NSString *key = objc_getAssociatedObject(sender, "kPrefKey");
    if (key.length > 0) {
        [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

#pragma mark - License Tab UI

- (void)setupLicenseTab {
    // 1. Status Card
    self.licenseStatusCard = [[UIView alloc] init];
    self.licenseStatusCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.licenseStatusCard.backgroundColor = [self surfaceCardColor];
    self.licenseStatusCard.layer.cornerRadius = 20.0;
    self.licenseStatusCard.layer.borderWidth = 1.0;
    self.licenseStatusCard.layer.borderColor = [self borderSubtleColor].CGColor;
    [self.tabLicenseStack addArrangedSubview:self.licenseStatusCard];

    UIStackView *cardSt = [[UIStackView alloc] init];
    cardSt.translatesAutoresizingMaskIntoConstraints = NO;
    cardSt.axis = UILayoutConstraintAxisVertical;
    cardSt.spacing = 10.0;
    [self.licenseStatusCard addSubview:cardSt];

    [NSLayoutConstraint activateConstraints:@[
        [cardSt.topAnchor constraintEqualToAnchor:self.licenseStatusCard.topAnchor constant:18.0],
        [cardSt.bottomAnchor constraintEqualToAnchor:self.licenseStatusCard.bottomAnchor constant:-18.0],
        [cardSt.leadingAnchor constraintEqualToAnchor:self.licenseStatusCard.leadingAnchor constant:18.0],
        [cardSt.trailingAnchor constraintEqualToAnchor:self.licenseStatusCard.trailingAnchor constant:-18.0]
    ]];

    UILabel *header = [[UILabel alloc] init];
    header.text = @"TRẠNG THÁI BẢN QUYỀN:";
    header.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
    header.textColor = [self mutedTextColor];
    [cardSt addArrangedSubview:header];

    self.licenseStatusTitle = [[UILabel alloc] init];
    self.licenseStatusTitle.text = @"VIP ACTIVE";
    self.licenseStatusTitle.font = [UIFont systemFontOfSize:20.0 weight:UIFontWeightBlack];
    self.licenseStatusTitle.textColor = [self emeraldColor];
    [cardSt addArrangedSubview:self.licenseStatusTitle];

    self.licenseStatusSub = [[UILabel alloc] init];
    self.licenseStatusSub.text = @"Đã xác thực bản quyền";
    self.licenseStatusSub.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    self.licenseStatusSub.textColor = [self secondaryTextColor];
    [cardSt addArrangedSubview:self.licenseStatusSub];

    // 2. Hardware ID (HWID) Card
    UIView *hwidCard = [[UIView alloc] init];
    hwidCard.backgroundColor = [self surfaceCardColor];
    hwidCard.layer.cornerRadius = 16.0;
    hwidCard.layer.borderWidth = 1.0;
    hwidCard.layer.borderColor = [self borderSubtleColor].CGColor;
    [self.tabLicenseStack addArrangedSubview:hwidCard];

    UIStackView *hwidSt = [[UIStackView alloc] init];
    hwidSt.translatesAutoresizingMaskIntoConstraints = NO;
    hwidSt.axis = UILayoutConstraintAxisVertical;
    hwidSt.spacing = 10.0;
    [hwidCard addSubview:hwidSt];

    [NSLayoutConstraint activateConstraints:@[
        [hwidSt.topAnchor constraintEqualToAnchor:hwidCard.topAnchor constant:14.0],
        [hwidSt.bottomAnchor constraintEqualToAnchor:hwidCard.bottomAnchor constant:-14.0],
        [hwidSt.leadingAnchor constraintEqualToAnchor:hwidCard.leadingAnchor constant:14.0],
        [hwidSt.trailingAnchor constraintEqualToAnchor:hwidCard.trailingAnchor constant:-14.0]
    ]];

    UILabel *hwidHeader = [[UILabel alloc] init];
    hwidHeader.text = @"MÃ THIẾT BỊ (HWID - 1 KEY / 1 MÁY):";
    hwidHeader.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
    hwidHeader.textColor = [self mutedTextColor];
    [hwidSt addArrangedSubview:hwidHeader];

    UIStackView *hwidRow = [[UIStackView alloc] init];
    hwidRow.axis = UILayoutConstraintAxisHorizontal;
    hwidRow.spacing = 8.0;
    hwidRow.alignment = UIStackViewAlignmentCenter;
    [hwidSt addArrangedSubview:hwidRow];

    self.licenseHwidLabel = [[UILabel alloc] init];
    self.licenseHwidLabel.text = [ChangeInfoLicenseManager deviceHardwareID];
    self.licenseHwidLabel.font = [UIFont monospacedSystemFontOfSize:17.0 weight:UIFontWeightBlack];
    self.licenseHwidLabel.textColor = [self goldAccentColor];
    [hwidRow addArrangedSubview:self.licenseHwidLabel];

    UIButton *btnCopyHwid = [UIButton buttonWithType:UIButtonTypeSystem];
    btnCopyHwid.layer.cornerRadius = 8.0;
    btnCopyHwid.backgroundColor = [self surfaceInsetColor];
    btnCopyHwid.layer.borderWidth = 1.0;
    btnCopyHwid.layer.borderColor = [self borderSubtleColor].CGColor;
    [btnCopyHwid setTitle:@"Sao chép" forState:UIControlStateNormal];
    [btnCopyHwid setTitleColor:[self primaryTextColor] forState:UIControlStateNormal];
    btnCopyHwid.titleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
    [btnCopyHwid.widthAnchor constraintEqualToConstant:76.0].active = YES;
    [btnCopyHwid.heightAnchor constraintEqualToConstant:32.0].active = YES;
    [btnCopyHwid addTarget:self action:@selector(onTapCopyHWID) forControlEvents:UIControlEventTouchUpInside];
    [hwidRow addArrangedSubview:btnCopyHwid];

    // 3. Key Input Card
    UIView *keyCard = [[UIView alloc] init];
    keyCard.backgroundColor = [self surfaceCardColor];
    keyCard.layer.cornerRadius = 16.0;
    keyCard.layer.borderWidth = 1.0;
    keyCard.layer.borderColor = [self borderSubtleColor].CGColor;
    [self.tabLicenseStack addArrangedSubview:keyCard];

    UIStackView *keySt = [[UIStackView alloc] init];
    keySt.translatesAutoresizingMaskIntoConstraints = NO;
    keySt.axis = UILayoutConstraintAxisVertical;
    keySt.spacing = 12.0;
    [keyCard addSubview:keySt];

    [NSLayoutConstraint activateConstraints:@[
        [keySt.topAnchor constraintEqualToAnchor:keyCard.topAnchor constant:14.0],
        [keySt.bottomAnchor constraintEqualToAnchor:keyCard.bottomAnchor constant:-14.0],
        [keySt.leadingAnchor constraintEqualToAnchor:keyCard.leadingAnchor constant:14.0],
        [keySt.trailingAnchor constraintEqualToAnchor:keyCard.trailingAnchor constant:-14.0]
    ]];

    UILabel *keyCap = [[UILabel alloc] init];
    keyCap.text = @"NHẬP KEY KÍCH HOẠT BẢN QUYỀN:";
    keyCap.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
    keyCap.textColor = [self mutedTextColor];
    [keySt addArrangedSubview:keyCap];

    UIStackView *inRow = [[UIStackView alloc] init];
    inRow.axis = UILayoutConstraintAxisHorizontal;
    inRow.spacing = 8.0;
    [keySt addArrangedSubview:inRow];

    self.licenseKeyField = [[ChangeInfoSafeTextField alloc] init];
    self.licenseKeyField.backgroundColor = [self surfaceInsetColor];
    self.licenseKeyField.layer.cornerRadius = 10.0;
    self.licenseKeyField.layer.borderWidth = 1.0;
    self.licenseKeyField.layer.borderColor = [self borderSubtleColor].CGColor;
    self.licenseKeyField.textColor = [self primaryTextColor];
    self.licenseKeyField.font = [UIFont monospacedSystemFontOfSize:13.5 weight:UIFontWeightBold];
    self.licenseKeyField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.licenseKeyField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.licenseKeyField.returnKeyType = UIReturnKeyDone;
    self.licenseKeyField.delegate = self;
    self.licenseKeyField.placeholder = @"GT-VIP-XXXX-XXXX";
    self.licenseKeyField.text = [ChangeInfoLicenseManager savedLicenseKey] ?: @"";
    [self.licenseKeyField.heightAnchor constraintEqualToConstant:42.0].active = YES;

    UIToolbar *kbToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 44)];
    kbToolbar.barStyle = self.isLightMode ? UIBarStyleDefault : UIBarStyleBlack;
    kbToolbar.translucent = YES;
    kbToolbar.tintColor = [self goldAccentColor];
    UIBarButtonItem *btnDone = [[UIBarButtonItem alloc] initWithTitle:@"Đóng phím"
                                                                style:UIBarButtonItemStylePlain
                                                               target:self.view
                                                               action:@selector(endEditing:)];
    UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                            target:nil
                                                                            action:nil];
    UIBarButtonItem *btnSubmitKey = [[UIBarButtonItem alloc] initWithTitle:@"✓ KÍCH HOẠT NGAY"
                                                                     style:UIBarButtonItemStyleDone
                                                                    target:self
                                                                    action:@selector(onTapSubmitLicenseKey)];
    kbToolbar.items = @[btnDone, spacer, btnSubmitKey];
    self.licenseKeyField.inputAccessoryView = kbToolbar;

    [inRow addArrangedSubview:self.licenseKeyField];

    UIButton *btnPaste = [UIButton buttonWithType:UIButtonTypeSystem];
    btnPaste.layer.cornerRadius = 10.0;
    btnPaste.backgroundColor = [self surfaceInsetColor];
    btnPaste.layer.borderWidth = 1.0;
    btnPaste.layer.borderColor = [self borderSubtleColor].CGColor;
    [btnPaste setTitle:@"Dán" forState:UIControlStateNormal];
    [btnPaste setTitleColor:[self primaryTextColor] forState:UIControlStateNormal];
    btnPaste.titleLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightBold];
    [btnPaste.widthAnchor constraintEqualToConstant:54.0].active = YES;
    [btnPaste addTarget:self action:@selector(onTapPasteLicenseKey) forControlEvents:UIControlEventTouchUpInside];
    [inRow addArrangedSubview:btnPaste];

    self.btnActivateLicense = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnActivateLicense.layer.cornerRadius = 14.0;
    self.btnActivateLicense.backgroundColor = [self goldAccentColor];
    [self.btnActivateLicense setTitle:@"KÍCH HOẠT BẢN QUYỀN" forState:UIControlStateNormal];
    [self.btnActivateLicense setTitleColor:[self darkInkColor] forState:UIControlStateNormal];
    self.btnActivateLicense.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightBlack];
    [self.btnActivateLicense.heightAnchor constraintEqualToConstant:46.0].active = YES;
    [self attachSpringTouchFeedbackToButton:self.btnActivateLicense];
    [self.btnActivateLicense addTarget:self action:@selector(onTapSubmitLicenseKey) forControlEvents:UIControlEventTouchUpInside];
    [keySt addArrangedSubview:self.btnActivateLicense];

    self.btnRefreshLicense = [UIButton buttonWithType:UIButtonTypeSystem];
    self.btnRefreshLicense.layer.cornerRadius = 12.0;
    self.btnRefreshLicense.backgroundColor = [self surfaceInsetColor];
    self.btnRefreshLicense.layer.borderWidth = 1.0;
    self.btnRefreshLicense.layer.borderColor = [self borderSubtleColor].CGColor;
    [self.btnRefreshLicense setTitle:@"🔄 Kiểm Tra / Làm Mới Trạng Thái Online" forState:UIControlStateNormal];
    [self.btnRefreshLicense setTitleColor:[self secondaryTextColor] forState:UIControlStateNormal];
    self.btnRefreshLicense.titleLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold];
    [self.btnRefreshLicense.heightAnchor constraintEqualToConstant:38.0].active = YES;
    [self attachSpringTouchFeedbackToButton:self.btnRefreshLicense];
    [self.btnRefreshLicense addTarget:self action:@selector(onTapRefreshOnlineLicense) forControlEvents:UIControlEventTouchUpInside];
    [keySt addArrangedSubview:self.btnRefreshLicense];
}

- (void)refreshLicenseStateUI {
    BOOL isValid = [ChangeInfoLicenseManager isLicenseCurrentlyValid];
    if (isValid) {
        self.headerLicenseBadge.backgroundColor = [self emeraldBadgeBgColor];
        self.headerLicenseBadge.layer.borderColor = [self emeraldColor].CGColor;
        self.headerLicenseText.textColor = [self emeraldColor];
        self.headerLicenseText.text = @"VIP Active";
        self.headerLicenseIcon.image = [ChangeInfoVectorIcons iconWithType:ChangeInfoIconShieldCheck size:14.0 color:[self emeraldColor]];

        self.licenseStatusTitle.text = @"VIP ACTIVE";
        self.licenseStatusTitle.textColor = [self emeraldColor];
        self.licenseStatusSub.text = [ChangeInfoLicenseManager licenseStatusSummary];
    } else {
        self.headerLicenseBadge.backgroundColor = [self goldBadgeBgColor];
        self.headerLicenseBadge.layer.borderColor = [self goldAccentColor].CGColor;
        self.headerLicenseText.textColor = [self goldAccentColor];
        self.headerLicenseText.text = @"Kích hoạt Key";
        self.headerLicenseIcon.image = [ChangeInfoVectorIcons iconWithType:ChangeInfoIconShieldLock size:14.0 color:[self goldAccentColor]];

        self.licenseStatusTitle.text = @"CHƯA KÍCH HOẠT";
        self.licenseStatusTitle.textColor = [UIColor colorWithRed:0.94 green:0.27 blue:0.27 alpha:1.0];
        self.licenseStatusSub.text = @"Vui lòng nhập Key bản quyền để mở khóa toàn bộ tính năng";
    }
}

#pragma mark - Loading Overlay

- (void)setupLoadingOverlay {
    self.loadingOverlayView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.loadingOverlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.loadingOverlayView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.75];
    self.loadingOverlayView.alpha = 0.0;
    self.loadingOverlayView.hidden = YES;
    [self.view addSubview:self.loadingOverlayView];

    UIView *box = [[UIView alloc] init];
    box.translatesAutoresizingMaskIntoConstraints = NO;
    box.backgroundColor = [self surfaceCardColor];
    box.layer.cornerRadius = 20.0;
    box.layer.borderWidth = 1.0;
    box.layer.borderColor = [self borderSubtleColor].CGColor;
    [self.loadingOverlayView addSubview:box];

    UIStackView *boxSt = [[UIStackView alloc] init];
    boxSt.translatesAutoresizingMaskIntoConstraints = NO;
    boxSt.axis = UILayoutConstraintAxisVertical;
    boxSt.spacing = 10.0;
    boxSt.alignment = UIStackViewAlignmentCenter;
    [box addSubview:boxSt];

    [NSLayoutConstraint activateConstraints:@[
        [box.centerXAnchor constraintEqualToAnchor:self.loadingOverlayView.centerXAnchor],
        [box.centerYAnchor constraintEqualToAnchor:self.loadingOverlayView.centerYAnchor],
        [box.widthAnchor constraintEqualToConstant:240.0],

        [boxSt.topAnchor constraintEqualToAnchor:box.topAnchor constant:22.0],
        [boxSt.bottomAnchor constraintEqualToAnchor:box.bottomAnchor constant:-22.0],
        [boxSt.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:16.0],
        [boxSt.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-16.0]
    ]];

    self.loadingSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.loadingSpinner.color = [self goldAccentColor];
    [boxSt addArrangedSubview:self.loadingSpinner];

    self.loadingTitleLabel = [[UILabel alloc] init];
    self.loadingTitleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightBold];
    self.loadingTitleLabel.textColor = [self primaryTextColor];
    self.loadingTitleLabel.textAlignment = NSTextAlignmentCenter;
    [boxSt addArrangedSubview:self.loadingTitleLabel];

    self.loadingSubLabel = [[UILabel alloc] init];
    self.loadingSubLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    self.loadingSubLabel.textColor = [self mutedTextColor];
    self.loadingSubLabel.textAlignment = NSTextAlignmentCenter;
    [boxSt addArrangedSubview:self.loadingSubLabel];
}

- (void)showLoadingWithTitle:(NSString *)title sub:(NSString *)sub {
    self.loadingTitleLabel.text = title;
    self.loadingSubLabel.text = sub;
    [self.loadingSpinner startAnimating];
    self.loadingOverlayView.hidden = NO;
    [UIView animateWithDuration:0.2 animations:^{
        self.loadingOverlayView.alpha = 1.0;
    }];
}

- (void)hideLoading {
    [UIView animateWithDuration:0.2 animations:^{
        self.loadingOverlayView.alpha = 0.0;
    } completion:^(BOOL finished) {
        self.loadingOverlayView.hidden = YES;
        [self.loadingSpinner stopAnimating];
    }];
}

#pragma mark - Actions

- (void)onTapRandomDevice {
    if (![ChangeInfoLicenseManager isLicenseCurrentlyValid]) {
        [self showToast:@"Vui lòng kích hoạt bản quyền để sử dụng tính năng này!" isError:YES];
        [self switchTab:ChangeInfoMainTabLicense];
        return;
    }

    [self showLoadingWithTitle:@"Đang khởi tạo cấu hình..." sub:@"Ghi thông số phần cứng & dylib hooks"];

    // Capture all UIKit properties on the MAIN thread before entering background queue
    BOOL lock = self.lockModelSwitch ? self.lockModelSwitch.isOn : NO;
    BOOL sameSc = self.sameScreenSwitch ? self.sameScreenSwitch.isOn : NO;
    BOOL matchC = self.matchChipSwitch ? self.matchChipSwitch.isOn : NO;
    ChangeInfoModelTierFilter tier = self.currentModelTier;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        ChangeInfoDeviceProfile *prof = [ChangeInfoDeviceDatabase generateProfileWithLockRealModel:lock
                                                                                        sameScreen:sameSc
                                                                                         matchChip:matchC
                                                                                         modelTier:tier
                                                                                       currentCity:nil];
        if (prof) {
            [ChangeInfoDeviceDatabase writeProfileFiles:prof error:nil];
            [ChangeInfoDeviceDatabase seedNaturalVietnameseContactsIfFew];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (prof) {
                self.currentProfile = prof;
                [self refreshUIWithCurrentProfile];
            }
            [self hideLoading];
            if (prof) {
                [self showToast:[NSString stringWithFormat:@"Đã đổi sang %@ (%@) thành công!", prof.modelName, prof.machineId] isError:NO];
            } else {
                [self showToast:@"Không thể tạo cấu hình mới, vui lòng thử lại." isError:YES];
            }
        });
    });
}

- (void)onTapRespring {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Xác nhận Respring"
                                                                   message:@"Khởi động lại SpringBoard để toàn bộ hệ thống áp dụng thông số cấu hình mới ngay lập tức?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Respring Ngay" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self showLoadingWithTitle:@"Đang khởi động lại SpringBoard..." sub:@"Vui lòng chờ trong giây lát"];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [ChangeInfoDeviceDatabase performRespringIfPossible];
        });
        // Auto-dismiss safety timer: unfreeze UI after 2.2s if system lacks shell-cmds / sbreload
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self hideLoading];
            [self showToast:@"Đã áp dụng cấu hình! (Vuốt tắt app mục tiêu để nhận ngay)" isError:NO];
        });
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)onTapCopyUUID {
    if (self.currentProfile.identifier.length > 0) {
        UIPasteboard.generalPasteboard.string = self.currentProfile.identifier;
        [self showToast:@"Đã sao chép UUID vào bộ nhớ tạm!" isError:NO];
    }
}

- (void)onTapCopyProfileText {
    NSString *rep = [self.currentProfile fullReportTextWithFlags:self.lockModelSwitch.isOn
                                                   respringAfter:YES
                                                      sameScreen:self.sameScreenSwitch.isOn
                                                       matchChip:self.matchChipSwitch.isOn];
    UIPasteboard.generalPasteboard.string = rep;
    [self showToast:@"Đã sao chép toàn bộ thông số cấu hình!" isError:NO];
}

- (void)onTapOpenDiagnostics {
    NSString *diagReport = [ChangeInfoDiagnostics generateFullSystemDiagnosticReport];

    UIViewController *diagVC = [[UIViewController alloc] init];
    diagVC.view.backgroundColor = [self surfaceCardColor];

    UINavigationBar *bar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 56)];
    bar.barTintColor = [self surfaceCardColor];
    UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:@"Chẩn Đoán Hệ Thống"];
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(onDismissModal)];
    item.rightBarButtonItem = done;
    bar.items = @[item];
    [diagVC.view addSubview:bar];

    UITextView *tv = [[UITextView alloc] initWithFrame:CGRectMake(16, 64, self.view.bounds.size.width - 32, self.view.bounds.size.height - 130)];
    tv.backgroundColor = [self surfaceInsetColor];
    tv.textColor = [self primaryTextColor];
    tv.font = [UIFont monospacedSystemFontOfSize:11.0 weight:UIFontWeightRegular];
    tv.editable = NO;
    tv.layer.cornerRadius = 12.0;
    tv.text = diagReport;
    [diagVC.view addSubview:tv];

    UIButton *btnCopy = [UIButton buttonWithType:UIButtonTypeSystem];
    btnCopy.frame = CGRectMake(16, self.view.bounds.size.height - 58, self.view.bounds.size.width - 32, 44);
    btnCopy.backgroundColor = [self goldAccentColor];
    [btnCopy setTitle:@"Sao chép toàn bộ báo cáo" forState:UIControlStateNormal];
    [btnCopy setTitleColor:[self darkInkColor] forState:UIControlStateNormal];
    btnCopy.titleLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightBold];
    btnCopy.layer.cornerRadius = 12.0;
    objc_setAssociatedObject(btnCopy, "kDiagText", diagReport, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [btnCopy addTarget:self action:@selector(onCopyDiagFromModal:) forControlEvents:UIControlEventTouchUpInside];
    [diagVC.view addSubview:btnCopy];

    [self presentViewController:diagVC animated:YES completion:nil];
}

- (void)onDismissModal {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)onCopyDiagFromModal:(UIButton *)sender {
    NSString *t = objc_getAssociatedObject(sender, "kDiagText");
    if (t.length > 0) {
        UIPasteboard.generalPasteboard.string = t;
        [self showToast:@"Đã sao chép báo cáo chẩn đoán!" isError:NO];
    }
}

#pragma mark - Proxy Modal

- (void)onTapOpenProxyModal {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Cài Đặt Proxy"
                                                                   message:@"Nhập địa chỉ Proxy dạng: IP:Port hoặc IP:Port:User:Pass"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"VD: 103.152.118.25:8080:user:pass";
        textField.text = self.currentProfile.activeProxy ?: @"";
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Xóa Proxy" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        self.currentProfile.activeProxy = @"";
        [ChangeInfoDeviceDatabase writeProfileFiles:self.currentProfile error:nil];
        [self refreshUIWithCurrentProfile];
        [self showToast:@"Đã gỡ bỏ Proxy. Đang dùng mạng trực tiếp." isError:NO];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Áp Dụng" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *val = alert.textFields.firstObject.text;
        self.currentProfile.activeProxy = [val stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [ChangeInfoDeviceDatabase writeProfileFiles:self.currentProfile error:nil];
        [self refreshUIWithCurrentProfile];
        [self showToast:@"Đã lưu Proxy thành công!" isError:NO];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - License Actions

- (void)onTapHeaderLicenseBadge {
    [self switchTab:ChangeInfoMainTabLicense];
}

- (void)onTapCopyHWID {
    NSString *hwid = [ChangeInfoLicenseManager deviceHardwareID];
    UIPasteboard.generalPasteboard.string = hwid;
    [self showToast:[NSString stringWithFormat:@"Đã sao chép HWID: %@", hwid] isError:NO];
}

- (void)onTapPasteLicenseKey {
    NSString *clip = ChangeInfoReadClipboardSafely();
    if (clip.length > 0) {
        self.licenseKeyField.text = clip;
        [self showToast:@"Đã dán Key từ bộ nhớ tạm" isError:NO];
    }
}

- (void)onTapSubmitLicenseKey {
    NSString *key = self.licenseKeyField.text;
    if (!key || key.length == 0) {
        [self showToast:@"Vui lòng nhập Key bản quyền!" isError:YES];
        return;
    }

    [self.view endEditing:YES];
    [self showLoadingWithTitle:@"Đang xác thực Key..." sub:@"Kết nối máy chủ bản quyền Upstash & GitHub"];

    [ChangeInfoLicenseManager verifyAndActivateKey:key completion:^(BOOL isValid, NSString *message, NSString *ownerName, NSString *expiryText) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideLoading];
            [self refreshLicenseStateUI];
            [self showToast:message isError:!isValid];
            if (isValid) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self switchTab:ChangeInfoMainTabFeatures];
                });
            }
        });
    }];
}

- (void)onTapRefreshOnlineLicense {
    [self showLoadingWithTitle:@"Đang kiểm tra bản quyền..." sub:@"Đồng bộ thông tin từ máy chủ"];
    [ChangeInfoLicenseManager refreshSavedLicenseInBackgroundWithCompletion:^(BOOL isValid, NSString *statusText) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideLoading];
            [self refreshLicenseStateUI];
            [self showToast:isValid ? @"Bản quyền hợp lệ và đang hoạt động!" : statusText isError:!isValid];
        });
    }];
}

- (void)onTapToggleTheme {
    self.isLightMode = !self.isLightMode;
    [[NSUserDefaults standardUserDefaults] setBool:self.isLightMode forKey:@"ChangeInfo_LightMode"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self buildCompleteInterface];
}

#pragma mark - UI Refresh

- (void)refreshUIWithCurrentProfile {
    self.modelHeroLabel.text = self.currentProfile.modelName ?: @"iPhone 7";
    self.machineBadgeLabel.text = [NSString stringWithFormat:@"  %@  ", self.currentProfile.machineId ?: @"iPhone9,3"];
    self.iosBadgeLabel.text = [NSString stringWithFormat:@"  iOS %@  ", self.currentProfile.iosVersion ?: @"15.8.4"];
    self.uuidMonoLabel.text = [NSString stringWithFormat:@"UUID: %@", self.currentProfile.identifier ?: @""];

    self.specChipValueLabel.text = [NSString stringWithFormat:@"%@ · %ldGB", self.currentProfile.chipName ?: @"A10 Fusion", (long)self.currentProfile.ramGB];
    self.specScreenValueLabel.text = [NSString stringWithFormat:@"%@ px", self.currentProfile.screenKey ?: @"375x667"];
    self.specNetValueLabel.text = [NSString stringWithFormat:@"%@ · %@", self.currentProfile.carrier ?: @"Viettel", self.currentProfile.city ?: @"Hà Nội"];
    self.specBatValueLabel.text = [NSString stringWithFormat:@"%ld%% · %ld liên hệ", (long)self.currentProfile.batteryPercent, (long)self.currentProfile.contactsCount];

    if (self.currentProfile.activeProxy.length > 0) {
        [self.configProxyButton setTitle:[NSString stringWithFormat:@"🛡️ Proxy: %@", self.currentProfile.activeProxy] forState:UIControlStateNormal];
        self.configProxyButton.backgroundColor = [self emeraldBadgeBgColor];
        self.configProxyButton.layer.borderColor = [self emeraldColor].CGColor;
        [self.configProxyButton setTitleColor:[self emeraldColor] forState:UIControlStateNormal];
    } else {
        [self.configProxyButton setTitle:@"🌐 Mạng trực tiếp (Không Proxy / 4G)" forState:UIControlStateNormal];
        self.configProxyButton.backgroundColor = [self surfaceInsetColor];
        self.configProxyButton.layer.borderColor = [self borderSubtleColor].CGColor;
        [self.configProxyButton setTitleColor:[self secondaryTextColor] forState:UIControlStateNormal];
    }
}

- (void)attachSpringTouchFeedbackToButton:(UIButton *)button {
    [button addTarget:self action:@selector(btnTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(btnTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
}

- (void)btnTouchDown:(UIButton *)btn {
    @try {
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            [gen prepare];
            [gen impactOccurred];
        }
    } @catch (id ex) {
        // Haptic feedback failure should never crash the application (e.g. system haptics off or tweak hooks)
    }
    [UIView animateWithDuration:0.12 animations:^{
        btn.transform = CGAffineTransformMakeScale(0.96, 0.96);
    }];
}

- (void)btnTouchUp:(UIButton *)btn {
    @try {
        [UIView animateWithDuration:0.22 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
            btn.transform = CGAffineTransformIdentity;
        } completion:nil];
    } @catch (id ex) {}
}

#pragma mark - Keyboard Handling & TextField Delegate

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    UIEdgeInsets insets = UIEdgeInsetsMake(0, 0, kbSize.height + 40.0, 0);
    self.scrollView.contentInset = insets;
    self.scrollView.scrollIndicatorInsets = insets;

    if (self.licenseKeyField && self.licenseKeyField.isFirstResponder) {
        CGRect r = [self.contentStack convertRect:self.licenseKeyField.frame fromView:self.licenseKeyField.superview];
        [self.scrollView scrollRectToVisible:CGRectInset(r, 0, -80.0) animated:YES];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification {
    UIEdgeInsets insets = UIEdgeInsetsZero;
    self.scrollView.contentInset = insets;
    self.scrollView.scrollIndicatorInsets = insets;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self.view endEditing:YES];
    if (textField == self.licenseKeyField) {
        [self onTapSubmitLicenseKey];
    }
    return YES;
}

@end
