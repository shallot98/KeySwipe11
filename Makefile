TARGET := iphone:clang:16.5:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = KeySwipe

KeySwipe_FILES = Tweak.xm
KeySwipe_FRAMEWORKS = UIKit CoreGraphics
KeySwipe_CFLAGS = -fobjc-arc
KeySwipe_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/tweak.mk
