#import "ChangeInfoDeviceDatabase.h"
#import <sys/utsname.h>
#import <sys/stat.h>
#import <spawn.h>
#import <notify.h>
#import <stdlib.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>

extern char **environ;

@implementation ChangeInfoDeviceProfile

- (NSString *)summaryLine1 {
    return [NSString stringWithFormat:@"%@ (%@) · iOS %@",
            self.modelName ?: @"iPhone 7",
            self.machineId ?: @"iPhone9,3",
            self.iosVersion ?: @"15.8.4"];
}

- (NSString *)summaryLine2 {
    NSString *proxyTag = (self.activeProxy && self.activeProxy.length > 0)
        ? [NSString stringWithFormat:@" · 🛡 Proxy: %@", self.activeProxy]
        : @"";
    return [NSString stringWithFormat:@"Pin %ld%% · %@ · %@ · %@ · %ld danh bạ%@",
            (long)self.batteryPercent,
            self.carrier ?: @"Viettel",
            self.wifiSsid ?: @"Viettel_Home_5G",
            self.city ?: @"Hà Nội",
            (long)self.contactsCount,
            proxyTag];
}

- (NSString *)fullReportTextWithFlags:(BOOL)lockModel
                          respringAfter:(BOOL)respring
                             sameScreen:(BOOL)sameScreen
                              matchChip:(BOOL)matchChip {
    NSMutableString *s = [NSMutableString string];
    [s appendString:@"========================================================\n"];
    [s appendString:@"        CHANGE INFO - BÁO CÁO CẤU HÌNH THIẾT BỊ\n"];
    [s appendString:@"========================================================\n\n"];
    [s appendFormat:@"• Thiết Bị:        %@ (%@)\n", self.modelName, self.machineId];
    [s appendFormat:@"• Phiên Bản iOS:   iOS %@\n", self.iosVersion];
    [s appendFormat:@"• Vi Xử Lý (SoC):  %@ (%ld GB RAM)\n", self.chipName, (long)self.ramGB];
    [s appendFormat:@"• Độ Phân Giải:    %@ px\n", self.screenKey];
    [s appendFormat:@"• Mã Định Danh:    %@\n", self.identifier];
    [s appendFormat:@"• Mạng / Nhà Mạng: %@\n", self.carrier];
    [s appendFormat:@"• Điểm WiFi:       %@\n", self.wifiSsid];
    [s appendFormat:@"• Vị Trí / Tỉnh:   %@\n", self.city];
    [s appendFormat:@"• Mức Pin Hiện Tại: %ld%%\n", (long)self.batteryPercent];
    [s appendFormat:@"• Số Danh Bạ:      %ld liên hệ\n", (long)self.contactsCount];
    if (self.activeProxy.length > 0) {
        [s appendFormat:@"• Proxy Hoạt Động: %@\n", self.activeProxy];
    } else {
        [s appendString:@"• Mạng:            Trực tiếp (Không Proxy)\n"];
    }
    [s appendString:@"\n------------------ TUỲ CHỌN KHÓA -------------------\n"];
    [s appendFormat:@"• Khóa Máy Thật:   %@\n", lockModel ? @"BẬT (Khớp 100%)" : @"TẮT (Random)"];
    [s appendFormat:@"• Trùng Màn Hình:  %@\n", sameScreen ? @"BẬT" : @"TẮT"];
    [s appendFormat:@"• Trùng Chip/RAM:  %@\n", matchChip ? @"BẬT" : @"TẮT"];
    [s appendFormat:@"• Tự Động Respring:%@\n", respring ? @"BẬT" : @"TẮT"];
    [s appendString:@"========================================================\n"];
    return s;
}

