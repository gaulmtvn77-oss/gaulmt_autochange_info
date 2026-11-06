#import "ChangeInfoVectorIcons.h"

@implementation ChangeInfoVectorIcons

+ (UIImage *)iconWithType:(ChangeInfoCustomIconType)type
                     size:(CGFloat)ptSize
                    color:(UIColor *)primaryColor {
    if (ptSize <= 0) ptSize = 24.0;
    if (!primaryColor) primaryColor = [UIColor whiteColor];

    CGSize size = CGSizeMake(ptSize, ptSize);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return [[UIImage alloc] init];

    CGContextSetStrokeColorWithColor(ctx, primaryColor.CGColor);
    CGContextSetFillColorWithColor(ctx, primaryColor.CGColor);
    CGContextSetLineWidth(ctx, MAX(1.5, ptSize * 0.075));
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);

    CGFloat w = ptSize;
    CGFloat h = ptSize;

    switch (type) {
        case ChangeInfoIconBrandCrest: {
            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, w * 0.5, h * 0.08);
            CGContextAddLineToPoint(ctx, w * 0.88, h * 0.22);
            CGContextAddLineToPoint(ctx, w * 0.88, h * 0.55);
            CGContextAddQuadCurveToPoint(ctx, w * 0.5, h * 0.92, w * 0.5, h * 0.92);
            CGContextAddQuadCurveToPoint(ctx, w * 0.12, h * 0.55, w * 0.12, h * 0.55);
            CGContextAddLineToPoint(ctx, w * 0.12, h * 0.22);
            CGContextClosePath(ctx);
            CGContextStrokePath(ctx);

            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, w * 0.32, h * 0.50);
            CGContextAddLineToPoint(ctx, w * 0.45, h * 0.64);
            CGContextAddLineToPoint(ctx, w * 0.70, h * 0.36);
            CGContextStrokePath(ctx);
            break;
        }
        case ChangeInfoIconTabSpoof:
        case ChangeInfoIconDevicePhone: {
            CGFloat insetW = w * 0.22;
            CGFloat insetH = h * 0.10;
            CGRect phoneRect = CGRectMake(insetW, insetH, w - (insetW * 2), h - (insetH * 2));
            UIBezierPath *bp = [UIBezierPath bezierPathWithRoundedRect:phoneRect cornerRadius:ptSize * 0.14];
            CGContextAddPath(ctx, bp.CGPath);
            CGContextStrokePath(ctx);

            // Screen notch/island & home bar
            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, w * 0.42, h * 0.16);
            CGContextAddLineToPoint(ctx, w * 0.58, h * 0.16);
            CGContextStrokePath(ctx);

            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, w * 0.40, h * 0.84);
            CGContextAddLineToPoint(ctx, w * 0.60, h * 0.84);
            CGContextStrokePath(ctx);
            break;
        }
        case ChangeInfoIconTabLicense:
        case ChangeInfoIconKeyVip: {
            CGFloat cx = w * 0.40;
            CGFloat cy = h * 0.40;
            CGFloat r = ptSize * 0.24;
            CGContextStrokeEllipseInRect(ctx, CGRectMake(cx - r, cy - r, r * 2, r * 2));

            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, cx + (r * 0.707), cy + (r * 0.707));
            CGContextAddLineToPoint(ctx, w * 0.85, h * 0.85);
            CGContextStrokePath(ctx);

            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, w * 0.75, h * 0.75);
            CGContextAddLineToPoint(ctx, w * 0.84, h * 0.66);
            CGContextStrokePath(ctx);
            break;
        }
        case ChangeInfoIconChipCpu: {
            CGRect r = CGRectMake(w * 0.22, h * 0.22, w * 0.56, h * 0.56);
            UIBezierPath *bp = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:ptSize * 0.08];
            CGContextAddPath(ctx, bp.CGPath);
            CGContextStrokePath(ctx);

            CGFloat pins[4] = {0.33, 0.44, 0.56, 0.67};
            for (int i = 0; i < 4; i++) {
                CGFloat pos = pins[i];
                CGContextMoveToPoint(ctx, w * pos, h * 0.08);
                CGContextAddLineToPoint(ctx, w * pos, h * 0.22);
                CGContextMoveToPoint(ctx, w * pos, h * 0.78);
                CGContextAddLineToPoint(ctx, w * pos, h * 0.92);
                CGContextMoveToPoint(ctx, w * 0.08, h * pos);
                CGContextAddLineToPoint(ctx, w * 0.22, h * pos);
                CGContextMoveToPoint(ctx, w * 0.78, h * pos);
                CGContextAddLineToPoint(ctx, w * 0.92, h * pos);
            }
            CGContextStrokePath(ctx);
            break;
        }
        case ChangeInfoIconDisplayScreen: {
            CGRect r = CGRectMake(w * 0.12, h * 0.16, w * 0.76, h * 0.52);
            UIBezierPath *bp = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:ptSize * 0.08];
            CGContextAddPath(ctx, bp.CGPath);
            CGContextStrokePath(ctx);

            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, w * 0.50, h * 0.68);
            CGContextAddLineToPoint(ctx, w * 0.50, h * 0.84);
            CGContextMoveToPoint(ctx, w * 0.35, h * 0.84);
            CGContextAddLineToPoint(ctx, w * 0.65, h * 0.84);
            CGContextStrokePath(ctx);
            break;
        }
        case ChangeInfoIconSignalRadar: {
            CGFloat baseY = h * 0.84;
            CGFloat barW = w * 0.12;
            CGFloat heights[4] = {0.25, 0.45, 0.65, 0.85};
            for (int i = 0; i < 4; i++) {
                CGFloat x = w * (0.16 + (i * 0.20));
                CGFloat barH = h * heights[i];
                CGRect br = CGRectMake(x, baseY - barH, barW, barH);
                UIBezierPath *bp = [UIBezierPath bezierPathWithRoundedRect:br cornerRadius:2.0];
                CGContextAddPath(ctx, bp.CGPath);
                CGContextFillPath(ctx);
            }
            break;
        }
        case ChangeInfoIconBatteryBolt: {
            CGRect r = CGRectMake(w * 0.12, h * 0.25, w * 0.68, h * 0.50);
            UIBezierPath *bp = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:ptSize * 0.08];
            CGContextAddPath(ctx, bp.CGPath);
            CGContextStrokePath(ctx);

            CGContextFillRect(ctx, CGRectMake(w * 0.82, h * 0.40, w * 0.07, h * 0.20));

            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, w * 0.48, h * 0.32);
            CGContextAddLineToPoint(ctx, w * 0.34, h * 0.52);
            CGContextAddLineToPoint(ctx, w * 0.46, h * 0.52);
            CGContextAddLineToPoint(ctx, w * 0.42, h * 0.68);
            CGContextAddLineToPoint(ctx, w * 0.58, h * 0.46);
            CGContextAddLineToPoint(ctx, w * 0.46, h * 0.46);
            CGContextClosePath(ctx);
            CGContextFillPath(ctx);
            break;
        }
        case ChangeInfoIconRefreshMorph: {
            CGFloat cx = w * 0.5;
            CGFloat cy = h * 0.5;
            CGFloat r = ptSize * 0.35;
            CGContextAddArc(ctx, cx, cy, r, -M_PI_4, M_PI * 1.3, 0);
            CGContextStrokePath(ctx);

            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, w * 0.85, h * 0.25);
            CGContextAddLineToPoint(ctx, w * 0.85, h * 0.45);
            CGContextAddLineToPoint(ctx, w * 0.65, h * 0.45);
            CGContextStrokePath(ctx);
            break;
        }
        case ChangeInfoIconLocationPin: {
            CGFloat cx = w * 0.5;
            CGFloat cy = h * 0.35;
            CGFloat r = ptSize * 0.25;
            CGContextAddArc(ctx, cx, cy, r, M_PI, 0, 1);
            CGContextAddLineToPoint(ctx, cx, h * 0.88);
            CGContextClosePath(ctx);
            CGContextStrokePath(ctx);

            CGContextStrokeEllipseInRect(ctx, CGRectMake(cx - (r * 0.4), cy - (r * 0.4), r * 0.8, r * 0.8));
            break;
        }
        case ChangeInfoIconRocketLaunch: {
            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, w * 0.50, h * 0.10);
            CGContextAddQuadCurveToPoint(ctx, w * 0.80, h * 0.50, w * 0.75, h * 0.70);
            CGContextAddLineToPoint(ctx, w * 0.25, h * 0.70);
            CGContextAddQuadCurveToPoint(ctx, w * 0.20, h * 0.50, w * 0.50, h * 0.10);
            CGContextClosePath(ctx);
            CGContextStrokePath(ctx);

            CGContextStrokeEllipseInRect(ctx, CGRectMake(w * 0.42, h * 0.32, w * 0.16, h * 0.16));
            break;
        }
        case ChangeInfoIconProxyNodes: {
            CGFloat r = ptSize * 0.12;
            CGContextStrokeEllipseInRect(ctx, CGRectMake(w * 0.20 - r, h * 0.30 - r, r * 2, r * 2));
            CGContextStrokeEllipseInRect(ctx, CGRectMake(w * 0.80 - r, h * 0.30 - r, r * 2, r * 2));
            CGContextStrokeEllipseInRect(ctx, CGRectMake(w * 0.50 - r, h * 0.75 - r, r * 2, r * 2));

            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, w * 0.28, h * 0.35);
            CGContextAddLineToPoint(ctx, w * 0.44, h * 0.68);
            CGContextMoveToPoint(ctx, w * 0.72, h * 0.35);
            CGContextAddLineToPoint(ctx, w * 0.56, h * 0.68);
            CGContextStrokePath(ctx);
            break;
        }
        case ChangeInfoIconSlidersTune: {
            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, w * 0.10, h * 0.30);
            CGContextAddLineToPoint(ctx, w * 0.90, h * 0.30);
            CGContextMoveToPoint(ctx, w * 0.10, h * 0.70);
            CGContextAddLineToPoint(ctx, w * 0.90, h * 0.70);
            CGContextStrokePath(ctx);

            CGContextFillEllipseInRect(ctx, CGRectMake(w * 0.30 - 3, h * 0.30 - 5, 6, 10));
            CGContextFillEllipseInRect(ctx, CGRectMake(w * 0.70 - 3, h * 0.70 - 5, 6, 10));
            break;
        }
        case ChangeInfoIconCopyClone: {
            CGRect r1 = CGRectMake(w * 0.12, h * 0.12, w * 0.56, h * 0.56);
            CGRect r2 = CGRectMake(w * 0.32, h * 0.32, w * 0.56, h * 0.56);
            UIBezierPath *bp1 = [UIBezierPath bezierPathWithRoundedRect:r1 cornerRadius:3.0];
            UIBezierPath *bp2 = [UIBezierPath bezierPathWithRoundedRect:r2 cornerRadius:3.0];
            CGContextAddPath(ctx, bp1.CGPath);
            CGContextStrokePath(ctx);
            CGContextAddPath(ctx, bp2.CGPath);
            CGContextStrokePath(ctx);
            break;
        }
        case ChangeInfoIconClipboardPaste: {
            CGRect r = CGRectMake(w * 0.18, h * 0.22, w * 0.64, h * 0.68);
            UIBezierPath *bp = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:4.0];
            CGContextAddPath(ctx, bp.CGPath);
            CGContextStrokePath(ctx);

            CGRect clip = CGRectMake(w * 0.35, h * 0.10, w * 0.30, h * 0.20);
            UIBezierPath *cp = [UIBezierPath bezierPathWithRoundedRect:clip cornerRadius:2.0];
            CGContextAddPath(ctx, cp.CGPath);
            CGContextStrokePath(ctx);
            break;
        }
        case ChangeInfoIconShieldCheck: {
            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, w * 0.50, h * 0.10);
            CGContextAddLineToPoint(ctx, w * 0.85, h * 0.22);
            CGContextAddLineToPoint(ctx, w * 0.85, h * 0.52);
            CGContextAddQuadCurveToPoint(ctx, w * 0.50, h * 0.90, w * 0.50, h * 0.90);
            CGContextAddQuadCurveToPoint(ctx, w * 0.15, h * 0.52, w * 0.15, h * 0.52);
            CGContextAddLineToPoint(ctx, w * 0.15, h * 0.22);
            CGContextClosePath(ctx);
            CGContextStrokePath(ctx);

            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, w * 0.34, h * 0.48);
            CGContextAddLineToPoint(ctx, w * 0.46, h * 0.60);
            CGContextAddLineToPoint(ctx, w * 0.68, h * 0.36);
            CGContextStrokePath(ctx);
            break;
        }
        case ChangeInfoIconShieldLock: {
            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, w * 0.50, h * 0.10);
            CGContextAddLineToPoint(ctx, w * 0.85, h * 0.22);
            CGContextAddLineToPoint(ctx, w * 0.85, h * 0.52);
            CGContextAddQuadCurveToPoint(ctx, w * 0.50, h * 0.90, w * 0.50, h * 0.90);
            CGContextAddQuadCurveToPoint(ctx, w * 0.15, h * 0.52, w * 0.15, h * 0.52);
            CGContextAddLineToPoint(ctx, w * 0.15, h * 0.22);
            CGContextClosePath(ctx);
            CGContextStrokePath(ctx);

            CGRect lk = CGRectMake(w * 0.36, h * 0.45, w * 0.28, h * 0.24);
            UIBezierPath *lp = [UIBezierPath bezierPathWithRoundedRect:lk cornerRadius:2.0];
            CGContextAddPath(ctx, lp.CGPath);
            CGContextStrokePath(ctx);
            break;
        }
        case ChangeInfoIconCheckmark: {
            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, w * 0.20, h * 0.52);
            CGContextAddLineToPoint(ctx, w * 0.42, h * 0.74);
            CGContextAddLineToPoint(ctx, w * 0.82, h * 0.26);
            CGContextStrokePath(ctx);
            break;
        }
        case ChangeInfoIconInfoDiag: {
            CGContextStrokeEllipseInRect(ctx, CGRectMake(w * 0.10, h * 0.10, w * 0.80, h * 0.80));
            CGContextFillEllipseInRect(ctx, CGRectMake(w * 0.46, h * 0.26, w * 0.08, h * 0.08));
            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, w * 0.50, h * 0.44);
            CGContextAddLineToPoint(ctx, w * 0.50, h * 0.74);
            CGContextStrokePath(ctx);
            break;
        }
        default: {
            CGContextStrokeEllipseInRect(ctx, CGRectMake(w * 0.15, h * 0.15, w * 0.70, h * 0.70));
            break;
        }
    }

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img ?: [[UIImage alloc] init];
}

+ (UIImage *)brandCrestLogoWithSize:(CGFloat)ptSize {
    UIColor *gold = [UIColor colorWithRed:0.96 green:0.62 blue:0.04 alpha:1.0];
    return [self iconWithType:ChangeInfoIconBrandCrest size:ptSize color:gold];
}

@end
