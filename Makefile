# Module & File Config
SIM_MODULE    = wb_1m2s_interconnect_tb

# SystemVerilog Sources
RTL_SV        = rtl/sv/wb_1m2s_interconnect.sv
TB_SV_FILES   = tb/wb_1m2s_interconnect_tb.sv tb/wb_slave_stub.sv

# VHDL Sources (For future VHDL testbench setup)
RTL_VHDL      = rtl/vhdl/wb_1m2s_interconnect.vhd
TB_VHDL_FILES = tb/vhdl/wb_1m2s_interconnect_tb.vhd tb/vhdl/wb_slave_stub.vhd
# The VHDL testbench is not yet implemented, but the structure is in place for future development.


# Tools
VERILATOR     = verilator
GHDL          = ghdl
GHDL_FLAGS    = --std=08

.PHONY: all sim-sv sim-vhdl clean waves

# Default target runs SystemVerilog simulation
all: sim-sv

# SystemVerilog Simulation (Verilator)
sim-sv:
	$(VERILATOR) --binary --timing --trace -Wall \
		-Wno-UNUSEDSIGNAL -Wno-INITIALDLY \
		--top $(SIM_MODULE) $(TB_SV_FILES) $(RTL_SV)
	./obj_dir/V$(SIM_MODULE)

# VHDL Simulation (GHDL)
sim-vhdl:
	mkdir -p work_vhdl
	$(GHDL) -a $(GHDL_FLAGS) --workdir=work_vhdl $(RTL_VHDL) $(TB_VHDL_FILES)
	$(GHDL) -e $(GHDL_FLAGS) --workdir=work_vhdl $(SIM_MODULE)
	$(GHDL) -r $(GHDL_FLAGS) --workdir=work_vhdl $(SIM_MODULE) --vcd=wb_tb_vhdl.vcd

# Waveform viewer
waves:
	gtkwave wb_tb.vcd &

clean:
	rm -rf obj_dir work_vhdl *.vcd *.cf