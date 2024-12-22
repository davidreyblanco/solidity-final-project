// Importing necessary modules and functions from Hardhat and Chai for testing
const { loadFixture, time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

// Describing a test suite for the CollateralizedLoan contract
describe("CollateralizedLoan", function () {
  /**
   * Loan Parameters:
   * - Loan-to-Value (LTV): 72% (0.72 on a 0-1 scale)
   * - Interest Rate: 5% per annum
   * - Loan Duration: 600 seconds (10 minutes)
   * - Collateral Value: Equivalent to 100% of the loan amount
   */
  const LTV_PCT = 72; // Loan-to-Value percentage
  const LTV = LTV_PCT / 100; // Loan-to-Value ratio
  const interestRate = 5; // Annual interest rate (percentage)
  const loanDuration = 600; // Loan duration in seconds (10 minutes)

  /**
   * Fixture to deploy the CollateralizedLoan contract.
   * This ensures a fresh contract instance is available before each test.
   */
  async function deployCollateralizedLoanFixture() {
    const [owner, addr1, addr2] = await ethers.getSigners();

    // Deploying the contract
    const CollateralizedLoan = await ethers.getContractFactory("CollateralizedLoan");
    const contract = await CollateralizedLoan.deploy(LTV_PCT);
    await contract.waitForDeployment();

    return { contract, owner, addr1, addr2 };
  }

  /**
   * Test suite for the loan request functionality
   */
  describe("Loan Request", function () {
    it("Should let a borrower deposit collateral and request a loan", async function () {
      // Load the deployed fixture
      const { contract, addr1 } = await loadFixture(deployCollateralizedLoanFixture);

      // Borrower deposits 1 ETH as collateral
      const collateralAmount = ethers.parseEther("1");

      // Check that the LoanRequested event is emitted with the correct data
      await expect(
        contract.connect(addr1).depositCollateralAndRequestLoan(interestRate, loanDuration, {
          value: collateralAmount,
        })
      )
        .to.emit(contract, "LoanRequested")
        .withArgs(
          addr1.address,
          ethers.parseEther(LTV.toString()),
          interestRate,
          loanDuration
        );
    });
  });

  /**
   * Test suite for funding a loan
   */
  describe("Funding a Loan", function () {
    it("Allows a lender to fund a requested loan", async function () {
      // Load the deployed fixture
      const { contract, addr1, addr2 } = await loadFixture(deployCollateralizedLoanFixture);

      // Borrower requests a loan
      const collateralAmount = ethers.parseEther("1");
      await contract.connect(addr1).depositCollateralAndRequestLoan(interestRate, loanDuration, {
        value: collateralAmount,
      });

      // Lender funds the loan
      const loanAmount = ethers.parseEther(LTV.toString());
      await expect(contract.connect(addr2).fundLoan(1, { value: loanAmount }))
        .to.emit(contract, "LoanFunded")
        .withArgs(1, loanAmount, addr2.address, addr1.address);
    });
  });

  /**
   * Test suite for repaying a loan
   */
  describe("Repaying a Loan", function () {
    it("Enables the borrower to repay the loan fully", async function () {
      // Load the deployed fixture
      const { contract, addr1, addr2 } = await loadFixture(deployCollateralizedLoanFixture);

      // Borrower requests and lender funds the loan
      const collateralAmount = ethers.parseEther("1");
      await contract.connect(addr1).depositCollateralAndRequestLoan(interestRate, loanDuration, {
        value: collateralAmount,
      });
      await contract.connect(addr2).fundLoan(1, { value: ethers.parseEther(LTV.toString()) });

      // Calculate repayment amount (principal + interest)
      const expectedRepaymentAmount = (LTV * (1 + interestRate / 100)).toFixed(4); // Rounded to 4 decimals
      const repaymentAmount = ethers.parseEther(expectedRepaymentAmount.toString());

      // Check that the LoanRepaid event is emitted with the correct data
      await expect(contract.connect(addr1).repayLoan(1, { value: repaymentAmount }))
        .to.emit(contract, "LoanRepaid")
        .withArgs(1, repaymentAmount, addr2.address, addr1.address);
    });
  });

  /**
   * Test suite for claiming collateral
   */
  describe("Claiming Collateral", function () {
    it("Permits the lender to claim collateral if the loan isn't repaid on time", async function () {
      // Load the deployed fixture
      const { contract, addr1, addr2 } = await loadFixture(deployCollateralizedLoanFixture);

      // Borrower requests and lender funds the loan
      const collateralAmount = ethers.parseEther("1");
      await contract.connect(addr1).depositCollateralAndRequestLoan(interestRate, loanDuration, {
        value: collateralAmount,
      });
      await contract.connect(addr2).fundLoan(1, { value: ethers.parseEther(LTV.toString()) });

      // Simulate time passage beyond the loan duration
      await ethers.provider.send("evm_increaseTime", [loanDuration + 1]);
      await ethers.provider.send("evm_mine");

      // Lender claims collateral
      await expect(contract.connect(addr2).claimCollateral(1))
        .to.emit(contract, "LoanCollateralClaimed")
        .withArgs(1, addr1.address, addr2.address, collateralAmount);
    });
  });
});