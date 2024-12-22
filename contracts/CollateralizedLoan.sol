// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

//
/// @title Collateralized Loan Contract
/// @notice A decentralized platform for collateralized lending
/// @dev Uses OpenZeppelin's Ownable to restrict sensitive operations to the owner
//
contract CollateralizedLoan is Ownable {
    /// @notice Structure defining a loan
    struct Loan {
        address borrower;          // Address of the borrower
        address lender;            // Address of the lender
        uint collateralAmount;     // Collateral amount provided by the borrower (in wei)
        uint amount;               // Loan amount (in wei)
        uint interestRate;         // Annual interest rate (in percentage)
        uint dueDate;              // Loan due date (timestamp)
        bool isFunded;             // True if the loan is funded by a lender
        bool isRepaid;             // True if the loan has been repaid
    }

    /// @notice Loan-to-Value (LTV) ratio, specified in percentage (0-100)
    uint public LTV;

    /// @notice Mapping to store loans by their unique ID
    mapping(uint => Loan) public loans;

    /// @notice Counter for generating unique loan IDs
    uint public nextLoanId;

    /// @notice Event emitted when a loan is requested
    event LoanRequested(
        address indexed borrower,
        uint amount,
        uint interestRate,
        uint duration
    );

    /// @notice Event emitted when a loan is funded by a lender
    event LoanFunded(
        uint loanId,
        uint amount,
        address lender,
        address borrower
    );

    /// @notice Event emitted when a loan is successfully repaid
    event LoanRepaid(
        uint loanId,
        uint amount,
        address lender,
        address borrower
    );

    /// @notice Event emitted when collateral is claimed on loan default
    event LoanCollateralClaimed(
        uint loanId,
        address borrower,
        address lender,
        uint amount
    );

    /// @dev Constructor to initialize the contract with a specified LTV ratio
    /// @param _ltv Loan-to-Value ratio (in percentage, max 100)
    constructor(uint _ltv) Ownable(msg.sender) {
        require(_ltv <= 100, "LTV cannot exceed 100%");
        LTV = _ltv;
    }

    /// @dev Modifier to ensure the loan exists
    modifier onlyLoanExists(uint loanId) {
        require(loans[loanId].amount > 0, "Loan does not exist");
        _;
    }

    /// @dev Modifier to ensure the loan is not funded
    modifier onlyLoanNotFunded(uint loanId) {
        require(!loans[loanId].isFunded, "Loan is already funded");
        _;
    }

    /// @dev Modifier to ensure the loan is funded
    modifier onlyLoanFunded(uint loanId) {
        require(loans[loanId].isFunded, "Loan is not funded yet");
        _;
    }

    /// @notice Allows borrowers to request a loan by depositing collateral
    /// @param _interestRate Annual interest rate for the loan (in percentage)
    /// @param _duration Loan duration (in seconds)
    function depositCollateralAndRequestLoan(uint _interestRate, uint _duration) external payable {
        require(msg.value > 0, "Collateral must be greater than zero");
        require(_interestRate > 0, "Interest rate must be positive");
        require(_duration > 0, "Duration must be positive");
        require(block.timestamp + _duration > block.timestamp, "Duration overflow");

        // Calculate loan amount based on Loan-to-Value ratio
        uint loanAmount = (LTV * msg.value) / 100;

        // Increment loan ID and create a new loan
        nextLoanId++;
        loans[nextLoanId] = Loan({
            borrower: msg.sender,
            lender: address(0),
            collateralAmount: msg.value,
            amount: loanAmount,
            interestRate: _interestRate,
            dueDate: block.timestamp + _duration,
            isFunded: false,
            isRepaid: false
        });

        emit LoanRequested(msg.sender, loanAmount, _interestRate, _duration);
    }

    /// @notice Allows a lender to fund a requested loan
    /// @param loanId ID of the loan to be funded
    function fundLoan(uint loanId) external payable onlyLoanExists(loanId) onlyLoanNotFunded(loanId) {
        Loan storage loan = loans[loanId];

        require(msg.value == loan.amount, "Incorrect funding amount");
        require(block.timestamp < loan.dueDate, "Loan due date has passed");

        // Transfer funds to the borrower
        (bool sent, ) = payable(loan.borrower).call{value: msg.value}("");
        require(sent, "Failed to transfer funds to borrower");

        // Update loan status
        loan.isFunded = true;
        loan.lender = msg.sender;

        emit LoanFunded(loanId, msg.value, msg.sender, loan.borrower);
    }

    /// @notice Allows a borrower to repay a funded loan
    /// @param loanId ID of the loan to be repaid
    function repayLoan(uint loanId) external payable onlyLoanExists(loanId) onlyLoanFunded(loanId) {
        Loan storage loan = loans[loanId];

        require(!loan.isRepaid, "Loan has already been repaid");

        // Calculate repayment amount (principal + interest)
        uint repaymentAmount = loan.amount + (loan.amount * loan.interestRate) / 100;
        require(msg.value == repaymentAmount, "Incorrect repayment amount");

        // Transfer repayment to the lender
        (bool sent, ) = payable(loan.lender).call{value: msg.value}("");
        require(sent, "Failed to transfer repayment to lender");

        // Mark loan as repaid
        loan.isRepaid = true;

        emit LoanRepaid(loanId, repaymentAmount, loan.lender, msg.sender);
    }

    /// @notice Allows a lender to claim collateral if the loan defaults
    /// @param loanId ID of the loan for which collateral is claimed
    function claimCollateral(uint loanId) external onlyLoanExists(loanId) {
        Loan storage loan = loans[loanId];

        require(block.timestamp > loan.dueDate, "Loan is not in default");
        require(loan.isFunded, "Loan is not funded");
        require(!loan.isRepaid, "Loan has already been repaid");
        require(msg.sender == loan.lender, "Only the lender can claim collateral");

        // Transfer collateral to the lender
        (bool sent, ) = payable(loan.lender).call{value: loan.collateralAmount}("");
        require(sent, "Failed to transfer collateral to lender");

        emit LoanCollateralClaimed(loanId, loan.borrower, loan.lender, loan.collateralAmount);
    }
}