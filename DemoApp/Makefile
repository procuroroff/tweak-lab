TARGET := iphone:clang:latest:15.0
ARCHS := arm64
THEOS_PACKAGE_SCHEME = rootless

APPLICATION_NAME := TweakLabDemo
TweakLabDemo_FILES := DemoApp.m
TweakLabDemo_FRAMEWORKS := UIKit Foundation
TweakLabDemo_CFLAGS := -fobjc-arc

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/application.mk
