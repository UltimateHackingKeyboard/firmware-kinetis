# Copyright (C) 2018 Kristian Lauszus. All rights reserved.
#
# This software may be distributed and modified under the terms of the GNU
# General Public License version 2 (GPL2) as published by the Free Software
# Foundation and appearing in the file GPL2.TXT included in the packaging of
# this file. Please note that GPL2 Section 2[b] requires that all works based
# on this software must also be made publicly available under the terms of
# the GPL2 ("Copyleft").
#
# Contact information
# -------------------
# Kristian Lauszus
# Web      :  http://www.lauszus.com
# e-mail   :  lauszus@gmail.com

# Debug using Semihosting.
SEMIHOSTING ?= 0

# Build directory.
BUILD_DIR ?= build_make

 # Preprocessor directives.
BUILD_FLAGS += -D__NEWLIB__ -D__USE_CMSIS -D__MCUXPRESSO -DCPU_$(PART) -D__STARTUP_CLEAR_BSS

# Path to project object file.
PROJECT_OBJ = $(BUILD_DIR)/$(PROJECT_NAME).axf

# Set the prefix for the tools to use.
PREFIX ?= arm-none-eabi

# Determine if we are on a Windows machine and set the .exe suffix.
# We can not use the suffix command, as the PREFIX might contain spaces.
UNAME_S := $(shell uname -s)
ifeq ($(OS),Windows_NT) # Native Windows.
    SUFFIX := .exe
endif

# The command for calling the compilers.
CC = $(PREFIX)-gcc$(SUFFIX)
CXX = $(PREFIX)-g++$(SUFFIX)

# The command for calling the linker.
LD = $(PREFIX)-g++$(SUFFIX)

# The command for extracting images from the linked executables.
OBJCOPY = $(PREFIX)-objcopy$(SUFFIX)

# The command for the size tool.
SIZE = $(PREFIX)-size$(SUFFIX)

# Auto-dependency generation flags.
DEPS = -MMD -MP

# The flags passed to the assembler.
AFLAGS = -mthumb                    \
         $(CPU)                     \
         $(FPU)                     \
         $(DEPS)                    \
         $(BUILD_FLAGS)             \
         -x assembler-with-cpp

# The flags passed to the compiler.
CFLAGS = -mthumb                    \
         $(CPU)                     \
         $(FPU)                     \
         $(DEPS)                    \
         -fno-builtin               \
         -ffunction-sections        \
         -fdata-sections            \
         -fno-common                \
         -Wdouble-promotion         \
         -Woverflow                 \
         -Wall                      \
         -Wshadow                   \
         $(BUILD_FLAGS)

# Compiler options for C++ only.
CXXFLAGS = -felide-constructors -fno-exceptions -fno-rtti

# Set the C/C++ standard to use.
CSTD = -std=gnu11
CXXSTD = -std=gnu++14

# Make all warnings into errors when building using Travis CI.
ifdef TRAVIS
    CFLAGS += -Werror
endif

# Set default value for the bootloader vector table address.
BL_APP_VECTOR_TABLE_ADDRESS ?= 0

# The flags passed to the linker.
LDFLAGS = --specs=nano.specs -mthumb $(CPU) $(FPU) -T $(LDSCRIPT) -Wl,-Map=$(PROJECT_OBJ:.axf=.map),--gc-sections,-print-memory-usage,-no-wchar-size-warning,--defsym=__heap_size__=$(HEAP_SIZE),--defsym=__stack_size__=$(STACK_SIZE),--defsym=__bl_app_vector_table_address__=$(BL_APP_VECTOR_TABLE_ADDRESS)

# Include the following archives.
LDARCHIVES = -Wl,--start-group -lg -lgcc -lm -Wl,--end-group

# Add flags to the build flags and linker depending on the build settings.
ifeq ($(SEMIHOSTING),1)
    # Include Semihost library.
    LDARCHIVES += -lcr_newlib_semihost

    # Enable printf floating numbers.
    LDFLAGS += -u _printf_float
else
    # Include libnosys.a if Semihosting is disabled.
    LDARCHIVES += -lnosys
endif

# Check if the DEBUG environment variable is set.
DEBUG ?= 1
ifeq ($(DEBUG),1)
    CFLAGS += -O3 -g3 -DDEBUG
else
    CFLAGS += -O3 -DNDEBUG
endif

