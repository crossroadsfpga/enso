package require -exact qsys 18.0

# create the system "probe8"
proc do_create_probe8 {} {
	# create the system
	create_system probe8
	set_project_property DEVICE {1SM21BHU2F53E1VG}
	set_project_property DEVICE_FAMILY {Stratix 10}
	set_project_property HIDE_FROM_IP_CATALOG {false}
	set_use_testbench_naming_pattern 0 {}

	# add the components
	add_instance altera_in_system_sources_probes_0 altera_in_system_sources_probes 19.1
	set_instance_parameter_value altera_in_system_sources_probes_0 {create_source_clock} {0}
	set_instance_parameter_value altera_in_system_sources_probes_0 {create_source_clock_enable} {0}
	set_instance_parameter_value altera_in_system_sources_probes_0 {gui_use_auto_index} {1}
	set_instance_parameter_value altera_in_system_sources_probes_0 {instance_id} {NONE}
	set_instance_parameter_value altera_in_system_sources_probes_0 {probe_width} {8}
	set_instance_parameter_value altera_in_system_sources_probes_0 {sld_instance_index} {0}
	set_instance_parameter_value altera_in_system_sources_probes_0 {source_initial_value} {0}
	set_instance_parameter_value altera_in_system_sources_probes_0 {source_width} {1}
	set_instance_property altera_in_system_sources_probes_0 AUTO_EXPORT true

	# add wirelevel expressions

	# add the exports
	set_interface_property sources EXPORT_OF altera_in_system_sources_probes_0.sources
	set_interface_property probes EXPORT_OF altera_in_system_sources_probes_0.probes

	# set the the module properties
	set_module_property BONUS_DATA {<?xml version="1.0" encoding="UTF-8"?>
<bonusData>
 <element __value="altera_in_system_sources_probes_0">
  <datum __value="_sortIndex" value="0" type="int" />
 </element>
</bonusData>
}
	set_module_property FILE {probe8.ip}
	set_module_property GENERATION_ID {0x00000000}
	set_module_property NAME {probe8}

	# save the system
	sync_sysinfo_parameters
	save_system probe8
}

# create all the systems, from bottom up
do_create_probe8
