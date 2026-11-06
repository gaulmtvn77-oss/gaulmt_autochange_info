TARGET := iphone:clang:latest:14.0
ARCHS := arm64 arm64e

INSTALL_TARGET_PROCESSES = ChangeInfo

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = ChangeInfo
ChangeInfo_FILES = $(wildcard Sources/*.m)
ChangeInfo_FRAMEWORKS = UIKit Foundation CoreGraphics Security
ChangeInfo_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-error
ChangeInfo_CODESIGN_FLAGS = -Sentitlements.xml

TWEAK_NAME = ChangeInfoHook
ChangeInfoHook_FILES = Tweak/ChangeInfoHook.m
ChangeInfoHook_FRAMEWORKS = UIKit Foundation Security CFNetwork WebKit
ChangeInfoHook_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-error
ChangeInfoHook_USE_SUBSTRATE = 0

include $(THEOS_MAKE_PATH)/application.mk
include $(THEOS_MAKE_PATH)/tweak.mk
