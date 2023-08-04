export CLI = 0
export ROOTLESS = 1
export ARCHS = arm64

ifeq ($(ROOTLESS),1)
export THEOS_PACKAGE_SCHEME = rootless
export TARGET = iphone:clang:latest:15.0
else
export ADDITIONAL_CFLAGS = -D XINA_SUPPORT
export TARGET = iphone:clang:latest:13.0
endif

INSTALL_TARGET_PROCESSES = IAmLazy

include $(THEOS)/makefiles/common.mk

ifneq ($(CLI),1)
APPLICATION_NAME = IAmLazy

IAmLazy_FILES = Task.c $(wildcard Shared/**/*.m) $(wildcard App/*.m App/**/*.m)
IAmLazy_FRAMEWORKS = UIKit
IAmLazy_LIBRARIES = archive
IAmLazy_CFLAGS = -fobjc-arc
IAmLazy_CODESIGN_FLAGS = -SApp/entitlements.plist
IAmLazy_RESOURCE_DIRS = App/Resources

include $(THEOS_MAKE_PATH)/application.mk
else
TOOL_NAME = ial

ial_FILES = Task.c $(wildcard Shared/**/*.m) $(wildcard CLI/*.m) App/UI/IALProgressViewController.m
ial_LIBRARIES = archive
ial_CFLAGS = -fobjc-arc
ial_CODESIGN_FLAGS = -SCLI/entitlements.plist
ial_INSTALL_PATH = /usr/local/bin

include $(THEOS_MAKE_PATH)/tool.mk
endif

export ADDITIONAL_CFLAGS += -D CLI="$(CLI)"

SUBPROJECTS += AndSoAreYou

include $(THEOS_MAKE_PATH)/aggregate.mk

before-package::
ifneq ($(CLI),1)
	$(ECHO_NOTHING)mv $(wildcard $(THEOS_STAGING_DIR)/Applications/IAmLazy.app/Strings/*.lproj) "$(THEOS_STAGING_DIR)/Applications/IAmLazy.app/"$(ECHO_END)
	$(ECHO_NOTHING)rm -r "$(THEOS_STAGING_DIR)/Applications/IAmLazy.app/Strings/"$(ECHO_END)
else
	$(ECHO_NOTHING)sed -i 's/Conflicts: me.lightmann.iamlazy-cli/Conflicts: me.lightmann.iamlazy/' $(THEOS_STAGING_DIR)/DEBIAN/control$(ECHO_END)
	$(ECHO_NOTHING)sed -i 's/Package: me.lightmann.iamlazy/Package: me.lightmann.iamlazy-cli/' $(THEOS_STAGING_DIR)/DEBIAN/control$(ECHO_END)
	$(ECHO_NOTHING)sed -i 's/Name: IAmLazy/Name: IAmLazy CLI/' $(THEOS_STAGING_DIR)/DEBIAN/control$(ECHO_END)
endif
