#import "ChangeInfoLicenseManager.h"
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>

static NSString * const kChangeInfoHWIDPrefKey     = @"ZTechPermanentHWID_v1";
static NSString * const kChangeInfoSavedKeyPref    = @"ChangeInfoSavedLicenseKey_v1";
static NSString * const kChangeInfoSavedOwnerPref  = @"ChangeInfoSavedLicenseOwner_v1";
static NSString * const kChangeInfoSavedExpiryPref = @"ChangeInfoSavedLicenseExpiry_v1";
static NSString * const kChangeInfoSavedValidPref  = @"ChangeInfoSavedLicenseValid_v1";

// Upstash Redis REST API Configuration (Shared key vault)
static NSString * const kUpstashRedisURL      = @"https://right-cat-209639.upstash.io";
static NSString * const kUpstashRedisToken    = @"gQAAAAAAAzLnAAIgcDFiYzU0NDBiOGJmYzE0OTFmYWQ2YTUzYTg4M2MwYmNlNA";
static NSString * const kRedisHashKey         = @"ztech:licenses";
static NSString * const kRedisPendingHashKey  = @"ztech:pending_devices";

@implementation ChangeInfoLicenseManager

#pragma mark - Permanent Device Hardware ID (1 Key = 1 Device)

+ (NSString *)deviceHardwareID {
    CFTypeRef cfHwid = CFPreferencesCopyAppValue((__bridge CFStringRef)kChangeInfoHWIDPrefKey, kCFPreferencesAnyApplication);
    if (cfHwid && CFGetTypeID(cfHwid) == CFStringGetTypeID()) {
        NSString *val = [(__bridge NSString *)cfHwid copy];
        CFRelease(cfHwid);
        if (val.length >= 10 && [val hasPrefix:@"GT-"]) {
            return val;
        }
    } else if (cfHwid) {
        CFRelease(cfHwid);
    }

    NSArray<NSString *> *hwidPaths = @[
        @"/var/jb/var/mobile/Library/Preferences/com.gaulmt.hwid.txt",
        @"/var/mobile/Library/Preferences/com.gaulmt.hwid.txt"
    ];
    for (NSString *path in hwidPaths) {
        NSString *diskVal = [[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil]
                             stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (diskVal.length >= 10 && [diskVal hasPrefix:@"GT-"]) {
            [self savePermanentHWID:diskVal];
            return diskVal;
        }
    }

    NSString *udVal = [[NSUserDefaults standardUserDefaults] stringForKey:kChangeInfoHWIDPrefKey];
    if (udVal.length >= 10 && [udVal hasPrefix:@"GT-"]) {
        [self savePermanentHWID:udVal];
        return udVal;
    }

    NSString *chars = @"23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
    NSMutableString *p1 = [NSMutableString stringWithCapacity:4];
    NSMutableString *p2 = [NSMutableString stringWithCapacity:4];
    for (int i = 0; i < 4; i++) {
        [p1 appendFormat:@"%C", [chars characterAtIndex:arc4random_uniform((uint32_t)chars.length)]];
        [p2 appendFormat:@"%C", [chars characterAtIndex:arc4random_uniform((uint32_t)chars.length)]];
    }
    NSString *newHwid = [NSString stringWithFormat:@"GT-%@-%@", p1, p2];
    [self savePermanentHWID:newHwid];
    return newHwid;
}

+ (void)savePermanentHWID:(NSString *)hwid {
    [[NSUserDefaults standardUserDefaults] setObject:hwid forKey:kChangeInfoHWIDPrefKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    CFPreferencesSetAppValue((__bridge CFStringRef)kChangeInfoHWIDPrefKey,
                             (__bridge CFStringRef)hwid,
                             kCFPreferencesAnyApplication);
    CFPreferencesAppSynchronize(kCFPreferencesAnyApplication);

    NSArray<NSString *> *hwidPaths = @[
        @"/var/jb/var/mobile/Library/Preferences/com.gaulmt.hwid.txt",
        @"/var/mobile/Library/Preferences/com.gaulmt.hwid.txt"
    ];
    for (NSString *path in hwidPaths) {
        [hwid writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

#pragma mark - License State Getters & Setters

+ (nullable NSString *)savedLicenseKey {
    // If not found in ChangeInfo prefs, check ZTech prefs for seamless cross-app license sharing
    NSString *k = [[NSUserDefaults standardUserDefaults] stringForKey:kChangeInfoSavedKeyPref];
    if (!k || k.length == 0) {
        k = [[NSUserDefaults standardUserDefaults] stringForKey:@"ZTechSavedLicenseKey_v1"];
    }
    return k;
}

+ (BOOL)isLicenseCurrentlyValid {
    NSString *key = [self savedLicenseKey];
    if (!key || key.length == 0) return NO;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kChangeInfoSavedValidPref]) {
        return YES;
    }
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"ZTechSavedLicenseValid_v1"];
}

+ (NSString *)licenseStatusSummary {
    if (![self isLicenseCurrentlyValid]) {
        return @"Chưa kích hoạt bản quyền";
    }
    NSString *owner = [[NSUserDefaults standardUserDefaults] stringForKey:kChangeInfoSavedOwnerPref]
                   ?: [[NSUserDefaults standardUserDefaults] stringForKey:@"ZTechSavedLicenseOwner_v1"]
                   ?: @"VIP Member";
    NSString *expiry = [[NSUserDefaults standardUserDefaults] stringForKey:kChangeInfoSavedExpiryPref]
                    ?: [[NSUserDefaults standardUserDefaults] stringForKey:@"ZTechSavedLicenseExpiry_v1"]
                    ?: @"Vĩnh viễn";
    return [NSString stringWithFormat:@"%@ • Hạn: %@", owner, expiry];
}

+ (void)saveActiveLicense:(NSString *)key
                    owner:(NSString *)owner
                   expiry:(NSString *)expiry {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setObject:key forKey:kChangeInfoSavedKeyPref];
    [ud setObject:owner forKey:kChangeInfoSavedOwnerPref];
    [ud setObject:expiry forKey:kChangeInfoSavedExpiryPref];
    [ud setBool:YES forKey:kChangeInfoSavedValidPref];
    [ud synchronize];
}

+ (void)clearSavedLicense {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud removeObjectForKey:kChangeInfoSavedKeyPref];
    [ud removeObjectForKey:kChangeInfoSavedOwnerPref];
    [ud removeObjectForKey:kChangeInfoSavedExpiryPref];
    [ud setBool:NO forKey:kChangeInfoSavedValidPref];
    [ud synchronize];
}