# Add the include file paths to AFLAGS and CFLAGS.
AFLAGS += $(patsubst %,-I%,$(subst :, ,$(IPATH)))
CFLAGS += $(patsubst %,-I%,$(subst :, ,$(IPATH)))

# Create lists of C, C++ and assembly objects.
C_OBJS := $(addsuffix .o,$(addprefix $(BUILD_DIR)/,$(basename $(filter %.c,$(abspath $(SOURCE))))))
CPP_OBJS := $(addsuffix .o,$(addprefix $(BUILD_DIR)/,$(basename $(filter %.cpp,$(abspath $(SOURCE))))))
S_OBJS := $(addsuffix .o,$(addprefix $(BUILD_DIR)/,$(basename $(filter %.S,$(abspath $(SOURCE))))))

# Create a list of all objects.
OBJS := $(C_OBJS) $(CPP_OBJS) $(S_OBJS)

# Define the commands used for compiling the project.
LD_CMD = $(LD) $(LDFLAGS) -o $(@) $(filter %.o %.a, $(^)) $(LDARCHIVES)
CC_CMD = $(CC) $(CFLAGS) $(CSTD) -c $(<) -o $(@)
CXX_CMD = $(CXX) $(CFLAGS) $(CXXFLAGS) $(CXXSTD) -c $(<) -o $(@)
AS_CMD = $(CC) $(AFLAGS) $(CSTD) -c $(<) -o $(@)

# Everyone need colors in their life!
INTERACTIVE := $(shell [ -t 0 ] && echo 1)
ifeq ($(INTERACTIVE),1)
    color_default = \033[0m
    color_bold = \033[01m
    color_red = \033[31m
    color_green = \033[32m
    color_yellow = \033[33m
    color_blue = \033[34m
    color_magenta = \033[35m
    color_cyan = \033[36m
    color_orange = \033[38;5;172m
    color_light_blue = \033[38;5;039m
    color_gray = \033[38;5;008m
    color_purple = \033[38;5;097m
endif

.PHONY: all clean

# The default rule, which causes the project to be built.
all: $(PROJECT_OBJ)

# The rule to clean out all the build products.
clean:
	@rm -rf $(BUILD_DIR) $(wildcard *~)
	@echo "$(color_red)Done cleaning!$(color_default)"

# Rebuild all objects when the Makefile changes.
$(OBJS): Makefile

# The rule for linking the application.
$(PROJECT_OBJ): $(OBJS) $(LDSCRIPT)
	@if [ '$(VERBOSE)' = 1 ]; then                                        \
	     echo $(LD_CMD);                                                  \
	 else                                                                 \
	     echo "    $(color_purple)LD$(color_default)    $(notdir $(@))";  \
	 fi
	@echo
	@$(LD_CMD)
	@echo
	@if [ '$(VERBOSE)' = 1 ]; then                                        \
	     $(SIZE) -Ax $(@);                                                \
	 fi
	@$(OBJCOPY) -O binary $(@) $(@:.axf=.bin)
	@$(OBJCOPY) -O ihex $(@) $(@:.axf=.hex)

# The rule for building the object files from each source file.
$(C_OBJS): $(BUILD_DIR)/%.o : %.c
	@mkdir -p $(@D)
	@if [ '$(VERBOSE)' = 1 ]; then                                        \
	     echo $(CC_CMD);                                                  \
	 else                                                                 \
	     echo "    $(color_green)CC$(color_default)    $(notdir $(<))";   \
	 fi
	@$(CC_CMD)

$(CPP_OBJS): $(BUILD_DIR)/%.o : %.cpp
	@mkdir -p $(@D)
	@if [ '$(VERBOSE)' = 1 ]; then                                        \
	     echo $(CXX_CMD);                                                 \
	 else                                                                 \
	     echo "    $(color_cyan)CXX$(color_default)   $(notdir $(<))";    \
	 fi
	@$(CXX_CMD)

$(S_OBJS): $(BUILD_DIR)/%.o: %.S
	@mkdir -p $(@D)
	@if [ '$(VERBOSE)' = 1 ]; then                                        \
	     echo $(AS_CMD);                                                  \
	 else                                                                 \
	     echo "    $(color_magenta)AS$(color_default)    $(notdir $(<))"; \
	 fi
	@$(AS_CMD)

# Include the automatically generated dependency files.
-include $(OBJS:.o=.d)