- (NSDictionary *)toDictionary {
    return @{
        @"identifier": self.identifier ?: @"",
        @"modelName": self.modelName ?: @"iPhone 7",
        @"machineId": self.machineId ?: @"iPhone9,3",
        @"iosVersion": self.iosVersion ?: @"15.8.4",
        @"batteryPercent": @(self.batteryPercent),
        @"carrier": self.carrier ?: @"Viettel",
        @"wifiSsid": self.wifiSsid ?: @"Viettel_Home_5G",
        @"city": self.city ?: @"Hà Nội",
        @"contactsCount": @(self.contactsCount),
        @"chipName": self.chipName ?: @"A10 Fusion",
        @"ramGB": @(self.ramGB),
        @"screenKey": self.screenKey ?: @"375x667",
        @"activeProxy": self.activeProxy ?: @"",
        @"writtenFilesCount": @(self.writtenFilesCount),
        @"successItemsCount": @(self.successItemsCount)
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) return nil;
    ChangeInfoDeviceProfile *p = [[ChangeInfoDeviceProfile alloc] init];
    p.identifier = dict[@"identifier"] ?: @"7BD46FDA-D93D-45BD-9158-7178669502DD";
    p.modelName = dict[@"modelName"] ?: @"iPhone 7";
    p.machineId = dict[@"machineId"] ?: @"iPhone9,3";
    p.iosVersion = dict[@"iosVersion"] ?: @"15.8.4";
    p.batteryPercent = [dict[@"batteryPercent"] integerValue] ?: 82;
    p.carrier = dict[@"carrier"] ?: @"Viettel";
    p.wifiSsid = dict[@"wifiSsid"] ?: @"Viettel_Home_5G";
    p.city = dict[@"city"] ?: @"Hà Nội";
    p.contactsCount = [dict[@"contactsCount"] integerValue] ?: 28;
    p.chipName = dict[@"chipName"] ?: @"A10 Fusion";
    p.ramGB = [dict[@"ramGB"] integerValue] ?: 2;
    p.screenKey = dict[@"screenKey"] ?: @"375x667";
    p.activeProxy = dict[@"activeProxy"] ?: @"";
    p.writtenFilesCount = [dict[@"writtenFilesCount"] integerValue] ?: 7;
    p.successItemsCount = [dict[@"successItemsCount"] integerValue] ?: 10;
    return p;
}

@end

@implementation ChangeInfoDeviceDatabase

