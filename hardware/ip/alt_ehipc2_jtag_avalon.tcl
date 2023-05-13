package require -exact qsys 18.0

# create the system "alt_ehipc2_jtag_avalon"
proc do_create_alt_ehipc2_jtag_avalon {} {
	# create the system
	create_system alt_ehipc2_jtag_avalon
	set_project_property DEVICE {1SM21BHU2F53E1VG}
	set_project_property DEVICE_FAMILY {Stratix 10}
	set_project_property HIDE_FROM_IP_CATALOG {false}
	set_use_testbench_naming_pattern 0 {}

	# add the components
	add_instance altera_jtag_avalon_master_0 altera_jtag_avalon_master 19.1
	set_instance_parameter_value altera_jtag_avalon_master_0 {FAST_VER} {0}
	set_instance_parameter_value altera_jtag_avalon_master_0 {FIFO_DEPTHS} {2}
	set_instance_parameter_value altera_jtag_avalon_master_0 {PLI_PORT} {50000}
	set_instance_parameter_value altera_jtag_avalon_master_0 {USE_PLI} {0}
	set_instance_property altera_jtag_avalon_master_0 AUTO_EXPORT true

	# add wirelevel expressions

	# add the exports
	set_interface_property clk EXPORT_OF altera_jtag_avalon_master_0.clk
	set_interface_property clk_reset EXPORT_OF altera_jtag_avalon_master_0.clk_reset
	set_interface_property master_reset EXPORT_OF altera_jtag_avalon_master_0.master_reset
	set_interface_property master EXPORT_OF altera_jtag_avalon_master_0.master

	# set the the module properties
	set_module_property BONUS_DATA {<?xml version="1.0" encoding="UTF-8"?>
<bonusData>
 <element __value="altera_jtag_avalon_master_0">
  <datum __value="_sortIndex" value="0" type="int" />
 </element>
</bonusData>
}
	set_module_property FILE {alt_ehipc2_jtag_avalon.ip}
	set_module_property GENERATION_ID {0x00000000}
	set_module_property NAME {alt_ehipc2_jtag_avalon}

	# save the system
	sync_sysinfo_parameters
	save_system alt_ehipc2_jtag_avalon
}

# create all the systems, from bottom up
do_create_alt_ehipc2_jtag_avalon
