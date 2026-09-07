DEVKITPRO ?= /opt/devkitpro
DEVKITARM ?= $(DEVKITPRO)/devkitARM
LIBNDS    ?= $(DEVKITPRO)/libnds

GAME ?= examples/high_level/http_get_example.rb
NAME := $(basename $(notdir $(GAME)))

BUILD       := build
APP_BUILD   := $(BUILD)/$(NAME)
MRUBY_BUILD := $(abspath $(BUILD)/mruby)
MRUBY_LIB   := $(MRUBY_BUILD)/nds/lib/libmruby.a
MRBC        := $(MRUBY_BUILD)/host/bin/mrbc
MRUBY_GEMS  := $(shell find gems -type f)
ASSET_BUILD := $(BUILD)/assets
ASSET_STAMP := $(BUILD)/.assets-built
VIDEO_ENCODER := $(BUILD)/r15v
BEARSSL := vendor/bearssl
BEARSSL_REV := 7bea48e5e850ab4cafbe68d3765cdaba13a86d6f
TJPGD := $(BUILD)/tjpgd
TJPGD_SHA256 := 052fe3efbc9a8be29f31597ad009c5b51a4f6905878eb28569e0ab3d46d0c013
PVMP3 := $(BUILD)/pvmp3
PVMP3_REV := ee17317c6362f54bd311ec359b5c3518137fae9f
TLS_CA_BUNDLE ?= third_party/certs/cacert.pem

CC      := $(DEVKITARM)/bin/arm-none-eabi-gcc
CXX     := $(DEVKITARM)/bin/arm-none-eabi-g++
NDSTOOL := $(DEVKITPRO)/tools/bin/ndstool
RUBY    ?= ruby
HOSTCC  ?= cc

ARCH := -march=armv5te -mtune=arm946e-s -mthumb -mthumb-interwork
CPPFLAGS := -D__NDS__ -DARM9 -DMRB_INT32 -DMRB_USE_FLOAT32 \
	-I$(LIBNDS)/include -I$(DEVKITPRO)/calico/include \
	-Ivendor/mruby/include -I$(MRUBY_BUILD)/nds/include \
	-Ithird_party/fastlz -I$(BEARSSL)/inc -I$(TJPGD)/src \
	-I$(PVMP3)/include -I$(PVMP3)/src -I$(BUILD)
CFLAGS  := -O2 -Wall -ffunction-sections -fdata-sections -MMD -MP $(ARCH)
CXXFLAGS := $(CFLAGS) -fno-exceptions -fno-rtti
PVMP3_FLAGS := -DPV_ARM_GCC_V5 -Wno-deprecated-declarations -Wno-attributes
LDFLAGS := -specs=$(DEVKITPRO)/calico/share/ds9.specs $(ARCH) \
	-Wl,--gc-sections -Wl,-Map,$(APP_BUILD)/$(NAME).map
LDLIBS  := -L$(MRUBY_BUILD)/nds/lib -L$(LIBNDS)/lib \
	-L$(DEVKITPRO)/calico/lib -lmruby -lmm9 -ldswifi9 \
	-L$(BUILD)/bearssl-nds -lbearssl -lfilesystem -lfat -lnds9 -lcalico_ds9 -lm

BINDINGS := src/main.c src/bindings_net.c src/bindings_tls.c src/bindings_input.c \
	src/bindings_gfx.c src/bindings_video.c src/bindings_fs.c src/bindings_audio.c \
	src/bindings_mp3.c src/bindings_system.c
OBJECTS := $(BINDINGS:src/%.c=$(BUILD)/%.o)
OBJECTS += $(BUILD)/fastlz.o $(BUILD)/tjpgd.o

PVMP3_CPP := pvmp3_normalize pvmp3_alias_reduction pvmp3_crc \
	pvmp3_decode_header pvmp3_decode_huff_cw pvmp3_getbits \
	pvmp3_dequantize_sample pvmp3_framedecoder pvmp3_get_main_data_size \
	pvmp3_get_side_info pvmp3_get_scale_factors pvmp3_mpeg2_get_scale_data \
	pvmp3_mpeg2_get_scale_factors pvmp3_mpeg2_stereo_proc \
	pvmp3_huffman_decoding pvmp3_huffman_parsing pvmp3_tables \
	pvmp3_imdct_synth pvmp3_mdct_6 pvmp3_dct_6 \
	pvmp3_poly_phase_synthesis pvmp3_equalizer pvmp3_seek_synch \
	pvmp3_stereo_proc pvmp3_reorder
