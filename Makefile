export ARCHS = arm64
export TARGET = iphone:clang:latest:13.0

INSTALL_TARGET_PROCESSES = IAmLazy

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = IAmLazy

IAmLazy_FILES = Task.c $(wildcard *.m) $(filter-out $(wildcard AndSoAreYou/*.m), $(wildcard **/*.m))
IAmLazy_FRAMEWORKS = UIKit
IAmLazy_LIBRARIES = archive
IAmLazy_CFLAGS = -fobjc-arc -Wno-unguarded-availability-new # since can't use @available on Linux
IAmLazy_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

SUBPROJECTS += AndSoAreYou

include $(THEOS_MAKE_PATH)/aggregate.mk

before-package::
	$(ECHO_NOTHING)mv $(wildcard $(THEOS_STAGING_DIR)/Applications/IAmLazy.app/Strings/*.lproj) "$(THEOS_STAGING_DIR)/Applications/IAmLazy.app/"$(ECHO_END)
	$(ECHO_NOTHING)rm -r "$(THEOS_STAGING_DIR)/Applications/IAmLazy.app/Strings/"$(ECHO_END)