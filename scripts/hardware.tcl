#!/usr/bin/tclsh

# Simple Microblaze+UART design.

source scripts/utils.tcl

# Create project
create_project -force $projname $projpath -part $fpga;

set_property board_part digilentinc.com:basys3:part0:1.1 [current_project];

# Add constraint
add_files -fileset constrs_1 -norecurse ./basys3.xdc

##### Block Design #####

#Importing TEA Catalog
set_property  ip_repo_paths $rootdir/cryptographyIP/TEA/VIVADO_PROJECT [current_project]
update_ip_catalog 

create_bd_design "microcontroller";

# Add clock wizard
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0;
apply_board_connection -board_interface "sys_clock" -ip_intf "clk_wiz_0/clock_CLK_IN1" -diagram "microcontroller";

# Microblaze
create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze:11.0 microblaze_0; 
apply_bd_automation -rule xilinx.com:bd_rule:microblaze -config { axi_intc {0} axi_periph {Enabled} cache {None} clk {/clk_wiz_0/clk_out1 (100 MHz)} debug_module {Debug Only} ecc {None} local_mem {128KB} preset {None}}  [get_bd_cells microblaze_0]

# UART
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:2.0 axi_uartlite_0;
apply_board_connection -board_interface "usb_uart" -ip_intf "axi_uartlite_0/UART" -diagram "microcontroller";

# TEA IP
create_bd_cell -type ip -vlnv SoinMicroelectronic.org:soin_ip:tea_apb_wrapper:1.0 tea_apb_wrapper_0
connect_bd_net [get_bd_pins tea_apb_wrapper_0/PCLK] [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins tea_apb_wrapper_0/PRESETn] [get_bd_pins rst_clk_wiz_0_100M/peripheral_aresetn]

#AXI to APB
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_apb_bridge:3.0 axi_apb_bridge_0
set_property -dict [list CONFIG.C_APB_NUM_SLAVES {1}] [get_bd_cells axi_apb_bridge_0]
connect_bd_net [get_bd_pins axi_apb_bridge_0/s_axi_aclk] [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_apb_bridge_0/s_axi_aresetn] [get_bd_pins rst_clk_wiz_0_100M/peripheral_aresetn]
#TEA Connection
connect_bd_intf_net [get_bd_intf_pins tea_apb_wrapper_0/APB_S] [get_bd_intf_pins axi_apb_bridge_0/APB_M]


# Axi Interconnection
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0
set_property -dict [list CONFIG.NUM_MI {2}] [get_bd_cells axi_interconnect_0]
connect_bd_net [get_bd_pins axi_interconnect_0/ACLK] [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_0/ARESETN]  [get_bd_pins rst_clk_wiz_0_100M/peripheral_aresetn]
#S00
connect_bd_net [get_bd_pins axi_interconnect_0/S00_ACLK] [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_0/S00_ARESETN] [get_bd_pins rst_clk_wiz_0_100M/peripheral_aresetn]
connect_bd_intf_net -boundary_type upper [get_bd_intf_pins axi_interconnect_0/S00_AXI] [get_bd_intf_pins microblaze_0/M_AXI_DP]
#M00
connect_bd_net [get_bd_pins axi_interconnect_0/M00_ACLK] [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_0/M00_ARESETN] [get_bd_pins rst_clk_wiz_0_100M/peripheral_aresetn]
connect_bd_intf_net -boundary_type upper [get_bd_intf_pins axi_interconnect_0/M00_AXI] [get_bd_intf_pins axi_uartlite_0/S_AXI]
#M01
connect_bd_net [get_bd_pins axi_interconnect_0/M01_ACLK] [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_pins axi_interconnect_0/M01_ARESETN] [get_bd_pins rst_clk_wiz_0_100M/peripheral_aresetn]
connect_bd_intf_net -boundary_type upper [get_bd_intf_pins axi_interconnect_0/M01_AXI] [get_bd_intf_pins axi_apb_bridge_0/AXI4_LITE]


# Run Connection Automation
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {reset ( Reset Signal (BTNC) ) } Manual_Source {Auto}}  [get_bd_pins clk_wiz_0/reset];
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {reset ( Reset Signal (BTNC) ) } Manual_Source {New External Port (ACTIVE_LOW)}}  [get_bd_pins rst_clk_wiz_0_100M/ext_reset_in];
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/clk_wiz_0/clk_out1 (100 MHz)} Clk_slave {Auto} Clk_xbar {Auto} Master {/microblaze_0 (Periph)} Slave {/axi_uartlite_0/S_AXI} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins axi_uartlite_0/S_AXI];

#Address Mapping
assign_bd_address

# Validate
validate_bd_design;

# Wrap
make_wrapper -files [get_files $projpath/iot.srcs/sources_1/bd/microcontroller/microcontroller.bd] -top
add_files -norecurse $projpath/iot.srcs/sources_1/bd/microcontroller/hdl/microcontroller_wrapper.v;

# Generate bitstream
#launch_runs impl_1 -to_step write_bitstream -jobs 4;

#wait_on_run impl_1

# Export hardware to SDK
#file mkdir $projpath/iot.sdk;
#file copy -force $projpath/iot.runs/impl_1/microcontroller_wrapper.sysdef $projpath/iot.sdk/$hardware_hdf;

exit 