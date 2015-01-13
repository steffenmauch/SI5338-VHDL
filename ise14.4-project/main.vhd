----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Steffen Mauch [steffen.mauch (at) gmail.com]
-- Create Date:    10:33:30 11/28/2013 
-- Design Name: 
-- Module Name:    main - Behavioral 
-- Project Name:   si5338-vhdl implementation
-- Target Devices: Xilinx Kintex-7
-- Tool versions: 
-- Description: 		LICENSE: BSD!
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
--
-- Copyright (c) 2013/2014, Steffen Mauch
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice, this
--    list of conditions and the following disclaimer. 
-- 2. Redistributions in binary form must reproduce the above copyright notice,
--    this list of conditions and the following disclaimer in the documentation
--    and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
-- ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-- The views and conclusions contained in the software and documentation are those
-- of the authors and should not be interpreted as representing official policies, 
-- either expressed or implied, of the FreeBSD Project.
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity main is
PORT(
    --reset	  			: in  std_logic;
	 
	 LED 					: out std_logic_vector( 7 downto 0 );
	 BOARD_LED_RED		: out std_logic;
	 BOARD_LED_GREEN	: out std_logic;
	 SI5338_SCL			: inout std_logic;
	 SI5338_SDA			: inout std_logic;
	 CLK0_SI5338		: in  std_logic;
	 SI5338_CLK_EN		: out std_logic;
	 SI5338_IN4			: out std_logic
	 );
end main;

architecture Behavioral of main is

component si5338 is
	GENERIC(
    input_clk 		: INTEGER := 50_000_000; --input clock speed from user logic in Hz
	 i2c_address	: std_logic_vector(6 downto 0) := "111" & "0000";
    bus_clk   		: INTEGER := 400_000);   --speed the i2c bus (scl) will run at in Hz
	port
		(
			clk     		: in std_logic;
			reset			: in std_logic;
			
			done			: out std_logic;
			error			: out std_logic;
						
			SCL 			: inout std_logic;
			SDA 			: inout std_logic
		);
end component;


attribute S: string;

signal done : std_logic;
signal reset_internal : std_logic;

signal error : std_logic;
signal EOS : std_logic;

signal clk0 : std_logic;
signal clock_internal : std_logic;
attribute S of clock_internal : signal is "TRUE";
signal clock_internal_i : std_logic;

begin

STARTUPE2_inst : STARTUPE2
generic map (
   PROG_USR => "FALSE",  -- Activate program event security feature. Requires encrypted bitstreams.
   SIM_CCLK_FREQ => 20.0  -- Set the Configuration Clock Frequency(ns) for simulation.
)
port map (
   --CFGCLK => CFGCLK,       -- 1-bit output: Configuration main clock output
   CFGMCLK => clock_internal_i,     -- 1-bit output: Configuration internal oscillator clock output
	-- configured to 50 MHz while generating bit file!
   EOS => EOS,             -- 1-bit output: Active high output signal indicating the End Of Startup.
   --PREQ => PREQ,           -- 1-bit output: PROGRAM request to fabric output
   CLK => '0',             -- 1-bit input: User start-up clock input
   GSR => '0',             -- 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
   GTS => '0',             -- 1-bit input: Global 3-state input (GTS cannot be used for the port name)
   KEYCLEARB => '0', -- 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
   PACK => '0',           -- 1-bit input: PROGRAM acknowledge input
   USRCCLKO => '0',   -- 1-bit input: User CCLK input
   USRCCLKTS => '0', -- 1-bit input: User CCLK 3-state enable input
   USRDONEO => '1',   -- 1-bit input: User DONE pin output control
   USRDONETS => '1'  -- 1-bit input: User DONE 3-state enable output
);

clock_internal_bufg_inst : BUFG
port map (
   O => clock_internal,  				-- Clock buffer output
   I => clock_internal_i
);

IBUFG_inst : IBUFG
port map (
   O => clk0,  				-- Clock buffer output
   I => CLK0_SI5338
);

SI5338_IN4 <= '0';
SI5338_CLK_EN <= '1';

reset_internal <= not EOS;

BOARD_LED_RED <=  done;
BOARD_LED_GREEN <= EOS;

LED(7) <= error;
LED( 6 downto 4 ) <= done & done & done;
LED(3) <= clk0;
LED(2) <= EOS;
LED(1) <= clock_internal;
LED(0) <= done;

si5338_inst : si5338 
	generic map(
		input_clk 		=> 65_000_000, --input clock speed from user logic in Hz
		i2c_address		=> "111" & "0000",
		bus_clk   		=> 400_000    --speed the i2c bus (scl) will run at in Hz
	)
	port map(
		clk     		=> clock_internal,
		reset			=> reset_internal,
				
		done			=> done,
		error			=> error,
		
		SCL 			=> SI5338_SCL,
		SDA 			=> SI5338_SDA
	);



end Behavioral;

