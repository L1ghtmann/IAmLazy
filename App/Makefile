INSTALL_TARGET_PROCESSES = IAmLazy

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = IAmLazy

IAmLazy_FILES = ../Task.c $(wildcard ../Shared/**/*.m ../Shared/**/*.c) $(wildcard *.m **/*.m)
IAmLazy_FRAMEWORKS = UIKit
IAmLazy_LIBRARIES = archive
IAmLazy_CFLAGS = -fobjc-arc
IAmLazy_CODESIGN_FLAGS = -Sentitlements.plist
IAmLazy_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/application.mk

before-package::
	@mv $(wildcard $(THEOS_STAGING_DIR)/Applications/IAmLazy.app/Strings/*.lproj) "$(THEOS_STAGING_DIR)/Applications/IAmLazy.app/"
	@rm -r "$(THEOS_STAGING_DIR)/Applications/IAmLazy.app/Strings/"
