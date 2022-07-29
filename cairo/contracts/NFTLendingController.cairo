%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import Uint256, uint256_check, uint256_eq, uint256_lt
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address, get_block_timestamp

from openzeppelin.security.safemath import uint256_checked_add, uint256_checked_sub_le
from openzeppelin.token.erc721.interfaces.IERC721 import IERC721

##################################################################
# DATA STRUCTURES
##################################################################

const LOAN_STATUS_OPEN = 0
const LOAN_STATUS_CANCELLED = 1
const LOAN_STATUS_ACTIVE = 2
const LOAN_STATUS_REPAID = 3
const LOAN_STATUS_CLAIMED = 4
const LOAN_STATUS_DEFAULTED = 5

struct Loan:
    member id: Uint256
    member nftCollectionAddress: felt
    member nftTokenId: Uint256
    member amount: Uint256
    member interest: Uint256
    member duration: felt
    member dueTimestamp: felt
    member borrowerAddress: felt
    member lenderAddress: felt
    member status: felt
end

##################################################################
# EVENTS
##################################################################

@event
func LoanListed(loanId: Uint256, nftCollectionAddress: felt, nftTokenId: Uint256, amount: Uint256, interest: Uint256, duration: felt, borrowerAddress: felt):
end

@event
func LoanCancelled(loanId: Uint256):
end

@event
func LoanActivated(loanId: Uint256, dueTimestamp: felt, lenderAddress: felt):
end

@event
func LoanRepaid(loanId: Uint256):
end

@event
func LoanClaimed(loanId: Uint256):
end

@event
func LoanDefaulted(loanId: Uint256):
end

##################################################################
# STORAGE VARIABLES
##################################################################

@storage_var
func _loans(loanId: Uint256) -> (loan: Loan):
end

@storage_var
func _lastLoanId() -> (lastLoanId: Uint256):
end

##################################################################
# FUNCTIONS
##################################################################

@external
func listLoan{
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    } (_nftCollectionAddress: felt, _nftTokenId: Uint256, _amount: Uint256, _interest: Uint256, _duration: felt):
    alloc_locals 

    local validNFTAddress = 1
    if _nftCollectionAddress == 0:
        validNFTAddress = 0
    end
    with_attr error_message("Invalid NFT address"):
        assert validNFTAddress = 1
    end

    let (validTokenID) = uint256_lt(Uint256(0, 0), _nftTokenId)
    uint256_check(_nftTokenId)
    with_attr error_message("Invalid NFT tokenId"):
        assert validTokenID  = 1
    end

    let (validAmount) = uint256_lt(Uint256(0 ,0), _amount)
    uint256_check(_amount)
    with_attr error_message("Invalid amount"):
        assert validAmount  = 1
    end

    let (validInterest) = uint256_lt(Uint256(0, 0), _interest)
    uint256_check(_interest)
    with_attr error_message("Invalid interest"):
        assert validInterest  = 1
    end

    let (lastLoanId) = _lastLoanId.read()
    let (newLoanId) = uint256_checked_add(lastLoanId, Uint256(1, 0))
    _lastLoanId.write(newLoanId)

    let (caller) = get_caller_address()
    let (this) = get_contract_address()        
    _loans.write(newLoanId, Loan(newLoanId, _nftCollectionAddress, _nftTokenId, _amount, _interest, _duration, 0, caller, 0, LOAN_STATUS_OPEN))
    IERC721.transferFrom(contract_address=_nftCollectionAddress, _from=caller, to=this, tokenId=_nftTokenId)

    LoanListed.emit(newLoanId, _nftCollectionAddress, _nftTokenId, _amount, _interest, _duration, caller)
    return ()
end

@external
func cancelLoan{
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    } (_loanId: Uint256):
    alloc_locals

    uint256_check(_loanId)
    let (validLoanID) = uint256_lt(Uint256(0, 0), _loanId)
    with_attr error_message("Invalid Loan ID"):
        assert validLoanID = 1
    end

    let (loan) = _loans.read(_loanId)
    let (loanFound) = uint256_eq(_loanId, loan.id)
    with_attr error_message("Loan not found"):
        assert loanFound = 1
    end

    with_attr error_message("Loan is not OPEN"):
        assert loan.status = LOAN_STATUS_OPEN
    end
    
    let (caller) = get_caller_address()
    let (this) = get_contract_address()
    with_attr error_message("Only the borrower can cancel the loan"):
        assert loan.borrowerAddress = caller
    end

    _loans.write(_loanId, Loan(_loanId, loan.nftCollectionAddress, loan.nftTokenId, loan.amount, loan.interest, loan.duration, loan.dueTimestamp, loan.borrowerAddress, loan.lenderAddress, LOAN_STATUS_CANCELLED))

    IERC721.transferFrom(contract_address=loan.nftCollectionAddress, _from=this, to=loan.borrowerAddress, tokenId=loan.nftTokenId)    

    LoanCancelled.emit(_loanId)
    return()
end

