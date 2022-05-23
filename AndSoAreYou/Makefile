include $(THEOS)/makefiles/common.mk

TOOL_NAME = AndSoAreYou

AndSoAreYou_FILES = AndSoAreYou.m
AndSoAreYou_CFLAGS = -fobjc-arc
AndSoAreYou_CODESIGN_FLAGS = -Sentitlements.plist
AndSoAreYou_INSTALL_PATH = /usr/libexec/iamlazy/

include $(THEOS_MAKE_PATH)/tool.mk

SUBPROJECTS += postinst

include $(THEOS_MAKE_PATH)/aggregate.mk
