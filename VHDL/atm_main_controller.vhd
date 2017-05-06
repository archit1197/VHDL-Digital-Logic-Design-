----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:22:29 03/15/2017 
-- Design Name: 
-- Module Name:    ATM_Main_Controller - Behavioral 
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
use IEEE.STD_LOGIC_UNSIGNED.ALL;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity atm_main_controller is
    Generic(N : natural := 1000000);
	 Port ( -- Peripheral input --------------------------------------------------------------------
			clk : in STD_LOGIC;
			start : in STD_LOGIC;
			reset : in STD_LOGIC;
			next_data_in : in STD_LOGIC;
			done : in STD_LOGIC;
			data_in_sliders : in STD_LOGIC_VECTOR(7 downto 0);

			-- encrytion/decryption port -----------------------------------------------------------
			plaintext_encryptor : out STD_LOGIC_VECTOR(63 downto 0);
			ciphertext_encryptor : in STD_LOGIC_VECTOR(63 downto 0);
			ciphertext_decryptor : out STD_LOGIC_VECTOR(63 downto 0);
			plaintext_decryptor : in STD_LOGIC_VECTOR(63 downto 0);

			start_encryption : out STD_LOGIC;
			start_decryption : out STD_LOGIC;
			done_encryptor : in STD_LOGIC;
			done_decryptor : in STD_LOGIC;
			
			reset_out : out STD_LOGIC;
			-- DVR interface -----------------------------------------------------------------------------
			chanAddr_in  : in  STD_LOGIC_VECTOR(6 downto 0);  -- the selected channel (0-127)

			-- Host >> FPGA pipe:
			h2fData_in   : in  STD_LOGIC_VECTOR(7 downto 0);  -- data lines used when the host writes to a channel
			h2fValid_in  : in  STD_LOGIC;                     -- '1' means "on the next clock rising edge, please accept the data on h2fData_in"
			h2fReady_out : out STD_LOGIC;                     -- channel logic can drive this low to say "I'm not ready for more data yet"

			-- Host << FPGA pipe:
			f2hData_out  : out STD_LOGIC_VECTOR(7 downto 0);  -- data lines used when the host reads from a channel
			f2hValid_out : out STD_LOGIC;                     -- channel logic can drive this low to say "I don't have data ready for you"
			f2hReady_in  : in  STD_LOGIC;                     -- '1' means "on the next clock rising edge, put your next byte of data on f2hData"

			-- LED port -----------------------------------------------------------------------------------
			led_out : out STD_LOGIC_VECTOR(7 downto 0));
end atm_main_controller;

architecture Behavioral of atm_main_controller is
	
----------component definitons-----------------------------------------------------------------
	
	component read_multiple_data_bytes
        port(
				clk : in  STD_LOGIC;
            reset : in  STD_LOGIC;
            data_in : in  STD_LOGIC_VECTOR (7 downto 0);
            next_data : in  STD_LOGIC;
            data_read : out  STD_LOGIC_VECTOR (63 downto 0));
    end component;
	
	component counter
		port(
			 clk: in STD_LOGIC;
			 output_pulse : out STD_LOGIC;
			 output_pulse_two : out STD_LOGIC;
			 done : out STD_LOGIC);
	end component;
	
	component cash_dispense
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
	end component;

