# compile

# elaboration + simulation

# simulation with gui

vlib work                           // Create your work area for the simulation – Run only the first time. 
vlog -f ../src_list/fpga_lib_sim.f  // Load the Verilog files. 
vsim tb                             // Open a simulation session with "tb" as the top module.


vsim work.tb -c -do 'run -all'
