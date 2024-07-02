import { parseEther } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { createWalletClient, http } from "viem";
import { sepolia } from "viem/chains";
import type { SendUserOperationResult } from "@alchemy/aa-core";

import { smartAccountClient } from "./smart-account-client";
import { config } from "./config";

async function main(): Promise<void> {
  const smartAccountAddress = smartAccountClient.getAddress();

  const balance = await smartAccountClient.getBalance({
    address: smartAccountAddress,
  });

  console.log(`Smart account balance: ${balance}`);

  const account = privateKeyToAccount(`0x${config.PRIV_KEY}`);

  const wallet = createWalletClient({
    account: account,
    chain: sepolia,
    transport: http(config.ALCHEMY_API_URL),
  });

  if (parseEther("0.05") > balance) {
    console.log(`Sending 0.1 ETH to smart account: ${smartAccountAddress}`);
    const txHash = await wallet.sendTransaction({
      to: smartAccountAddress,
      value: parseEther("0.1"),
    });

    console.log(`Sent 0.1 ETH to smart account: ${smartAccountAddress}`);
    console.log(`Transaction hash: ${txHash}`);

    return; // Exit the script, we need to wait for the transaction to be mined
  }

  const amountToSend = parseEther("0.001");

  const result: SendUserOperationResult =
    await smartAccountClient.sendUserOperation({
      uo: {
        target: account.address,
        value: amountToSend,
        data: "0x",
      },
    });

  console.log(`Sent ${amountToSend} to ${account.address}`);
  console.info("User operation result:", result);

  console.info(
    "\nWaiting for the user operation to be included in a mined transaction..."
  );

  const txHash = await smartAccountClient.waitForUserOperationTransaction(
    result
  );

  console.log(`User operation included in transaction: ${txHash}`);

  const userOpReceipt = await smartAccountClient.getUserOperationReceipt(
    result.hash
  );

  console.log("User operation receipt:", userOpReceipt);

  const txReceipt = await smartAccountClient.waitForTransactionReceipt({
    hash: txHash,
  });

  console.log("Transaction receipt:", txReceipt);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
