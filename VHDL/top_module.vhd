----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    17:34:29 01/23/2017
-- Design Name:
-- Module Name:    Controller_Top_Module - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.02 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity top_level is
	port(
		-- FX2LP interface ---------------------------------------------------------------------------
		fx2Clk_in      : in    std_logic;                    -- 48MHz clock from FX2LP
		fx2Addr_out    : out   std_logic_vector(1 downto 0); -- select FIFO: "00" for EP2OUT, "10" for EP6IN
		fx2Data_io     : inout std_logic_vector(7 downto 0); -- 8-bit data to/from FX2LP

		-- When EP2OUT selected:
		fx2Read_out    : out   std_logic;                    -- asserted (active-low) when reading from FX2LP
		fx2OE_out      : out   std_logic;                    -- asserted (active-low) to tell FX2LP to drive bus
		fx2GotData_in  : in    std_logic;                    -- asserted (active-high) when FX2LP has data for us

		-- When EP6IN selected:
		fx2Write_out   : out   std_logic;                    -- asserted (active-low) when writing to FX2LP
		fx2GotRoom_in  : in    std_logic;                    -- asserted (active-high) when FX2LP has room for more data from us
		fx2PktEnd_out  : out   std_logic;                    -- asserted (active-low) when a host read needs to be committed early

		-- Onboard peripherals -----------------------------------------------------------------------
		led_out        : out   std_logic_vector(7 downto 0); -- eight LEDs
		sw_in          : in    std_logic_vector(7 downto 0); -- eight switches
	   reset          : in    std_logic;					 -- asserted (active) to wipe the data out
 	   start          : in    std_logic;					 -- asserted (active) to start the transaction
 	   next_data_in   : in    std_logic;					 -- asserted (active) to read the next 8 bits of data
	   done           : in   std_logic 					 -- asserted (active) to end the transaction
	);
end entity;

