`include "ddr_pkg.pkg"

class driver;
  
  mailbox gen2drv;
  int no_trans = 0; 
  virtual tb_interface tb_intf;
  virtual ddr_interface ddr_intf; 
  
  
  function new(input mailbox gen2drv, 
               input virtual tb_interface tb_intf, 
               input virtual ddr_interface ddr_intf); 
    
    this.gen2drv = gen2drv; 
    this.tb_intf = tb_intf; 
    this.ddr_intf = ddr_intf; 
    
  endfunction 
  
  /* Get requests from generator, and send to DUT
  */
  task run();
    host_request gen_req;
    tb_intf.rd_data <=  '0; 
    tb_intf.wr_data <=  'z; 
    tb_intf.log_addr <= 'x; 
    tb_intf.request <= NOP;
    tb_intf.CL <= '0;
    tb_intf.AL <= '0;
    tb_intf.CWL <= '0;
    tb_intf.RD_PRE <= '0;
    tb_intf.WR_PRE <= '0;
    tb_intf.cmd_rdy <= 1'b0;
    
    forever
      begin 
        gen2drv.get(gen_req);
        @(negedge ddr_intf.CK_t);
        @(negedge ddr_intf.CK_t)
        tb_intf.cmd_rdy<= 1'b1;
        tb_intf.log_addr <= gen_req.log_addr;
        tb_intf.request <= gen_req.request;
        if(gen_req.request == WR)
          tb_intf.wr_data <= gen_req.wr_data; 
        else tb_intf.wr_data <= 'z; 
        @(negedge ddr_intf.CK_t)
        tb_intf.cmd_rdy <= 1'b0;
        $display("-----------------------------"); 
        $display("@%0t:DRIVER%0d", $time, no_trans); 
        $display("Host Address:%0h\nRequest:%0h\nWrite Data:%0h\n",gen_req.log_addr, gen_req.request, gen_req.wr_data);
        no_trans++; 
      end 
  endtask 
  
endclass 
  