+ (NSArray<NSDictionary *> *)allDeviceSpecs {
    return @[
        @{@"name": @"iPhone 6s", @"machine": @"iPhone8,1", @"chip": @"A9", @"ram": @2, @"screen": @"375x667", @"tier": @0, @"ios": @[@"15.8.4", @"15.8.3", @"15.8.2"]},
        @{@"name": @"iPhone 6s Plus", @"machine": @"iPhone8,2", @"chip": @"A9", @"ram": @2, @"screen": @"414x736", @"tier": @0, @"ios": @[@"15.8.4", @"15.8.3", @"15.8.2"]},
        @{@"name": @"iPhone SE (1st Gen)", @"machine": @"iPhone8,4", @"chip": @"A9", @"ram": @2, @"screen": @"320x568", @"tier": @0, @"ios": @[@"15.8.4", @"15.8.3", @"15.8.2"]},
        @{@"name": @"iPhone 7", @"machine": @"iPhone9,3", @"chip": @"A10 Fusion", @"ram": @2, @"screen": @"375x667", @"tier": @0, @"ios": @[@"15.8.4", @"15.8.3", @"15.8.2"]},
        @{@"name": @"iPhone 7 Plus", @"machine": @"iPhone9,4", @"chip": @"A10 Fusion", @"ram": @3, @"screen": @"414x736", @"tier": @0, @"ios": @[@"15.8.4", @"15.8.3", @"15.8.2"]},
        @{@"name": @"iPhone 8", @"machine": @"iPhone10,1", @"chip": @"A11 Bionic", @"ram": @2, @"screen": @"375x667", @"tier": @0, @"ios": @[@"16.4.1", @"16.6.1", @"16.7.5", @"16.7.8"]},
        @{@"name": @"iPhone 8", @"machine": @"iPhone10,4", @"chip": @"A11 Bionic", @"ram": @2, @"screen": @"375x667", @"tier": @0, @"ios": @[@"16.4.1", @"16.6.1", @"16.7.5", @"16.7.8"]},
        @{@"name": @"iPhone 8 Plus", @"machine": @"iPhone10,2", @"chip": @"A11 Bionic", @"ram": @3, @"screen": @"414x736", @"tier": @0, @"ios": @[@"16.5.1", @"16.6.1", @"16.7.5", @"16.7.8"]},
        @{@"name": @"iPhone 8 Plus", @"machine": @"iPhone10,5", @"chip": @"A11 Bionic", @"ram": @3, @"screen": @"414x736", @"tier": @0, @"ios": @[@"16.5.1", @"16.6.1", @"16.7.5", @"16.7.8"]},
        @{@"name": @"iPhone X", @"machine": @"iPhone10,3", @"chip": @"A11 Bionic", @"ram": @3, @"screen": @"375x812", @"tier": @0, @"ios": @[@"16.5.1", @"16.6.1", @"16.7.5", @"16.7.8"]},
        @{@"name": @"iPhone X", @"machine": @"iPhone10,6", @"chip": @"A11 Bionic", @"ram": @3, @"screen": @"375x812", @"tier": @0, @"ios": @[@"16.5.1", @"16.6.1", @"16.7.5", @"16.7.8"]},
        @{@"name": @"iPhone XR", @"machine": @"iPhone11,8", @"chip": @"A12 Bionic", @"ram": @3, @"screen": @"414x896", @"tier": @0, @"ios": @[@"16.5.1", @"16.6.1", @"17.1.2", @"17.4.1"]},
        @{@"name": @"iPhone XS", @"machine": @"iPhone11,2", @"chip": @"A12 Bionic", @"ram": @4, @"screen": @"375x812", @"tier": @0, @"ios": @[@"16.6.1", @"17.1.2", @"17.4.1", @"17.6.1"]},
        @{@"name": @"iPhone XS Max", @"machine": @"iPhone11,6", @"chip": @"A12 Bionic", @"ram": @4, @"screen": @"414x896", @"tier": @0, @"ios": @[@"16.6.1", @"17.1.2", @"17.4.1", @"17.6.1"]},
        @{@"name": @"iPhone SE (2020)", @"machine": @"iPhone12,8", @"chip": @"A13 Bionic", @"ram": @3, @"screen": @"375x667", @"tier": @0, @"ios": @[@"16.6.1", @"17.1.2", @"17.4.1", @"17.6.1"]},
        @{@"name": @"iPhone 11", @"machine": @"iPhone12,1", @"chip": @"A13 Bionic", @"ram": @4, @"screen": @"414x896", @"tier": @0, @"ios": @[@"16.6.1", @"17.2.1", @"17.5.1", @"18.1.1"]},
        @{@"name": @"iPhone 11 Pro", @"machine": @"iPhone12,3", @"chip": @"A13 Bionic", @"ram": @4, @"screen": @"375x812", @"tier": @0, @"ios": @[@"16.6.1", @"17.2.1", @"17.5.1", @"18.1.1"]},
        @{@"name": @"iPhone 11 Pro Max", @"machine": @"iPhone12,5", @"chip": @"A13 Bionic", @"ram": @4, @"screen": @"414x896", @"tier": @0, @"ios": @[@"16.6.1", @"17.2.1", @"17.5.1", @"18.1.1"]},
        @{@"name": @"iPhone 12 mini", @"machine": @"iPhone13,1", @"chip": @"A14 Bionic", @"ram": @4, @"screen": @"375x812", @"tier": @0, @"ios": @[@"16.6.1", @"17.3.1", @"17.6.1", @"18.1.1"]},
        @{@"name": @"iPhone 12", @"machine": @"iPhone13,2", @"chip": @"A14 Bionic", @"ram": @4, @"screen": @"390x844", @"tier": @0, @"ios": @[@"16.6.1", @"17.3.1", @"17.6.1", @"18.1.1"]},
        @{@"name": @"iPhone 12 Pro", @"machine": @"iPhone13,3", @"chip": @"A14 Bionic", @"ram": @6, @"screen": @"390x844", @"tier": @0, @"ios": @[@"16.6.1", @"17.3.1", @"17.6.1", @"18.1.1"]},
        @{@"name": @"iPhone 12 Pro Max", @"machine": @"iPhone13,4", @"chip": @"A14 Bionic", @"ram": @6, @"screen": @"428x926", @"tier": @0, @"ios": @[@"16.6.1", @"17.3.1", @"17.6.1", @"18.1.1"]},
        @{@"name": @"iPhone 13 mini", @"machine": @"iPhone14,4", @"chip": @"A15 Bionic", @"ram": @4, @"screen": @"375x812", @"tier": @0, @"ios": @[@"16.6.1", @"17.4.1", @"17.6.1", @"18.2.1"]},
        @{@"name": @"iPhone 13", @"machine": @"iPhone14,5", @"chip": @"A15 Bionic", @"ram": @4, @"screen": @"390x844", @"tier": @0, @"ios": @[@"16.6.1", @"17.4.1", @"17.6.1", @"18.2.1"]},
        @{@"name": @"iPhone 13 Pro", @"machine": @"iPhone14,2", @"chip": @"A15 Bionic", @"ram": @6, @"screen": @"390x844", @"tier": @0, @"ios": @[@"16.6.1", @"17.4.1", @"17.6.1", @"18.2.1"]},
        @{@"name": @"iPhone 13 Pro Max", @"machine": @"iPhone14,3", @"chip": @"A15 Bionic", @"ram": @6, @"screen": @"428x926", @"tier": @0, @"ios": @[@"16.6.1", @"17.4.1", @"17.6.1", @"18.2.1"]},
        @{@"name": @"iPhone SE (2022)", @"machine": @"iPhone14,6", @"chip": @"A15 Bionic", @"ram": @4, @"screen": @"375x667", @"tier": @0, @"ios": @[@"16.6.1", @"17.2.1", @"17.5.1", @"18.1.1"]},
        @{@"name": @"iPhone 14", @"machine": @"iPhone14,7", @"chip": @"A15 Bionic", @"ram": @6, @"screen": @"390x844", @"tier": @1, @"ios": @[@"16.6.1", @"17.4.1", @"17.6.1", @"18.2.1"]},
        @{@"name": @"iPhone 14 Plus", @"machine": @"iPhone14,8", @"chip": @"A15 Bionic", @"ram": @6, @"screen": @"428x926", @"tier": @1, @"ios": @[@"16.6.1", @"17.4.1", @"17.6.1", @"18.2.1"]},
        @{@"name": @"iPhone 14 Pro", @"machine": @"iPhone15,2", @"chip": @"A16 Bionic", @"ram": @6, @"screen": @"393x852", @"tier": @1, @"ios": @[@"16.6.1", @"17.4.1", @"17.6.1", @"18.2.1"]},
        @{@"name": @"iPhone 14 Pro Max", @"machine": @"iPhone15,3", @"chip": @"A16 Bionic", @"ram": @6, @"screen": @"430x932", @"tier": @1, @"ios": @[@"16.6.1", @"17.4.1", @"17.6.1", @"18.2.1"]},
        @{@"name": @"iPhone 15", @"machine": @"iPhone15,4", @"chip": @"A16 Bionic", @"ram": @6, @"screen": @"393x852", @"tier": @1, @"ios": @[@"17.2.1", @"17.5.1", @"18.1.1", @"18.2.1"]},
        @{@"name": @"iPhone 15 Plus", @"machine": @"iPhone15,5", @"chip": @"A16 Bionic", @"ram": @6, @"screen": @"430x932", @"tier": @1, @"ios": @[@"17.2.1", @"17.5.1", @"18.1.1", @"18.2.1"]},
        @{@"name": @"iPhone 15 Pro", @"machine": @"iPhone16,1", @"chip": @"A17 Pro", @"ram": @8, @"screen": @"393x852", @"tier": @1, @"ios": @[@"17.2.1", @"17.5.1", @"18.1.1", @"18.3.1"]},
        @{@"name": @"iPhone 15 Pro Max", @"machine": @"iPhone16,2", @"chip": @"A17 Pro", @"ram": @8, @"screen": @"430x932", @"tier": @1, @"ios": @[@"17.2.1", @"17.5.1", @"18.1.1", @"18.3.1"]},
        @{@"name": @"iPhone 16e", @"machine": @"iPhone17,5", @"chip": @"A18", @"ram": @8, @"screen": @"390x844", @"tier": @2, @"ios": @[@"18.3", @"18.3.1", @"18.3.2"]},
        @{@"name": @"iPhone 16", @"machine": @"iPhone17,3", @"chip": @"A18", @"ram": @8, @"screen": @"393x852", @"tier": @2, @"ios": @[@"18.0.1", @"18.1.1", @"18.2.1", @"18.3.1"]},
        @{@"name": @"iPhone 16 Plus", @"machine": @"iPhone17,4", @"chip": @"A18", @"ram": @8, @"screen": @"430x932", @"tier": @2, @"ios": @[@"18.0.1", @"18.1.1", @"18.2.1", @"18.3.1"]},
        @{@"name": @"iPhone 16 Pro", @"machine": @"iPhone17,1", @"chip": @"A18 Pro", @"ram": @8, @"screen": @"402x874", @"tier": @2, @"ios": @[@"18.0.1", @"18.1.1", @"18.2.1", @"18.3.1"]},
        @{@"name": @"iPhone 16 Pro Max", @"machine": @"iPhone17,2", @"chip": @"A18 Pro", @"ram": @8, @"screen": @"440x956", @"tier": @2, @"ios": @[@"18.0.1", @"18.1.1", @"18.2.1", @"18.3.1"]}
    ];
}

