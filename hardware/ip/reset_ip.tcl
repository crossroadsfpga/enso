package require -exact qsys 18.0

# create the system "reset_ip"
proc do_create_reset_ip {} {
	# create the system
	create_system reset_ip
	set_project_property DEVICE {1SM21BHU2F53E1VG}
	set_project_property DEVICE_FAMILY {Stratix 10}
	set_project_property HIDE_FROM_IP_CATALOG {false}
	set_use_testbench_naming_pattern 0 {}

	# add the components
	add_instance altera_s10_user_rst_clkgate_0 altera_s10_user_rst_clkgate 19.1.0
	set_instance_property altera_s10_user_rst_clkgate_0 AUTO_EXPORT true

	# add wirelevel expressions

	# add the exports
	set_interface_property ninit_done EXPORT_OF altera_s10_user_rst_clkgate_0.ninit_done

	# set the the module properties
	set_module_property BONUS_DATA {<?xml version="1.0" encoding="UTF-8"?>
<bonusData>
 <element __value="altera_s10_user_rst_clkgate_0">
  <datum __value="_sortIndex" value="0" type="int" />
 </element>
</bonusData>
}
	set_module_property FILE {reset_ip.ip}
	set_module_property GENERATION_ID {0x00000000}
	set_module_property NAME {reset_ip}

	# save the system
	sync_sysinfo_parameters
	save_system reset_ip
}

# create all the systems, from bottom up
do_create_reset_ip
