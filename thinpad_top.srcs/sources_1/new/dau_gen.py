#!/usr/bin/env python
"""
Generates a unified device access unit with instruction and data devices to control unit.
"""

from __future__ import print_function

import argparse
import math
from jinja2 import Template

def main():
    parser = argparse.ArgumentParser(description=__doc__.strip())
    parser.add_argument('-d', '--devices',  type=int, default=3, help="number of external devices.")
    parser.add_argument('-n', '--name',   type=str, help="module name")
    parser.add_argument('-o', '--output', type=str, help="output file name")

    args = parser.parse_args()

    try:
        generate(**args.__dict__)
    except IOError as ex:
        print(ex)
        exit(1)

def generate(devices=3, name=None, output=None):
    if name is None:
        name = "dau_{0}".format(devices)

    if output is None:
        output = name + ".sv"

    print("Opening file '{0}'...".format(output))

    output_file = open(output, 'w')

    print("Generating {0} devices DAU. {1}...".format(devices, name))

    select_width = int(math.ceil(math.log(devices, 2)))

    t = Template(u"""
`timescale 1 ns / 1 ps

module {{name}} (
    input wire sys_clk,
    input wire sys_rst,

    // Interface to Control Unit - Instruction
    input wire         instr_re_i,
    input wire  [31:0] instr_addr_i,
    output wire [31:0] instr_data_o,
    output wire        instr_ack_o,

    // Interface to Control Unit - Data
    input  wire        we_i,
    input  wire        re_i,
    input  wire [31:0] addr_i,
    input  wire [ 3:0] byte_en,
    input  wire [31:0] data_i,
    output wire [31:0] data_o,
    output wire ack_o,

    // Interface to External device
    /* Add desired interfaces here, such as UART, SRAM, Flash, ... */
);
   // This module could be illustrated as the diagram below.

   // +-------------+    +--------+        +---------------+   +------------------+
   // | instruction | ---| i-mux  |+-+-----| Ext arbiter 1 |---| Ext controller 1 |
   // +-------------+    +--------+  |  +--|               |   |    (slave)       |
   //                                |  |  +---------------+   +------------------+
   //                                |  |  +---------------+   +------------------+
   //                                +-----| Ext arbiter 2 |---| Ext controller 2 |
   //                                |  +--|               |   |     (slave)      |
   //                                |  |  +---------------+   +------------------+
   //                                |  |  +---------------+   +------------------+
   // +-------------+    +--------+  +-----| Ext arbiter 3 |---| Ext controller 3 |
   // | data        | ---| d-mux  |--|--+--|               |   |     (slave)      |
   // +-------------+    +--------+  |  |  +---------------+   +------------------+
   //                                |  |        ...                ...

    logic        instr_wbm_cyc_o;
    logic        instr_wbm_stb_o;
    logic        instr_wbm_ack_i;
    logic [31:0] instr_wbm_adr_o;
    logic [31:0] instr_wbm_dat_o;
    logic [31:0] instr_wbm_dat_i;
    logic [ 3:0] instr_wbm_sel_o;
    logic        instr_wbm_we_o;

    // dau_master -- For Data part
    dau_master_comb #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) instruction_master (
        .clk_i(sys_clk),
        .rst_i(sys_rst),

        // Interface to control unit
        .we(1'b0),
        .re(instr_re_i),
        .addr(instr_addr_i),
        .byte_en(4'b1111),
        .data_i(32'b0),
        .data_o(instr_data_o),
        .ack_o(instr_ack_o),
        
        // wishbone master
        .wb_cyc_o(instr_wbm_cyc_o),
        .wb_stb_o(instr_wbm_stb_o),
        .wb_ack_i(instr_wbm_ack_i),
        .wb_adr_o(instr_wbm_adr_o),
        .wb_dat_o(instr_wbm_dat_o),
        .wb_dat_i(instr_wbm_dat_i),
        .wb_sel_o(instr_wbm_sel_o),
        .wb_we_o (instr_wbm_we_o)
    );


    logic        data_wbm_cyc_o;
    logic        data_wbm_stb_o;
    logic        data_wbm_ack_i;
    logic [31:0] data_wbm_adr_o;
    logic [31:0] data_wbm_dat_o;
    logic [31:0] data_wbm_dat_i;
    logic [ 3:0] data_wbm_sel_o;
    logic        data_wbm_we_o;

    // dau_master -- For Data part
    dau_master_comb #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) data_master (
        .clk_i(sys_clk),
        .rst_i(sys_rst),

        // Interface to control unit
        .we(we_i),
        .re(re_i),
        .addr(addr_i),
        .byte_en(byte_en),
        .data_i(data_i),
        .data_o(data_o),
        .ack_o(ack_o),
        
        // wishbone master
        .wb_cyc_o(data_wbm_cyc_o),
        .wb_stb_o(data_wbm_stb_o),
        .wb_ack_i(data_wbm_ack_i),
        .wb_adr_o(data_wbm_adr_o),
        .wb_dat_o(data_wbm_dat_o),
        .wb_dat_i(data_wbm_dat_i),
        .wb_sel_o(data_wbm_sel_o),
        .wb_we_o (data_wbm_we_o)
    );

    /* =========== Master end =========== */

    /* =========== MUX for Instruction begin =========== */
{% for p in devices %}
    logic instr_mux_arb{{p}}_cyc_o;
    logic instr_mux_arb{{p}}_stb_o;
    logic instr_mux_arb{{p}}_ack_i;
    logic [31:0] instr_mux_arb{{p}}_adr_o;
    logic [31:0] instr_mux_arb{{p}}_dat_o;
    logic [31:0] instr_mux_arb{{p}}_dat_i;
    logic [ 3:0] instr_mux_arb{{p}}_sel_o;
    logic instr_mux_arb{{p}}_we_o;

{%- endfor %}

    device_access_mux instr_mux (
        .clk(sys_clk),
        .rst(sys_rst),

        // Master interface
        .wbm_adr_i(instr_wbm_adr_o),
        .wbm_dat_i(instr_wbm_dat_o),
        .wbm_dat_o(instr_wbm_dat_i),
        .wbm_we_i (instr_wbm_we_o),
        .wbm_sel_i(instr_wbm_sel_o),
        .wbm_stb_i(instr_wbm_stb_o),
        .wbm_ack_o(instr_wbm_ack_i),
        .wbm_err_o(),
        .wbm_rty_o(),
        .wbm_cyc_i(instr_wbm_cyc_o),

{% for p in devices %}
        // Slave interface {{p}}
        .wbs{{p}}_addr    (32'h000{{p}}_0000),
        .wbs{{p}}_addr_msk(32'h000{{p}}_0000), // TODO: Modify to match what you wants to allocate.

        .wbs{{p}}_adr_o(instr_mux_arb{{p}}_adr_o),
        .wbs{{p}}_dat_i(instr_mux_arb{{p}}_dat_i),
        .wbs{{p}}_dat_o(instr_mux_arb{{p}}_dat_o),
        .wbs{{p}}_we_o (instr_mux_arb{{p}}_we_o),
        .wbs{{p}}_sel_o(instr_mux_arb{{p}}_sel_o),
        .wbs{{p}}_stb_o(instr_mux_arb{{p}}_stb_o),
        .wbs{{p}}_ack_i(instr_mux_arb{{p}}_ack_i),
        .wbs{{p}}_err_i('0),
        .wbs{{p}}_rty_i('0),
        .wbs{{p}}_cyc_o(instr_mux_arb{{p}}_cyc_o),

{%- endfor %}
    );
    
{% for p in devices %}
    logic data_mux_arb{{p}}_cyc_o;
    logic data_mux_arb{{p}}_stb_o;
    logic data_mux_arb{{p}}_ack_i;
    logic [31:0] data_mux_arb{{p}}_adr_o;
    logic [31:0] data_mux_arb{{p}}_dat_o;
    logic [31:0] data_mux_arb{{p}}_dat_i;
    logic [ 3:0] data_mux_arb{{p}}_sel_o;
    logic data_mux_arb{{p}}_we_o;

{%- endfor %}

    device_access_mux instr_mux (
        .clk(sys_clk),
        .rst(sys_rst),

        // Master interface
        .wbm_adr_i(data_wbm_adr_o),
        .wbm_dat_i(data_wbm_dat_o),
        .wbm_dat_o(data_wbm_dat_i),
        .wbm_we_i (data_wbm_we_o),
        .wbm_sel_i(data_wbm_sel_o),
        .wbm_stb_i(data_wbm_stb_o),
        .wbm_ack_o(data_wbm_ack_i),
        .wbm_err_o(),
        .wbm_rty_o(),
        .wbm_cyc_i(data_wbm_cyc_o),

{% for p in devices %}
        // Slave interface {{p}}
        .wbs{{p}}_addr    (32'h000{{p}}_0000),
        .wbs{{p}}_addr_msk(32'h000{{p}}_0000), // TODO: Modify to match what you wants to allocate.

        .wbs{{p}}_adr_o(data_mux_arb{{p}}_adr_o),
        .wbs{{p}}_dat_i(data_mux_arb{{p}}_dat_i),
        .wbs{{p}}_dat_o(data_mux_arb{{p}}_dat_o),
        .wbs{{p}}_we_o (data_mux_arb{{p}}_we_o),
        .wbs{{p}}_sel_o(data_mux_arb{{p}}_sel_o),
        .wbs{{p}}_stb_o(data_mux_arb{{p}}_stb_o),
        .wbs{{p}}_ack_i(data_mux_arb{{p}}_ack_i),
        .wbs{{p}}_err_i('0),
        .wbs{{p}}_rty_i('0),
        .wbs{{p}}_cyc_o(data_mux_arb{{p}}_cyc_o),

{%- endfor %}
    );
    /* =========== Slaves begin =========== */
    // 1. The arbiters
{% for p in devices %}
    logic wbs{{p}}_cyc_o;
    logic wbs{{p}}_stb_o;
    logic wbs{{p}}_ack_i;
    logic [31:0] wbs{{p}}_adr_o;
    logic [31:0] wbs{{p}}_dat_o;
    logic [31:0] wbs{{p}}_dat_i;
    logic [3:0] wbs{{p}}_sel_o;
    logic wbs{{p}}_we_o;

    wb_arbiter_2 #(
        .ARB_LSB_HIGH_PRIORITY(1)
    ) arbiter_{{p}}(
        .clk(sys_clk),
        .rst(sys_rst),
    /*
     * Wishbone master 1 input
     */
     .wbm1_adr_i(instr_mux_arb{{p}}_adr_o),
     .wbm1_dat_i(instr_mux_arb{{p}}_dat_o),
     .wbm1_dat_o(instr_mux_arb{{p}}_dat_i),
     .wbm1_we_i (instr_mux_arb{{p}}_we_o),
     .wbm1_sel_i(instr_mux_arb{{p}}_sel_o),
     .wbm1_stb_i(instr_mux_arb{{p}}_stb_o),
     .wbm1_ack_o(instr_mux_arb{{p}}_ack_i),
     .wbm1_err_o(),
     .wbm1_rty_o(),
     .wbm1_cyc_i(instr_mux_arb{{p}}_cyc_o),

    /*
     * Wishbone master 0 input
     */
     .wbm0_adr_i(data_mux_arb{{p}}_adr_o),
     .wbm0_dat_i(data_mux_arb{{p}}_dat_o),
     .wbm0_dat_o(data_mux_arb{{p}}_dat_i),
     .wbm0_we_i (data_mux_arb{{p}}_we_o),
     .wbm0_sel_i(data_mux_arb{{p}}_sel_o),
     .wbm0_stb_i(data_mux_arb{{p}}_stb_o),
     .wbm0_ack_o(data_mux_arb{{p}}_ack_i),
     .wbm0_err_o(),
     .wbm0_rty_o(),
     .wbm0_cyc_i(data_mux_arb{{p}}_cyc_o),

    /*
     * Wishbone slave output
     */
     .wbs_adr_o(wbs{{p}}_adr_o),
     .wbs_dat_i(wbs{{p}}_dat_i),
     .wbs_dat_o(wbs{{p}}_dat_o),
     .wbs_we_o (wbs{{p}}_we_o),
     .wbs_sel_o(wbs{{p}}_sel_o),
     .wbs_stb_o(wbs{{p}}_stb_o),
     .wbs_ack_i(wbs{{p}}_ack_i),
     .wbs_err_i(1'b0),
     .wbs_rty_i(1'b0),
     .wbs_cyc_o(wbs{{p}}_cyc_o)
    );

{%- endfor %}

    // 2. The controllers

    {% for p in devices %}
    /* TODO: Module name */ #(
        /* TODO: parameters*/
    ) /* TODO: Instance name */ (
        .clk_i(sys_clk),
        .rst_i(sys_rst),

        // Wishbone slave (to MUX)
        .wb_cyc_i(wbs{{p}}_cyc_o),
        .wb_stb_i(wbs{{p}}_stb_o),
        .wb_ack_o(wbs{{p}}_ack_i),
        .wb_adr_i(wbs{{p}}_adr_o),
        .wb_dat_i(wbs{{p}}_dat_o),
        .wb_dat_o(wbs{{p}}_dat_i),
        .wb_sel_i(wbs{{p}}_sel_o),
        .wb_we_i (wbs{{p}}_we_o),

        /* TODO: Other ports in interest. */
    );

{%- endfor %}
endmodule

""")
    
    output_file.write(t.render(
        n=devices,
        w=select_width,
        name=name,
        devices=range(devices)
    ))
    
    print("Done")

if __name__ == "__main__":
    main()