+ (NSString *)realHardwareMachine {
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *machine = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    if (!machine || ![machine hasPrefix:@"iPhone"]) {
        return @"iPhone9,3";
    }
    return machine;
}

+ (NSString *)realScreenKey {
    CGSize size = [UIScreen mainScreen].bounds.size;
    NSInteger w = (NSInteger)MIN(size.width, size.height);
    NSInteger h = (NSInteger)MAX(size.width, size.height);
    return [NSString stringWithFormat:@"%ldx%ld", (long)w, (long)h];
}

+ (NSDictionary *)realDeviceSpecFallback {
    NSString *realMachine = [self realHardwareMachine];
    for (NSDictionary *spec in [self allDeviceSpecs]) {
        if ([spec[@"machine"] isEqualToString:realMachine]) {
            return spec;
        }
    }
    NSString *screenKey = [self realScreenKey];
    for (NSDictionary *spec in [self allDeviceSpecs]) {
        if ([spec[@"screen"] isEqualToString:screenKey]) {
            return spec;
        }
    }
    return [self allDeviceSpecs][3]; // iPhone 7
}

+ (ChangeInfoDeviceProfile *)loadOrCreateDefaultProfile {
    NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"ChangeInfoCurrentProfile"];
    if (saved) {
        ChangeInfoDeviceProfile *loaded = [ChangeInfoDeviceProfile fromDictionary:saved];
        if (loaded) {
            [self writeProfileFiles:loaded error:nil];
            return loaded;
        }
    }
    ChangeInfoDeviceProfile *initial = [[ChangeInfoDeviceProfile alloc] init];
    initial.identifier = @"7BD46FDA-D93D-45BD-9158-7178669502DD";
    initial.modelName = @"iPhone 7";
    initial.machineId = @"iPhone9,3";
    initial.iosVersion = @"15.8.4";
    initial.batteryPercent = 82;
    initial.carrier = @"Viettel";
    initial.wifiSsid = @"Viettel_Home_5G";
    initial.city = @"Hà Nội";
    initial.contactsCount = 28;
    initial.chipName = @"A10 Fusion";
    initial.ramGB = 2;
    initial.screenKey = @"375x667";
    initial.activeProxy = @"";
    initial.writtenFilesCount = 7;
    initial.successItemsCount = 10;
    [self writeProfileFiles:initial error:nil];
    return initial;
}

