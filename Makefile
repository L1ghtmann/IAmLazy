export CLI = 0
export ROOTLESS = 1
export ARCHS = arm64

ifeq ($(ROOTLESS),1)
export THEOS_PACKAGE_SCHEME = rootless
export TARGET = iphone:clang:14.5:15.0
else
export ADDITIONAL_CFLAGS = -D XINA_SUPPORT
export TARGET = iphone:clang:14.5:13.0
endif

include $(THEOS)/makefiles/common.mk

export ADDITIONAL_CFLAGS += -I$(PWD)/Headers -DCLI="$(CLI)"

ifeq ($(CLI),1)
SUBPROJECTS = CLI
else
SUBPROJECTS = App
endif
SUBPROJECTS += AndSoAreYou

include $(THEOS_MAKE_PATH)/aggregate.mk

before-package::
ifeq ($(CLI),1)
	@sed -i'' 's/Conflicts: me.lightmann.iamlazy-cli/Conflicts: me.lightmann.iamlazy/' $(THEOS_STAGING_DIR)/DEBIAN/control
	@sed -i'' 's/Package: me.lightmann.iamlazy/Package: me.lightmann.iamlazy-cli/' $(THEOS_STAGING_DIR)/DEBIAN/control
	@sed -i'' 's/Name: IAmLazy/Name: IAmLazy CLI/' $(THEOS_STAGING_DIR)/DEBIAN/control
else
	@mv $(wildcard $(THEOS_STAGING_DIR)/Applications/IAmLazy.app/Strings/*.lproj) "$(THEOS_STAGING_DIR)/Applications/IAmLazy.app/"
	@rm -r "$(THEOS_STAGING_DIR)/Applications/IAmLazy.app/Strings/"
endif
