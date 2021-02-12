const HDWalletProvider = require("@truffle/hdwallet-provider");
require("dotenv").config();
const GAS_LIMIT = 8e6;

module.exports = {
    networks: {
        // Useful for testing. The `development` name is special - truffle uses it by default
        // if it's defined here and no other network is specified at the command line.
        // You should run a client (like ganache-cli, geth or parity) in a separate terminal
        // tab if you use this network and you must also set the `host`, `port` and `network_id`
        // options below to some value.
        //
        // development: {
        //  host: "127.0.0.1",     // Localhost (default: none)
        //  port: 8545,            // Standard Ethereum port (default: none)
        //  network_id: "*",       // Any network (default: none)
        // },
        // Another network with more advanced options...
        // advanced: {
        // port: 8777,             // Custom port
        // network_id: 1342,       // Custom network
        // gas: 8500000,           // Gas sent with each transaction (default: ~6700000)
        // gasPrice: 20000000000,  // 20 gwei (in wei) (default: 100 gwei)
        // from: <address>,        // Account to send txs from (default: accounts[0])
        // websockets: true        // Enable EventEmitter interface for web3 (default: false)
        // },
        // Useful for deploying to a public network.
        // NB: It's important to wrap the provider as a function.
        rinkeby: {
            provider: () => 
                new HDWalletProvider(
                    process.env.MNEMONIC,
                    `https://rinkeby.infura.io/v3/${process.env.INFURA_ID}`
                ),
            network_id: 4,       // Rinkeby id
            gas: 5500000,        // Rinkeby has a lower block limit than mainnet
            gasPrice: 1e9,        // Rinkeby has a lower block limit than mainnet
            confirmations: 2,    // # of confs to wait between deployments. (default: 0)
            timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
            skipDryRun: false     // Skip dry run before migrations? (default: false for public nets )
        },
        // Useful for private networks
        // private: {
        // provider: () => new HDWalletProvider(mnemonic, `https://network.io`),
        // network_id: 2111,   // This network is yours, in the cloud.
        // production: true    // Treats this network as if it was a public net. (default: false)
        // }

        goerli: {
            provider: () =>
                new HDWalletProvider(
                    process.env.MNEMONIC,
                    `https://goerli.infura.io/v3/${process.env.INFURA_ID}`
                ),
            network_id: 5, // Goerli's id
            gas: GAS_LIMIT,
            gasPrice: 10e9, // 10 GWEI
            //confirmations: 6, // # of confs to wait between deployments. (default: 0)
            timeoutBlocks: 50, // # of blocks before a deployment times out  (minimum/default: 50)
            skipDryRun: false // Skip dry run before migrations? (default: false for public nets )
        },
        ganache: {
            host: "127.0.0.1",
            network_id: "*",
            port: 8545
        }
    },
    compilers: {
        solc: {
            version: "0.7.6" // Fetch exact version from solc-bin (default: truffle's version)
        }
    },
    mocha: {
        timeout: 1000000
    },
    plugins: [
        'truffle-plugin-verify'
    ],
    api_keys: {
        etherscan: process.env.ETHERSCAN_API_KEY
    }
};
