
//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTLendingController {

  ////////////////////////////////////////////////////////////////////////////////
  // DATA STRUCTURES
  ////////////////////////////////////////////////////////////////////////////////

  struct Loan {
    uint256 id;
    address nftCollateralAddress;
    uint256 nftCollateralTokenId;
    uint256 amount;
    uint256 interest;
    uint256 duration;
    uint256 startTime;
    uint256 endTime;
    address borrowerAddress;
    address lenderAddress;
    bool withdrawn;
    LoanStatus status;
  }

  enum LoanStatus{
    OPEN,
    ACTIVE,
    CANCELLED,
    REPAID,
    DEFAULTED
  }

  ////////////////////////////////////////////////////////////////////////////////
  // EVENTS
  ////////////////////////////////////////////////////////////////////////////////

  event LoanListed(address nftCollateralAddress, uint256 nftCollateralTokenId, uint256 amount, uint256 interest, uint256 duration, address borrowerAddress);
  event LoanActivated(uint256 id, uint256 startTime, uint256 endTime, address lenderAddress);
  event LoanCancelled(uint256 id);
  event LoanRepaid(uint256 id);
  event LoanFundsWithdrawn(uint256 id);
  event LoanCollateralWithdrawn(uint256 id);

  ////////////////////////////////////////////////////////////////////////////////
  // STORAGE VARIABLES
  ////////////////////////////////////////////////////////////////////////////////

  mapping(uint256 => Loan) private _loans;
  uint256 private _lastLoanId;

  ////////////////////////////////////////////////////////////////////////////////
  // FUNCTIONS
  ////////////////////////////////////////////////////////////////////////////////

  function listLoan(address _nftCollateralAddress, uint256 _nftCollateralTokenId, uint256 _amount, uint256 _interest, uint256 _duration) external {
    require(_nftCollateralAddress != address(0x0), "Invalid NFT address.");
    require(_nftCollateralTokenId > 0, "Invalid NFT tokenId.");
    require(_amount > 0, "Invalid loan amount.");
    require(_interest > 0, "Invalid loan interest.");
    require(_duration > 7 days, "Invalid loan duration.");

    IERC721 nftCollection = IERC721(_nftCollateralAddress);
    require(nftCollection.ownerOf(_nftCollateralTokenId) == msg.sender, "User does not own this NFT");
    nftCollection.transferFrom(msg.sender, address(this), _nftCollateralTokenId);

    _lastLoanId++;  
    Loan storage loan = _loans[_lastLoanId];
    loan.id = _lastLoanId;
    loan.nftCollateralAddress = _nftCollateralAddress;
    loan.nftCollateralTokenId = _nftCollateralTokenId;
    loan.amount = _amount;
    loan.interest = _interest;
    loan.duration = _duration;
    loan.startTime = 0;
    loan.endTime = 0;
    loan.borrowerAddress = msg.sender;
    loan.lenderAddress = address(0x0);
    loan.withdrawn = false;
    loan.status = LoanStatus.OPEN;

    emit LoanListed(_nftCollateralAddress, _nftCollateralTokenId, _amount, _interest, _duration, msg.sender);
  }

  function cancelLoan(uint256 _loanId) external {
    Loan storage loan = _loans[_loanId];
    
    require(_loanId > 0 && loan.id == _loanId, "Loan not found");
    require(loan.status == LoanStatus.OPEN, "Loan is not OPEN");
    require(msg.sender == loan.borrowerAddress, "Only the borrower can cancel the loan");

    loan.status = LoanStatus.CANCELLED;

    emit LoanCancelled(loan.id);
  }

  function activateLoan(uint256 _loanId) external {
    Loan storage loan = _loans[_loanId];
    
    require(_loanId > 0 && loan.id == _loanId, "Loan not found");
    require(loan.status == LoanStatus.OPEN, "Loan is not OPEN");
    require(msg.sender != loan.borrowerAddress, "Borrower cannot activate the loan");

    loan.startTime = block.timestamp;
    loan.endTime = block.timestamp + loan.duration;
    loan.lenderAddress = msg.sender;
    loan.status = LoanStatus.ACTIVE;

    // TODO: transfer money from lender to borrower.

    emit LoanActivated(loan.id, loan.startTime, loan.endTime, loan.lenderAddress);
  }

  function repayLoan(uint _loanId) external {
    Loan storage loan = _loans[_loanId];
    
    require(_loanId > 0 && loan.id == _loanId, "Loan not found");
    require(loan.status == LoanStatus.ACTIVE, "Loan is not ACTIVE");
    require(loan.endTime >= block.timestamp, "Loan has defaulted");
    require(msg.sender == loan.borrowerAddress, "Only the borrower can repay the loan");

    loan.status = LoanStatus.REPAID;

    // TODO: escrow payment for the lender.

    IERC721(loan.nftCollateralAddress).transferFrom(address(this), loan.borrowerAddress, loan.nftCollateralTokenId);
    emit LoanRepaid(loan.id);
  }

  function withdrawLoanFunds(uint256 _loanId) external {
    Loan storage loan = _loans[_loanId];
    
    require(_loanId > 0 && loan.id == _loanId, "Loan not found");
    require(loan.status == LoanStatus.REPAID, "Loan is not REPAID");
    require(msg.sender == loan.lenderAddress, "Only the lender can withdraw the loan funds");
    require(loan.withdrawn == false, "Loan funds have been already withdrawn");

    // TODO: transfer funds to lender.

    loan.withdrawn = true;

    emit LoanFundsWithdrawn(loan.id);
  }

  function withdrawLoanCollateral(uint _loanId) external {
    Loan storage loan = _loans[_loanId];
    
    require(_loanId > 0 && loan.id == _loanId, "Loan not found");
    require(loan.status == LoanStatus.ACTIVE, "Loan is not ACTIVE");
    require(loan.endTime < block.timestamp, "Loan is still ACTIVE");
    require(msg.sender == loan.lenderAddress, "Only the lender can withdraw the loan collateral");
    require(loan.withdrawn == false, "Loan collateral has been already withdrawn");

    IERC721(loan.nftCollateralAddress).transferFrom(address(this), loan.lenderAddress, loan.nftCollateralTokenId);
    loan.withdrawn = true;
    loan.status = LoanStatus.DEFAULTED;

    emit LoanCollateralWithdrawn(loan.id);      
  }
}
