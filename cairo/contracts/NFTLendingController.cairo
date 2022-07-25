%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_check,
    uint256_le,
    uint256_eq,
    uint256_lt
)

from openzeppelin.security.safemath import (
    uint256_checked_add,
    uint256_checked_sub_le
)

from openzeppelin.token.erc721.library import (
    ERC721_ownerOf,
    ERC721_transferFrom,
)

##################################################################
# DATA STRUCTURES
##################################################################

const LOAN_STATUS_OPEN = 0
const LOAN_STATUS_ACTIVE = 1
const LOAN_STATUS_CANCELED = 2
const LOAN_STATUS_REPAID = 3
const LOAN_STATUS_DEFAULTED = 4

struct Loan:
    member id: Uint256
    member nftCollateralAddress: felt
    member nftCollateralTokenId: Uint256
    member amount: Uint256
    member interest: Uint256
    member duration: felt
    member startTime: felt
    member endTime: felt
    member borrowerAddress: felt
    member lenderAddress: felt
    member withdrawn: felt
    member status: felt
end

##################################################################
# EVENTS
##################################################################

@event
func LoanListed(nftCollateralAddress: felt, nftCollateralTokenId: Uint256, amount: Uint256, interest: Uint256, duration: felt, borrowerAddress: felt):
end

@event
func LoanActivated(id: Uint256, startTime: felt, endTime: felt, lenderAddress: felt):
end

@event
func LoanCancelled(id: Uint256):
end

@event
func LoanRepaid(id: Uint256):
end

@event
func LoanFundsWithdrawn(id: Uint256):
end

@event
func LoanCollateralWithdrawn(id: Uint256):
end

##################################################################
# STORAGE VARIABLES
##################################################################

@storage_var
func _loans(loanId: Uint256) -> (loan: Loan):
end

@storage_var
func _lastLoanId() -> (lastLoanId: Loan):
end

##################################################################
# FUNCTIONS
##################################################################

@external
func listLoan{
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    } (_nftCollateralAddress: Uint256, _nftCollateralTokenId: Uint256, _amount: Uint256, _interest: Uint256, _duration: felt):
    alloc_locals

    tempvar validNFTAddress = 1
    if _nftCollateralAddress == 0:
        validNFTAddress = 0
    end
    with_attr error_message("Invalid NFT address."):
        assert validNFTAddress  = 1
    end

    let validTokenID = 

    with_attr error_message("Invalid NFT tokenId."):
        assert _nftCollateralTokenId  = 1
    end

    return ()
end


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