#pragma mark - Verification Engine

+ (void)verifyAndActivateKey:(NSString *)rawKey
                  completion:(ChangeInfoLicenseVerifyCompletion)completion {
    NSString *cleanKey = [[rawKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    if (cleanKey.length < 6) {
        if (completion) completion(NO, @"Định dạng Key không hợp lệ. Vui lòng kiểm tra lại.", nil, nil);
        return;
    }

    NSString *myHWID = [self deviceHardwareID];

    // Priority 1: Query Upstash Redis Hash Key
    NSString *endpoint = [NSString stringWithFormat:@"%@/hget/%@/%@", kUpstashRedisURL, kRedisHashKey, cleanKey];
    NSURL *url = [NSURL URLWithString:endpoint];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"GET";
    req.timeoutInterval = 10.0;
    [req setValue:[NSString stringWithFormat:@"Bearer %@", kUpstashRedisToken] forHTTPHeaderField:@"Authorization"];

    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!error && data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSString *rawVal = json[@"result"];
            if (rawVal && [rawVal isKindOfClass:[NSString class]] && rawVal.length > 0) {
                NSDictionary *entry = [NSJSONSerialization JSONObjectWithData:[rawVal dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
                if (entry) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self evaluateLicenseEntry:entry key:cleanKey hwid:myHWID isFreshActivate:YES completion:completion];
                    });
                    return;
                }
            }
        }

        // Priority 2: Fallback to GitHub Pages Static Repo
        [self verifyViaGitHubPages:cleanKey hwid:myHWID completion:completion];
    }] resume];
}

