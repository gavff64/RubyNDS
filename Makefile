DEVKITPRO ?= /opt/devkitpro
DEVKITARM ?= $(DEVKITPRO)/devkitARM
LIBNDS    ?= $(DEVKITPRO)/libnds

GAME ?= examples/high_level/http_example.rb
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
CFLAGS  := -O2 -Wall -ffunction-sections -fdata-sections -MMD -MP $(ARCH)
LDFLAGS := -specs=$(DEVKITPRO)/calico/share/ds9.specs $(ARCH) \
	-Wl,--gc-sections -Wl,-Map,$(APP_BUILD)/$(NAME).map
LDLIBS  := -L$(MRUBY_BUILD)/nds/lib -L$(LIBNDS)/lib \
	-L$(DEVKITPRO)/calico/lib -lmruby -lmm9 -ldswifi9 \
	-lfilesystem -lfat -lnds9 -lcalico_ds9 -lm

BINDINGS := src/main.c src/bindings_net.c src/bindings_input.c \
	src/bindings_gfx.c src/bindings_fs.c src/bindings_audio.c \
	src/bindings_system.c
OBJECTS := $(BINDINGS:src/%.c=$(BUILD)/%.o)

NITROFS_FILES := $(wildcard assets/*)

.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.PHONY: all clean

all: $(NAME).nds

$(BUILD)/.mruby-built: build_config.rb
	@test -f vendor/mruby/Rakefile || (echo "vendor/mruby is missing. Restore it from the project archive or clone mruby 4.0.0 into vendor/mruby." && exit 1)
	mkdir -p $(BUILD)
	cd vendor/mruby && MRUBY_CONFIG=$(abspath build_config.rb) \
		MRUBY_BUILD_DIR=$(MRUBY_BUILD) rake
	touch $@

$(MRBC) $(MRUBY_LIB): $(BUILD)/.mruby-built

$(APP_BUILD)/app_bytecode.c: $(GAME) $(MRBC)
	mkdir -p $(APP_BUILD)
	$(MRBC) -Bapp_bytecode -o $@ $<

$(BUILD)/%.o: src/%.c src/bindings.h $(MRUBY_LIB)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(APP_BUILD)/app_bytecode.o: $(APP_BUILD)/app_bytecode.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(APP_BUILD)/$(NAME).elf: $(OBJECTS) $(APP_BUILD)/app_bytecode.o $(MRUBY_LIB)
	$(CC) $(LDFLAGS) -o $@ $(OBJECTS) $(APP_BUILD)/app_bytecode.o $(LDLIBS)

$(NAME).nds: $(APP_BUILD)/$(NAME).elf $(NITROFS_FILES)
	$(NDSTOOL) -c $@ -9 $< \
		-7 $(DEVKITPRO)/calico/bin/ds7_maine.elf \
		-b $(DEVKITPRO)/calico/share/nds-icon.bmp "$(NAME);Ruby on Nintendo DS;dsi-ruby" \
		-d assets

clean:
	rm -rf $(BUILD) *.nds

-include $(OBJECTS:.o=.d)
