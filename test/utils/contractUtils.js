const path = require("path");

/// @dev Load contract from truffle built artifacts
const builtTruffleContractLoader = (name) => {
    try {
        const filePath = path.join("@superfluid-finance/ethereum-contracts/build/contracts", name + ".json");
        const builtContract = require(filePath);
        return {
            name,
            abi: builtContract.abi,
            bytecode: builtContract.bytecode,
        }
    } catch (e) {
        throw new Error(
            `Cannot load built truffle contract ${name}. Have you built?`
        );
    }
}

module.exports = {
    builtTruffleContractLoader
}