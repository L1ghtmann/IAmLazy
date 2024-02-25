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
