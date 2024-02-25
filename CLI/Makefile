INSTALL_TARGET_PROCESSES = ial

include $(THEOS)/makefiles/common.mk

TOOL_NAME = ial

# TODO remove dependency on prog (and header) view
ial_FILES = $(wildcard ../Shared/**/*.m ../Shared/**/*.c ../Shared/*.c) $(wildcard *.m) ../App/UI/IALHeaderView.m ../App/UI/IALProgressViewController.m
ial_LIBRARIES = archive
ial_CFLAGS = -fobjc-arc
ial_CODESIGN_FLAGS = -Sentitlements.plist
ial_INSTALL_PATH = /usr/local/bin

include $(THEOS_MAKE_PATH)/tool.mk
