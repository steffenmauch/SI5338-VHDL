----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Steffen Mauch [steffen.mauch (at) gmail.com]
-- 
-- Create Date:    08:42:49 12/03/2013 
-- Design Name: 
-- Module Name:    tb_si5338 - testbench 
-- Project Name:   si5338-vhdl testbench
-- Target Devices: Xilinx Kintex-7
-- Tool versions: 
-- Description: 		LICENSE: BSD!
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
--
-- The MIT License (MIT)
--
-- Copyright (c) 2014 Steffen Mauch
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
----------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY tb_si5338 IS
END tb_si5338;
 
ARCHITECTURE behavior OF tb_si5338 IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
	component si5338 is
		generic(
		input_clk 		: INTEGER := 50_000_000; --input clock speed from user logic in Hz
		i2c_address		: std_logic_vector(6 downto 0) := "111" & "0000";
		bus_clk   		: INTEGER := 400_000);   --speed the i2c bus (scl) will run at in Hz
	port(
		clk     		: in std_logic;
		reset			: in std_logic;
			
		done			: out std_logic;
			
		error 		: out std_logic;
			
		SCL 			: inout std_logic;
		SDA 			: inout std_logic
	);
	end component si5338;
	
	component i2c_slave_si5338 is
--   generic (
--		SLAVE_ADDR 	: std_logic_vector( 6 downto 0 ) := "111" & "0000";
--		SDA_DELAY 	: integer range 1 to 16 := 5
--	);
   port(
      clk			: in std_logic;
      reset_n		: in std_logic;

      -- I2C clock and data (SDA is open drain)
      scl			: in std_logic;
      sda			: inout std_logic

      -- slave status
      --busy			: out std_logic
   );
	end component i2c_slave_si5338;
	
	
	constant INPUT_CLK 		: integer := 25_000_000;
	constant i2c_address 	: std_logic_vector( 6 downto 0) := "111" & "0000";
	constant bus_clk	 		: integer := 400_000;


   --Inputs
   signal clk : std_logic := '0';
   signal reset : std_logic := '0';

	--BiDirs
   signal SCL : std_logic;
   signal SDA : std_logic;

 	--Outputs
   signal done : std_logic;
   signal error : std_logic;

   -- Clock period definitions
   constant clk_period : time := 40 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: si5338 
		GENERIC MAP(
			INPUT_CLK 	=> INPUT_CLK,
			i2c_address => i2c_address,
			bus_clk		=> bus_clk
		)
		PORT MAP (
          clk => clk,
          reset => reset,
          done => done,
          error => error,
          SCL => SCL,
          SDA => SDA
        );
	
	SCL <= 'H';
	SDA <= 'H';

	uut_slave : i2c_slave_si5338
--   generic map(
--		SLAVE_ADDR 	=> i2c_address,
--		SDA_DELAY 	=> 2
--	)
   port map(
      clk			=> clk,
      reset_n		=> not reset,

      -- I2C clock and data (SDA is open drain)
      scl			=> SCL,
      sda			=> SDA

      -- slave status
      --busy			: out std_logic
   );
	

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
		reset <= '1';
      wait for 10 us;
		reset <= '0';
		

      wait for clk_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
