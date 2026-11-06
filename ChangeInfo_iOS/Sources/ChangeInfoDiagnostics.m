#import "ChangeInfoDiagnostics.h"
#import "ChangeInfoDeviceDatabase.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <sys/stat.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>

@implementation ChangeInfoDiagnostics

static NSString *ChangeInfoFormatFilePerms(NSString *path, NSFileManager *fm) {
    if (!path || path.length == 0 || ![fm fileExistsAtPath:path]) {
        return @"[Không tồn tại]";
    }
    NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
    if (!attrs) return @"[Tồn tại - không đọc được thuộc tính]";
    NSNumber *posix = attrs[NSFilePosixPermissions];
    NSNumber *owner = attrs[NSFileOwnerAccountID];
    NSNumber *group = attrs[NSFileGroupOwnerAccountID];
    unsigned long long size = [attrs[NSFileSize] unsignedLongLongValue];
    NSString *sizeStr = (size > 1048576) ? [NSString stringWithFormat:@"%.1f MB", (double)size / 1048576.0]
                      : (size > 1024)    ? [NSString stringWithFormat:@"%.1f KB", (double)size / 1024.0]
                      : [NSString stringWithFormat:@"%llu B", size];
    return [NSString stringWithFormat:@"Tồn tại (%@, 0%o, %d:%d)",
            sizeStr,
            posix ? [posix unsignedShortValue] : 0,
            owner ? [owner intValue] : -1,
            group ? [group intValue] : -1];
}

+ (NSString *)generateFullSystemDiagnosticReport {
    NSMutableString *outStr = [NSMutableString string];
    NSFileManager *fm = [NSFileManager defaultManager];

    [outStr appendString:@"========================================================
"];
    [outStr appendString:@"       🔍 CHANGE INFO BÁO CÁO CHẨN ĐOÁN THIẾT BỊ
"];
    [outStr appendString:@"========================================================

"];

    // 1. THIẾT BỊ GỐC (KERNEL & HARDWARE)
    [outStr appendString:@"1. THÔNG SỐ THIẾT BỊ GỐC (KERNEL & SYSTEM):
"];
    struct utsname uts;
    if (uname(&uts) == 0) {
        [outStr appendFormat:@"- uts.machine: %s
", uts.machine];
        [outStr appendFormat:@"- uts.nodename: %s
", uts.nodename];
        [outStr appendFormat:@"- uts.release: %s
", uts.release];
        [outStr appendFormat:@"- uts.version: %s
", uts.version];
    }

    char sysMachine[64] = {0};
    size_t sLen = sizeof(sysMachine);
    if (sysctlbyname("hw.machine", sysMachine, &sLen, NULL, 0) == 0) {
        [outStr appendFormat:@"- sysctlbyname(hw.machine): %s
", sysMachine];
    }
    char sysModel[64] = {0};
    sLen = sizeof(sysModel);
    if (sysctlbyname("hw.model", sysModel, &sLen, NULL, 0) == 0) {
        [outStr appendFormat:@"- sysctlbyname(hw.model): %s
", sysModel];
    }

    uint64_t memBytes = 0;
    size_t mLen = sizeof(memBytes);
    if (sysctlbyname("hw.memsize", &memBytes, &mLen, NULL, 0) == 0) {
        [outStr appendFormat:@"- RAM phát hiện: %.2f GB (%llu bytes)
", (double)memBytes / (1024.0 * 1024.0 * 1024.0), memBytes];
    }

    int ncpu = 0;
    size_t cLen = sizeof(ncpu);
    if (sysctlbyname("hw.ncpu", &ncpu, &cLen, NULL, 0) == 0) {
        [outStr appendFormat:@"- Số Core CPU: %d cores
", ncpu];
    }

    UIDevice *curDev = [UIDevice currentDevice];
    [outStr appendFormat:@"- UIDevice model: %@
", curDev.model];
    [outStr appendFormat:@"- UIDevice name: %@
", curDev.name];
    [outStr appendFormat:@"- UIDevice systemVersion: %@
", curDev.systemVersion];
    [outStr appendFormat:@"- NSProcessInfo OS: %@

", [[NSProcessInfo processInfo] operatingSystemVersionString]];

    // 2. MÔI TRƯỜNG JAILBREAK & ROOTLESS
    [outStr appendString:@"2. MÔI TRƯỜNG JAILBREAK & TWEAK INJECTION:
"];
    BOOL isRootless = [fm fileExistsAtPath:@"/var/jb"];
    [outStr appendFormat:@"- Môi trường: %@
", isRootless ? @"Rootless (/var/jb phát hiện)" : @"Rootful / Tiêu chuẩn"];

    NSArray<NSString *> *tweakPaths = @[
        @"/var/jb/usr/lib/TweakInject/ChangeInfoHook.dylib",
        @"/var/jb/Library/MobileSubstrate/DynamicLibraries/ChangeInfoHook.dylib",
        @"/Library/MobileSubstrate/DynamicLibraries/ChangeInfoHook.dylib",
        @"/usr/lib/TweakInject/ChangeInfoHook.dylib",
        @"/var/jb/usr/lib/TweakInject/ZTechHook.dylib",
        @"/Library/MobileSubstrate/DynamicLibraries/ZTechHook.dylib"
    ];
    for (NSString *tp in tweakPaths) {
        if ([fm fileExistsAtPath:tp]) {
            [outStr appendFormat:@"- Dylib Hook: %@ -> %@
", tp, ChangeInfoFormatFilePerms(tp, fm)];
        }
    }

    // 3. PROFILE SPOOF HIỆN HÀNH
    [outStr appendString:@"
3. PROFILE FAKE ĐANG LƯU TRÊN Ổ CỨNG:
"];
    NSArray<NSString *> *profilePaths = @[
        @"/var/jb/var/mobile/Library/Preferences/com.ztech.profile.plist",
        @"/var/mobile/Library/Preferences/com.ztech.profile.plist",
        @"/Library/Preferences/ZTechShared/com.ztech.profile.plist",
        @"/var/tmp/com.ztech.profile.plist"
    ];
    for (NSString *pp in profilePaths) {
        [outStr appendFormat:@"- %@:
  -> %@
", pp, ChangeInfoFormatFilePerms(pp, fm)];
        if ([fm fileExistsAtPath:pp]) {
            NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:pp];
            if (d) {
                [outStr appendFormat:@"     Model: %@ (%@) | iOS %@ | UUID: %@ | Proxy: %@
",
                 d[@"modelName"], d[@"machineId"], d[@"iosVersion"], d[@"identifier"],
                 (d[@"activeProxy"] && [d[@"activeProxy"] length] > 0) ? d[@"activeProxy"] : @"None"];
            }
        }
    }

    [outStr appendString:@"
========================================================
"];
    [outStr appendString:@"             KẾT THÚC BÁO CÁO CHẨN ĐOÁN
"];
    [outStr appendString:@"========================================================
"];

    return outStr;
}

@end
