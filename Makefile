export DEBUG = 0
export ARCHS = arm64 arm64e

INSTALL_TARGET_PROCESSES = Preferences

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = IAmLazy

IAmLazy_FILES = IAmLazyManager.m IAmLazyPrefsCell.m IAmLazyRootListController.m IAmLazyViewController.m
IAmLazy_FRAMEWORKS = UIKit
IAmLazy_PRIVATE_FRAMEWORKS = Preferences
IAmLazy_INSTALL_PATH = /Library/PreferenceBundles
IAmLazy_CFLAGS = -fobjc-arc 

include $(THEOS_MAKE_PATH)/bundle.mk

SUBPROJECTS += AndSoAreYou

include $(THEOS_MAKE_PATH)/aggregate.mk