+ (ChangeInfoDeviceProfile *)generateProfileWithLockRealModel:(BOOL)lockModel
                                                   sameScreen:(BOOL)sameScreen
                                                    matchChip:(BOOL)matchChip
                                                    modelTier:(ChangeInfoModelTierFilter)modelTier
                                                  currentCity:(NSString *)currentCity {
    NSArray<NSDictionary *> *allSpecs = [self allDeviceSpecs];
    NSDictionary *realSpec = [self realDeviceSpecFallback];
    // NSString *realScreen = [self realScreenKey];
    NSDictionary *prevSaved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"ChangeInfoCurrentProfile"];
    NSString *prevMachine = prevSaved[@"machineId"];
    NSString *prevProxy = prevSaved[@"activeProxy"] ?: @"";

    NSMutableArray<NSDictionary *> *candidates = [NSMutableArray array];

    if (lockModel) {
        if (realSpec) [candidates addObject:realSpec];
    } else if (modelTier == ChangeInfoModelTierNativeCompatible) {
        // ⭐ Mode 0: Chuẩn iPhone 7/8/SE/X (A10/A11)
        for (NSDictionary *spec in allSpecs) {
            NSString *mach = spec[@"machine"];
            if ([mach isEqualToString:@"iPhone9,3"] ||
                [mach isEqualToString:@"iPhone9,1"] ||
                [mach isEqualToString:@"iPhone9,4"] ||
                [mach isEqualToString:@"iPhone9,2"] ||
                [mach isEqualToString:@"iPhone10,1"] ||
                [mach isEqualToString:@"iPhone10,4"] ||
                [mach isEqualToString:@"iPhone10,2"] ||
                [mach isEqualToString:@"iPhone10,5"] ||
                [mach isEqualToString:@"iPhone10,3"] ||
                [mach isEqualToString:@"iPhone10,6"] ||
                [mach isEqualToString:@"iPhone12,8"]) {
                [candidates addObject:spec];
            }
        }
    } else if (modelTier == ChangeInfoModelTierHighEnd) {
        for (NSDictionary *spec in allSpecs) {
            if ([spec[@"tier"] integerValue] >= 1) {
                [candidates addObject:spec];
            }
        }
    } else {
        candidates = [allSpecs mutableCopy];
    }

    if (candidates.count == 0) {
        candidates = [allSpecs mutableCopy];
    }

    if (!lockModel && prevMachine.length > 0) {
        NSMutableArray<NSDictionary *> *nonRepeat = [NSMutableArray array];
        for (NSDictionary *spec in candidates) {
            if (![spec[@"machine"] isEqualToString:prevMachine]) {
                [nonRepeat addObject:spec];
            }
        }
        if (nonRepeat.count > 0) {
            candidates = nonRepeat;
        }
    }

    if (candidates.count == 0) {
        candidates = [allSpecs mutableCopy];
    }

    NSDictionary *chosen = (candidates.count > 0) ? candidates[arc4random_uniform((uint32_t)candidates.count)] : (allSpecs.count > 0 ? allSpecs[0] : nil);
    if (!chosen) {
        chosen = @{
            @"name": @"iPhone X",
            @"machine": @"iPhone10,6",
            @"chip": @"A11 Bionic",
            @"ram": @3,
            @"screen": @"375x812",
            @"tier": @0,
            @"ios": @[@"16.7.8", @"16.7.5"]
        };
    }
    NSArray<NSString *> *iosList = chosen[@"ios"];
    NSString *chosenIOS = (iosList && iosList.count > 0) ? iosList[arc4random_uniform((uint32_t)iosList.count)] : @"16.7.8";

    NSArray<NSString *> *carriers = @[@"MobiFone", @"Viettel", @"Vinaphone", @"Vietnamobile"];
    NSString *carrier = carriers[arc4random_uniform((uint32_t)carriers.count)];

    NSArray<NSString *> *wifiPrefixes = @[@"Home", @"Office", @"Coffee", @"Wifi", @"Guest", @"Highlands", @"TheCoffeeHouse", @"5G_Plus"];
    NSString *wifi = [NSString stringWithFormat:@"%@_%03d", wifiPrefixes[arc4random_uniform((uint32_t)wifiPrefixes.count)], (int)(arc4random_uniform(900) + 100)];

    NSString *city = currentCity;
    if (!city || city.length == 0) {
        NSArray<NSString *> *cities = @[@"Hà Nội", @"Hồ Chí Minh", @"Đà Nẵng", @"Hải Phòng", @"Cần Thơ", @"Nha Trang", @"Biên Hòa", @"Bình Dương"];
        city = cities[arc4random_uniform((uint32_t)cities.count)];
    }

    NSInteger battery = 45 + arc4random_uniform(53); // 45% -> 97%
    NSInteger contacts = 18 + arc4random_uniform(45); // 18 -> 62

    ChangeInfoDeviceProfile *p = [[ChangeInfoDeviceProfile alloc] init];
    p.identifier = [[NSUUID UUID] UUIDString];
    p.modelName = chosen[@"name"];
    p.machineId = chosen[@"machine"];
    p.iosVersion = chosenIOS;
    p.batteryPercent = battery;
    p.carrier = carrier;
    p.wifiSsid = wifi;
    p.city = city;
    p.contactsCount = contacts;
    p.chipName = chosen[@"chip"];
    p.ramGB = [chosen[@"ram"] integerValue];
    p.screenKey = chosen[@"screen"];
    p.activeProxy = prevProxy ?: @"";

    return p;
}