architecture structural of top_level is

    -- Component definitions -------------------------------------------------------------------------
	component debouncer
        port(
        	clk: in STD_LOGIC;
            button: in STD_LOGIC;
            button_deb: out STD_LOGIC);
    end component;
    
    component encrypter
        port(
        	clk: in STD_LOGIC;
            reset : in  STD_LOGIC;
            plaintext: in STD_LOGIC_VECTOR (63 downto 0);
            start: in STD_LOGIC;
            ciphertext: out STD_LOGIC_VECTOR (63 downto 0);
            done: out STD_LOGIC);
    end component;

    component decrypter
        port(
        	clk: in STD_LOGIC;
            reset : in  STD_LOGIC;
            ciphertext: in STD_LOGIC_VECTOR (63 downto 0);
            start: in STD_LOGIC;
            plaintext: out STD_LOGIC_VECTOR (63 downto 0);
            done: out STD_LOGIC);
    end component;

    component comm_fpga_fx2
	    port(
			clk_in         : in    std_logic;                     -- 48MHz clock from FX2LP
			reset_in       : in    std_logic;                     -- synchronous active-high reset input
			reset_out      : out   std_logic;                     -- synchronous active-high reset output

			-- FX2LP interface ---------------------------------------------------------------------------
			fx2FifoSel_out : out   std_logic;                     -- select FIFO: '0' for EP2OUT, '1' for EP6IN
			fx2Data_io     : inout std_logic_vector(7 downto 0);  -- 8-bit data to/from FX2LP

			-- When EP2OUT selected:
			fx2Read_out    : out   std_logic;                     -- asserted (active-low) when reading from FX2LP
			fx2GotData_in  : in    std_logic;                     -- asserted (active-high) when FX2LP has data for us

			-- When EP6IN selected:
			fx2Write_out   : out   std_logic;                     -- asserted (active-low) when writing to FX2LP
			fx2GotRoom_in  : in    std_logic;                     -- asserted (active-high) when FX2LP has room for more data from us
			fx2PktEnd_out  : out   std_logic;                     -- asserted (active-low) when a host read needs to be committed early

			-- Channel read/write interface --------------------------------------------------------------
			chanAddr_out   : out   std_logic_vector(6 downto 0);  -- the selected channel (0-127)

			-- Host >> FPGA pipe:
			h2fData_out    : out   std_logic_vector(7 downto 0);  -- data lines used when the host writes to a channel
			h2fValid_out   : out   std_logic;                     -- '1' means "on the next clock rising edge, please accept the data on h2fData_out"
			h2fReady_in    : in    std_logic;                     -- channel logic can drive this low to say "I'm not ready for more data yet"

			-- Host << FPGA pipe:
			f2hData_in     : in    std_logic_vector(7 downto 0);  -- data lines used when the host reads from a channel
			f2hValid_in    : in    std_logic;                     -- channel logic can drive this low to say "I don't have data ready for you"
			f2hReady_out   : out   std_logic                      -- '1' means "on the next clock rising edge, put your next byte of data on f2hData_in"
		);
	end component;

	component atm_main_controller
		port(
			-- Peripheral input --------------------------------------------------------------------
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

			-- DVR interface -----------------------------------------------------------------------------
			chanAddr_in  : in  STD_LOGIC_VECTOR(6 downto 0);  -- the selected channel (0-127)

			-- Host >> FPGA pipe:
			h2fData_in   : in  STD_LOGIC_VECTOR(7 downto 0);  -- data lines used when the host writes to a channel
			h2fValid_in  : in  STD_LOGIC;                     -- '1' means "on the next clock rising edge, please accept the data on h2fData"
			h2fReady_out : out STD_LOGIC;                     -- channel logic can drive this low to say "I'm not ready for more data yet"

			-- Host << FPGA pipe:
			f2hData_out  : out STD_LOGIC_VECTOR(7 downto 0);  -- data lines used when the host reads from a channel
			f2hValid_out : out STD_LOGIC;                     -- channel logic can drive this low to say "I don't have data ready for you"
			f2hReady_in  : in  STD_LOGIC;                     -- '1' means "on the next clock rising edge, put your next byte of data on f2hData"

			-- LED port -----------------------------------------------------------------------------------
			led_out : out STD_LOGIC_VECTOR(7 downto 0);
			
			-- reset button -------------------------------------------------------------------------------
			reset_out : out STD_LOGIC
			);
	end component;


	-- Channel read/write interface -----------------------------------------------------------------
	signal chanAddr    : std_logic_vector(6 downto 0);  -- the selected channel (0-127)

	-- Host >> FPGA pipe:
	signal h2fData     : std_logic_vector(7 downto 0);  -- data lines used when the host writes to a channel
	signal h2fValid    : std_logic;                     -- '1' means "on the next clock rising edge, please accept the data on h2fData"
	signal h2fReady    : std_logic;                     -- channel logic can drive this low to say "I'm not ready for more data yet"

	-- Host << FPGA pipe:
	signal f2hData     : std_logic_vector(7 downto 0);  -- data lines used when the host reads from a channel
	signal f2hValid    : std_logic;                     -- channel logic can drive this low to say "I don't have data ready for you"
	signal f2hReady    : std_logic;                     -- '1' means "on the next clock rising edge, put your next byte of data on f2hData"
	-- ----------------------------------------------------------------------------------------------

	-- Needed so that the comm_fpga_fx2 module can drive both fx2Read_out and fx2OE_out
	signal fx2Read     : std_logic;

	-- Reset signal so host can delay startup
	signal fx2Reset    : std_logic;
	-- Encryptor/Decryptor read/write interface -----------------------------------------------------
	signal plaintext_encryptor : std_logic_vector(63 downto 0);       -- data to be encrypted
	signal ciphertext_encryptor : std_logic_vector(63 downto 0);     -- data after encrytion
	signal plaintext_decryptor : std_logic_vector(63 downto 0);      -- data from decrytor after processing
	signal ciphertext_decryptor : std_logic_vector(63 downto 0);     -- data from host that has to be decypted
	signal start_encryption : std_logic;                             -- asserted(active) to start encrytion
	signal start_decryption : std_logic;                             -- asserted(active) to start decyption
	signal done_encryptor   : std_logic;                             -- asserted(active) by encryptor after processing
	signal done_decryptor   : std_logic;                             -- asserted(active) by decryptor after processing
	signal reset_out : std_logic;

	-- debounced signals to various module -----------------------------------------------------------
	signal debounced_next_data_in: std_logic;                 -- asserted(active) by the debouncer
   signal debounced_start: std_logic;                        
   signal debounced_reset: std_logic;
   signal debounced_done : std_logic;

