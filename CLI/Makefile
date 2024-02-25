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

before-package::
	@sed -i 's/Conflicts: me.lightmann.iamlazy-cli/Conflicts: me.lightmann.iamlazy/' $(THEOS_STAGING_DIR)/DEBIAN/control
	@sed -i 's/Package: me.lightmann.iamlazy/Package: me.lightmann.iamlazy-cli/' $(THEOS_STAGING_DIR)/DEBIAN/control
	@sed -i 's/Name: IAmLazy/Name: IAmLazy CLI/' $(THEOS_STAGING_DIR)/DEBIAN/control
