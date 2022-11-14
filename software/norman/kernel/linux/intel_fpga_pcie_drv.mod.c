// Copyright 2017-2018 Intel Corporation.
//
// Intel, the Intel logo, Intel, MegaCore, NIOS II, Quartus and TalkBack words
// and logos are trademarks of Intel Corporation or its subsidiaries in the
// U.S. and/or other countries. Other marks and brands may be claimed as the
// property of others. See Trademarks on intel.com for full list of Intel
// trademarks or the Trademarks & Brands Names Database (if Intel) or see
// www.intel.com/legal (if Altera). Your use of Intel Corporation's design
// tools, logic functions and other software and tools, and its AMPP partner
// logic functions, and any output files any of the foregoing (including
// device programming or simulation files), and any associated documentation
// or information are expressly subject to the terms and conditions of the
// Altera Program License Subscription Agreement, Intel MegaCore Function
// License Agreement, or other applicable license agreement, including,
// without limitation, that your use is for the sole purpose of programming
// logic devices manufactured by Intel and sold by Intel or its authorized
// distributors. Please refer to the applicable agreement for further details.

#include <linux/compiler.h>
#include <linux/module.h>
#include <linux/vermagic.h>

MODULE_INFO(vermagic, VERMAGIC_STRING);
MODULE_INFO(name, KBUILD_MODNAME);

__visible struct module __this_module
    __attribute__((section(".gnu.linkonce.this_module"))) = {
        .name = KBUILD_MODNAME,
        .init = init_module,
#ifdef CONFIG_MODULE_UNLOAD
        .exit = cleanup_module,
#endif
        .arch = MODULE_ARCH_INIT,
};

#ifdef CONFIG_RETPOLINE
MODULE_INFO(retpoline, "Y");
#endif

static const char __module_depends[] __used
    __attribute__((section(".modinfo"))) = "depends=uio";

MODULE_ALIAS("pci:v00001172d*sv*sd*bc*sc*i*");

MODULE_INFO(srcversion, "5DF3FFEA146BA522A377EC8");
