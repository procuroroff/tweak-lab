TARGET := iphone:clang:latest:15.0
ARCHS := arm64

# Rootless-схема: пути установки уходят в /var/jb, пакет собирается как iphoneos-arm64
THEOS_PACKAGE_SCHEME = rootless

# Процесс, который перезапускается после make install
INSTALL_TARGET_PROCESSES = TweakLabDemo

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := TweakLab
TweakLab_FILES := Tweak.x
TweakLab_CFLAGS := -fobjc-arc
TweakLab_FRAMEWORKS := UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
