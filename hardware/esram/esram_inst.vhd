	component esram is
		port (
			c0_q_0          : out std_logic_vector(71 downto 0);                    -- s2c0_qb_0
			c1_q_0          : out std_logic_vector(71 downto 0);                    -- s2c1_qb_0
			c2_q_0          : out std_logic_vector(71 downto 0);                    -- s2c2_qb_0
			c3_q_0          : out std_logic_vector(71 downto 0);                    -- s2c3_qb_0
			c4_q_0          : out std_logic_vector(71 downto 0);                    -- s2c4_qb_0
			c5_q_0          : out std_logic_vector(71 downto 0);                    -- s2c5_qb_0
			c6_q_0          : out std_logic_vector(71 downto 0);                    -- s2c6_qb_0
			c7_q_0          : out std_logic_vector(71 downto 0);                    -- s2c7_qb_0
			esram2f_clk     : out std_logic;                                        -- esram2f_clk
			iopll_lock2core : out std_logic;                                        -- iopll_lock2core
			c0_data_0       : in  std_logic_vector(71 downto 0) := (others => 'X'); -- s2c0_da_0
			c0_rdaddress_0  : in  std_logic_vector(10 downto 0) := (others => 'X'); -- s2c0_adrb_0
			c0_rden_n_0     : in  std_logic                     := 'X';             -- s2c0_meb_n_0
			c0_sd_n_0       : in  std_logic                     := 'X';             -- s2c0_sd_n_0
			c0_wraddress_0  : in  std_logic_vector(10 downto 0) := (others => 'X'); -- s2c0_adra_0
			c0_wren_n_0     : in  std_logic                     := 'X';             -- s2c0_mea_n_0
			c1_data_0       : in  std_logic_vector(71 downto 0) := (others => 'X'); -- s2c1_da_0
			c1_rdaddress_0  : in  std_logic_vector(10 downto 0) := (others => 'X'); -- s2c1_adrb_0
			c1_rden_n_0     : in  std_logic                     := 'X';             -- s2c1_meb_n_0
			c1_sd_n_0       : in  std_logic                     := 'X';             -- s2c1_sd_n_0
			c1_wraddress_0  : in  std_logic_vector(10 downto 0) := (others => 'X'); -- s2c1_adra_0
			c1_wren_n_0     : in  std_logic                     := 'X';             -- s2c1_mea_n_0
			c2_data_0       : in  std_logic_vector(71 downto 0) := (others => 'X'); -- s2c2_da_0
			c2_rdaddress_0  : in  std_logic_vector(10 downto 0) := (others => 'X'); -- s2c2_adrb_0
			c2_rden_n_0     : in  std_logic                     := 'X';             -- s2c2_meb_n_0
			c2_sd_n_0       : in  std_logic                     := 'X';             -- s2c2_sd_n_0
			c2_wraddress_0  : in  std_logic_vector(10 downto 0) := (others => 'X'); -- s2c2_adra_0
			c2_wren_n_0     : in  std_logic                     := 'X';             -- s2c2_mea_n_0
			c3_data_0       : in  std_logic_vector(71 downto 0) := (others => 'X'); -- s2c3_da_0
			c3_rdaddress_0  : in  std_logic_vector(10 downto 0) := (others => 'X'); -- s2c3_adrb_0
			c3_rden_n_0     : in  std_logic                     := 'X';             -- s2c3_meb_n_0
			c3_sd_n_0       : in  std_logic                     := 'X';             -- s2c3_sd_n_0
			c3_wraddress_0  : in  std_logic_vector(10 downto 0) := (others => 'X'); -- s2c3_adra_0
			c3_wren_n_0     : in  std_logic                     := 'X';             -- s2c3_mea_n_0
			c4_data_0       : in  std_logic_vector(71 downto 0) := (others => 'X'); -- s2c4_da_0
			c4_rdaddress_0  : in  std_logic_vector(10 downto 0) := (others => 'X'); -- s2c4_adrb_0
			c4_rden_n_0     : in  std_logic                     := 'X';             -- s2c4_meb_n_0
			c4_sd_n_0       : in  std_logic                     := 'X';             -- s2c4_sd_n_0
			c4_wraddress_0  : in  std_logic_vector(10 downto 0) := (others => 'X'); -- s2c4_adra_0
			c4_wren_n_0     : in  std_logic                     := 'X';             -- s2c4_mea_n_0
			c5_data_0       : in  std_logic_vector(71 downto 0) := (others => 'X'); -- s2c5_da_0
			c5_rdaddress_0  : in  std_logic_vector(10 downto 0) := (others => 'X'); -- s2c5_adrb_0
			c5_rden_n_0     : in  std_logic                     := 'X';             -- s2c5_meb_n_0
			c5_sd_n_0       : in  std_logic                     := 'X';             -- s2c5_sd_n_0
			c5_wraddress_0  : in  std_logic_vector(10 downto 0) := (others => 'X'); -- s2c5_adra_0
			c5_wren_n_0     : in  std_logic                     := 'X';             -- s2c5_mea_n_0
			c6_data_0       : in  std_logic_vector(71 downto 0) := (others => 'X'); -- s2c6_da_0
			c6_rdaddress_0  : in  std_logic_vector(10 downto 0) := (others => 'X'); -- s2c6_adrb_0
			c6_rden_n_0     : in  std_logic                     := 'X';             -- s2c6_meb_n_0
			c6_sd_n_0       : in  std_logic                     := 'X';             -- s2c6_sd_n_0
			c6_wraddress_0  : in  std_logic_vector(10 downto 0) := (others => 'X'); -- s2c6_adra_0
			c6_wren_n_0     : in  std_logic                     := 'X';             -- s2c6_mea_n_0
			c7_data_0       : in  std_logic_vector(71 downto 0) := (others => 'X'); -- s2c7_da_0
			c7_rdaddress_0  : in  std_logic_vector(10 downto 0) := (others => 'X'); -- s2c7_adrb_0
			c7_rden_n_0     : in  std_logic                     := 'X';             -- s2c7_meb_n_0
			c7_sd_n_0       : in  std_logic                     := 'X';             -- s2c7_sd_n_0
			c7_wraddress_0  : in  std_logic_vector(10 downto 0) := (others => 'X'); -- s2c7_adra_0
			c7_wren_n_0     : in  std_logic                     := 'X';             -- s2c7_mea_n_0
			refclk          : in  std_logic                     := 'X'              -- clock
		);
	end component esram;

	u0 : component esram
		port map (
			c0_q_0          => CONNECTED_TO_c0_q_0,          -- ram_output.s2c0_qb_0
			c1_q_0          => CONNECTED_TO_c1_q_0,          --           .s2c1_qb_0
			c2_q_0          => CONNECTED_TO_c2_q_0,          --           .s2c2_qb_0
			c3_q_0          => CONNECTED_TO_c3_q_0,          --           .s2c3_qb_0
			c4_q_0          => CONNECTED_TO_c4_q_0,          --           .s2c4_qb_0
			c5_q_0          => CONNECTED_TO_c5_q_0,          --           .s2c5_qb_0
			c6_q_0          => CONNECTED_TO_c6_q_0,          --           .s2c6_qb_0
			c7_q_0          => CONNECTED_TO_c7_q_0,          --           .s2c7_qb_0
			esram2f_clk     => CONNECTED_TO_esram2f_clk,     --           .esram2f_clk
			iopll_lock2core => CONNECTED_TO_iopll_lock2core, --           .iopll_lock2core
			c0_data_0       => CONNECTED_TO_c0_data_0,       --  ram_input.s2c0_da_0
			c0_rdaddress_0  => CONNECTED_TO_c0_rdaddress_0,  --           .s2c0_adrb_0
			c0_rden_n_0     => CONNECTED_TO_c0_rden_n_0,     --           .s2c0_meb_n_0
			c0_sd_n_0       => CONNECTED_TO_c0_sd_n_0,       --           .s2c0_sd_n_0
			c0_wraddress_0  => CONNECTED_TO_c0_wraddress_0,  --           .s2c0_adra_0
			c0_wren_n_0     => CONNECTED_TO_c0_wren_n_0,     --           .s2c0_mea_n_0
			c1_data_0       => CONNECTED_TO_c1_data_0,       --           .s2c1_da_0
			c1_rdaddress_0  => CONNECTED_TO_c1_rdaddress_0,  --           .s2c1_adrb_0
			c1_rden_n_0     => CONNECTED_TO_c1_rden_n_0,     --           .s2c1_meb_n_0
			c1_sd_n_0       => CONNECTED_TO_c1_sd_n_0,       --           .s2c1_sd_n_0
			c1_wraddress_0  => CONNECTED_TO_c1_wraddress_0,  --           .s2c1_adra_0
			c1_wren_n_0     => CONNECTED_TO_c1_wren_n_0,     --           .s2c1_mea_n_0
			c2_data_0       => CONNECTED_TO_c2_data_0,       --           .s2c2_da_0
			c2_rdaddress_0  => CONNECTED_TO_c2_rdaddress_0,  --           .s2c2_adrb_0
			c2_rden_n_0     => CONNECTED_TO_c2_rden_n_0,     --           .s2c2_meb_n_0
			c2_sd_n_0       => CONNECTED_TO_c2_sd_n_0,       --           .s2c2_sd_n_0
			c2_wraddress_0  => CONNECTED_TO_c2_wraddress_0,  --           .s2c2_adra_0
			c2_wren_n_0     => CONNECTED_TO_c2_wren_n_0,     --           .s2c2_mea_n_0
			c3_data_0       => CONNECTED_TO_c3_data_0,       --           .s2c3_da_0
			c3_rdaddress_0  => CONNECTED_TO_c3_rdaddress_0,  --           .s2c3_adrb_0
			c3_rden_n_0     => CONNECTED_TO_c3_rden_n_0,     --           .s2c3_meb_n_0
			c3_sd_n_0       => CONNECTED_TO_c3_sd_n_0,       --           .s2c3_sd_n_0
			c3_wraddress_0  => CONNECTED_TO_c3_wraddress_0,  --           .s2c3_adra_0
			c3_wren_n_0     => CONNECTED_TO_c3_wren_n_0,     --           .s2c3_mea_n_0
			c4_data_0       => CONNECTED_TO_c4_data_0,       --           .s2c4_da_0
			c4_rdaddress_0  => CONNECTED_TO_c4_rdaddress_0,  --           .s2c4_adrb_0
			c4_rden_n_0     => CONNECTED_TO_c4_rden_n_0,     --           .s2c4_meb_n_0
			c4_sd_n_0       => CONNECTED_TO_c4_sd_n_0,       --           .s2c4_sd_n_0
			c4_wraddress_0  => CONNECTED_TO_c4_wraddress_0,  --           .s2c4_adra_0
			c4_wren_n_0     => CONNECTED_TO_c4_wren_n_0,     --           .s2c4_mea_n_0
			c5_data_0       => CONNECTED_TO_c5_data_0,       --           .s2c5_da_0
			c5_rdaddress_0  => CONNECTED_TO_c5_rdaddress_0,  --           .s2c5_adrb_0
			c5_rden_n_0     => CONNECTED_TO_c5_rden_n_0,     --           .s2c5_meb_n_0
			c5_sd_n_0       => CONNECTED_TO_c5_sd_n_0,       --           .s2c5_sd_n_0
			c5_wraddress_0  => CONNECTED_TO_c5_wraddress_0,  --           .s2c5_adra_0
			c5_wren_n_0     => CONNECTED_TO_c5_wren_n_0,     --           .s2c5_mea_n_0
			c6_data_0       => CONNECTED_TO_c6_data_0,       --           .s2c6_da_0
			c6_rdaddress_0  => CONNECTED_TO_c6_rdaddress_0,  --           .s2c6_adrb_0
			c6_rden_n_0     => CONNECTED_TO_c6_rden_n_0,     --           .s2c6_meb_n_0
			c6_sd_n_0       => CONNECTED_TO_c6_sd_n_0,       --           .s2c6_sd_n_0
			c6_wraddress_0  => CONNECTED_TO_c6_wraddress_0,  --           .s2c6_adra_0
			c6_wren_n_0     => CONNECTED_TO_c6_wren_n_0,     --           .s2c6_mea_n_0
			c7_data_0       => CONNECTED_TO_c7_data_0,       --           .s2c7_da_0
			c7_rdaddress_0  => CONNECTED_TO_c7_rdaddress_0,  --           .s2c7_adrb_0
			c7_rden_n_0     => CONNECTED_TO_c7_rden_n_0,     --           .s2c7_meb_n_0
			c7_sd_n_0       => CONNECTED_TO_c7_sd_n_0,       --           .s2c7_sd_n_0
			c7_wraddress_0  => CONNECTED_TO_c7_wraddress_0,  --           .s2c7_adra_0
			c7_wren_n_0     => CONNECTED_TO_c7_wren_n_0,     --           .s2c7_mea_n_0
			refclk          => CONNECTED_TO_refclk           --           .clock
		);

