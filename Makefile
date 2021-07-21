export DEBUG = 0
export ARCHS = arm64 arm64e
export TARGET = iphone:clang:latest:13.0

INSTALL_TARGET_PROCESSES = IAmLazy

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = IAmLazy

IAmLazy_FILES = $(wildcard *.m)
IAmLazy_FRAMEWORKS = UIKit CoreGraphics
IAmLazy_CFLAGS = -fobjc-arc
IAmLazy_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

SUBPROJECTS += AndSoAreYou

include $(THEOS_MAKE_PATH)/aggregate.mk
