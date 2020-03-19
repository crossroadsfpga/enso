# (C) 2001-2019 Intel Corporation. All rights reserved.
# Your use of Intel Corporation's design tools, logic functions and other 
# software and tools, and its AMPP partner logic functions, and any output 
# files from any of the foregoing (including device programming or simulation 
# files), and any associated documentation or information are expressly subject 
# to the terms and conditions of the Intel Program License Subscription 
# Agreement, Intel FPGA IP License Agreement, or other applicable 
# license agreement, including, without limitation, that your use is for the 
# sole purpose of programming logic devices manufactured by Intel and sold by 
# Intel or its authorized distributors.  Please refer to the applicable 
# agreement for further details.


#####################################################################
#
# THIS IS AN AUTO-GENERATED FILE!
# -------------------------------
# If you modify this files, all your changes will be lost if you
# regenerate the core!
#
# FILE DESCRIPTION
# ----------------
# This file contains the timing constraints for the Intel Native eSRAM IP.

set script_dir [file dirname [info script]]

source "$script_dir/stratix10_esram_sdc_parameters.tcl"

set ::GLOBAL_corename_debug 0
set ::GLOBAL_corename $var(ip_name)

# ----------------------------------------------------------------
#
# Load required package
#
catch {
    load_package design
} err_loading_packages

# ----------------------------------------------------------------
#
proc ai_post_message {msg_type msg {msg_context sta_only}} {
#
# Description: Posts a message to Quartus, depending on 
# msg_context (sta_only, all)
#              
#              
#
# ----------------------------------------------------------------

    if {$msg_type == "debug"} {
        if {$::GLOBAL_corename_debug} {
            puts $msg
        }
    } else {
        if {$msg_context == "all"} {
            post_message -type $msg_type $msg
        } elseif {$msg_context == "sta_only"} {
            if {$::TimeQuestInfo(nameofexecutable) == "quartus_sta"} {
                post_message -type $msg_type $msg
            }
        }
    }
}


# ----------------------------------------------------------------
#
proc ai_get_core_full_instance_list {corename} {
#
# Description: Finds the instances of the particular IP by searching through the cells
#
# ----------------------------------------------------------------
    set instance_list [design::get_instances -entity $corename]
    return $instance_list
}



# ----------------------------------------------------------------
#
proc ai_get_core_instance_list {corename} {
#
# Description: Converts node names from one style to another style
#
# ----------------------------------------------------------------
    set full_instance_list [ai_get_core_full_instance_list $corename]
    set instance_list [list]

    foreach inst $full_instance_list {
        if {[lsearch $instance_list [escape_brackets $inst]] == -1} {
            ai_post_message debug "Found instance:  $inst"
            lappend instance_list $inst
        }
    }
    return $instance_list
}


# ----------------------------------------------------------------
#
proc ai_initialize_esram_db { esram_db_par var_array_name } {
#
# Description: Gets the instances of this particular ESRAM IP and creates the pin
#              cache
#
# ----------------------------------------------------------------
    upvar $esram_db_par local_esram_db
    upvar 1 $var_array_name var

    global ::GLOBAL_corename

    ai_post_message info "Initializing eSRAM database for CORE $::GLOBAL_corename"
    set instance_list [ai_get_core_instance_list $::GLOBAL_corename]

    foreach instname $instance_list {
        ai_post_message info "Finding port-to-pin mapping for CORE: $::GLOBAL_corename INSTANCE: $instname"
        ai_get_esram_pins $instname allpins var
        set local_esram_db($instname) [ array get allpins ]
    }
}

# ----------------------------------------------------------------
#
proc ai_get_esram_pins { instname allpins var_array_name } {
#
# Description: Gets the pins of interest for this instance
#
# ----------------------------------------------------------------
    upvar allpins pins
    upvar 1 $var_array_name var

    set pins(src) "${instname}|mega_iopll|iopll|stratix10_altera_iopll_i|s10_iopll.fourteennm_pll|vcoph[0]"
    set pins(itgt)  "${instname}|fourteennm_cpa_component|pa_core_clk_out[0]"
    set pins(itgt1) "${instname}|fourteennm_cpa_component|pa_core_clk_out[1]"
    set pins(tgt) "${instname}|fourteennm_esram_component|esram2f_clk_from_cip[0]"
    set pins(tgt1) "${instname}|fourteennm_esram_component|esram2f_clk_from_cip[1]"
    set pins(c0clk) "${instname}|mega_iopll|iopll|stratix10_altera_iopll_i|s10_iopll.fourteennm_pll~c0cntr_reg"
}

# Find required information including pin names
ai_initialize_esram_db esram_db_${::GLOBAL_corename} var
upvar 0 esram_db_${::GLOBAL_corename} local_db

set instances [ array names local_db ]
foreach { inst } $instances {
    if { [ info exists pins ] } {
        unset pins
    }
    array set pins $local_db($inst)
   
    # Clock constraints
    create_generated_clock -name ${inst}_cpa_clk0 -source [get_pins $pins(src)] -divide_by $var(vco_divider) [get_pins $pins(itgt)]
    create_generated_clock -name ${inst}_cpa_clk1 -source [get_pins $pins(src)] -divide_by $var(vco_divider) [get_pins $pins(itgt1)]
    create_generated_clock -name ${inst}_clk0 -source [get_pins $pins(itgt)]  -divide_by 1 [get_pins $pins(tgt)]
    create_generated_clock -name ${inst}_clk1 -source [get_pins $pins(itgt1)] -divide_by 1 [get_pins $pins(tgt1)]
    if { $var(vco_div_internal) != 1} {
       # Skip this generated clock when VCO divisor is 1
       create_generated_clock -name ${inst}_internal -source [get_pins $pins(src)] -divide_by $var(vco_div_internal) $pins(c0clk) 
    }

   
}



