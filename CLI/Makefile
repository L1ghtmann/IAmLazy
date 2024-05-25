INSTALL_TARGET_PROCESSES = ial

include $(THEOS)/makefiles/common.mk

TOOL_NAME = ial

ial_FILES = $(wildcard ../Shared/*.m ../Shared/**/*.m ../Shared/**/*.c ../Shared/*.c) $(wildcard *.m)
ial_LIBRARIES = archive
ial_CFLAGS = -fobjc-arc
ial_CODESIGN_FLAGS = -Sentitlements.plist
ial_INSTALL_PATH = /usr/local/bin

include $(THEOS_MAKE_PATH)/tool.mk
