----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    22:16:58 01/23/2017 
-- Design Name: 
-- Module Name:    debouncer - Behavioral 
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

-- Code adapted from http://fpga-tutorials.blogspot.in/2012/12/deouncing-push-buttons.html
-- Please see the above site for an excellent description of debouncing logic and
-- the need for this.

entity debouncer is
    Generic (wait_cycles : STD_LOGIC_VECTOR (19 downto 0) := x"FFFFF");
    Port ( clk : in  STD_LOGIC;
           button : in  STD_LOGIC;
           button_deb : out  STD_LOGIC);
end debouncer;

architecture Behavioral of debouncer is
begin 
	  process (clk, button)
	    variable oldbutton: STD_LOGIC := '1';
		 variable count: STD_LOGIC_VECTOR (19 downto 0);
		 
	  begin
	    if (clk'event AND clk = '1') then 
		   if (oldbutton /= button) then
			  count := (others => '0'); -- reset counter
			  oldbutton := button; -- save current value of button
			else 
			  count := count + "1";  -- increment counter
			  if ((count = wait_cycles) AND (oldbutton = button)) then
               button_deb <= oldbutton; -- button had persistent value
			  end if;
			end if;
		 end if;
	  end process;

end Behavioral;