# Changelog

## [0.11.0](https://github.com/eihu0F/asdf-extras/compare/v0.10.0...v0.11.0) (2026-10-30)


### Features

* add session-only asdf shell overrides to shell initialization ([#81](https://github.com/eihu0F/asdf-extras/issues/81)) ([2048071](https://github.com/eihu0F/asdf-extras/commit/2048071897626b56f727df31aea98011612fb29d))

## [0.10.0](https://github.com/eihu0F/asdf-extras/compare/v0.9.2...v0.10.0) (2026-10-26)


### Features

* add a read-only get command for scoped version reads ([#77](https://github.com/eihu0F/asdf-extras/issues/77)) ([b6ffb5a](https://github.com/eihu0F/asdf-extras/commit/b6ffb5a1dd29b27816730e93dfe72d20dbc262d8))
* add a setup subcommand to install asdf-extras itself ([#78](https://github.com/eihu0F/asdf-extras/issues/78)) ([eeec7e8](https://github.com/eihu0F/asdf-extras/commit/eeec7e801f9c427b5d39176c506e61b8cf6cdf67))
* support version lists and --replace in install and update ([#79](https://github.com/eihu0F/asdf-extras/issues/79)) ([d3e98fd](https://github.com/eihu0F/asdf-extras/commit/d3e98fd2f76717f4a4be4029a88ed94251a36b82))


### Bug Fixes

* route init and completion through stable entry points ([#74](https://github.com/eihu0F/asdf-extras/issues/74)) ([73cf25e](https://github.com/eihu0F/asdf-extras/commit/73cf25e2dac897831c7e0270b7a87ab99173b328))
* show the resolved version when installing or updating a tool ([#76](https://github.com/eihu0F/asdf-extras/issues/76)) ([23d0c8e](https://github.com/eihu0F/asdf-extras/commit/23d0c8e89d4ac751965781bceda1ca895e9684e7))
* stop init from loading completion ([#71](https://github.com/eihu0F/asdf-extras/issues/71)) ([0c9d0dc](https://github.com/eihu0F/asdf-extras/commit/0c9d0dcd53da4c0d16187d6c9f52176c9d3ef75c))

## [0.9.2](https://github.com/eihu0F/asdf-extras/compare/v0.9.1...v0.9.2) (2026-10-23)


### Bug Fixes

* isolate install-time build environment ([#52](https://github.com/eihu0F/asdf-extras/issues/52)) ([7185ca4](https://github.com/eihu0F/asdf-extras/commit/7185ca4eae6e4e7d1462ec2e9f7eb95416758e5b))

## [0.9.1](https://github.com/eihu0F/asdf-extras/compare/v0.9.0...v0.9.1) (2026-10-21)


### Bug Fixes

* add per-plugin use-latest update control ([#49](https://github.com/eihu0F/asdf-extras/issues/49)) ([094f367](https://github.com/eihu0F/asdf-extras/commit/094f3677ed4d46909b5e888cf930af257c0695e5))

## [0.9.0](https://github.com/eihu0F/asdf-extras/compare/v0.8.1...v0.9.0) (2026-10-21)


### Features

* enhance update command with --use-latest option ([#47](https://github.com/eihu0F/asdf-extras/issues/47)) ([5c05db4](https://github.com/eihu0F/asdf-extras/commit/5c05db47e69c3e68b479aad7466f0fd01464cb0a))

## [0.8.0](https://github.com/eihu0F/asdf-extras/compare/v0.7.0...v0.8.0) (2026-10-21)


### Features

* enhance prune command with plugin selection ([#41](https://github.com/eihu0F/asdf-extras/issues/41)) ([eff59bf](https://github.com/eihu0F/asdf-extras/commit/eff59bf80c1ac6f7991d228dc4b7fd244967bd62))

## [0.7.0](https://github.com/eihu0F/asdf-extras/compare/v0.6.2...v0.7.0) (2026-10-21)


### Features

* add prune command and related documentation ([#39](https://github.com/eihu0F/asdf-extras/issues/39)) ([39649bd](https://github.com/eihu0F/asdf-extras/commit/39649bdd76d183b59c71e892d5baf2a5fc269abe))

## [0.6.2](https://github.com/eihu0F/asdf-extras/compare/v0.6.1...v0.6.2) (2026-10-21)


### Bug Fixes

* preserve running extras runtime during bulk updates ([#36](https://github.com/eihu0F/asdf-extras/issues/36)) ([1db23f6](https://github.com/eihu0F/asdf-extras/commit/1db23f65b2f1dd03088ea404b0656ddff62889e8))

## [0.6.1](https://github.com/eihu0F/asdf-extras/compare/v0.6.0...v0.6.1) (2026-10-21)


### Bug Fixes

* recognize prefixed asdf version output ([#34](https://github.com/eihu0F/asdf-extras/issues/34)) ([818c4ce](https://github.com/eihu0F/asdf-extras/commit/818c4ce2a633917f857f1d0b6cf8aaa1a37f8c3e))

## [0.6.0](https://github.com/eihu0F/asdf-extras/compare/v0.5.1...v0.6.0) (2026-10-21)


### Features

* add native-delegating Elvish completion ([#32](https://github.com/eihu0F/asdf-extras/issues/32)) ([56f7661](https://github.com/eihu0F/asdf-extras/commit/56f766157ca100fcefec88ed4f54faf4024b6bd6))
* add shell initialization refresh functionality ([#26](https://github.com/eihu0F/asdf-extras/issues/26)) ([fc464ac](https://github.com/eihu0F/asdf-extras/commit/fc464ac87260c7f48cd42ff80406d188640d9421))
* add support for local installation scope ([#23](https://github.com/eihu0F/asdf-extras/issues/23)) ([bd8305c](https://github.com/eihu0F/asdf-extras/commit/bd8305cee96e236999e2694c54436990b5e19e36))
* enhance asdf self-update functionality ([#25](https://github.com/eihu0F/asdf-extras/issues/25)) ([06a2a52](https://github.com/eihu0F/asdf-extras/commit/06a2a529bd62a03934cac87ddec5f2c1d47fd4b5))
* enhance update command safety and testing ([#15](https://github.com/eihu0F/asdf-extras/issues/15)) ([bb0f3e7](https://github.com/eihu0F/asdf-extras/commit/bb0f3e76c5d40421c377215f0611a64ffbcc267a))
* expose extras guidance through native asdf help ([#33](https://github.com/eihu0F/asdf-extras/issues/33)) ([8eda138](https://github.com/eihu0F/asdf-extras/commit/8eda1381f504a96f27ef16f3535c91d2108cc9a0))
* extend completion while preserving native handlers ([#29](https://github.com/eihu0F/asdf-extras/issues/29)) ([64c50f6](https://github.com/eihu0F/asdf-extras/commit/64c50f64dac86abd85142ee630e901cd79d58f67))
* integrate Nushell completion with native definitions ([#30](https://github.com/eihu0F/asdf-extras/issues/30)) ([8a2e86a](https://github.com/eihu0F/asdf-extras/commit/8a2e86a51287fc28aadffe160cb106313e20c8a4))

## [0.5.1](https://github.com/eihu0F/asdf-extras/compare/v0.5.0...v0.5.1) (2026-10-20)


### Bug Fixes

* support macOS Bash empty arrays during install ([#13](https://github.com/eihu0F/asdf-extras/issues/13)) ([d05ef7e](https://github.com/eihu0F/asdf-extras/commit/d05ef7e4c941f3034bbc7887561690f9119c4781))

## [0.5.0](https://github.com/eihu0F/asdf-extras/compare/v0.4.0...v0.5.0) (2026-10-20)


### Features

* add install-time environment hooks ([#12](https://github.com/eihu0F/asdf-extras/issues/12)) ([54ac3a0](https://github.com/eihu0F/asdf-extras/commit/54ac3a01e2eb6cc3f49d9c83598d50a2774daba2))
* harden update safety and branch precheck workflow ([#10](https://github.com/eihu0F/asdf-extras/issues/10)) ([fbbf776](https://github.com/eihu0F/asdf-extras/commit/fbbf7762733834cb10fa0edf388bd0ddeeaab400))

## [0.4.0](https://github.com/eihu0F/asdf-extras/compare/v0.3.0...v0.4.0) (2026-10-19)


### Features

* add branch precheck skill and update README ([#8](https://github.com/eihu0F/asdf-extras/issues/8)) ([cc554ad](https://github.com/eihu0F/asdf-extras/commit/cc554ad4a344b131d7c85aa16c73100cff73f0dc))

## [0.3.0](https://github.com/eihu0F/asdf-extras/compare/0.2.1...v0.3.0) (2026-10-19)


### Features

* enhance install command options ([65d8a1f](https://github.com/eihu0F/asdf-extras/commit/65d8a1f82d1b4d420fbae6702d80282f1e493bf5))


### Bug Fixes

* fetch missing release refs during download ([0edb94e](https://github.com/eihu0F/asdf-extras/commit/0edb94e050e7af9eb89ea63786c6fd0b9127484a))
* fetch missing release tags during plugin installation ([#5](https://github.com/eihu0F/asdf-extras/issues/5)) ([d388dcf](https://github.com/eihu0F/asdf-extras/commit/d388dcf77008464e19e48a0d67e98a3c882cbafb))
* resolve checkout reference for version ([9e27b07](https://github.com/eihu0F/asdf-extras/commit/9e27b07eed9309caaa5e3bb7839d34daf964b6ec))
