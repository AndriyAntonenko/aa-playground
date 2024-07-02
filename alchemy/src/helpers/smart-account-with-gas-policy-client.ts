// Import the necessary packages
import {
  LocalAccountSigner,
  type SmartAccountSigner,
  sepolia,
} from "@alchemy/aa-core";
import { createModularAccountAlchemyClient } from "@alchemy/aa-alchemy";
import { config } from "./config";

// Define the constants
const chain = sepolia;
const signer: SmartAccountSigner = LocalAccountSigner.privateKeyToAccountSigner(
  `0x${config.PRIV_KEY}`
);

/**
 * @description Creates a smart contract account that can be used to send user operations.
 * @returns The smart contract account owner + provider, as a signer, that can be used to send user operations from the SCA
 */

// Client with the Gas Manager to sponsor gas.
// Find your Gas Manager policy id at: dashboard.alchemy.com/gas-manager/policy/create
export const smartAccountClient = await createModularAccountAlchemyClient({
  apiKey: config.ALCHEMY_API_KEY,
  chain,
  signer, // or any SmartAccountSigner
  gasManagerConfig: {
    policyId: config.ALCHEMY_GAS_MANAGER_POLICY_ID,
  },
});
