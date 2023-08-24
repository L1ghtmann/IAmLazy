include $(THEOS)/makefiles/common.mk

TOOL_NAME = postinst

postinst_FILES = postinst.c
postinst_CODESIGN_FLAGS = -S../entitlements.plist
postinst_INSTALL_PATH = /DEBIAN

include $(THEOS_MAKE_PATH)/tool.mk