PVMP3_ASM := pvmp3_polyphase_filter_window_gcc pvmp3_mdct_18_gcc \
	pvmp3_dct_9_gcc pvmp3_dct_16_gcc
PVMP3_OBJECTS := $(PVMP3_CPP:%=$(BUILD)/pvmp3-nds/%.o) \
	$(PVMP3_ASM:%=$(BUILD)/pvmp3-nds/%.o)
OBJECTS += $(PVMP3_OBJECTS)

NITROFS_FILES := $(shell find assets -type f -o -type d)

.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.PHONY: all clean

all: $(NAME).nds

$(BUILD)/.mruby-built: build_config.rb $(MRUBY_GEMS)
	@test -f vendor/mruby/Rakefile || (echo "vendor/mruby is missing. Restore it from the project archive or clone mruby 4.0.0 into vendor/mruby." && exit 1)
	mkdir -p $(BUILD)
	cd vendor/mruby && MRUBY_CONFIG=$(abspath build_config.rb) \
		MRUBY_BUILD_DIR=$(MRUBY_BUILD) rake
	touch $@

$(MRBC) $(MRUBY_LIB): $(BUILD)/.mruby-built

$(BEARSSL)/.rubynds-$(BEARSSL_REV):
	@test -d $(BEARSSL)/.git || git clone https://www.bearssl.org/git/BearSSL $(BEARSSL)
	git -C $(BEARSSL) checkout --detach $(BEARSSL_REV)
	touch $@

$(BUILD)/bearssl-nds/libbearssl.a: $(BEARSSL)/.rubynds-$(BEARSSL_REV)
	$(MAKE) -C $(BEARSSL) BUILD=$(abspath $(BUILD)/bearssl-nds) lib \
		CC=$(CC) AR=$(DEVKITARM)/bin/arm-none-eabi-ar \
		CFLAGS="$(CFLAGS) -marm -DBR_USE_UNIX_TIME=1 -DBR_CT_MUL31=1 -DBR_CT_MUL15=1"

$(BUILD)/bearssl-host/brssl: $(BEARSSL)/.rubynds-$(BEARSSL_REV)
	$(MAKE) -C $(BEARSSL) BUILD=$(abspath $(BUILD)/bearssl-host) tools CC=$(HOSTCC) LD=$(HOSTCC)

$(BUILD)/tls_roots.h: $(TLS_CA_BUNDLE) $(BUILD)/bearssl-host/brssl
	$(BUILD)/bearssl-host/brssl ta $(TLS_CA_BUNDLE) > $@

$(BUILD)/bindings_tls.o: $(BUILD)/tls_roots.h

$(TJPGD)/.rubynds-$(TJPGD_SHA256):
	mkdir -p $(TJPGD)
	curl -L --fail --silent --show-error --retry 3 --retry-all-errors --http1.1 --tlsv1.2 https://elm-chan.org/fsw/tjpgd/arc/tjpgd3.zip -o $(TJPGD)/tjpgd.zip
	echo "$(TJPGD_SHA256)  $(TJPGD)/tjpgd.zip" | sha256sum -c -
	unzip -oq $(TJPGD)/tjpgd.zip -d $(TJPGD)
	sed -i 's/#define[[:space:]]*JD_FORMAT[[:space:]]*0/#define JD_FORMAT 1/' $(TJPGD)/src/tjpgdcnf.h
	sed -i 's/#define[[:space:]]*JD_FASTDECODE[[:space:]]*0/#define JD_FASTDECODE 1/' $(TJPGD)/src/tjpgdcnf.h
	touch $@

$(ASSET_STAMP): tools/assets.rb $(NITROFS_FILES) $(VIDEO_ENCODER)
	mkdir -p $(BUILD)
	$(RUBY) tools/assets.rb assets $(ASSET_BUILD) $(VIDEO_ENCODER)
	touch $@

