import * as dotenv from "dotenv";

dotenv.config();
const { PRIV_KEY, ALCHEMY_API_KEY, ALCHEMY_API_URL } = process.env;

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

export const config = {
  PRIV_KEY,
  ALCHEMY_API_KEY,
  ALCHEMY_API_URL,
};
