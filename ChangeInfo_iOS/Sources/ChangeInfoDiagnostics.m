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

    [outStr appendString:@"========================================================\n"];
    [outStr appendString:@"       🔍 CHANGE INFO BÁO CÁO CHẨN ĐOÁN THIẾT BỊ\n"];
    [outStr appendString:@"========================================================\n\n"];

    // 1. THIẾT BỊ GỐC (KERNEL & HARDWARE)
    [outStr appendString:@"1. THÔNG SỐ THIẾT BỊ GỐC (KERNEL & SYSTEM):\n"];
    struct utsname uts;
    if (uname(&uts) == 0) {
        [outStr appendFormat:@"- uts.machine: %s\n", uts.machine];
        [outStr appendFormat:@"- uts.nodename: %s\n", uts.nodename];
        [outStr appendFormat:@"- uts.release: %s\n", uts.release];
        [outStr appendFormat:@"- uts.version: %s\n", uts.version];
    }

    char sysMachine[64] = {0};
    size_t sLen = sizeof(sysMachine);
    if (sysctlbyname("hw.machine", sysMachine, &sLen, NULL, 0) == 0) {
        [outStr appendFormat:@"- sysctlbyname(hw.machine): %s\n", sysMachine];
    }
    char sysModel[64] = {0};
    sLen = sizeof(sysModel);
    if (sysctlbyname("hw.model", sysModel, &sLen, NULL, 0) == 0) {
        [outStr appendFormat:@"- sysctlbyname(hw.model): %s\n", sysModel];
    }

    uint64_t memBytes = 0;
    size_t mLen = sizeof(memBytes);
    if (sysctlbyname("hw.memsize", &memBytes, &mLen, NULL, 0) == 0) {
        [outStr appendFormat:@"- RAM phát hiện: %.2f GB (%llu bytes)\n", (double)memBytes / (1024.0 * 1024.0 * 1024.0), memBytes];
    }

    int ncpu = 0;
    size_t cLen = sizeof(ncpu);
    if (sysctlbyname("hw.ncpu", &ncpu, &cLen, NULL, 0) == 0) {
        [outStr appendFormat:@"- Số Core CPU: %d cores\n", ncpu];
    }

    UIDevice *curDev = [UIDevice currentDevice];
    [outStr appendFormat:@"- UIDevice model: %@\n", curDev.model];
    [outStr appendFormat:@"- UIDevice name: %@\n", curDev.name];
    [outStr appendFormat:@"- UIDevice systemVersion: %@\n", curDev.systemVersion];
    [outStr appendFormat:@"- NSProcessInfo OS: %@\n\n", [[NSProcessInfo processInfo] operatingSystemVersionString]];

    // 2. MÔI TRƯỜNG JAILBREAK & ROOTLESS
    [outStr appendString:@"2. MÔI TRƯỜNG JAILBREAK & TWEAK INJECTION:\n"];
    BOOL isRootless = [fm fileExistsAtPath:@"/var/jb"];
    [outStr appendFormat:@"- Môi trường: %@\n", isRootless ? @"Rootless (/var/jb phát hiện)" : @"Rootful / Tiêu chuẩn"];

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
            [outStr appendFormat:@"- Dylib Hook: %@ -> %@\n", tp, ChangeInfoFormatFilePerms(tp, fm)];
        }
    }

    // 3. PROFILE SPOOF HIỆN HÀNH
    [outStr appendString:@"\n3. PROFILE FAKE ĐANG LƯU TRÊN Ổ CỨNG:\n"];
    NSArray<NSString *> *profilePaths = @[
        @"/var/jb/var/mobile/Library/Preferences/com.ztech.profile.plist",
        @"/var/mobile/Library/Preferences/com.ztech.profile.plist",
        @"/Library/Preferences/ZTechShared/com.ztech.profile.plist",
        @"/var/tmp/com.ztech.profile.plist"
    ];
    for (NSString *pp in profilePaths) {
        [outStr appendFormat:@"- %@:\n  -> %@\n", pp, ChangeInfoFormatFilePerms(pp, fm)];
        if ([fm fileExistsAtPath:pp]) {
            NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:pp];
            if (d) {
                [outStr appendFormat:@"     Model: %@ (%@) | iOS %@ | UUID: %@ | Proxy: %@\n",
                 d[@"modelName"], d[@"machineId"], d[@"iosVersion"], d[@"identifier"],
                 (d[@"activeProxy"] && [d[@"activeProxy"] length] > 0) ? d[@"activeProxy"] : @"None"];
            }
        }
    }

    [outStr appendString:@"\n========================================================\n"];
    [outStr appendString:@"             KẾT THÚC BÁO CÁO CHẨN ĐOÁN\n"];
    [outStr appendString:@"========================================================\n"];

    return outStr;
}

@end