@external
func activateLoan{
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    } (_loanId: Uint256):
    alloc_locals

    uint256_check(_loanId)
    let (validLoanID) = uint256_lt(Uint256(0, 0), _loanId)
    with_attr error_message("Invalid Loan ID"):
        assert validLoanID = 1
    end

    let (loan) = _loans.read(_loanId)
    let (loanFound) = uint256_eq(_loanId, loan.id)
    with_attr error_message("Loan not found"):
        assert loanFound = 1
    end

    with_attr error_message("Loan is not OPEN"):
        assert loan.status = LOAN_STATUS_OPEN
    end
    
    let (caller) = get_caller_address()
    let (this) = get_contract_address()
    local callerIsBorrower = 0
    if caller == loan.borrowerAddress:
        callerIsBorrower = 1
    end 
    with_attr error_message("Borrower cannot activate the loan"):
        assert callerIsBorrower = 0
    end

    let (now) = get_block_timestamp()
    tempvar dueTimestamp = now + loan.duration
    _loans.write(_loanId, Loan(_loanId, loan.nftCollectionAddress, loan.nftTokenId, loan.amount, loan.interest, loan.duration, dueTimestamp, loan.borrowerAddress, caller, LOAN_STATUS_ACTIVE))

    # TODO: transfer money from lender to borrower.

    LoanActivated.emit(_loanId, dueTimestamp, caller)
    return()
end

@external
func repayLoan{
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    } (_loanId: Uint256):
    alloc_locals

    uint256_check(_loanId)
    let (validLoanID) = uint256_lt(Uint256(0, 0), _loanId)
    with_attr error_message("Invalid Loan ID"):
        assert validLoanID = 1
    end

    let (loan) = _loans.read(_loanId)
    let (loanFound) = uint256_eq(_loanId, loan.id)
    with_attr error_message("Loan not found"):
        assert loanFound = 1
    end

    with_attr error_message("Loan is not ACTIVE"):
        assert loan.status = LOAN_STATUS_ACTIVE
    end
    
    let (caller) = get_caller_address()
    let (this) = get_contract_address()
    with_attr error_message("Only the borrower can repay the loan"):
        assert loan.borrowerAddress = caller
    end

    _loans.write(_loanId, Loan(_loanId, loan.nftCollectionAddress, loan.nftTokenId, loan.amount, loan.interest, loan.duration, loan.dueTimestamp, loan.borrowerAddress, loan.lenderAddress, LOAN_STATUS_DEFAULTED))

    # TODO: escrow payment for the lender.
    IERC721.transferFrom(contract_address=loan.nftCollectionAddress, _from=this, to=loan.borrowerAddress, tokenId=loan.nftTokenId)    

    LoanRepaid.emit(_loanId)
    return()
end

@external
func claimLoan{
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    } (_loanId: Uint256):
    alloc_locals

    uint256_check(_loanId)
    let (validLoanID) = uint256_lt(Uint256(0, 0), _loanId)
    with_attr error_message("Invalid Loan ID"):
        assert validLoanID = 1
    end

    let (loan) = _loans.read(_loanId)
    let (loanFound) = uint256_eq(_loanId, loan.id)
    with_attr error_message("Loan not found"):
        assert loanFound = 1
    end

    with_attr error_message("Loan is not REPAID"):
        assert loan.status = LOAN_STATUS_REPAID
    end
    
    _loans.write(_loanId, Loan(_loanId, loan.nftCollectionAddress, loan.nftTokenId, loan.amount, loan.interest, loan.duration, loan.dueTimestamp, loan.borrowerAddress, loan.lenderAddress, LOAN_STATUS_CLAIMED))
    # TODO: transfer funds to lender.     

    LoanClaimed.emit(_loanId)
    return()
end

@external
func defaultLoan{
        pedersen_ptr: HashBuiltin*,
        syscall_ptr: felt*,
        range_check_ptr
    } (_loanId: Uint256):
    alloc_locals

    uint256_check(_loanId)
    let (validLoanID) = uint256_lt(Uint256(0, 0), _loanId)
    with_attr error_message("Invalid Loan ID"):
        assert validLoanID = 1
    end

    let (loan) = _loans.read(_loanId)
    let (loanFound) = uint256_eq(_loanId, loan.id)
    with_attr error_message("Loan not found"):
        assert loanFound = 1
    end

    with_attr error_message("Loan is not ACTIVE"):
        assert loan.status = LOAN_STATUS_ACTIVE
    end
    
    let (now) = get_block_timestamp()
    let (loanStillActive) = is_le(now, loan.dueTimestamp)
    with_attr error_message("Loan is still ACTIVE"):
        assert loanStillActive = 0
    end

    _loans.write(_loanId, Loan(_loanId, loan.nftCollectionAddress, loan.nftTokenId, loan.amount, loan.interest, loan.duration, loan.dueTimestamp, loan.borrowerAddress, loan.lenderAddress, LOAN_STATUS_DEFAULTED))

    let (caller) = get_caller_address()
    let (this) = get_contract_address()        
    IERC721.transferFrom(contract_address=loan.nftCollectionAddress, _from=this, to=caller, tokenId=loan.nftTokenId)

    LoanDefaulted.emit(_loanId)
    return()
end