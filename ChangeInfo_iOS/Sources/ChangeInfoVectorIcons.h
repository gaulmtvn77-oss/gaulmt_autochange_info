#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ChangeInfoCustomIconType) {
    ChangeInfoIconBrandCrest = 0,
    ChangeInfoIconTabSpoof,
    ChangeInfoIconTabLicense,
    ChangeInfoIconDevicePhone,
    ChangeInfoIconChipCpu,
    ChangeInfoIconDisplayScreen,
    ChangeInfoIconSignalRadar,
    ChangeInfoIconBatteryBolt,
    ChangeInfoIconRefreshMorph,
    ChangeInfoIconLocationPin,
    ChangeInfoIconRocketLaunch,
    ChangeInfoIconProxyNodes,
    ChangeInfoIconSlidersTune,
    ChangeInfoIconCopyClone,
    ChangeInfoIconClipboardPaste,
    ChangeInfoIconShieldCheck,
    ChangeInfoIconShieldLock,
    ChangeInfoIconKeyVip,
    ChangeInfoIconKeypadGrid,
    ChangeInfoIconCloudSync,
    ChangeInfoIconCrownTier,
    ChangeInfoIconCheckmark,
    ChangeInfoIconInfoDiag
};

@interface ChangeInfoVectorIcons : NSObject

+ (UIImage *)iconWithType:(ChangeInfoCustomIconType)type
                     size:(CGFloat)ptSize
                    color:(UIColor *)primaryColor;

+ (UIImage *)brandCrestLogoWithSize:(CGFloat)ptSize;

@end

NS_ASSUME_NONNULL_END
