// SPDX-License-Identifier: GPL-2.0+
/*
 * Allwinner H3 (sun8i) PIO register setup for ST7789V reset/dc GPIO.
 * Uses direct register access so display works without DM pinctrl/GPIO
 * (avoids probe-order hangs on sunxi when using gpio_request_by_name).
 *
 * GPIO pins are read from the device tree: reset-gpios and dc-gpios.
 * Sunxi #gpio-cells = 3: (bank, pin, flags). Same CPU, different board
 * wiring only needs DTS change (e.g. reset-gpios = <&pio 0 4 ...> or
 * <&pio 1 3 ...> for PB3).
 */

#include <dm.h>
#include <errno.h>
#include <linux/bitops.h>
#include <linux/types.h>
#include <stdbool.h>
#include <asm/io.h>
#include <asm/arch/cpu.h>
#include <sunxi_gpio.h>
#include <dm/read.h>
#include <linux/delay.h>

/* Pin index for set_value: 0 = reset, 1 = dc */
#define ST7789V_H3_PIN_RESET  0
#define ST7789V_H3_PIN_DC     1

/* PIO register layout helpers (mirrors drivers/gpio/sunxi_gpio.c) */
#define GPIO_DAT_REG_OFFSET	0x10

/* Parsed from DTS: (bank, pin) for reset and dc. Bank 0..8 = PA..PI, 11 = PL (R_PIO). */
static unsigned int reset_bank, reset_pin;
static unsigned int dc_bank, dc_pin;
static unsigned int reset_flags, dc_flags;
static bool gpio_parsed;

static void *bank_to_gpio_base(unsigned int bank)
{
	void *pio_base;

	if (bank < SUNXI_GPIO_L) {
		pio_base = (void *)(uintptr_t)SUNXI_PIO_BASE;
	} else {
		pio_base = (void *)(uintptr_t)SUNXI_R_PIO_BASE;
		bank -= SUNXI_GPIO_L;
	}

	return pio_base + bank * SUNXI_PINCTRL_BANK_SIZE;
}

static void set_pin_value(unsigned int bank, unsigned int pin, int value)
{
	void *bank_base = bank_to_gpio_base(bank);
	u32 mask = 1U << pin;

	/* clrsetbits: clear when 0, set when 1 */
	clrsetbits_le32(bank_base + GPIO_DAT_REG_OFFSET,
			value ? 0 : mask, value ? mask : 0);
}

/* Convert (bank, pin) from DTS to sunxi global pin number for set_cfgpin/set_pull */
static u32 bank_pin_to_sunxi_pin(uint bank, uint pin)
{
	if (bank < SUNXI_GPIO_L)
		return bank * SUNXI_GPIOS_PER_BANK + pin;
	return SUNXI_GPIO_L_START + pin;
}

/* Parse DTS once; call from probe only (not from bind or sync, to avoid hang). */
int st7789v_sunxi_h3_parse_dts(struct udevice *dev)
{
	struct ofnode_phandle_args args;
	int ret;

	if (gpio_parsed)
		return 0;

	ret = dev_read_phandle_with_args(dev, "reset-gpios", "#gpio-cells", 0, 0, &args);
	if (ret || args.args_count < 2)
		return ret ? ret : -EINVAL;
	reset_bank = args.args[0];
	reset_pin = args.args[1];
	reset_flags = args.args_count >= 3 ? args.args[2] : 0;

	ret = dev_read_phandle_with_args(dev, "dc-gpios", "#gpio-cells", 0, 0, &args);
	if (ret || args.args_count < 2)
		return ret ? ret : -EINVAL;
	dc_bank = args.args[0];
	dc_pin = args.args[1];
	dc_flags = args.args_count >= 3 ? args.args[2] : 0;

	gpio_parsed = true;
	return 0;
}

void st7789v_sunxi_h3_gpio_set_value(int pin_index, int value);

/* Only configure PIO and set levels; DTS must have been parsed in bind. */
int st7789v_sunxi_h3_gpio_init(struct udevice *dev)
{
	if (!gpio_parsed)
		return -EINVAL;

	/* Mux as GPIO output; same CPU, different pins work via DTS. */
	sunxi_gpio_set_cfgpin(bank_pin_to_sunxi_pin(reset_bank, reset_pin), SUNXI_GPIO_OUTPUT);
	sunxi_gpio_set_cfgpin(bank_pin_to_sunxi_pin(dc_bank, dc_pin), SUNXI_GPIO_OUTPUT);
	sunxi_gpio_set_pull(bank_pin_to_sunxi_pin(reset_bank, reset_pin), SUNXI_GPIO_PULL_DISABLE);
	sunxi_gpio_set_pull(bank_pin_to_sunxi_pin(dc_bank, dc_pin), SUNXI_GPIO_PULL_DISABLE);

	/* Default: reset high (deasserted), dc low (command) */
	st7789v_sunxi_h3_gpio_set_value(ST7789V_H3_PIN_RESET, 1);
	st7789v_sunxi_h3_gpio_set_value(ST7789V_H3_PIN_DC, 0);
	return 0;
}

void st7789v_sunxi_h3_gpio_set_value(int pin_index, int value)
{
	/*
	 * Value here is a logical value (0/1). If DTS marks the GPIO as
	 * active-low, invert to get the physical level.
	 */
	uint flags;
	int phys;

	if (!gpio_parsed)
		return;
	if (pin_index == ST7789V_H3_PIN_RESET) {
		flags = reset_flags;
		phys = (flags & BIT(0)) ? !value : value;
		set_pin_value(reset_bank, reset_pin, phys);
	} else if (pin_index == ST7789V_H3_PIN_DC) {
		flags = dc_flags;
		phys = (flags & BIT(0)) ? !value : value;
		set_pin_value(dc_bank, dc_pin, phys);
	}
}
