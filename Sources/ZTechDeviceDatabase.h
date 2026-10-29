#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, ZTechModelTierFilter) {
    ZTechModelTierNativeCompatible = 0, // ⭐ Chuẩn iPhone 7/8/SE (A10-A11) - Khớp 100% phần cứng thật
    ZTechModelTierAll = 1,              // Tất cả các đời (iPhone 6s -> 16 Pro Max)
    ZTechModelTierHighEnd = 2           // Chỉ đời cao (iPhone 14 -> 16 Pro Max)
};

@interface ZTechDeviceProfile : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *modelName;
@property (nonatomic, copy) NSString *machineId;
@property (nonatomic, copy) NSString *iosVersion;
@property (nonatomic, assign) NSInteger batteryPercent;
@property (nonatomic, copy) NSString *carrier;
@property (nonatomic, copy) NSString *wifiSsid;
@property (nonatomic, copy) NSString *city;
@property (nonatomic, assign) NSInteger contactsCount;
@property (nonatomic, copy) NSString *chipName;
@property (nonatomic, assign) NSInteger ramGB;
@property (nonatomic, copy) NSString *screenKey;
@property (nonatomic, copy) NSString *activeProxy;
@property (nonatomic, assign) NSInteger writtenFilesCount;
@property (nonatomic, assign) NSInteger successItemsCount;

- (NSString *)summaryLine1;
- (NSString *)summaryLine2;
- (NSString *)fullReportTextWithFlags:(BOOL)lockModel
                          respringAfter:(BOOL)respring
                             sameScreen:(BOOL)sameScreen
                              matchChip:(BOOL)matchChip;
- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;

@end

@interface ZTechDeviceDatabase : NSObject

+ (ZTechDeviceProfile *)loadOrCreateDefaultProfile;
+ (ZTechDeviceProfile *)generateProfileWithLockRealModel:(BOOL)lockModel
                                              sameScreen:(BOOL)sameScreen
                                               matchChip:(BOOL)matchChip
                                               modelTier:(ZTechModelTierFilter)modelTier
                                             currentCity:(NSString *)currentCity;
+ (BOOL)writeProfileFiles:(ZTechDeviceProfile *)profile error:(NSError **)error;
+ (BOOL)verifyCurrentProfileAppliedSuccessfully:(ZTechDeviceProfile *)profile
                                   isNewSession:(BOOL)isNewSession
                                          error:(NSError **)outError;
+ (NSInteger)cleanResetAllProfileDataAndCache;
+ (NSInteger)cleanResetContainerContentsForRestore;
+ (void)repairContainerStructureAtPath:(NSString *)containerPath fileManager:(NSFileManager *)fm;
+ (void)syncLocationByIPWithCompletion:(void (^)(NSString *city, NSString *isp, NSError *error))completion;
+ (void)performRespringIfPossible;

@end
