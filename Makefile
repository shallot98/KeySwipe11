TARGET := iphone:clang:latest:12.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = KeySwipe11

KeySwipe11_FILES = Tweak.xm
KeySwipe11_FRAMEWORKS = UIKit Foundation CoreGraphics
KeySwipe11_CFLAGS = -fobjc-arc
KeySwipe11_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/tweak.mk
