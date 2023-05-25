export CLI = 0
export ARCHS = arm64
export TARGET = iphone:clang:latest:13.0

INSTALL_TARGET_PROCESSES = IAmLazy

include $(THEOS)/makefiles/common.mk

ifneq ($(CLI),1)
APPLICATION_NAME = IAmLazy

IAmLazy_FILES = Task.c $(filter-out $(wildcard AndSoAreYou/*.m CLI/*.m), $(wildcard **/*.m)) $(wildcard App/**/*.m)
IAmLazy_FRAMEWORKS = UIKit
IAmLazy_LIBRARIES = archive
IAmLazy_CFLAGS = -fobjc-arc -Wno-unguarded-availability-new -D CLI="$(CLI)"
IAmLazy_CODESIGN_FLAGS = -SApp/entitlements.plist
IAmLazy_RESOURCE_DIRS = App/Resources

include $(THEOS_MAKE_PATH)/application.mk
else
TOOL_NAME = ial

ial_FILES = Task.c $(filter-out $(wildcard AndSoAreYou/*.m App/*.m), $(wildcard **/*.m))
ial_LIBRARIES = archive
ial_CFLAGS = -fobjc-arc -D CLI="$(CLI)"
ial_CODESIGN_FLAGS = -SCLI/entitlements.plist
ial_INSTALL_PATH = /usr/local/bin

include $(THEOS_MAKE_PATH)/tool.mk
endif

SUBPROJECTS += AndSoAreYou

include $(THEOS_MAKE_PATH)/aggregate.mk

before-package::
ifneq ($(CLI),1)
	$(ECHO_NOTHING)mv $(wildcard $(THEOS_STAGING_DIR)/Applications/IAmLazy.app/Strings/*.lproj) "$(THEOS_STAGING_DIR)/Applications/IAmLazy.app/"$(ECHO_END)
	$(ECHO_NOTHING)rm -r "$(THEOS_STAGING_DIR)/Applications/IAmLazy.app/Strings/"$(ECHO_END)
else
	$(ECHO_NOTHING)sed -i 's/me.lightmann.iamlazy/me.lightmann.iamlazy-cli/' $(THEOS_STAGING_DIR)/DEBIAN/control$(ECHO_END)
	$(ECHO_NOTHING)sed -i 's/IAmLazy/IAmLazy CLI/' $(THEOS_STAGING_DIR)/DEBIAN/control$(ECHO_END)
endif
