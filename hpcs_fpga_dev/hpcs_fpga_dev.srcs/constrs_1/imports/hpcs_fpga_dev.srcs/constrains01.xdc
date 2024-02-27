############## clock define##################
# create_clock -name sys_clk_p -period 5.000 [get_ports sys_clk_p]
set_property PACKAGE_PIN AE10 [get_ports sys_clk_p]
set_property IOSTANDARD DIFF_SSTL15 [get_ports sys_clk_p]
############## IFC define  ##################
set_property PACKAGE_PIN H20     [get_ports ifc_ad_bus[ 0]]
set_property PACKAGE_PIN K18     [get_ports ifc_ad_bus[ 1]]
set_property PACKAGE_PIN L18     [get_ports ifc_ad_bus[ 2]]
set_property PACKAGE_PIN L17     [get_ports ifc_ad_bus[ 3]]
set_property PACKAGE_PIN G20     [get_ports ifc_ad_bus[ 4]]
set_property PACKAGE_PIN C21     [get_ports ifc_ad_bus[ 5]]
set_property PACKAGE_PIN H21     [get_ports ifc_ad_bus[ 6]]
set_property PACKAGE_PIN H22     [get_ports ifc_ad_bus[ 7]]
set_property PACKAGE_PIN D21     [get_ports ifc_ad_bus[ 8]]
set_property PACKAGE_PIN K20     [get_ports ifc_ad_bus[ 9]]
set_property PACKAGE_PIN H19     [get_ports ifc_ad_bus[10]]
set_property PACKAGE_PIN J19     [get_ports ifc_ad_bus[11]]
set_property PACKAGE_PIN K19     [get_ports ifc_ad_bus[12]]
set_property PACKAGE_PIN H17     [get_ports ifc_ad_bus[13]]
set_property PACKAGE_PIN J18     [get_ports ifc_ad_bus[14]]
set_property PACKAGE_PIN J17     [get_ports ifc_ad_bus[15]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_ad_bus[ 0]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_ad_bus[ 1]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_ad_bus[ 2]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_ad_bus[ 3]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_ad_bus[ 4]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_ad_bus[ 5]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_ad_bus[ 6]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_ad_bus[ 7]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_ad_bus[ 8]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_ad_bus[ 9]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_ad_bus[10]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_ad_bus[11]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_ad_bus[12]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_ad_bus[13]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_ad_bus[14]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_ad_bus[15]]
set_property PACKAGE_PIN G22     [get_ports ifc_addr_lat[ 0]]
set_property PACKAGE_PIN F22     [get_ports ifc_addr_lat[ 1]]
set_property PACKAGE_PIN D22     [get_ports ifc_addr_lat[ 2]]
set_property PACKAGE_PIN C22     [get_ports ifc_addr_lat[ 3]]
set_property PACKAGE_PIN F21     [get_ports ifc_addr_lat[ 4]]
set_property PACKAGE_PIN E21     [get_ports ifc_addr_lat[ 5]]
set_property PACKAGE_PIN F20     [get_ports ifc_addr_lat[ 6]]
set_property PACKAGE_PIN E20     [get_ports ifc_addr_lat[ 7]]
set_property PACKAGE_PIN D17     [get_ports ifc_addr_lat[ 8]]
set_property PACKAGE_PIN D18     [get_ports ifc_addr_lat[ 9]]
set_property PACKAGE_PIN E19     [get_ports ifc_addr_lat[10]]
set_property PACKAGE_PIN D19     [get_ports ifc_addr_lat[11]]
set_property PACKAGE_PIN D16     [get_ports ifc_addr_lat[12]]
set_property PACKAGE_PIN C16     [get_ports ifc_addr_lat[13]]
set_property PACKAGE_PIN G18     [get_ports ifc_addr_lat[14]]
set_property PACKAGE_PIN F18     [get_ports ifc_addr_lat[15]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_addr_lat[ 0]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_addr_lat[ 1]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_addr_lat[ 2]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_addr_lat[ 3]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_addr_lat[ 4]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_addr_lat[ 5]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_addr_lat[ 6]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_addr_lat[ 7]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_addr_lat[ 8]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_addr_lat[ 9]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_addr_lat[10]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_addr_lat[11]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_addr_lat[12]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_addr_lat[13]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_addr_lat[14]]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_addr_lat[15]]
set_property PACKAGE_PIN F17     [get_ports ifc_cs]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_cs]
set_property PACKAGE_PIN C17     [get_ports ifc_we_b]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_we_b]
set_property PACKAGE_PIN G17     [get_ports ifc_oe_b]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_oe_b]
set_property PACKAGE_PIN A21     [get_ports ifc_avd]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_avd]
set_property PACKAGE_PIN A17     [get_ports irq]
set_property IOSTANDARD LVCMOS33 [get_ports irq]
set_property PACKAGE_PIN A21     [get_ports ifc_avd]
set_property IOSTANDARD LVCMOS33 [get_ports ifc_avd]
#############DAC Configurate Setting#################
set_property PACKAGE_PIN W23     [get_ports spi2_cs]
set_property IOSTANDARD LVCMOS33 [get_ports spi2_cs]
set_property PACKAGE_PIN W24     [get_ports spi2_clk]
set_property IOSTANDARD LVCMOS33 [get_ports spi2_clk]
set_property PACKAGE_PIN U22     [get_ports spi2_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports spi2_mosi]
set_property PACKAGE_PIN U23     [get_ports spi2_miso]
set_property IOSTANDARD LVCMOS33 [get_ports spi2_miso]
#############ADC Configurate Setting#################
set_property PACKAGE_PIN V29     [get_ports spi1_cs]
set_property IOSTANDARD LVCMOS33 [get_ports spi1_cs]
set_property PACKAGE_PIN V30     [get_ports spi1_clk]
set_property IOSTANDARD LVCMOS33 [get_ports spi1_clk]
set_property PACKAGE_PIN V25     [get_ports spi1_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports spi1_mosi]
set_property PACKAGE_PIN W26     [get_ports spi1_miso]
set_property IOSTANDARD LVCMOS33 [get_ports spi1_miso]
#############SPI Configurate Setting#################
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullup [current_design]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]