-----------signals---------------------------------------------------------------------------------------
	signal reset_signal : STD_LOGIC := '0';
	signal state : STD_LOGIC_VECTOR(2 downto 0) := (others => '0'); 
    -- Ready state = 000
    -- Get_USER_Input = 001
    -- Communicating_With backend = 010
    -- Dispensing_Cash = 011
    -- Loading_Cash = 100
    signal sub_state : STD_LOGIC_VECTOR(1 downto 0) := (others => '0'); -- Depending on the state means diff state 
    signal sub_sub_state : STD_LOGIC_VECTOR(2 downto 0) := (others => '0'); -- Depending on the sub_state means diff state
    signal future_state : STD_LOGIC_VECTOR(7 downto 0) := (others => '0'); -- Data from chanAddr_in = 9
    signal next_data_in_counter : STD_LOGIC_VECTOR(3 downto 0) := (others => '0'); -- Counter for reading data
	 signal done_processing : STD_LOGIC := '0';

    -- read_multiple_data_bytes interface ---------------------------------------------------------------
    signal multi_byte_data_read: std_logic_vector(63 downto 0);      -- 8 bytes of data read from sliders

    -- encrypted data from backend -----------------------------------------------------------------------
    signal backend_encrypted : STD_LOGIC_VECTOR(63 downto 0) := (others => '0'); 
	 
	 -- counter singals
 	 signal counter_signal : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');

	 -- Registers for balance in the ATM ------------------------------------------------------------------
	 signal n2000 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	 signal n1000 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	 signal n500 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	 signal n100 : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	 
	 ----Stores the available notes in atm, for sending to backend
	 signal available_balance : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
	 
	 -- Signals for operating the LED's -------------------------------------------------------------------
	 signal pulse : STD_LOGIC;
	 signal pulse_two : STD_LOGIC;
	 signal counter_change : STD_LOGIC := '0';
	 signal counter_two : STD_LOGIC := '0';
	 signal blink_done : STD_LOGIC;
	 
	 -- Signal for using the Dispense Module -------------------------------------------------------------
	 -- Start done signal
	 signal start_dispense       : STD_LOGIC;
	 signal done_dispense        : STD_LOGIC;
	 -- Actual restrictions are passes
	 signal possible_dispense    : STD_LOGIC;
	 signal restriction_dispense : STD_LOGIC_VECTOR( 31 downto 0); 
	 signal available_dispense   : STD_LOGIC_VECTOR( 31 downto 0);
	 signal amount_dispense      : STD_LOGIC_VECTOR( 31 downto 0);
	 signal dispense             : STD_LOGIC_VECTOR( 31 downto 0);
	 signal user_encrypted		  : STD_LOGIC_VECTOR( 63 downto 0);
	 signal amount_details 		  : STD_LOGIC_VECTOR( 63 downto 0);
	 
	 signal cash_state           : STD_LOGIC_VECTOR( 2 downto 0);
		
begin

data_input: read_multiple_data_bytes 
			port map (
						clk => clk,
						reset => reset_signal,
						data_in => data_in_sliders,
						next_data => next_data_in,
						data_read => multi_byte_data_read); 
				
timer: counter 
			port map(
						clk => clk,
						output_pulse => pulse,						
						output_pulse_two => pulse_two,
						done => blink_done);
						
dispenser : cash_dispense
			port map( 
			-- Self Explanatory
			clk         => clk,
			reset       => reset_signal,
			start       => start_dispense,
			done        => done_dispense,
			-- Restrictions and available balance given by ATM controller to Dispense Module
			possible    => possible_dispense,
			restriction => restriction_dispense,
			available   => available_dispense,
			amount      => amount_dispense,
			-- The breakdown needed after the processing is done
			dispense    => dispense
			);						
								