+ (void)evaluateLicenseEntry:(NSDictionary *)entry
                         key:(NSString *)key
                        hwid:(NSString *)hwid
             isFreshActivate:(BOOL)isFresh
                  completion:(ChangeInfoLicenseVerifyCompletion)completion {
    BOOL active = YES;
    if (entry[@"active"] != nil) {
        active = [entry[@"active"] boolValue];
    } else if (entry[@"status"] != nil) {
        active = [entry[@"status"] isEqualToString:@"active"];
    }

    if (!active) {
        [self clearSavedLicense];
        if (completion) completion(NO, @"Key bản quyền này đã bị khoá hoặc thu hồi bởi Quản trị viên.", nil, nil);
        return;
    }

    // Expiry check
    NSString *expiryStr = entry[@"expiry"] ?: entry[@"expires"] ?: @"2099-12-31";
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyy-MM-dd";
    NSDate *expDate = [df dateFromString:expiryStr];
    if (expDate && [expDate compare:[NSDate date]] == NSOrderedAscending) {
        [self clearSavedLicense];
        if (completion) completion(NO, [NSString stringWithFormat:@"Key này đã hết hạn sử dụng vào ngày %@", expiryStr], nil, nil);
        return;
    }

    NSString *boundHwid = entry[@"hwid"] ?: @"";
    NSString *owner = entry[@"owner"] ?: @"Khách hàng VIP";

    if (boundHwid.length == 0 || [boundHwid isEqualToString:@"UNBOUND"]) {
        // First activation: bind to this HWID
        [self bindKeyToHardware:key hwid:hwid existingEntry:entry completion:^(BOOL ok) {
            if (ok) {
                [self saveActiveLicense:key owner:owner expiry:expiryStr];
                if (completion) completion(YES, [NSString stringWithFormat:@"Kích hoạt thành công cho %@!", owner], owner, expiryStr);
            } else {
                if (completion) completion(NO, @"Không thể liên kết Key với thiết bị. Vui lòng thử lại.", nil, nil);
            }
        }];
        return;
    }

    if ([boundHwid isEqualToString:@"*"] || [boundHwid isEqualToString:hwid]) {
        [self saveActiveLicense:key owner:owner expiry:expiryStr];
        if (completion) completion(YES, [NSString stringWithFormat:@"Xác thực thành công! Xin chào %@.", owner], owner, expiryStr);
    } else {
        [self clearSavedLicense];
        if (completion) completion(NO, [NSString stringWithFormat:@"Key này đã được kích hoạt cho máy khác (%@). Mỗi máy yêu cầu 1 Key riêng biệt.", boundHwid], nil, nil);
    }
}

+ (void)bindKeyToHardware:(NSString *)key
                     hwid:(NSString *)hwid
            existingEntry:(NSDictionary *)entry
               completion:(void (^)(BOOL ok))completion {
    NSMutableDictionary *updated = [entry mutableCopy];
    updated[@"hwid"] = hwid;
    updated[@"activated_at"] = [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]];

    NSData *d = [NSJSONSerialization dataWithJSONObject:updated options:0 error:nil];
    NSString *strVal = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];

    NSString *endpoint = [NSString stringWithFormat:@"%@/hset/%@/%@", kUpstashRedisURL, kRedisHashKey, key];
    NSURL *url = [NSURL URLWithString:endpoint];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    req.HTTPBody = [strVal dataUsingEncoding:NSUTF8StringEncoding];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", kUpstashRedisToken] forHTTPHeaderField:@"Authorization"];

    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(!error);
        });
    }] resume];
}

+ (void)verifyViaGitHubPages:(NSString *)key
                        hwid:(NSString *)hwid
                  completion:(ChangeInfoLicenseVerifyCompletion)completion {
    NSString *ts = [NSString stringWithFormat:@"?t=%lu", (unsigned long)[[NSDate date] timeIntervalSince1970]];
    NSURL *url = [NSURL URLWithString:[@"https://gaulmt.github.io/licenses.json" stringByAppendingString:ts]];

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    req.timeoutInterval = 8.0;

    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !data) {
                if ([self isLicenseCurrentlyValid]) {
                    if (completion) completion(YES, @"Đang dùng bản quyền đã lưu (Offline Mode)", [self licenseStatusSummary], @"Offline");
                } else {
                    if (completion) completion(NO, @"Không thể kết nối đến máy chủ xác thực bản quyền.", nil, nil);
                }
                return;
            }

            NSDictionary *root = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSDictionary *keys = root[@"keys"];
            NSDictionary *entry = keys[key];

            if (entry) {
                [self evaluateLicenseEntry:entry key:key hwid:hwid isFreshActivate:NO completion:completion];
            } else {
                [self clearSavedLicense];
                if (completion) completion(NO, @"Key bản quyền không tồn tại trong hệ thống.", nil, nil);
            }
        });
    }] resume];
}

+ (void)refreshSavedLicenseInBackgroundWithCompletion:(void (^)(BOOL isValid, NSString *statusText))completion {
    NSString *key = [self savedLicenseKey];
    if (!key || key.length == 0) {
        if (completion) completion(NO, @"Chưa kích hoạt bản quyền");
        return;
    }

    [self verifyAndActivateKey:key completion:^(BOOL isValid, NSString *message, NSString *ownerName, NSString *expiryText) {
        if (completion) {
            completion(isValid, isValid ? [self licenseStatusSummary] : message);
        }
    }];
}

@end
