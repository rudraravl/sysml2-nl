// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IPredictDotLoan} from "./interfaces/IPredictDotLoan.sol";
import {ICTFExchange} from "./interfaces/ICTFExchange.sol";
import {IConditionalTokens} from "./interfaces/IConditionalTokens.sol";
import {INegRiskAdapter} from "./interfaces/INegRiskAdapter.sol";
import {NegRiskIdLib} from "./libraries/NegRiskIdLib.sol";
import {IUmaCtfAdapter} from "./interfaces/IUmaCtfAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {InterestLib} from "./libraries/InterestLib.sol";
import {PredictDotLoan} from "./PredictDotLoan.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "./ValidationCodeConstants.sol";

/**
 * @title PredictDotLoanValidator
 * @notice PredictDotLoanValidator allows users to validate lending/borrowing proposals
 *         It performs checks for:
 *         1. Proposal expiration
 * @author predict.fun protocol team
 */
contract PredictDotLoanValidator {
    /**
     * @notice PredictDotLoan contract
     */
    PredictDotLoan public immutable PREDICT_DOT_LOAN;

    /**
     * @notice Conditional tokens that can be used as collateral
     */
    IConditionalTokens private immutable CTF;

    /**
     * @notice predict.fun The only loan token allowed is the CTF exchange's collateral
     */
    IERC20 private immutable LOAN_TOKEN;

    /**
     * @notice Neg risk adapter
     */
    INegRiskAdapter private immutable NEG_RISK_ADAPTER;

    /**
     * @param _predictDotLoanAddress PredictDotLoan contract address
     */
    constructor(address _predictDotLoanAddress) {
        PREDICT_DOT_LOAN = PredictDotLoan(_predictDotLoanAddress);

        ICTFExchange ctfExchange = PREDICT_DOT_LOAN.CTF_EXCHANGE();
        ICTFExchange negRiskCtfExchange = PREDICT_DOT_LOAN.NEG_RISK_CTF_EXCHANGE();

        LOAN_TOKEN = IERC20(ctfExchange.getCollateral());

        NEG_RISK_ADAPTER = INegRiskAdapter(negRiskCtfExchange.getCtf());

        CTF = IConditionalTokens(ctfExchange.getCtf());
    }

    /**
     * @dev Shared validation logic between loan offers and borrow requests
     *
     * @notice This function verifies the validity of a proposal
     *
     * @param proposal The Proposal struct
     * @param taker The user who wishes to accept a given proposal
     * @param fulfillAmount The loan amount to be fulfilled
     *
     * @return validationCodes Array of validation codes
     */
    function validateProposal(
        IPredictDotLoan.Proposal calldata proposal,
        address taker,
        uint256 fulfillAmount
    ) public view returns (uint256[10] memory validationCodes) {
        bytes32 proposalId = PREDICT_DOT_LOAN.hashProposal(proposal);
        (bytes32 fulfillmentProposalId, , uint256 loanAmount) = PREDICT_DOT_LOAN.getFulfillment(proposal);
        validationCodes[0] = _validateExpiration(proposal);
        validationCodes[1] = _validateLenderIsNotBorrower(proposal, taker);
        validationCodes[2] = _validateSignature(proposalId, proposal.from, proposal.signature);
        validationCodes[3] = _validateFulfillAmount(fulfillAmount, loanAmount, proposal.loanAmount);
        validationCodes[4] = _validateSalt(
            fulfillmentProposalId,
            proposalId,
            proposal.from,
            proposal.salt,
            proposal.proposalType
        );
        validationCodes[5] = _validateNonceIsCurrent(proposal.proposalType, proposal.from, proposal.nonce);
        validationCodes[6] = _validateCollateralizationRatio(proposal.collateralAmount, proposal.loanAmount);
        validationCodes[7] = _validateInterestRate(proposal.interestRatePerSecond);
        validationCodes[8] = _validatePositionIsTradeable(proposal);
        validationCodes[9] = _validateQuestionPriceIsAvailable(proposal.questionType, proposal.questionId);
    }

    /**
     * @notice This function checks if the proposal has expired
     *
     * @param proposal The Proposal struct
     *
     * @return validationCode Validation code
     */
    function _validateExpiration(
        IPredictDotLoan.Proposal calldata proposal
    ) private view returns (uint256 validationCode) {
        if (block.timestamp > proposal.validUntil) {
            return PROPOSAL_EXPIRED;
        }

        return PROPOSAL_EXPECTED_TO_BE_VALID;
    }

    /**
     * @notice This function checks if the lender is the borrower
     *
     * @param proposal The Proposal
     * @param taker The user who wishes to accept a given proposal
     *
     * @return validationCode Validation code
     */
    function _validateLenderIsNotBorrower(
        IPredictDotLoan.Proposal calldata proposal,
        address taker
    ) private pure returns (uint256 validationCode) {
        address proposalCreator = proposal.from;
        if (proposalCreator == taker) {
            return LENDER_IS_BORROWER;
        }

        return PROPOSAL_EXPECTED_TO_BE_VALID;
    }

    /**
     * @notice This function checks if the signature is valid.
     *
     * @param proposalId The Proposal ID
     * @param from The signer
     * @param signature The signature
     *
     * @return validationCode Validation code
     */
    function _validateSignature(
        bytes32 proposalId,
        address from,
        bytes calldata signature
    ) private view returns (uint256 validationCode) {
        if (!SignatureChecker.isValidSignatureNow(from, proposalId, signature)) {
            return INVALID_SIGNATURE;
        }

        return PROPOSAL_EXPECTED_TO_BE_VALID;
    }

    /**
     * @notice This function checks if the fulfill amount is valid (not too low or too high)
     *
     * @param fulfillAmount The loan amount to be fulfilled
     * @param fulfilledAmount The loan amount fulfilled
     * @param loanAmount The proposal's loan amount
     *
     * @return validationCode Validation code
     */
    function _validateFulfillAmount(
        uint256 fulfillAmount,
        uint256 fulfilledAmount,
        uint256 loanAmount
    ) private pure returns (uint256 validationCode) {
        if (fulfilledAmount + fulfillAmount > loanAmount) {
            return FULFILL_AMOUNT_TOO_HIGH;
        }

        if (fulfillAmount != loanAmount - fulfilledAmount) {
            if (fulfillAmount < loanAmount / 10) {
                return FULFILL_AMOUNT_TOO_LOW;
            }
        }

        return PROPOSAL_EXPECTED_TO_BE_VALID;
    }

    /**
     * @notice This function checks if the proposal's salt is not cancelled and not used by another proposal
     *
     * @param fulfillmentProposalId The fulfillment's proposal ID, it's 0 if there is no fulfillment
     * @param proposalId The proposal ID
     * @param user The user who created the proposal
     * @param salt The salt
     * @param proposalType The proposal type
     *
     * @return validationCode Validation code
     */
    function _validateSalt(
        bytes32 fulfillmentProposalId,
        bytes32 proposalId,
        address user,
        uint256 salt,
        IPredictDotLoan.ProposalType proposalType
    ) private view returns (uint256 validationCode) {
        (bool _lending, bool _borrowing) = PREDICT_DOT_LOAN.saltCancellations(user, salt);
        if (fulfillmentProposalId != bytes32(0)) {
            if (fulfillmentProposalId != proposalId) {
                return SALT_ALREADY_USED;
            }
        }

        if (proposalType == IPredictDotLoan.ProposalType.LoanOffer) {
            if (_lending) {
                return PROPOSAL_CANCELLED;
            }
        } else {
            if (_borrowing) {
                return PROPOSAL_CANCELLED;
            }
        }

        return PROPOSAL_EXPECTED_TO_BE_VALID;
    }

    /**
     * @notice This function checks if the proposal's nonce matches the signer's nonce
     *
     * @param proposalType The proposal type
     * @param from The user who created the proposal
     * @param nonce The nonce
     *
     * @return validationCode Validation code
     */
    function _validateNonceIsCurrent(
        IPredictDotLoan.ProposalType proposalType,
        address from,
        uint256 nonce
    ) private view returns (uint256 validationCode) {
        (uint256 lendingNonce, uint256 borrowingNonce) = PREDICT_DOT_LOAN.nonces(from);
        if (proposalType == IPredictDotLoan.ProposalType.LoanOffer) {
            if (nonce != lendingNonce) {
                return NONCE_IS_NOT_CURRENT;
            }
        } else {
            if (nonce != borrowingNonce) {
                return NONCE_IS_NOT_CURRENT;
            }
        }

        return PROPOSAL_EXPECTED_TO_BE_VALID;
    }

    /**
     * @notice This function checks if the proposal's collateralization ratio is equal to or above 100%.
     *
     * @param collateralAmount The proposal's collateral amount
     * @param loanAmount The proposal's loan amount
     *
     * @return validationCode Validation code
     */
    function _validateCollateralizationRatio(
        uint256 collateralAmount,
        uint256 loanAmount
    ) private pure returns (uint256 validationCode) {
        if (collateralAmount < loanAmount) {
            return COLLATERALIZATION_RATIO_BELOW_100;
        }

        return PROPOSAL_EXPECTED_TO_BE_VALID;
    }

    /**
     * @notice This function checks if the proposal's interest rate is above the minimum interest rate
     *         and below the maximum interest rate.
     *
     * @param interestRatePerSecond The proposal's interest rate
     *
     * @return validationCode Validation code
     */
    function _validateInterestRate(uint256 interestRatePerSecond) private pure returns (uint256 validationCode) {
        if (interestRatePerSecond <= InterestLib.ONE) {
            return INTEREST_RATE_TOO_LOW;
        }

        if (interestRatePerSecond > InterestLib.ONE + InterestLib.TEN_THOUSAND_APY) {
            return INTEREST_RATE_TOO_HIGH;
        }

        return PROPOSAL_EXPECTED_TO_BE_VALID;
    }

    /**
     * @notice This function checks if the position is tradeable on the exchange or the neg risk CTF exchange.
     *
     * @param proposal The proposal
     */
    function _validatePositionIsTradeable(
        IPredictDotLoan.Proposal calldata proposal
    ) private view returns (uint256 validationCode) {
        uint256 positionId = _derivePositionId(proposal);
        ICTFExchange exchange = proposal.questionType == IPredictDotLoan.QuestionType.Binary
            ? PREDICT_DOT_LOAN.CTF_EXCHANGE()
            : PREDICT_DOT_LOAN.NEG_RISK_CTF_EXCHANGE();
        (uint256 complement, ) = exchange.registry(positionId);
        if (complement == 0) {
            return POSITION_IS_NOT_TRADEABLE;
        }

        return PROPOSAL_EXPECTED_TO_BE_VALID;
    }

    /**
     * @notice This function checks if the question price is available.
     *
     * @dev We do not allow positions that are already resolved from being used as collaterals for loans
     *      as it is very likely that the position is worth nothing
     *
     * @param questionType The question type
     * @param questionId The question ID
     */
    function _validateQuestionPriceIsAvailable(
        IPredictDotLoan.QuestionType questionType,
        bytes32 questionId
    ) private view returns (uint256 validationCode) {
        if (questionType == IPredictDotLoan.QuestionType.Binary) {
            validationCode = _validateBinaryOutcomeQuestionPriceUnavailable(
                PREDICT_DOT_LOAN.UMA_CTF_ADAPTER(),
                questionId
            );
        } else {
            if (_isNegRiskMarketDetermined(questionId)) {
                return MARKET_RESOLVED;
            }

            validationCode = _validateBinaryOutcomeQuestionPriceUnavailable(
                PREDICT_DOT_LOAN.NEG_RISK_UMA_CTF_ADAPTER(),
                questionId
            );
        }

        return validationCode;
    }

    /**
     * @notice This function checks if a binary outcome question price is unavailable.
     *
     * @param umaCtfAdapter The UMA CTF adapter address
     * @param questionId The question ID
     */
    function _validateBinaryOutcomeQuestionPriceUnavailable(
        address umaCtfAdapter,
        bytes32 questionId
    ) private view returns (uint256 validationCode) {
        (bool isAvailable, bytes4 umaError) = _isBinaryOutcomeQuestionPriceAvailable(umaCtfAdapter, questionId);

        // 0x579a4801 is the error code for PriceNotAvailable()
        if (isAvailable) {
            return QUESTION_RESOLVED;
        } else if (umaError != 0x579a4801) {
            // Loans should still be blocked if the error is NotInitialized, Flagged or Paused
            // Reference: https://github.com/Polymarket/uma-ctf-adapter/blob/main/src/UmaCtfAdapter.sol#L145
            return QUESTION_STATE_ABNORMAL;
        }

        return PROPOSAL_EXPECTED_TO_BE_VALID;
    }

    /**
     * @notice This function checks if a neg risk market is determined.
     *
     * @param questionId The question ID
     */
    function _isNegRiskMarketDetermined(bytes32 questionId) private view returns (bool isDetermined) {
        isDetermined = NEG_RISK_ADAPTER.getDetermined(NegRiskIdLib.getMarketId(questionId));
    }

    /**
     * @notice This function checks if a binary outcome question price is available.
     *
     * @param umaCtfAdapter The UMA CTF adapter address
     * @param questionId The question ID
     */
    function _isBinaryOutcomeQuestionPriceAvailable(
        address umaCtfAdapter,
        bytes32 questionId
    ) private view returns (bool isAvailable, bytes4 umaError) {
        try IUmaCtfAdapter(umaCtfAdapter).getExpectedPayouts(questionId) returns (uint256[] memory) {
            isAvailable = true;
        } catch (bytes memory reason) {
            isAvailable = false;
            umaError = bytes4(reason);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        CONDITIONAL TOKENS LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice This function derives the position ID from the proposal.
     *
     * @dev Derive the position ID from the question type, question ID and outcome
     *
     *      The proposal struct does not require positionId directly because it has
     *      to verify the question ID is not already resolved and the position ID actually
     *      comes from the question ID provided. It is more efficient to just derive the
     *      position ID and use it instead of requiring the user to provide it and then
     *      compare it to the derived position ID.
     *
     * @param proposal The Proposal
     */
    function _derivePositionId(IPredictDotLoan.Proposal calldata proposal) private view returns (uint256 positionId) {
        if (proposal.questionType == IPredictDotLoan.QuestionType.Binary) {
            bytes32 conditionId = _getConditionId(PREDICT_DOT_LOAN.UMA_CTF_ADAPTER(), proposal.questionId, 2);
            bytes32 collectionId = CTF.getCollectionId(bytes32(0), conditionId, proposal.outcome ? 1 : 2);
            positionId = _getPositionId(LOAN_TOKEN, collectionId);
        } else {
            positionId = NEG_RISK_ADAPTER.getPositionId(proposal.questionId, proposal.outcome);
        }
    }

    /*//////////////////////////////////////////////////////////////
          LOGIC COPIED FROM CTHelpers FOR PERFORMANCE REASONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice This function gets the condition ID based on the oracle, question ID and outcome slot count.
     *
     * @dev Constructs a condition ID from an oracle, a question ID, and the outcome slot count for the question.
     *
     * @param oracle The account assigned to report the result for the prepared condition.
     * @param questionId An identifier for the question to be answered by the oracle.
     * @param outcomeSlotCount The number of outcome slots which should be used for this condition. Must not exceed 256.
     */
    function _getConditionId(address oracle, bytes32 questionId, uint outcomeSlotCount) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(oracle, questionId, outcomeSlotCount));
    }

    /**
     * @notice This function gets the position ID based on the collateral token and collection ID.
     *
     * @dev Constructs a position ID from a collateral token and an outcome collection. These IDs are used as the ERC-1155 ID for this contract.
     *
     * @param collateralToken Collateral token which backs the position.
     * @param collectionId ID of the outcome collection associated with this position.
     */
    function _getPositionId(IERC20 collateralToken, bytes32 collectionId) private pure returns (uint) {
        return uint(keccak256(abi.encodePacked(collateralToken, collectionId)));
    }
}
