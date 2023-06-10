module CPU (clock,PC, IR, ALUOut, MDR, A, B, reg8);
    parameter R_FORMAT = 6'b000000;
    parameter ADDI     = 6'b001000;
    parameter ANDI     = 6'b001100;
    parameter LW       = 6'b100011;
    parameter SW       = 6'b101011;
    parameter BEQ      = 6'b000100;
    parameter BNE      = 6'b000101;
    parameter MJM      = 6'b110001;
    // other opcodes go here
    //....
    
    input clock;  //the clock is an external input
    //Make these datapath registers available outside the module in order to do the testing
    output PC, IR, ALUOut, MDR, A, B;
    reg[31:0] PC, IR, ALUOut, MDR, A, B;

    
    // The architecturally visible registers and scratch registers for implementation
    reg [31:0] Regs[0:31], Memory [0:1023];
    reg [2:0] state; // processor state
    wire [5:0] opcode; //use to get opcode easily
    wire [31:0] SignExtend, PCOffset; //used to get sign extended offset field
    
    assign opcode = IR[31:26]; //opcode is upper 6 bits
    assign SignExtend = {{16{IR[15]}},IR[15:0]}; //sign extension of lower 16-bits of instruction
    assign PCOffset = SignExtend << 2; //PC offset is shifted
    
    
    wire [31:0] reg8;
    output [31:0] reg8; //output reg 7 for testing
    assign reg8 = Regs[8]; //output reg 8 (i.e. $t0)
    
    
    initial begin      //Load a MIPS test program and data into Memory
        
        Memory[2] = 32'h20080005;  //addi $t0, $zero, 5
        Memory[3] = 32'hac08007c;  //sw $t0, 124($zero)
        Memory[4] = 32'h8c09007c;  //lw $t1, 124($zero)
        Memory[5] = 32'h01094020;  //add $t0, $t0, $t1
        Memory[6] = 32'h21290017;  //addi $t1, $t1, 23
        Memory[7] = 32'h01284022;  //sub $t0, $t1, $t0
        Memory[8] = 32'h11090002;  //beq $t0, $t1, L1
        Memory[9] = 32'h15090002;  //bne $t0, $t1, L2
        Memory[10] = 32'h0000000c;  //L1
        Memory[11] = 32'h0000000c;  //L2
        Memory[12] = 32'hc500007c;  //mjm 124($t0)


    end
    
    
    initial  begin  // set the PC to 8 and start the control in state 1 to start fetch instructions from Memory[2] (byte 8)
        PC = 8;
        state = 1;
    end
    
    always @(posedge clock) begin
        //make R0 0
        //short-cut way to make sure R0 is always 0
        Regs[0] = 0;
        
        case (state) //action depends on the state
        
            1: begin     //first step: fetch the instruction, increment PC, go to next state    
                IR <= Memory[PC>>2]; //changed
                PC <= PC + 4;        //changed
                state = 2; //next state
            end
            
            2: begin
                A <= Regs[IR[25:21]];
                state = 3;
            end
                
            3: begin     //second step: Instruction decode, register fetch, also compute branch address
                B <= Regs[IR[20:16]];
                state= 4;
                ALUOut <= PC + PCOffset;     // compute PC-relative branch target
                if (opcode == ADDI)
                    ALUOut <= A + SignExtend;
                else if (opcode == ANDI)
                    ALUOut <= A & SignExtend;
                else if ((opcode == LW) |(opcode==SW) | (opcode == MJM))
                    ALUOut <= A + SignExtend; //compute effective address
	    end
        
            4: begin     //third step:  Load/Store execution, ALU execution, Branch completion
                state = 5; // default next state
                if (opcode == R_FORMAT)
                    case (IR[5:0]) //case for the various R-type instructions
                        24: ALUOut = A & B; //and operation
                        32: ALUOut = A + B; //add operation
                        34: ALUOut = A - B; //sub operation
                        
                        // other function fields for R-Format instructions go here
                        //  
                        //
                        default: ALUOut = A; //other R-type operations
                    endcase
                
                if ((opcode == ADDI) | (opcode == ANDI)) begin
                    Regs[IR[20:16]] <= ALUOut;
                    state = 1;
                end
                    
                else if (opcode == LW) begin // load instruction
                    MDR <= Memory[ALUOut>>2]; // read the memory
                    state = 5; // next state
                end
                
                else if (opcode == SW) begin
                    Memory[ALUOut>>2] <= B; // write the memory
                    state = 1; // return to state 1
                end //store finishes
                
                if(opcode == MJM) begin
                    PC <= ALUOut;
                    state = 1;
                end
                
                else if (opcode == BEQ) begin
                    if (A==B)  
                        PC <= ALUOut; // branch taken--update PC
                    state = 1;  //  BEQ finished, return to first state
                end
                else if (opcode == BNE) begin
                    if (A!=B)
                        PC <= ALUOut;
                    state = 1;
                end
                
              
            end
        
            5: begin
                if (opcode == R_FORMAT) begin //ALU Operation
                    Regs[IR[15:11]] <= ALUOut; // write the result
                    state = 1;
                end //R-type finishes
		if (opcode == LW) begin
		    Regs[IR[20:16]] = MDR;         // write the MDR to the register
		    state = 1;
		end
            end
                
        endcase
        
    end // always
    
endmodule
