.PHONY: echidna echidna-assert echidna-explore

echidna:
	SOLC_VERSION=0.8.19 echidna-test ./echidna/EchidnaStakeBakeE2E.sol --contract EchidnaStakeBakeE2E --config ./echidna_config.yaml --workers 10 --test-mode property

echidna-assert:
	SOLC_VERSION=0.8.19 echidna-test ./echidna/EchidnaStakeBakeE2E.sol --contract EchidnaStakeBakeE2E --config ./echidna_config.yaml --workers 10 --test-mode assertion

echidna-explore:
	SOLC_VERSION=0.8.19 echidna-test ./echidna/EchidnaStakeBakeE2E.sol --contract EchidnaStakeBakeE2E --config ./echidna_config.yaml --workers 10 --test-mode exploration