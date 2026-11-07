# SPDX-License-Identifier: GPL-2.0-only

ccflags-y += -DVERSION=$(VERSION)
# Support GNU11 syntax on kernels using GNU89 defaults.
ccflags-y += -std=gnu11
obj-m += hid-xpadneo.o

hid-xpadneo-y += \
	xpadneo/consumer.o \
	xpadneo/core.o \
	xpadneo/debug.o \
	xpadneo/device.o \
	xpadneo/events.o \
	xpadneo/keyboard.o \
	xpadneo/mappings.o \
	xpadneo/mouse.o \
	xpadneo/power.o \
	xpadneo/quirks.o \
	xpadneo/rumble.o \
	xpadneo/synthetic.o
