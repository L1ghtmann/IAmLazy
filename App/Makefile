INSTALL_TARGET_PROCESSES = IAmLazy

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = IAmLazy

IAmLazy_FILES = $(wildcard ../Shared/**/*.m ../Shared/**/*.c ../Shared/*.c) $(wildcard *.m **/*.m)
IAmLazy_FRAMEWORKS = UIKit
IAmLazy_LIBRARIES = archive
IAmLazy_CFLAGS = -fobjc-arc
IAmLazy_CODESIGN_FLAGS = -Sentitlements.plist
IAmLazy_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/application.mk