+ (NSString *)storageDirectoryPath {
    NSString *base = @"/var/mobile/Library/Preferences/ZTechShared";
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb"]) {
        base = @"/var/jb/var/mobile/Library/Preferences/ZTechShared";
    }
    return base;
}

+ (BOOL)writeProfileFiles:(ChangeInfoDeviceProfile *)profile error:(NSError **)error {
    if (!profile) return NO;

    NSDictionary *dict = [profile toDictionary];
    [[NSUserDefaults standardUserDefaults] setObject:dict forKey:@"ChangeInfoCurrentProfile"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSInteger written = 0;

    // Build shared profile dict
    NSMutableDictionary *sharedDict = [NSMutableDictionary dictionary];
    sharedDict[@"identifier"] = profile.identifier ?: @"";
    sharedDict[@"modelName"] = profile.modelName ?: @"iPhone 7";
    sharedDict[@"machineId"] = profile.machineId ?: @"iPhone9,3";
    sharedDict[@"iosVersion"] = profile.iosVersion ?: @"15.8.4";
    sharedDict[@"batteryPercent"] = @(profile.batteryPercent);
    sharedDict[@"carrier"] = profile.carrier ?: @"Viettel";
    sharedDict[@"wifiSsid"] = profile.wifiSsid ?: @"Viettel_Home_5G";
    sharedDict[@"city"] = profile.city ?: @"Hà Nội";
    sharedDict[@"chipName"] = profile.chipName ?: @"A10 Fusion";
    sharedDict[@"ramGB"] = @(profile.ramGB);
    sharedDict[@"screenKey"] = profile.screenKey ?: @"375x667";
    sharedDict[@"activeProxy"] = profile.activeProxy ?: @"";

    // 1. Primary Preferences Paths
    NSArray<NSString *> *targetPaths = @[
        @"/var/jb/var/mobile/Library/Preferences/com.ztech.profile.plist",
        @"/var/mobile/Library/Preferences/com.ztech.profile.plist",
        @"/Library/Preferences/ZTechShared/com.ztech.profile.plist",
        @"/var/jb/Library/Preferences/ZTechShared/com.ztech.profile.plist",
        @"/var/tmp/com.ztech.profile.plist"
    ];

    for (NSString *tp in targetPaths) {
        NSString *dir = [tp stringByDeletingLastPathComponent];
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        chmod([dir UTF8String], 0777);
        if ([sharedDict writeToFile:tp atomically:YES]) {
            chmod([tp UTF8String], 0666);
            chown([tp UTF8String], 501, 501);
            written++;
        }
    }

    // 2. Also write active profile flag in Documents directory
    NSString *home = NSHomeDirectory();
    NSString *docs = [home stringByAppendingPathComponent:@"Documents"];
    [fm createDirectoryAtPath:docs withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *profInDocs = [docs stringByAppendingPathComponent:@"_zt_active_profile.plist"];
    if ([sharedDict writeToFile:profInDocs atomically:YES]) {
        chmod([profInDocs UTF8String], 0666);
        written++;
    }

    profile.writtenFilesCount = written;
    profile.successItemsCount = 10;
    return (written > 0);
}

+ (BOOL)verifyCurrentProfileAppliedSuccessfully:(ChangeInfoDeviceProfile *)profile
                                   isNewSession:(BOOL)isNewSession
                                          error:(NSError **)outError {
    if (!profile) return NO;
    NSArray<NSString *> *probePaths = @[
        @"/var/jb/var/mobile/Library/Preferences/com.ztech.profile.plist",
        @"/var/mobile/Library/Preferences/com.ztech.profile.plist",
        @"/var/tmp/com.ztech.profile.plist"
    ];

    for (NSString *p in probePaths) {
        NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:p];
        if (d && [d[@"machineId"] isEqualToString:profile.machineId]) {
            return YES;
        }
    }
    return NO;
}

+ (void)syncLocationByIPWithCompletion:(void (^)(NSString *city, NSString *isp, NSError *error))completion {
    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    cfg.timeoutIntervalForRequest = 6.0;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg];
    NSURL *url = [NSURL URLWithString:@"http://ip-api.com/json/?fields=status,city,regionName,isp"];

    [[session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
        if (err || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, nil, err);
            });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSString *city = json[@"city"] ?: json[@"regionName"];
        NSString *isp = json[@"isp"];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(city, isp, nil);
        });
    }] resume];
}

