const { ethers } = require("hardhat");

async function main() {
  console.log("Starting deployment...");

  // Get the contract factory for the CollateralizedLoan contract
  const CollateralizedLoan = await ethers.getContractFactory(
    "CollateralizedLoan"
  );

  // Default Loan to Value
  const LTV_PCT = 70; // Loan-to-Value ratio as a percentage

  // Deploy the contract
  const contract = await CollateralizedLoan.deploy(LTV_PCT);

  // The contract is now deployed, and you can log its address
  console.log(`CollateralizedLoan deployed successfully`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("An error occurred during deployment:", error);
    process.exit(1);
  });
