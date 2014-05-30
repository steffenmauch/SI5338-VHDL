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
-- Copyright (c) <2014, Steffen Mauch
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
    CPLD_XIO_clk		: in  std_logic;
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

signal done : std_logic;
signal reset_internal : std_logic;

signal error : std_logic;

signal clk0 : std_logic;

begin

IBUFG_inst : IBUFG
port map (
   O => clk0,  				-- Clock buffer output
   I => CLK0_SI5338
);


SI5338_IN4 <= '0';
SI5338_CLK_EN <= '1';

reset_internal <= '0';

BOARD_LED_RED <= '1';
BOARD_LED_GREEN <= '0';

LED(7) <= error;
LED( 6 downto 4 ) <= "101";
LED(3) <= clk0;
LED(2) <= SI5338_SCL;
LED(1) <= CPLD_XIO_clk;
LED(0) <= done;

si5338_inst : si5338 
	generic map(
		input_clk 		=> 25_000_000, --input clock speed from user logic in Hz
		i2c_address		=> "111" & "0000",
		bus_clk   		=> 400_000    --speed the i2c bus (scl) will run at in Hz
	)
	port map(
		clk     		=> CPLD_XIO_clk,
		reset			=> reset_internal,
				
		done			=> done,
		error			=> error,
		
		SCL 			=> SI5338_SCL,
		SDA 			=> SI5338_SDA
	);



end Behavioral;

