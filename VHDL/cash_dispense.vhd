----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:52:18 04/26/2017 
-- Design Name: 
-- Module Name:    Main_Dispense - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity cash_dispense is
	Port( 
------------------------------------------------------------------------------------	
------------------------------------------------------------------------------------
			-- Self Explanatory
			-- Convention for done, if the module is not in use done is set to 1 otherwise it is 0
			clk         : in STD_LOGIC;
			reset       : in STD_LOGIC;
			start       : in STD_LOGIC;
			done        : out STD_LOGIC;
------------------------------------------------------------------------------------
			-- possible is set to 1 if there is a combination of notes meeting the restrction and available balance otherwise set to 0
			possible    : out STD_LOGIC;
			-- restriction contains the maximum number of notes that can be dispenssed for each denomination
			-- MSB 1 byte contain the number for 2000 notes, next byte for 1000 notes and so on
			restriction : in STD_LOGIC_VECTOR( 31 downto 0); 
			-- available contain the number of notes that are currently in the ATM for each denomination
			-- MSB 1 byte contain the number for 2000 notes, next byte for 1000 notes and so on
			available   : in STD_LOGIC_VECTOR( 31 downto 0);
			-- amount contains the amount of money requested by the user 
			amount      : in STD_LOGIC_VECTOR( 31 downto 0);
			-- dispense contains the combination of notes which meets the requirements considering restriction and available
			-- MSB 1 byte contain the number for 2000 notes, next byte for 1000 notes and so on
			dispense    : out STD_LOGIC_VECTOR( 31 downto 0));
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------			
end cash_dispense;
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
architecture Behavioral of cash_dispense is
------------------------------------------------------------------------------------
--Signal declaration----------------------------------------------------------------
-- Used for state transition
signal state    : STD_LOGIC_VECTOR( 2 downto 0);
-- Used for detecting the rising edge of start signal
signal isitdone : STD_LOGIC;
-- Used for storing the difference after each iteration
signal reduced  : STD_LOGIC_VECTOR ( 31 downto 0);
-- Storing the number of notes of each denominatio that are calculated
signal d2000    : STD_LOGIC_VECTOR( 7 downto 0);
signal d1000    : STD_LOGIC_VECTOR( 7 downto 0);
signal d500     : STD_LOGIC_VECTOR( 7 downto 0);
signal d100     : STD_LOGIC_VECTOR( 7 downto 0);
-- Storing the minimum of restriction and available for each denomination
signal c2000    : STD_LOGIC_VECTOR( 7 downto 0);
signal c1000    : STD_LOGIC_VECTOR( 7 downto 0);
signal c500     : STD_LOGIC_VECTOR( 7 downto 0);
signal c100     : STD_LOGIC_VECTOR( 7 downto 0);
------------------------------------------------------------------------------------
begin
	process(clk, start, reset)
	begin
		if(rising_edge(clk)) then
------------------------------------------------------------------------------------
-- If reset is set to 1 at any time all the prior information is wiped out
-- By convention done is set to 1
-- isitdone is set to 1 to detect the next rising edge of start signal		
			if(reset = '1') then
				state <= "000";
				d2000 <= x"00";
				d1000 <= x"00";
				d500 <= x"00";
				d100 <= x"00";
				isitdone <= '0';
				state <= "000";
				done <= '1';
------------------------------------------------------------------------------------
-- When start is pressed the minimum of restriction and available is calculated and storedd in c2000, c1000 and so on
-- done is set to 0 because of convention				
			elsif(start = '1' and isitdone = '0') then
				done <= '0';
				possible <= '0';
				
				if( restriction( 31 downto 24) < available( 31 downto 24)) then
					c2000 <= restriction( 31 downto 24);
				else
					c2000 <= available( 31 downto 24);
				end if;
				if( restriction( 23 downto 16) < available( 23 downto 16)) then
					c1000 <= restriction( 23 downto 16);
				else
					c1000 <= available( 23 downto 16);
				end if;
				if( restriction( 15 downto 8) < available( 15 downto 8)) then
					c500 <= restriction( 15 downto 8);
				else 
					c500 <= available( 15 downto 8);
				end if;
				if( restriction( 7 downto 0) < available( 7 downto 0)) then
					c100 <= restriction( 7 downto 0);
				else
					c100 <= available( 7 downto 0);
				end if;
				
				reduced <= amount;
				isitdone <= '1';
				state <= "000";
------------------------------------------------------------------------------------
-- Starting with 2000, we greedily check the maxmimum number of notes for each denomination				
			elsif(isitdone = '1') then
------------------------------------------------------------------------------------
-- Checking the maximum number of notes that can be subtracted for 2000
				if(state = "000") then
					if( (reduced < x"000007D0") or not( d2000 < c2000) ) then
						state <= "001";
					else
-- Reducing the initial amount after each step by 2000
						reduced <= reduced - x"000007D0";
						d2000 <= d2000 + 1;
						state <= "000";
					end if;
------------------------------------------------------------------------------------
-- Checking the maximum number of notes that can be subtracted for 1000
				elsif(state = "001") then
					if( (reduced < x"000003E8") or not( d1000 < c1000) ) then
						state <= "010";
					else
-- Reducing the initial amount after each step by 1000
						reduced <= reduced - x"000003E8";
						d1000 <= d1000 + 1;
						state <= "001";
					end if;
------------------------------------------------------------------------------------
-- Checking the maximum number of notes that can be subtracted for 500					
				elsif(state = "010") then
					if( reduced < x"000001F4" or not( d500 < c500) ) then
						state <= "011";
					else
-- Reducing the initial amount after each step by 500					
						reduced <= reduced - x"000001F4";
						d500 <= d500 + 1;
						state <= "010";
					end if;
------------------------------------------------------------------------------------
-- Checking the maximum number of notes that can be subtracted for 100					
				elsif(state = "011") then
					if(reduced < x"00000064" or not( d100 < c100) ) then
						state <= "100";
					else
-- Reducing the initial amount after each step by 100					
						reduced <= reduced - x"00000064";
						d100 <= d100 + 1;
						state <= "011";
					end if;
------------------------------------------------------------------------------------
-- Putting the information on the ouptut channel
-- possible is set to 1 iff reduced goes to 0 after the above iteration 					
				else
					if(reduced = x"00000000") then
						dispense( 31 downto 24) <= d2000;
						dispense( 23 downto 16) <= d1000;
						dispense( 15 downto 8) <= d500;
						dispense( 7 downto 0) <= d100;
						done <= '1';
						possible <= '1';
					else
						dispense <= x"00000000";
						done <= '1';
						possible <= '0';
					end if;
				end if;		
			end if;	
		end if;
------------------------------------------------------------------------------------		
	end process;
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------	
end Behavioral;