overall_process:
process(clk)
begin	
	if (rising_edge(clk)) then
	-- When reset button is pressed all the cash is flushhed out and all signals are set to initial values
		if(reset = '1') then
			state <= "000";
			sub_state <= "00";
			sub_sub_state <= "000";
			cash_state <= "000";
			n2000 <= x"00";
			n1000 <= x"00";
			n500 <= x"00";
			n100 <= x"00";
			reset_signal <= '1';
			done_processing <= '0';
			reset_out <= '1';
	-- When start button is pressed the state is changes to that of Ready_State	
		elsif (start = '1') then
			reset_out <= '0';
			reset_signal <= '0';
			state <= "001";
	-- When done is pressed, it is first checked whether the processing has been done or not
		elsif (done = '1') then
			if(done_processing = '1') then
				if(sub_state = "00") then
					reset_out <= '1';
					reset_signal <= '1';
					sub_state <= "01";
				elsif(sub_state = "01") then
					reset_out <= '0';
					reset_signal <= '0';
					sub_state <= "00";
					state <= "000";
					done_processing <= '0';
				end if;
			end if;	
		end if;
		-- State "000" ensures that all the encryptor, Decryptor and read_muliple_data_bytes are set to initial values
		if (state = "000") then
			led_out <= "00000000";
			
			counter_change <= '0';

			sub_state <= "00";
			sub_sub_state <= "000";
			counter_signal <= "0000";
			cash_state <= "000";
			
			start_encryption <= '0';
			start_decryption <= '0';
		-- State "001" is responsible for reading 64 bits of data from the sliders using the read_multiple_data_bytes
		elsif (state = "001") then
			if(pulse = '1') then
				led_out(0) <= '1';
				led_out(1) <= counter_signal(0);
				led_out(2) <= counter_signal(1);
				led_out(3) <= counter_signal(2);
				led_out(4) <= '0';
				led_out(5) <= '0';
				led_out(6) <= '0';
				led_out(7) <= '0';
			else
				led_out(0) <= '0';
				led_out(1) <= counter_signal(0);
				led_out(2) <= counter_signal(1);
				led_out(3) <= counter_signal(2);
				led_out(4) <= '0';
				led_out(5) <= '0';
				led_out(6) <= '0';
				led_out(7) <= '0';
			end if;
			if(next_data_in = '1' and sub_state = "00" and counter_signal < "1000") then
				sub_state <= "01";
				counter_signal <= counter_signal + 1;
			elsif (next_data_in = '0' and sub_state = "01") then
				sub_state <= "00";
			elsif (counter_signal = "1000" and sub_state = "00") then
				if(sub_sub_state = "000") then
					plaintext_encryptor <= multi_byte_data_read;
					sub_sub_state <= "001";
				elsif(sub_sub_state = "001") then
					start_encryption <= '1';
					sub_sub_state <= "010";
				elsif(sub_sub_state <= "010") then
					start_encryption <= '0';
					sub_sub_state <= "011";
				elsif(sub_sub_state <= "011") then   -- Extra transitions required because of design choice
					sub_sub_state <= "100";           -- Encrypter produces done = '1' when not working
				elsif(sub_sub_state <= "100") then
					sub_sub_state <= "101";
				elsif(sub_sub_state <= "101") then
					sub_sub_state <= "110";
				elsif(sub_sub_state <= "110") then
					sub_sub_state <= "111";	
				elsif(sub_sub_state <= "111") then
					sub_sub_state <= "000";
					state <= "010";
				end if;
			end if;
		-- State "010" executes the encryption as well communicates with the backend and then decrypt the message
		elsif (state = "010") then
			if(pulse = '1') then
				led_out <= "00000011";
			else
				led_out <= "00000000";
			end if;
			if(done_encryptor = '1' and not(sub_state = "10")) then
				sub_state <= "01";
			end if;
			-- Communication with backend, f2hReady_in = '1' implies that backend wants data, and h2fValid = '1' implies that frontend can take data
			
			if(sub_state = "01") then
				available_balance <= n2000 & n1000 & n500 & n100 ; 
				if(f2hReady_in = '1') then
					if(chanAddr_in = "0000000") then
						f2hData_out <= x"01";
					
					elsif (chanAddr_in > "0000000" and chanAddr_in < "0001001") then
						f2hData_out <= ciphertext_encryptor((71 - 8*(to_integer(unsigned(chanAddr_in)))) downto (64 - 8*(to_integer(unsigned(chanAddr_in)))));
					elsif (chanAddr_in > "0010010" and chanAddr_in < "0010111") then
						f2hData_out <= available_balance(31-8*((to_integer(unsigned(chanAddr_in)))-19) downto 24-8*((to_integer(unsigned(chanAddr_in)))- 19)); 
					end if;
				elsif(h2fValid_in = '1') then	
					if (chanAddr_in = "0001001") then
						if( not( h2fData_in = x"00")) then   -- Storing the response of backend for future use
							future_state <= h2fData_in;
						end if;
					elsif (chanAddr_in > "0001001" and chanAddr_in < "0010010") then
						backend_encrypted(71 - 8*((to_integer(unsigned(chanAddr_in)))-9) downto 64 - 8*((to_integer(unsigned(chanAddr_in)))-9))	<= h2fData_in;
						if(chanAddr_in = "0010001") then
							sub_state <= "10";
							sub_sub_state <= "000";
							f2hData_out <= x"02";
						end if;
					end if;
				end if;
			elsif (sub_state = "10") then
				if (sub_sub_state = "000") then
					ciphertext_decryptor <= backend_encrypted;
					start_decryption <= '1';
					sub_sub_state <= "001";
				elsif (sub_sub_state = "001") then
					start_decryption <= '0';
					sub_sub_state <= "010";
				elsif (sub_sub_state = "010") then        -- Extra transitions required because of design choice
					sub_sub_state <= "011";                -- Decrypter produces done = '1' when not working
				elsif (sub_sub_state = "011") then
					sub_sub_state <= "100";
				elsif (sub_sub_state = "100") then
					sub_sub_state <= "101";
				elsif (sub_sub_state = "101") then
					sub_sub_state <= "111";
				elsif (sub_sub_state = "111") then
					if(done_decryptor = '1') then
					 --Deciding the next state using the information from Chan 9 after the decryption is done
						if(future_state = x"01") then
							--led_out <= "00000111";
							state <= "011";
							sub_state <= "00";
							sub_sub_state <= "000";
							counter_signal <= "0000";
						elsif (future_state = x"02") then
							--led_out <= "00000010";
							state <= "011";
							sub_state <= "01";
							sub_sub_state <= "000";
							counter_signal <= "0000";
						elsif (future_state = x"03") then
							state <= "100";
							sub_state <= "00";
							sub_sub_state <= "000";
							counter_signal <= "0000";
						elsif (future_state = x"04") then
							--led_out <= "00000111";
							state <= "000";
							sub_state <= "00";
							sub_sub_state <= "000";
							done_processing <= '1';
						end if;
					end if;
				end if ;
			end if;
		--elsif (plaintext_decryptor(31 downto 0) = x"00000000") then 
		elsif (state = "011") then
				if (sub_state = "00") then
					if(cash_state = "000") then
						available_dispense <= available_balance;
						restriction_dispense <= plaintext_decryptor(31 downto 0);
						amount_dispense <= plaintext_decryptor(63 downto 32);
						start_dispense <= '1';
						cash_state <= "001";
					elsif(cash_state = "001") then
						start_dispense <= '0';
						cash_state <= "010";
					elsif(cash_state = "010") then
						cash_state <= "011";
					elsif(cash_state = "011") then
						cash_state <= "100";
					elsif(cash_state = "100") then
						cash_state <= "101";
					elsif(cash_state = "101") then
						cash_state <= "110";
					elsif(cash_state = "110") then
						cash_state <= "111";
					elsif (done_dispense = '1' and possible_dispense = '1') then-- Sufficient balance in user's account, sufficient cash in ATM
						--Ensures that LED 0, 1, 2, 3 blink with time period T
						if (pulse = '1') then
							led_out(3 downto 0) <= "1111";
						elsif (pulse = '0') then
							led_out(3 downto 0) <= "0000";
						end if;
						 --Ensures that LED 4, 5, 6, 7 blink with time period 2T
						if(pulse_two = '1') then
							--if(sub_sub_state = "000" and counter_signal < plaintext_decryptor(39 downto 32)) then for 2000
							if(sub_sub_state = "000" and counter_signal < dispense(31 downto 24)) then
								led_out(7 downto 4) <= "0001";
							elsif(sub_sub_state = "000" and counter_signal = dispense(31 downto 24)) then
								sub_sub_state <= "001";
								counter_signal <= "0000";
							--elsif(sub_sub_state = "001" and counter_signal < plaintext_decryptor(47 downto 40)) then for 1000
							elsif(sub_sub_state = "001" and counter_signal < dispense(23 downto 16)) then
								led_out(7 downto 4) <= "0010";
							elsif(sub_sub_state = "001" and counter_signal = dispense(23 downto 16)) then
								sub_sub_state <= "010";
								counter_signal <= "0000";
							--elsif(sub_sub_state = "010" and counter_signal < plaintext_decryptor(55 downto 48)) then for 500
							elsif(sub_sub_state = "010" and counter_signal < dispense(15 downto 8)) then
								led_out(7 downto 4) <= "0100";
							elsif(sub_sub_state = "010" and counter_signal = dispense(15 downto 8)) then
								sub_sub_state <= "011";
								counter_signal <= "0000";
							--elsif(sub_sub_state = "011" and counter_signal < plaintext_decryptor(63 downto 56)) then for 100
							elsif(sub_sub_state = "011" and counter_signal < dispense(7 downto 0)) then
								led_out(7 downto 4) <= "1000";
							elsif(sub_sub_state = "011" and counter_signal = dispense(7 downto 0)) then
								n2000 <= n2000 - dispense(31 downto 24);
								n1000 <= n1000 - dispense(23 downto 16);
								n500 <= n500 - dispense(15 downto 8);
								n100 <= n100 - dispense(7 downto 0);
								state <= "000";
								sub_state <= "00";
								sub_sub_state <= "000";
								counter_signal <= "0000";
								done_processing <= '1';
								--led_out(7 downto 4) <= "1111";
							end if;
						else
							led_out(7 downto 4) <= "0000"; 
						end if;
						if(blink_done = '1') then
							counter_signal <= counter_signal + 1;
						end if;
					elsif(done_dispense = '1' and possible_dispense = '0') then                              -- Sufficient balance in user's account, insufficient cash in ATM
						if (pulse = '1' and counter_signal < "0111" and counter_change = '0') then
							led_out(3 downto 0) <= "1111";
							if (sub_sub_state < "111") then
								led_out(7 downto 4) <= "1111";
							else
								led_out(7 downto 4) <= "0000";
							end if;
							counter_change <= '1';
							counter_signal <= counter_signal + 1;
							sub_sub_state <= sub_sub_state + 1;
						elsif (pulse = '1' and counter_signal < "0111" and counter_change = '1') then
							led_out(3 downto 0) <= "1111";
							if (sub_sub_state < "111") then
								led_out(7 downto 4) <= "1111";
							else
								led_out(7 downto 4) <= "0000";
							end if;
						elsif (pulse = '0' and counter_signal < "0111") then
							led_out <= "00000000";
							counter_change <= '0';
						else
							state <= "000";
							sub_state <= "00";
							sub_sub_state <= "000";
							done_processing <= '1';
						end if;
					end if;
				elsif (sub_state = "01") then        -- Insufficient balance in user's account
					if (pulse = '1' and counter_signal < "0110" and counter_change = '0') then
						led_out(3 downto 0) <= "1111";
						if (sub_sub_state < "100") then
							led_out(7 downto 4) <= "1111";
						else
							led_out(7 downto 4) <= "0000";
						end if;
						counter_change <= '1';
						counter_signal <= counter_signal + 1;
						sub_sub_state <= sub_sub_state + 1;
					elsif (pulse = '1' and counter_signal < "0110" and counter_change = '1') then
						led_out(3 downto 0) <= "1111";
						if (sub_sub_state < "100") then
							led_out(7 downto 4) <= "1111";
						else
							led_out(7 downto 4) <= "0000";
						end if;
					elsif (pulse = '0' and counter_signal < "0110") then
						led_out <= "00000000";
						counter_change <= '0';
					else
						state <= "000";
						sub_state <= "00";
						sub_sub_state <= "000";
						done_processing <= '1';
					end if;
				end if ;
				
		elsif (state = "100") then
			if (pulse = '1' and counter_signal < "0111") then
				led_out <= "11100000";
				if (counter_change = '0') then
					counter_change <= '1';
					counter_signal <= counter_signal + 1;
				end if;
			elsif (pulse = '0' and counter_signal < "0111") then
				led_out <= "00000000";
				counter_change <= '0';
			else
				n100 <= plaintext_decryptor(63 downto 56);
				n500 <= plaintext_decryptor(55 downto 48);
				n1000 <= plaintext_decryptor(47 downto 40);
				n2000 <= plaintext_decryptor(39 downto 32);
				state <= "000";
				sub_state <= "00";
				sub_sub_state <= "000";
				done_processing <= '1';
			end if;
		end if;
	end if;
end process; 
f2hValid_out <= '1';
h2fReady_out <= '1';
end Behavioral;