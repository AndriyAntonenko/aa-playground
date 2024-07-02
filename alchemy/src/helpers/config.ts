import * as dotenv from "dotenv";

dotenv.config();
const {
  PRIV_KEY,
  ALCHEMY_API_KEY,
  ALCHEMY_API_URL,
  ALCHEMY_GAS_MANAGER_POLICY_ID,
} = process.env;

if (!PRIV_KEY) {
  throw new Error("Please provide a private key in the .env file as PRIV_KEY");
}

if (!ALCHEMY_API_KEY) {
  throw new Error(
    "Please provide an Alchemy API key in the .env file as ALCHEMY_API_KEY"
  );
}

if (!ALCHEMY_API_URL) {
  throw new Error(
    "Please provide an Alchemy API URL in the .env file as ALCHEMY_API_URL"
  );
}

if (!ALCHEMY_GAS_MANAGER_POLICY_ID) {
  throw new Error(
    "Please provide an Alchemy Gas Manager policy ID in the .env file as ALCHEMY_GAS_MANAGER_POLICY_ID"
  );
}

export const config = {
  PRIV_KEY,
  ALCHEMY_API_KEY,
  ALCHEMY_API_URL,
  ALCHEMY_GAS_MANAGER_POLICY_ID,
};
