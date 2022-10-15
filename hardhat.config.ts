import { config as dotenvConfig } from "dotenv";
import { resolve } from "path";
dotenvConfig({ path: resolve(__dirname, "./.env") });

import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "hardhat-gas-reporter";
import "@nomiclabs/hardhat-waffle";

const PRIVATE_KEY = process.env.PRIVATE_KEY || "";
const ARBITRUM_URL = process.env.ARBITRUM;
const ARBITRUM_RINKEBY_URL = process.env.ARBITRUM_RINKEBY;
const RINKEBY_URL = process.env.RINKEBY;

const config = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      mining: {
        //   auto: false,
        //   interval: [1000, 2000],
        auto: true,
      },
      timeout: 100_000,
      chainId: 1337,
      accounts: {
        count: 21,
      },
      loggingEnabled: true,
    },
    localhost: {
      timeout: 100_000,
      loggingEnabled: true,
      mining: {
        auto: true,
      },
      url: "http://127.0.0.1:8545/",
    },
    rinkeby: {
      url: RINKEBY_URL,
      accounts: [PRIVATE_KEY],
    },
    arbitrumRinkeby: {
      url: ARBITRUM_RINKEBY_URL,
      accounts: [PRIVATE_KEY],
    },
    arbitrum: {
      url: ARBITRUM_URL,
      accounts: [PRIVATE_KEY],
    },
  },
  solidity: "0.8.15",
  typechain: {
    outDir: "typechain-types", //for working ONLY in hardhat
    target: "ethers-v5",
  },
  mocha: {
    timeout: 1_200_000,
  },
};

export default config;
