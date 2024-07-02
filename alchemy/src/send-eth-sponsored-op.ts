/// Import the required functions and modules
import { parseEther } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import type { SendUserOperationResult } from "@alchemy/aa-core";

import { smartAccountClient } from "./helpers/smart-account-with-gas-policy-client";
import { config } from "./helpers/config";

/**
 * @description Creates a smart contract account, and sends ETH to the specified address (could be an EOA or SCA)
 * @note Seperating the logic to create the account, and the logic to send the transaction
 */
export async function main() {
  const account = privateKeyToAccount(`0x${config.PRIV_KEY}`);

  const amountToSend: bigint = parseEther("0.001");

  const result: SendUserOperationResult =
    await smartAccountClient.sendUserOperation({
      uo: {
        target: account.address,
        data: "0x",
        value: amountToSend,
      },
    });

  console.log("User operation result: ", result);

  console.log(
    "\nWaiting for the user operation to be included in a mined transaction..."
  );

  const txHash = await smartAccountClient.waitForUserOperationTransaction(
    result
  );

  console.log("\nTransaction hash: ", txHash);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
