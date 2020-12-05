get_device_names -hardware_name "Intel Stratix 10 MX FPGA Development Kit \[1-13\]"

#  Open Signal Tap session
open_session -name stp1.stp
###  Start acquisition of instances sld_signaltap and
###  auto_signaltap_1 at the same time
# Calling run_multiple_end starts all instances
# run_multiple_start
run -instance "auto_signaltap_0" \
    -signal_set "signal_set: 2020/12/03 12:35:57  #0" \
    -trigger "trigger: 2020/12/03 12:36:25  #0" \
    -hardware_name "Intel Stratix 10 MX FPGA Development Kit \[1-13\]" \
    -device_name "1SM21BHN(1|2|3)|1SM21BHU1|..@1#1-13#Intel Stratix 10 MX FPGA Development Kit" \
    -data_log log_1 -timeout 10
# run -instance auto_signaltap_1 -signal_set signal_set_1 -trigger \
# trigger_1 -data_log log_1 -timeout 5
# run_multiple_end


# Close Signal Tap session
close_session
