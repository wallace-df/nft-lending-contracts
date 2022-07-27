
//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTLendingController {

  ////////////////////////////////////////////////////////////////////////////////
  // DATA STRUCTURES
  ////////////////////////////////////////////////////////////////////////////////

  struct Loan {
    uint256 id;
    address nftCollectionAddress;
    uint256 nftTokenId;
    uint256 amount;
    uint256 interest;
    uint256 duration;
    uint256 dueTimestamp;
    address borrowerAddress;
    address lenderAddress;
    LoanStatus status;
  }

  enum LoanStatus{
    OPEN,
    CANCELLED,
    ACTIVE,
    REPAID,
    DEFAULTED,
    CLAIMED
  }

  ////////////////////////////////////////////////////////////////////////////////
  // EVENTS
  ////////////////////////////////////////////////////////////////////////////////

  event LoanListed(uint256 loanId, address nftCollectionAddress, uint256 nftTokenId, uint256 amount, uint256 interest, uint256 duration, address borrowerAddress);
  event LoanCancelled(uint256 loanId);
  event LoanActivated(uint256 loanId, uint256 dueTimestamp, address lenderAddress);
  event LoanRepaid(uint256 loanId);
  event LoanDefaulted(uint256 loanId);
  event LoanClaimed(uint256 loanId);

  ////////////////////////////////////////////////////////////////////////////////
  // STORAGE VARIABLES
  ////////////////////////////////////////////////////////////////////////////////

  mapping(uint256 => Loan) private _loans;
  uint256 private _lastLoanId;

  ////////////////////////////////////////////////////////////////////////////////
  // FUNCTIONS
  ////////////////////////////////////////////////////////////////////////////////

  function listLoan(address _nftCollectionAddress, uint256 _nftTokenId, uint256 _amount, uint256 _interest, uint256 _duration) external {
    require(_nftCollectionAddress != address(0x0), "Invalid NFT address.");
    require(_nftTokenId > 0, "Invalid NFT tokenId.");
    require(_amount > 0, "Invalid loan amount.");
    require(_interest > 0, "Invalid loan interest.");
    require(_duration > 1 minutes, "Invalid loan duration.");

    IERC721(_nftCollectionAddress).transferFrom(msg.sender, address(this), _nftTokenId);

    _lastLoanId++;  
 
    Loan storage loan = _loans[_lastLoanId];
    loan.id = _lastLoanId;
    loan.nftCollectionAddress = _nftCollectionAddress;
    loan.nftTokenId = _nftTokenId;
    loan.amount = _amount;
    loan.interest = _interest;
    loan.duration = _duration;
    loan.dueTimestamp = 0;
    loan.borrowerAddress = msg.sender;
    loan.lenderAddress = address(0x0);
    loan.status = LoanStatus.OPEN;

    emit LoanListed(_lastLoanId, _nftCollectionAddress, _nftTokenId, _amount, _interest, _duration, msg.sender);
  }

  function cancelLoan(uint256 _loanId) external {
    Loan storage loan = _loans[_loanId];
    
    require(loan.id == _loanId && _loanId > 0, "Loan not found");
    require(loan.status == LoanStatus.OPEN, "Loan is not OPEN");
    require(loan.borrowerAddress == msg.sender, "Only the borrower can cancel the loan");

    IERC721(loan.nftCollectionAddress).transferFrom(address(this), loan.borrowerAddress, loan.nftTokenId);

    loan.status = LoanStatus.CANCELLED;

    emit LoanCancelled(loan.id);
  }

  function activateLoan(uint256 _loanId) external {
    Loan storage loan = _loans[_loanId];
    
    require(loan.id == _loanId && _loanId > 0, "Loan not found");
    require(loan.status == LoanStatus.OPEN, "Loan is not OPEN");
    require(loan.borrowerAddress != msg.sender, "Borrower cannot activate the loan");

    loan.dueTimestamp = block.timestamp + loan.duration;
    loan.lenderAddress = msg.sender;
    loan.status = LoanStatus.ACTIVE;

    // TODO: transfer money from lender to borrower.

    emit LoanActivated(loan.id, loan.dueTimestamp, loan.lenderAddress);
  }

  function repayLoan(uint _loanId) external {
    Loan storage loan = _loans[_loanId];
    
    require(loan.id == _loanId && _loanId > 0, "Loan not found");
    require(loan.status == LoanStatus.ACTIVE, "Loan is not ACTIVE");
    require(loan.borrowerAddress == msg.sender, "Only the borrower can repay the loan");

    loan.status = LoanStatus.REPAID;

    // TODO: escrow payment for the lender.

    IERC721(loan.nftCollectionAddress).transferFrom(address(this), loan.borrowerAddress, loan.nftTokenId);

    emit LoanRepaid(loan.id);
  }

  function claimLoan(uint256 _loanId) external {
    Loan storage loan = _loans[_loanId];
    
    require(loan.id == _loanId && _loanId > 0, "Loan not found");
    require(loan.status == LoanStatus.REPAID, "Loan is not REPAID");

    // TODO: transfer funds to lender.

    loan.status = LoanStatus.CLAIMED;

    emit LoanClaimed(loan.id);
  }

  function defaultLoan(uint _loanId) external {
    Loan storage loan = _loans[_loanId];
    
    require(loan.id == _loanId && _loanId > 0, "Loan not found");
    require(loan.status == LoanStatus.ACTIVE, "Loan is not ACTIVE");
    require(loan.dueTimestamp < block.timestamp, "Loan is still ACTIVE");

    IERC721(loan.nftCollectionAddress).transferFrom(address(this), loan.lenderAddress, loan.nftTokenId);
    
    loan.status = LoanStatus.DEFAULTED;

    emit LoanDefaulted(loan.id);      
  }
}
