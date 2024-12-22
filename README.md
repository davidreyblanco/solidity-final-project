# CollateralizedLoan Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract which is a very basic code for a collateralized Loan project, a test for that contract, and a script that deploys that contract.

## Original instructions

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.js
```

The contract has been deployed to Sepolia network. Please check the following link [here](https://sepolia.etherscan.io/address/0x8c589aa05de02276954542d1ed01b695e61ad58f).



# Assumptions

I changed original solidity version 8.0.19 to 8.0.20 in order to work better with Ownable library (in order to prevent some of the most common attacks).

I also made the contract slightly configurable, where Loan To Value is configurable when instantiation:

```
    // Default Loan to Value
    const LTV_PCT = 70; // Loan-to-Value ratio as a percentage

    // Deploy the contract
    const contract = await CollateralizedLoan.deploy(LTV_PCT);
```

# Project documentation

## Overview
The `CollateralizedLoan` contract is a decentralized platform for collateralized lending. Borrowers can request loans by depositing collateral, and lenders can fund these loans. The contract is designed to ensure security and fairness by enforcing conditions on loans, repayments, and collateral claims.

---

## Features
- **Collateralized Loans**: Borrowers must deposit collateral to request loans.
- **Loan-to-Value (LTV) Ratio**: Determines the maximum loan amount as a percentage of the collateral value.
- **Event-Driven Architecture**: Emits events for key actions like loan requests, funding, repayments, and collateral claims.
- **Owner-Only Configuration**: The contract owner can modify sensitive parameters like the LTV ratio.

---

## Key Components

### **1. Structs**
#### `Loan`
Defines the structure of a loan:
- `borrower` (`address`): The borrower’s address.
- `lender` (`address`): The lender’s address.
- `collateralAmount` (`uint`): The amount of collateral deposited (in wei).
- `amount` (`uint`): The loan amount (in wei).
- `interestRate` (`uint`): The annual interest rate (percentage).
- `dueDate` (`uint`): The loan's due date (timestamp).
- `isFunded` (`bool`): Whether the loan is funded by a lender.
- `isRepaid` (`bool`): Whether the loan has been repaid.

---

### **2. State Variables**
- `LTV` (`uint`): Loan-to-Value ratio (percentage, max 100). Determines the maximum loan amount based on the collateral.
- `loans` (`mapping(uint => Loan)`): A mapping of loan IDs to loan details.
- `nextLoanId` (`uint`): Counter for generating unique loan IDs.

---

### **3. Events**
The contract emits the following events to track important actions:
- **`LoanRequested`**:
  - Emitted when a borrower requests a loan.
  - Parameters: `borrower`, `amount`, `interestRate`, `dueDate`.
  
- **`LoanFunded`**:
  - Emitted when a lender funds a loan.
  - Parameters: `loanId`, `amount`, `lender`, `borrower`.

- **`LoanRepaid`**:
  - Emitted when a borrower repays a loan.
  - Parameters: `loanId`, `amount`, `lender`, `borrower`.

- **`LoanCollateralClaimed`**:
  - Emitted when a lender claims collateral for a defaulted loan.
  - Parameters: `loanId`, `borrower`, `lender`, `amount`.

---

### **4. Modifiers**
- **`onlyLoanExists(uint loanId)`**: Ensures the loan exists.
- **`onlyLoanNotFunded(uint loanId)`**: Ensures the loan has not been funded.
- **`onlyLoanFunded(uint loanId)`**: Ensures the loan has been funded.

---

### **5. Functions**

#### **`constructor(uint _ltv)`**
- Initializes the contract with an LTV ratio.
- **Parameters**:
  - `_ltv` (`uint`): Loan-to-Value ratio (percentage, max 100).
- **Access Control**: Only callable during contract deployment.

#### **`depositCollateralAndRequestLoan(uint _interestRate, uint _duration)`**
- Allows a borrower to request a loan by depositing collateral.
- **Parameters**:
  - `_interestRate` (`uint`): Annual interest rate for the loan (in percentage).
  - `_duration` (`uint`): Loan duration (in seconds).
- **Requirements**:
  - Collateral (`msg.value`) must be greater than 0.
  - `_interestRate` and `_duration` must be positive.
  - No overflow in due date calculation.
- **Emits**: `LoanRequested`.

---

#### **`fundLoan(uint loanId)`**
- Allows a lender to fund a requested loan.
- **Parameters**:
  - `loanId` (`uint`): ID of the loan to be funded.
- **Requirements**:
  - Loan must exist and not be funded.
  - Funding amount must match the loan amount.
  - Current time must be before the loan's due date.
- **Emits**: `LoanFunded`.

---

#### **`repayLoan(uint loanId)`**
- Allows a borrower to repay a funded loan.
- **Parameters**:
  - `loanId` (`uint`): ID of the loan to be repaid.
- **Requirements**:
  - Loan must exist and be funded.
  - Loan must not already be repaid.
  - Repayment amount must match the principal plus interest.
- **Emits**: `LoanRepaid`.

---

#### **`claimCollateral(uint loanId)`**
- Allows a lender to claim collateral if the loan defaults.
- **Parameters**:
  - `loanId` (`uint`): ID of the loan for which collateral is claimed.
- **Requirements**:
  - Loan must exist and be funded.
 
## Tests Description

### Overview
This section outlines the test cases written to validate the functionality of the `CollateralizedLoan` smart contract. The tests are designed to ensure that the contract behaves correctly under various scenarios, covering loan requests, funding, repayments, and collateral claims.

---

### Test Setup
1. **Loan Parameters:**
   - Loan-to-Value (LTV): 72% (0.72 on a 0-1 scale).
   - Interest Rate: 5% per annum.
   - Loan Duration: 600 seconds (10 minutes).
   - Collateral Value: Equivalent to 100% of the loan amount.

2. **Testing Tools:**
   - **Hardhat** for local Ethereum blockchain simulation.
   - **Chai** for assertions.
   - **Hardhat Network Helpers** for managing time and fixtures.

3. **Fixture:** A helper function `deployCollateralizedLoanFixture` is used to deploy the contract and set up initial testing states.

---

### Test Suites

#### **Loan Request**
- **Description:** Validates that a borrower can deposit collateral and request a loan.
- **Key Steps:**
  1. Borrower deposits collateral (1 ETH).
  2. Checks that the `LoanRequested` event is emitted with correct data.
- **Assertions:**
  - Event is emitted.
  - Event arguments match the expected values:
    - Borrower address.
    - Loan amount (calculated as LTV * collateral).
    - Interest rate.
    - Loan duration.

#### **Funding a Loan**
- **Description:** Ensures that a lender can fund a requested loan.
- **Key Steps:**
  1. Borrower requests a loan.
  2. Lender funds the loan with the correct amount.
  3. Checks that the `LoanFunded` event is emitted with correct data.
- **Assertions:**
  - Event is emitted.
  - Event arguments match the expected values:
    - Loan ID.
    - Funded amount.
    - Lender address.
    - Borrower address.

#### **Repaying a Loan**
- **Description:** Tests the functionality for a borrower to repay a funded loan.
- **Key Steps:**
  1. Borrower requests a loan.
  2. Lender funds the loan.
  3. Borrower repays the loan, including interest.
  4. Checks that the `LoanRepaid` event is emitted with correct data.
- **Calculations:**
  - Repayment amount = `loan amount * (1 + interest rate)`.
  - Handles potential rounding issues by ensuring precision to 4 decimal places.
- **Assertions:**
  - Event is emitted.
  - Event arguments match the expected values:
    - Loan ID.
    - Repayment amount.
    - Lender address.
    - Borrower address.

#### **Claiming Collateral**
- **Description:** Verifies that a lender can claim collateral if the loan is not repaid on time.
- **Key Steps:**
  1. Borrower requests a loan.
  2. Lender funds the loan.
  3. Simulate the passage of time beyond the loan duration.
  4. Lender claims collateral.
  5. Checks that the `LoanCollateralClaimed` event is emitted with correct data.
- **Assertions:**
  - Event is emitted.
  - Event arguments match the expected values:
    - Loan ID.
    - Borrower address.
    - Lender address.
    - Collateral amount.

---

### Example Constants
- **LTV:** `72%` (0.72 on a 0-1 scale).
- **Interest Rate:** `5%`.
- **Loan Duration:** `600 seconds` (10 minutes).
- **Collateral Amount:** `1 ETH`.

---

### Key Features
1. **Event Validation:** Each test case validates emitted events and their arguments.
2. **Dynamic Time Handling:** Simulates time progression for testing collateral claims.
3. **Precise Calculations:** Ensures correct repayment amount, considering floating-point precision.