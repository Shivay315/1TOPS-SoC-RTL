# Imported IP sources

Imported unchanged upstream archive snapshots on 2026-11-11. Each repository commit, archive hash, and file hash is recorded in ip_import_manifest.json. This is a source import, not integration or verification.

## Peripheral sources

- gpio: `third_party/pulp/peripherals/gpio`; commit `8a9e71e64b588c49f66794fa655e35d4ccb038cb`.
- apb_uart: `third_party/pulp/peripherals/apb_uart`; commit `8182a85d234417db46fe833533f8536644d3bee3`.
- apb_spi_master: `third_party/pulp/peripherals/apb_spi_master`; commit `3fce81084b15870f4bd9da7806cf950774f9672e`.
- apb_timer: `third_party/pulp/peripherals/apb_timer`; commit `03eba2e6965f5363df12621882bc70498c551a73`.
- rv_plic: `third_party/pulp/peripherals/rv_plic`; commit `5b5c5a4c1c15c3d7bb833071d344b2c2bc5f599d`.
- clic: `third_party/pulp/peripherals/clic`; commit `cc03bc18c99d1dc9d30247d4165c0cc918aa70ce`.
- clint: `third_party/pulp/peripherals/clint`; commit `fc7a1ae5ddbbbc76e5c71c3b184e50162b07d5ac`.
- apb_i2c: `third_party/pulp/peripherals/apb_i2c`; commit `84855413cc2c8e70209ee7f168a0225d3c5914a1`.
- tech_cells_generic: `third_party/pulp/libraries/tech_cells_generic`; commit `55cb54513e2d426be5992d311cb9d5dbcad10c78`.
- common_cells: `third_party/pulp/libraries/common_cells`; commit `e73baaec2ca665cd80c3c384e9258e35242b829c`.
- common_verification: `third_party/pulp/libraries/common_verification`; commit `c5d97a1fae01d2d8e8e311dee341b6b8849dcf38`.
- register_interface: `third_party/pulp/libraries/register_interface`; commit `d6e1d4cdaab7870f4faf3f88a1c788eaf5ac129d`.
- apb: `third_party/pulp/libraries/apb`; commit `4821618d652cb2b219483f037395b902771a44dd`.
- axi: `third_party/pulp/libraries/axi`; commit `d436bd4936ba1c49cd87521df54580c5159114d3`.
- obi: `third_party/pulp/libraries/obi`; commit `f29d4cc421248dfb5c32986bbf9918e2a1ca7556`.
- obi_peripherals: `third_party/pulp/libraries/obi_peripherals`; commit `d8454a28d984e1422d3a6738543703cba915dd91`.
- axi_spi_master: `third_party/pulp/axi/axi_spi_master`; commit `ee219078353a76e468674c25675f5b7fe5f51127`.

## Status and remaining decisions

- All existing project RTL remains unchanged. No new RTL, adapters, stubs, or register definitions were authored.
- Original SPI source symlinks are preserved. The AXI SPI dependency is placed at their expected relative location. Do not compile both copies of the shared SPI modules.
- I2C is imported as optional source. I2S was not imported because the provided guidelines specify no source.
- CLIC is the linked source; CLINT is the separate candidate discussed in the plan. Neither is integrated.
- Imported dependency snapshots are identified by exact commits, but this is NOT a dependency-solver lockfile. Compatibility with each upstream Bender version constraint remains to be resolved and tested.
- Default GPIO is 64 pins; no register regeneration for 32 GPIOs has been performed.
- PLIC plic_top defaults to 30 sources and 2 targets, while its supplied plic_regs has fixed dimensions. Final parameter choices require reviewing/regenerating the register map.
- No AHB-to-APB bridge or JTAG implementation was supplied by these links.
- Compilation, synthesis, tests, firmware, and SoC integration have not been performed for the imported IPs.

Unresolved source symlinks: 0
