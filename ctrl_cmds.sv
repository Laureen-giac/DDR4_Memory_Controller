/***********************************************************************************
  * Script : ctrl_cmds.sv *
  * Author: Laureen Giacaman *
  * Description: This module is responsible for programming the DDR4 with 	->the set of commands from JEDEC sec4.1 pg: 24.
  ->The supported commands should be: MRS, REF, PRE(PREA*),ACT,WR(WRA*),
  	RD(RDA*), NOP, DES, ZQCL

  **ERRORS: DES is the default command:::FIXED
  **careful of NOP::FIXED, @ decode
****************************************************************************/


`include "ddr_pkg.pkg"


module ctrl_cmds(ctrl_interface ctrl_intf, ddr_interface ddr_intf, tb_interface tb_intf);

  rw_request host_req, rw_cmd_out;
  rw_request rw_cmd_queue[$];
  command_type cmd_out;
  mem_addr_type mem_addr; 
  bit act_cmd_d; 
  
  always_ff @(ddr_intf.CK_t) begin
    act_cmd_d <= tb_intf.cmd_rdy;
  end

  /*
  Asych. reset
  */

  always_comb
    begin
      if(!ddr_intf.reset_n) begin
        rw_cmd_queue.delete(); 
      end
    end 
      
      always_comb
        begin
          if(tb_intf.cmd_rdy && !ctrl_intf.busy) begin
             
            mem_addr = address_decode(tb_intf.phy_addr, mem_addr); 
            if(mem_addr) begin
              ctrl_intf.mem_addr = mem_addr;
              ctrl_intf.req = tb_intf.request;
            end 
            else begin 
              ctrl_intf.mem_addr = 'x; 
              ctrl_intf.req = 'x;
            end
          end 
        end 
      
      always_comb
        begin
          if(ctrl_intf.act_rdy || ctrl_intf.no_act_rdy) begin
            host_req.phy_addr = ctrl_intf.mem_addr;
            host_req.request = ctrl_intf.req; //GEN
            if(host_req.phy_addr) begin 
              rw_cmd_queue.push_back(host_req);
            end
          end
        end
  
  always_ff@(posedge ctrl_intf.cas_rdy) begin
    if(rw_cmd_queue.size() != 0 ) begin 
       rw_cmd_out = rw_cmd_queue.pop_front();
    end 
  end 
  
    
  /* Generating the commands is combo logic
  */

  always_comb//(ctrl_intf.act_rdy, ctrl_intf.rd_rdy, ctrl_intf.wr_rdy,  ctrl_intf.rda_rdy , ctrl_intf.wra_rdy , ctrl_intf.mrs_rdy , ctrl_intf.refresh_rdy , ctrl_intf.pre_rdy , ctrl_intf.prea_rdy , ctrl_intf.zqcl_rdy , ctrl_intf.des_rdy)
   begin

     /*
     Need to send memory @ here
     */

     if(ctrl_intf.act_rdy)
      begin
        cmd_out.cmd = ACT;
        cmd_out.req.phy_addr = mem_addr;
        cmd_out.req.request = 2'b00;
      end
     
    else if(ctrl_intf.cas_rdy) 
       begin
         if(rw_cmd_out.request == WR_R) begin 
           cmd_out.cmd = WR;
           cmd_out.req.phy_addr = rw_cmd_out.phy_addr; 
         end 
         
         else if(rw_cmd_out.request == RD_R)begin 
           cmd_out.cmd = RD; 
           cmd_out.req.phy_addr = rw_cmd_out.phy_addr; 
         end 
         
         else if(rw_cmd_out.request == WRA_R) begin 
           cmd_out.cmd = WRA; 
           cmd_out.req.phy_addr = rw_cmd_out.phy_addr; 
         end 
         
         else if(rw_cmd_out.request == RDA_R) begin 
           cmd_out.cmd = RDA; 
           cmd_out.req.phy_addr = rw_cmd_out.phy_addr;
         end 
       end 
     
     else begin
       cmd_out.cmd = NOP;
       cmd_out.req.phy_addr = '1;
       cmd_out.req.request = NOP_R; 
     end
     
     if(ctrl_intf.rd_rdy)begin 
       ctrl_intf.dimm_req = RD_R;
     end 
     
     if(ctrl_intf.wr_rdy)begin 
       ctrl_intf.dimm_req = WR_R; 
     end 
     
     if(ctrl_intf.mrs_rdy) begin
       cmd_out.cmd = MRS;
       cmd_out.req.phy_addr = {ctrl_intf.mode_reg, 10'b1};
     end
     
     if(ctrl_intf.refresh_rdy) begin
       cmd_out.cmd = REF;
     end

     if(ctrl_intf.pre_rdy) begin
       cmd_out.cmd = PRE;
       cmd_out.req.phy_addr = {ctrl_intf.pre_reg, 10'b1};
     end

     if(ctrl_intf.prea_rdy) begin
       cmd_out.cmd = PREA;
       cmd_out.req.phy_addr = {ctrl_intf.pre_reg, 10'b1};
     end
     
     if(ctrl_intf.zqcl_rdy) begin
       cmd_out.cmd = ZQCL;
     end
     
     if(ctrl_intf.des_rdy) begin
       cmd_out.cmd = DES;
       cmd_out.req.phy_addr = {ctrl_intf.mode_reg, 10'b1};
     end
   end

  /* Decoding the commands. Refer to JEDEC sec4.1 pg:24
  */

  always_ff @(posedge ddr_intf.CK_t)
    begin
      if ((ctrl_intf.act_rdy)
        ||(ctrl_intf.rd_rdy)
        ||(ctrl_intf.wr_rdy)
        ||(ctrl_intf.rda_rdy)
        ||(ctrl_intf.wra_rdy)
        ||(ctrl_intf.mrs_rdy)
        ||(ctrl_intf.refresh_rdy)
        ||(ctrl_intf.pre_rdy)
        ||(ctrl_intf.zqcl_rdy)
        ||(ctrl_intf.cas_rdy)  
        ||(ctrl_intf.des_rdy))
        
        begin 
          case(cmd_out.cmd)
            ACT: begin
              ddr_intf.cs_n <= 1'b0;
          	  ddr_intf.act_n <= 1'b0;
              ddr_intf.RAS_n_A16 <= 1'b1;
              ddr_intf.CAS_n_A15 <= 1'b1;
              ddr_intf.WE_n_A14 <= 1'b1;
          	  ddr_intf.bg_addr <= cmd_out.req.phy_addr.bg_addr;
          	  ddr_intf.ba_addr <= cmd_out.req.phy_addr.ba_addr;
          	  ddr_intf.A12_BC_n <= cmd_out.req.phy_addr.row_addr[12];
              ddr_intf.A17 <= 1'b1;
          	  ddr_intf.A13 <= cmd_out.req.phy_addr.row_addr[13];
          	  ddr_intf.A11 <= cmd_out.req.phy_addr.row_addr[11];
          	  ddr_intf.A10_AP <= cmd_out.req.phy_addr.row_addr[10];
          	  ddr_intf.A9_A0 <= cmd_out.req.phy_addr.row_addr[9:0];
            end

            RD: begin
              //$display("decoding read"); 
              ddr_intf.cs_n <= 1'b0;
              ddr_intf.act_n <= 1'b1;
          	  ddr_intf.RAS_n_A16 <= 1'b1;
         	  ddr_intf.CAS_n_A15 <= 1'b0;
          	  ddr_intf.WE_n_A14 <= 1'b1;
          	  ddr_intf.bg_addr <= cmd_out.req.phy_addr.bg_addr;
          	  ddr_intf.ba_addr <= cmd_out.req.phy_addr.ba_addr;
          	  ddr_intf.A12_BC_n <= 1'b1;
          	  ddr_intf.A17 <= 1'b1;
          	  ddr_intf.A13 <= 1'b1;
          	  ddr_intf.A11 <= 1'b1;
          	  ddr_intf.A10_AP <= 1'b0;
          	  ddr_intf.A9_A0 <= cmd_out.req.phy_addr.col_addr;
            end
            
            RDA: begin
              ddr_intf.cs_n <= 1'b0;
          	  ddr_intf.act_n <= 1'b1;
          	  ddr_intf.RAS_n_A16 <= 1'b1;
          	  ddr_intf.CAS_n_A15 <= 1'b0;
          	  ddr_intf.WE_n_A14 <= 1'b0;
          	  ddr_intf.bg_addr <= cmd_out.req.phy_addr.bg_addr;
          	  ddr_intf.ba_addr <= cmd_out.req.phy_addr.ba_addr;
          	  ddr_intf.A12_BC_n <= 1'b0;
          	  ddr_intf.A17 <= 1'b1;
          	  ddr_intf.A13 <= 1'b1;
          	  ddr_intf.A11 <= 1'b1;
          	  ddr_intf.A10_AP <= 1'b1;
          	  ddr_intf.A9_A0 <= cmd_out.req.phy_addr.col_addr;
            end
            
            WR: begin
              //$display("decoding write");
              ddr_intf.cs_n <= 1'b0;
              ddr_intf.act_n <= 1'b1;
              ddr_intf.RAS_n_A16 <= 1'b1;
              ddr_intf.CAS_n_A15 <= 1'b0;
              ddr_intf.WE_n_A14 <= 1'b0;
              ddr_intf.bg_addr <= cmd_out.req.phy_addr.bg_addr;
              ddr_intf.ba_addr <= cmd_out.req.phy_addr.ba_addr;
              ddr_intf.A12_BC_n <= 1'b1;
              ddr_intf.A17 <= 1'b1;
              ddr_intf.A13 <= 1'b1;
              ddr_intf.A11 <= 1'b1;
              ddr_intf.A10_AP <= 1'b0;
              ddr_intf.A9_A0 <= cmd_out.req.phy_addr.col_addr;
            end
            
            WRA: begin
              ddr_intf.cs_n <= 1'b0;
              ddr_intf.act_n <= 1'b1;
              ddr_intf.RAS_n_A16 <= 1'b1;
      	      ddr_intf.CAS_n_A15 <= 1'b0;
              ddr_intf.WE_n_A14 <= 1'b0;
              ddr_intf.bg_addr <= cmd_out.req.phy_addr.bg_addr;
              ddr_intf.ba_addr <= cmd_out.req.phy_addr.ba_addr;
              ddr_intf.A12_BC_n <= 1'b1;
              ddr_intf.A17 <= 1'b1;
              ddr_intf.A13 <= 1'b1;
              ddr_intf.A11 <= 1'b1;
              ddr_intf.A10_AP <= 1'b1;
              ddr_intf.A9_A0 <= cmd_out.req.phy_addr.col_addr[9:0];
            end
            
            REF: begin
              ddr_intf.cs_n <= 1'b0;
              ddr_intf.act_n <= 1'b1;
              ddr_intf.RAS_n_A16 <= 1'b0;
              ddr_intf.CAS_n_A15 <= 1'b0;
    	      ddr_intf.WE_n_A14 <= 1'b1;
              ddr_intf.bg_addr <= '1;
              ddr_intf.ba_addr <= '1;
              ddr_intf.A12_BC_n <= 1'b1;
              ddr_intf.A17 <= 1'b1;
              ddr_intf.A13 <= 1'b1;
              ddr_intf.A11 <= 1'b1;
              ddr_intf.A10_AP <= 1'b1;
              ddr_intf.A9_A0 <= '1;
            end
            
            MRS: begin
              ddr_intf.cs_n <= 1'b0;
              ddr_intf.act_n <= 1'b1;
              ddr_intf.RAS_n_A16 <= 1'b0;
              ddr_intf.CAS_n_A15 <= 1'b0;
              ddr_intf.WE_n_A14 <= 1'b0;
              ddr_intf.bg_addr <= ctrl_intf.mode_reg[18:17];
              ddr_intf.ba_addr <= ctrl_intf.mode_reg[16:15];
              ddr_intf.A12_BC_n <= cmd_out.req.phy_addr.row_addr[12];
              ddr_intf.A17 <= cmd_out.req.phy_addr.row_addr[13];
              ddr_intf.A13 <= cmd_out.req.phy_addr.row_addr[13];
              ddr_intf.A11 <= cmd_out.req.phy_addr.row_addr[11];
              ddr_intf.A10_AP <= cmd_out.req.phy_addr.row_addr[10];
              ddr_intf.A9_A0 <= cmd_out.req.phy_addr.row_addr[9:0];
            end
            
            PRE: begin
              ddr_intf.cs_n <= 1'b0;
              ddr_intf.act_n <= 1'b1;
              ddr_intf.RAS_n_A16 <= 1'b0;
              ddr_intf.CAS_n_A15 <= 1'b1;
              ddr_intf.WE_n_A14 <= 1'b0;
              ddr_intf.bg_addr <= cmd_out.req.phy_addr.bg_addr;
              ddr_intf.ba_addr <= cmd_out.req.phy_addr.ba_addr;
              ddr_intf.A12_BC_n <= 1'b1;
              ddr_intf.A17 <= 1'b1;
              ddr_intf.A13 <= 1'b1;
              ddr_intf.A11 <= 1'b1;
              ddr_intf.A10_AP <= 1'b0;
              ddr_intf.A9_A0 <= '1;
            end
            
            PREA: begin
              ddr_intf.cs_n <= 1'b0;
              ddr_intf.act_n <= 1'b1;
              ddr_intf.RAS_n_A16 <= 1'b0;
              ddr_intf.CAS_n_A15 <= 1'b1;
              ddr_intf.WE_n_A14 <= 1'b0;
              ddr_intf.bg_addr <= '1;
              ddr_intf.ba_addr <= '1;
              ddr_intf.A12_BC_n <= 1'b1;
              ddr_intf.A17 <= 1'b1;
              ddr_intf.A13 <= 1'b1;
              ddr_intf.A11 <= 1'b1;
              ddr_intf.A10_AP <= 1'b1;
              ddr_intf.A9_A0 <= '1;
            end
            
            DES: begin
              ddr_intf.cs_n <= 1'b1;
              ddr_intf.act_n <= 1'bx;
              ddr_intf.RAS_n_A16 <= 1'bx;
              ddr_intf.CAS_n_A15 <= 1'bx;
              ddr_intf.WE_n_A14 <= 1'bx;
              ddr_intf.bg_addr <= 2'bxx;
              ddr_intf.ba_addr <= 2'bxx;
              ddr_intf.A12_BC_n <= 1'bx;
              ddr_intf.A17 <= 1'bx;
              ddr_intf.A13 <= 1'bx;
              ddr_intf.A11 <= 1'bx;
              ddr_intf.A10_AP <= 1'bx;
              ddr_intf.A9_A0 <= 'x;
            end
            
            ZQCL: begin
              ddr_intf.cs_n <= 1'b0;
              ddr_intf.act_n <= 1'b1;
              ddr_intf.RAS_n_A16 <= 1'b1;
              ddr_intf.CAS_n_A15 <= 1'b1;
              ddr_intf.WE_n_A14 <= 1'b0;
              ddr_intf.bg_addr <= 2'b11;
              ddr_intf.ba_addr <= 2'b11;
              ddr_intf.A12_BC_n <= 1'b1;
              ddr_intf.A17 <= 1'b1;
              ddr_intf.A13 <= 1'b1;
              ddr_intf.A11 <= 1'b1;
              ddr_intf.A10_AP <= 1'b1;
              ddr_intf.A9_A0 <= '1;
            end
            
            NOP: begin
              ddr_intf.cs_n <= 1'b0;
              ddr_intf.act_n <= 1'b1;
              ddr_intf.RAS_n_A16 <= 1'b1;
              ddr_intf.CAS_n_A15 <= 1'b1;
              ddr_intf.WE_n_A14 <= 1'b1;
              ddr_intf.bg_addr <= 2'b11;
              ddr_intf.ba_addr <= 2'b11;
              ddr_intf.A12_BC_n <= 1'b1;
              ddr_intf.A17 <= 1'b1;
              ddr_intf.A13 <= 1'b1;
              ddr_intf.A11 <= 1'b1;
              ddr_intf.A10_AP <= 1'b1;
              ddr_intf.A9_A0 <= '1;
            end
            
            default: begin
              ddr_intf.cs_n <= 1'b0;
              ddr_intf.act_n <= 1'b1;
              ddr_intf.RAS_n_A16 <= 1'b1;
              ddr_intf.CAS_n_A15 <= 1'b1;
              ddr_intf.WE_n_A14 <= 1'b1;
              ddr_intf.bg_addr <= 2'b11;
              ddr_intf.ba_addr <= 2'b11;
              ddr_intf.A12_BC_n <= 1'b1;
              ddr_intf.A17 <= 1'b1;
              ddr_intf.A13 <= 1'b1;
              ddr_intf.A11 <= 1'b1;
              ddr_intf.A10_AP <= 1'b1;
              ddr_intf.A9_A0 <= '1;
            end
          endcase

        end

       end

  /*
  capture operating parameters of the MR at initialization
  */
  
  always @(ctrl_intf.mrs_rdy) begin
    case (ctrl_intf.mode_reg [17:15])
     //MR0
     // Supported CL for DDR4 1600 9,10,11,12
     3'b000: begin
       if (int'(ctrl_intf.mode_reg[6:3]) < 4)
            ctrl_intf.CL= 9 + int'(ctrl_intf.mode_reg [6:3]);
       
          else
             ctrl_intf.CL = 9;
       //$display("%d", ctrl_intf.CL); 
        //Get BL
         if (ctrl_intf.mode_reg[1:0] === 2'b10)
            ctrl_intf.BL = 4;
         else
            ctrl_intf.BL = 8;
         end

     //MR1
     3'b001: begin
         if ((int'(ctrl_intf.mode_reg[4:3]) == 1)||
             (int'(ctrl_intf.mode_reg[4:3]) == 2))
             ctrl_intf.AL = ctrl_intf.CL - int'(ctrl_intf.mode_reg[4:3]);
         else
             ctrl_intf.AL = 0;
         end

     //MR2 Supported CWL is 9, 11
     3'b010: begin
       if (int' (ctrl_intf.mode_reg[5:3]) == 0 || int' (ctrl_intf.mode_reg[5:3]) == 2)
             ctrl_intf.CWL = 9 + int'(ctrl_intf.mode_reg[5:3]);
       else
         ctrl_intf.CWL = 9;

       end
    //MR4
     3'b100: begin
          ctrl_intf.RD_PRE = int'(ctrl_intf.mode_reg[11])+ 1;
          ctrl_intf.WR_PRE = int'(ctrl_intf.mode_reg[12])+ 1;
     end

     //MR6
     3'b110: begin
          ctrl_intf.tCCD = 4 + int'(ctrl_intf.mode_reg[12:10]);
     end
     endcase
  end


  //find an algorithm

  function automatic mem_addr_type address_decode(logic[39:0] physical_addr, 
                                                  output mem_addr_type mem_addr);
      mem_addr.bg_addr =  physical_addr[1:0];
   	  mem_addr.ba_addr =  physical_addr[3:2];
 	  mem_addr.row_addr = physical_addr[17:4];
  	  mem_addr.col_addr = physical_addr[27:18];
      
    return mem_addr; 
    
   endfunction
  
  
  
endmodule
