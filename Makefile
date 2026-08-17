DEVKITPRO ?= /opt/devkitpro
DEVKITARM ?= $(DEVKITPRO)/devkitARM
LIBNDS    ?= $(DEVKITPRO)/libnds

GAME ?= src/game.rb
NAME := $(basename $(notdir $(GAME)))

BUILD       := build
APP_BUILD   := $(BUILD)/$(NAME)
MRUBY_BUILD := $(abspath $(BUILD)/mruby)
MRUBY_LIB   := $(MRUBY_BUILD)/nds/lib/libmruby.a
MRBC        := $(MRUBY_BUILD)/host/bin/mrbc

CC      := $(DEVKITARM)/bin/arm-none-eabi-gcc
NDSTOOL := $(DEVKITPRO)/tools/bin/ndstool

ARCH := -march=armv5te -mtune=arm946e-s -mthumb -mthumb-interwork
CPPFLAGS := -D__NDS__ -DARM9 -DMRB_INT32 -DMRB_USE_FLOAT32 \
	-I$(LIBNDS)/include -I$(DEVKITPRO)/calico/include \
	-Ivendor/mruby/include -I$(MRUBY_BUILD)/nds/include
CFLAGS  := -O2 -Wall -ffunction-sections -fdata-sections $(ARCH)
LDFLAGS := -specs=$(DEVKITPRO)/calico/share/ds9.specs $(ARCH) \
	-Wl,--gc-sections -Wl,-Map,$(APP_BUILD)/$(NAME).map
LDLIBS  := -L$(MRUBY_BUILD)/nds/lib -L$(LIBNDS)/lib \
	-L$(DEVKITPRO)/calico/lib -lmruby -ldswifi9 -lnds9 -lcalico_ds9 -lm

.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.PHONY: all clean

all: $(NAME).nds

$(BUILD)/.mruby-built: build_config.rb
	mkdir -p $(BUILD)
	cd vendor/mruby && MRUBY_CONFIG=$(abspath build_config.rb) \
		MRUBY_BUILD_DIR=$(MRUBY_BUILD) rake
	touch $@

$(MRBC) $(MRUBY_LIB): $(BUILD)/.mruby-built

$(APP_BUILD)/app_bytecode.c: $(GAME) $(MRBC)
	mkdir -p $(APP_BUILD)
	$(MRBC) -Bapp_bytecode -o $@ $<

$(BUILD)/main.o: src/main.c $(MRUBY_LIB)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(APP_BUILD)/app_bytecode.o: $(APP_BUILD)/app_bytecode.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(APP_BUILD)/$(NAME).elf: $(BUILD)/main.o $(APP_BUILD)/app_bytecode.o $(MRUBY_LIB)
	$(CC) $(LDFLAGS) -o $@ $(BUILD)/main.o $(APP_BUILD)/app_bytecode.o $(LDLIBS)

$(NAME).nds: $(APP_BUILD)/$(NAME).elf
	$(NDSTOOL) -c $@ -9 $< \
		-7 $(DEVKITPRO)/calico/bin/ds7_maine.elf \
		-b $(DEVKITPRO)/calico/share/nds-icon.bmp "$(NAME);Ruby on Nintendo DS;dsi-ruby"

clean:
	rm -rf $(BUILD) *.nds