begin
	-- CommFPGA module
	fx2Read_out <= fx2Read;
	fx2OE_out <= fx2Read;
	fx2Addr_out(0) <=  -- So fx2Addr_out(1)='0' selects EP2OUT, fx2Addr_out(1)='1' selects EP6IN
		'0' when fx2Reset = '0'
		else 'Z';
comm_fpga_fx2_1 : comm_fpga_fx2
		port map(
			clk_in         => fx2Clk_in,
			reset_in       => '0',
			reset_out      => fx2Reset,
			
			-- FX2LP interface
			fx2FifoSel_out => fx2Addr_out(1),
			fx2Data_io     => fx2Data_io,
			fx2Read_out    => fx2Read,
			fx2GotData_in  => fx2GotData_in,
			fx2Write_out   => fx2Write_out,
			fx2GotRoom_in  => fx2GotRoom_in,
			fx2PktEnd_out  => fx2PktEnd_out,

			-- DVR interface -> Connects to application module
			chanAddr_out   => chanAddr,
			h2fData_out    => h2fData,
			h2fValid_out   => h2fValid,
			h2fReady_in    => h2fReady,
			f2hData_in     => f2hData,
			f2hValid_in    => f2hValid,
			f2hReady_out   => f2hReady
		);

debouncer1: debouncer
              port map (clk => fx2Clk_in,
                        button => next_data_in,
                        button_deb => debounced_next_data_in);

debouncer2: debouncer
              port map (clk => fx2Clk_in,
                        button => reset,
                        button_deb => debounced_reset);

debouncer3: debouncer
              port map (clk => fx2Clk_in,
                        button => start,
                        button_deb => debounced_start);

debouncer4: debouncer
              port map (clk => fx2Clk_in,
                        button => done,
                        button_deb => debounced_done);

encrypt: encrypter
              port map (clk => fx2Clk_in,
                        reset => reset_out,
                        plaintext => plaintext_encryptor,
                        start => start_encryption,
                        ciphertext => ciphertext_encryptor,
                        done => done_encryptor);

decrypt: decrypter
              port map (clk => fx2Clk_in,
                        reset => reset_out,
                        ciphertext => ciphertext_decryptor,
                        start => start_decryption,
                        plaintext => plaintext_decryptor,
                        done => done_decryptor);

atm_controller: atm_main_controller
			  port map (clk => fx2Clk_in,
							start => debounced_start,
							reset => debounced_reset,
							next_data_in => debounced_next_data_in,
							done => debounced_done,
							data_in_sliders => sw_in,

							plaintext_encryptor => plaintext_encryptor,
							ciphertext_encryptor => ciphertext_encryptor,
							plaintext_decryptor => plaintext_decryptor,
							ciphertext_decryptor => ciphertext_decryptor,

							start_encryption => start_encryption,
							start_decryption => start_decryption,
							done_decryptor => done_decryptor,
							done_encryptor => done_encryptor,

							-- DVR interface -> Connects to comm_fpga module
							chanAddr_in  => chanAddr,
							h2fData_in   => h2fData,
							h2fValid_in  => h2fValid,
							h2fReady_out => h2fReady,
							f2hData_out  => f2hData,
							f2hValid_out => f2hValid,
							f2hReady_in  => f2hReady,

							led_out => led_out,
							reset_out => reset_out);

end structural;