+ (void)performRespringIfPossible {
    // Priority 1: Darwin Notification directly to SpringBoard Tweak
    notify_post("com.ztech.changeinfo.respring");
    notify_post("com.ztech.respring");
    notify_post("com.gaulmt.respring");

    // Priority 2: Comprehensive rootless & rootful binary paths
    const char *paths[] = {
        "/var/jb/usr/bin/sbreload",
        "/usr/bin/sbreload",
        "/var/jb/bin/sbreload",
        "/var/jb/usr/bin/killall",
        "/usr/bin/killall",
        "/var/jb/bin/killall",
        "/bin/killall"
    };

    for (int i = 0; i < 3; i++) {
        if (access(paths[i], X_OK) == 0) {
            pid_t pid;
            char *argv[] = { (char *)paths[i], NULL };
            if (posix_spawn(&pid, paths[i], NULL, NULL, argv, environ) == 0) return;
        }
    }

    for (int i = 3; i < 7; i++) {
        if (access(paths[i], X_OK) == 0) {
            pid_t pid;
            char *argv[] = { (char *)paths[i], (char *)"-9", (char *)"SpringBoard", NULL };
            if (posix_spawn(&pid, paths[i], NULL, NULL, argv, environ) == 0) return;
        }
    }

    // Priority 3: Shell command execution fallback
    typedef int (*ci_system_t)(const char *);
    ci_system_t dyn_sys = (ci_system_t)dlsym(RTLD_DEFAULT, "system");
    if (dyn_sys) {
        dyn_sys("/var/jb/usr/bin/sbreload 2>/dev/null || /var/jb/usr/bin/killall -9 SpringBoard 2>/dev/null || killall -9 SpringBoard 2>/dev/null");
    }
}

+ (NSInteger)seedNaturalVietnameseContactsIfFew {
    return 0;
}

@end