$(VIDEO_ENCODER): tools/r15v.c third_party/fastlz/fastlz.c third_party/fastlz/fastlz.h
	mkdir -p $(BUILD)
	$(HOSTCC) -O2 -Ithird_party/fastlz tools/r15v.c third_party/fastlz/fastlz.c -o $@

$(APP_BUILD)/app_bytecode.c: $(GAME) $(MRBC)
	mkdir -p $(APP_BUILD)
	$(MRBC) -Bapp_bytecode -o $@ $<

$(BUILD)/%.o: src/%.c src/bindings.h | $(BUILD)/.mruby-built
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(BUILD)/bindings_video.o: third_party/fastlz/fastlz.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -marm -c src/bindings_video.c -o $@

$(BUILD)/bindings_gfx.o: $(TJPGD)/.rubynds-$(TJPGD_SHA256)

$(PVMP3)/.rubynds-$(PVMP3_REV):
	mkdir -p $(PVMP3)
	curl -L --fail --silent --show-error --retry 3 --retry-all-errors --http1.1 --tlsv1.2 \
		https://android.googlesource.com/platform/frameworks/av/+archive/$(PVMP3_REV)/media/libstagefright/codecs/mp3dec.tar.gz \
		-o $(PVMP3)/mp3dec.tar.gz
	tar -xzf $(PVMP3)/mp3dec.tar.gz -C $(PVMP3)
	touch $@

$(BUILD)/bindings_mp3.o: $(PVMP3)/.rubynds-$(PVMP3_REV) | $(BUILD)/.mruby-built
	$(CC) $(CPPFLAGS) $(CFLAGS) $(PVMP3_FLAGS) -marm -c src/bindings_mp3.c -o $@

$(BUILD)/pvmp3-nds/%.o: $(PVMP3)/src/%.cpp $(PVMP3)/.rubynds-$(PVMP3_REV)
	mkdir -p $(BUILD)/pvmp3-nds
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(PVMP3_FLAGS) -Wno-register \
		'-DOSCL_UNUSED_ARG(x)=(void)(x)' -marm -c $< -o $@

$(BUILD)/pvmp3-nds/%.o: $(PVMP3)/src/asm/%.s $(PVMP3)/.rubynds-$(PVMP3_REV)
	mkdir -p $(BUILD)/pvmp3-nds
	$(CC) $(ARCH) -marm -c $< -o $@

$(PVMP3_CPP:%=$(PVMP3)/src/%.cpp) \
$(PVMP3_ASM:%=$(PVMP3)/src/asm/%.s): $(PVMP3)/.rubynds-$(PVMP3_REV)

$(BUILD)/fastlz.o: third_party/fastlz/fastlz.c third_party/fastlz/fastlz.h | $(BUILD)/.mruby-built
	$(CC) $(CPPFLAGS) $(CFLAGS) -marm -c $< -o $@

$(BUILD)/tjpgd.o: $(TJPGD)/.rubynds-$(TJPGD_SHA256) | $(BUILD)/.mruby-built
	$(CC) $(CPPFLAGS) $(CFLAGS) -marm -c $(TJPGD)/src/tjpgd.c -o $@

$(APP_BUILD)/app_bytecode.o: $(APP_BUILD)/app_bytecode.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(APP_BUILD)/$(NAME).elf: $(OBJECTS) $(APP_BUILD)/app_bytecode.o $(MRUBY_LIB) $(BUILD)/.mruby-built $(BUILD)/bearssl-nds/libbearssl.a
	$(CC) $(LDFLAGS) -o $@ $(OBJECTS) $(APP_BUILD)/app_bytecode.o $(LDLIBS)

$(NAME).nds: $(APP_BUILD)/$(NAME).elf $(ASSET_STAMP)
	$(NDSTOOL) -c $@ -9 $< \
		-7 $(DEVKITPRO)/calico/bin/ds7_maine.elf \
		-b $(DEVKITPRO)/calico/share/nds-icon.bmp "$(NAME);Ruby on Nintendo DS;dsi-ruby" \
		-d $(ASSET_BUILD)

clean:
	rm -rf $(BUILD) *.nds

-include $(OBJECTS:.o=.d)
