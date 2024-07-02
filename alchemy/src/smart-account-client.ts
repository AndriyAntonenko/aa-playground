import {
  LocalAccountSigner,
  type SmartAccountSigner,
  sepolia,
} from "@alchemy/aa-core";
import { createModularAccountAlchemyClient } from "@alchemy/aa-alchemy";
import { config } from "./config";

const signer: SmartAccountSigner = LocalAccountSigner.privateKeyToAccountSigner(
  `0x${config.PRIV_KEY}`
);

export const smartAccountClient = await createModularAccountAlchemyClient({
  apiKey: config.ALCHEMY_API_KEY,
  chain: sepolia,
  signer, // or any SmartAccountSigner
});
