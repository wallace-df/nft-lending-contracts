set -e
mkdir -p artifacts/compiled
mkdir -p artifacts/abis
cd contracts

starknet-compile NFTLendingController.cairo \
    --output ../artifacts/compiled/NFTLendingController.json \
    --abi ../artifacts/abis/NFTLendingController.json

echo "Done!"