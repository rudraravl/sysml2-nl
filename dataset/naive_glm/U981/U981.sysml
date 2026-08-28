package CashHandlingSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQCurrency::*;

    // ===== Value Types =====
    def value type CurrencyAmount :> Real { unit currency:cent; }
    def value type MassValue :> Real { unit mass:g; }
    def value type Count :> Integer;
    def value type TransactionId :> String;

    // ===== Item Types =====
    item def Bill {
        attribute denomination : CurrencyAmount;
        attribute serialNumber : String;
        attribute isAuthentic : Boolean;
        attribute isRecognized : Boolean;
    }

    item def Coin {
        attribute denomination : CurrencyAmount;
        attribute mass : MassValue;
        attribute isAuthentic : Boolean;
        attribute isRecognized : Boolean;
    }

    item def CashBatch {
        attribute totalValue : CurrencyAmount;
        attribute bills : Bill[0..*];
        attribute coins : Coin[0..*];
    }

    item def RejectedCurrency {
        attribute reason : String;
        attribute items : Bill[0..*];
        attribute coins : Coin[0..*];
    }

    item def TransactionRequest {
        attribute transactionId : TransactionId;
        attribute type : String; // "deposit" or "withdrawal"
        attribute amount : CurrencyAmount;
        attribute accountNumber : String;
        attribute pinHash : String;
    }

    item def TransactionResult {
        attribute transactionId : TransactionId;
        attribute status : String; // "approved", "rejected", "completed", "failed"
        attribute amount : CurrencyAmount;
        attribute timestamp : String;
    }

    item def AuthorizationRequest {
        attribute transactionId : TransactionId;
        attribute accountNumber : String;
        attribute pinHash : String;
        attribute amount : CurrencyAmount;
        attribute type : String;
    }

    item def AuthorizationResponse {
        attribute transactionId : TransactionId;
        attribute approved : Boolean;
        attribute balance : CurrencyAmount;
        attribute message : String;
    }

    item def DisplayMessage {
        attribute text : String;
        attribute severity : String; // "info", "warning", "error"
    }

    item def Receipt {
        attribute transactionId : TransactionId;
        attribute timestamp : String;
        attribute type : String;
        attribute amount : CurrencyAmount;
        attribute balance : CurrencyAmount;
    }

    item def AuditLogEntry {
        attribute transactionId : TransactionId;
        attribute timestamp : String;
        attribute action : String;
        attribute details : String;
    }

    // ===== Port Definitions =====
    port def BillFlowPort {
        out item bills : Bill[0..*];
        in item rejectedBills : Bill[0..*];
    }

    port def CoinFlowPort {
        out item coins : Coin[0..*];
        in item rejectedCoins : Coin[0..*];
    }

    port def CashBatchPort {
        out item batch : CashBatch;
        in item returnedBatch : CashBatch;
    }

    port def RejectedCurrencyPort {
        out item rejected : RejectedCurrency;
    }

    port def TransactionRequestPort {
        in item request : TransactionRequest;
        out item result : TransactionResult;
    }

    port def AuthorizationPort {
        out item authRequest : AuthorizationRequest;
        in item authResponse : AuthorizationResponse;
    }

    port def VaultCommandPort {
        out item prepareAmount : CurrencyAmount;
        out item storeBatch : CashBatch;
        in item dispenseBatch : CashBatch;
        in item vaultStatus : VaultStatus;
    }

    item def VaultStatus {
        attribute totalOnHand : CurrencyAmount;
        attribute billCount : Count;
        attribute coinCount : Count;
        attribute isSecure : Boolean;
    }

    port def DispenserPort {
        in item batch : CashBatch;
        out item dispensed : CashBatch;
    }

    port def DisplayPort {
        in item message : DisplayMessage;
    }

    port def ReceiptPort {
        in item receipt : Receipt;
    }

    port def AuditLogPort {
        in item entry : AuditLogEntry;
    }

    // ===== Parts =====

    part def BillAcceptor {
        port billOut : BillFlowPort;
        port rejectedOut : RejectedCurrencyPort;
        attribute insertedBills : Bill[0..*];

        action def AcceptBills {
            in item inserted : Bill[0..*];
            out item accepted : Bill[0..*];
            out item rejected : Bill[0..*];
        }
    }

    part def CoinAcceptor {
        port coinOut : CoinFlowPort;
        port rejectedOut : RejectedCurrencyPort;
        attribute insertedCoins : Coin[0..*];

        action def AcceptCoins {
            in item inserted : Coin[0..*];
            out item accepted : Coin[0..*];
            out item rejected : Coin[0..*];
        }
    }

    part def CurrencyValidator {
        port billIn : BillFlowPort;
        port coinIn : CoinFlowPort;
        port validatedOut : CashBatchPort;
        port rejectedOut : RejectedCurrencyPort;

        action def ValidateBill {
            in item bill : Bill;
            out item validated : Bill;
            out item rejected : Bill[0..*];
        }

        action def ValidateCoin {
            in item coin : Coin;
            out item validated : Coin;
            out item rejected : Coin[0..*];
        }

        action def ValidateAll {
            in item bills : Bill[0..*];
            in item coins : Coin[0..*];
            out item batch : CashBatch;
            out item rejected : RejectedCurrency;
        }
    }

    part def SecureVault {
        port command : VaultCommandPort;
        attribute totalOnHand : CurrencyAmount := 0;
        attribute billInventory : Bill[0..*];
        attribute coinInventory : Coin[0..*];
        attribute isTamperResistant : Boolean := true;
        attribute isSecure : Boolean := true;

        state def VaultStateMachine {
            entry; then Idle;
            state Idle;
            state Storing;
            state PreparingDispense;
            state Dispensing;
            state Alarm;

            transition Idle_to_Storing
                first Idle
                accept item storeBatch : CashBatch via command.storeBatch
                then Storing;

            transition Storing_to_Idle
                first Storing
                then Idle;

            transition Idle_to_PreparingDispense
                first Idle
                accept item prepareAmount : CurrencyAmount via command.prepareAmount
                then PreparingDispense;

            transition PreparingDispense_to_Dispensing
                first PreparingDispense
                then Dispensing;

            transition Dispensing_to_Idle
                first Dispensing
                then Idle;

            transition any_to_Alarm
                first Idle
                accept TamperDetected
                then Alarm;
        }

        action def StoreCash {
            in item batch : CashBatch;
            out item status : VaultStatus;
        }

        action def PrepareDispense {
            in item amount : CurrencyAmount;
            out item batch : CashBatch;
        }
    }

    part def TransactionController {
        port transaction : TransactionRequestPort;
        port authorization : AuthorizationPort;
        port vaultCommand : VaultCommandPort;
        port display : DisplayPort;
        port receipt : ReceiptPort;
        port auditLog : AuditLogPort;

        attribute currentTransaction : TransactionId;
        attribute transactionHistory : TransactionResult[0..*];

        state def ControllerStateMachine {
            entry; then WaitingForRequest;
            state WaitingForRequest;
            state Authorizing;
            state ProcessingDeposit;
            state ProcessingWithdrawal;
            state Dispensing;
            state PrintingReceipt;
            state Completed;
            state Failed;

            transition WaitingForRequest_to_Authorizing
                first WaitingForRequest
                accept item request : TransactionRequest via transaction.request
                then Authorizing;

            transition Authorizing_to_ProcessingDeposit
                first Authorizing
                accept item response : AuthorizationResponse via authorization.authResponse
                if response.approved and request.type == "deposit"
                then ProcessingDeposit;

            transition Authorizing_to_ProcessingWithdrawal
                first Authorizing
                accept item response : AuthorizationResponse via authorization.authResponse
                if response.approved and request.type == "withdrawal"
                then ProcessingWithdrawal;

            transition Authorizing_to_Failed
                first Authorizing
                accept item response : AuthorizationResponse via authorization.authResponse
                if not response.approved
                then Failed;

            transition ProcessingWithdrawal_to_Dispensing
                first ProcessingWithdrawal
                then Dispensing;

            transition Dispensing_to_PrintingReceipt
                first Dispensing
                then PrintingReceipt;

            transition ProcessingDeposit_to_PrintingReceipt
                first ProcessingDeposit
                then PrintingReceipt;

            transition PrintingReceipt_to_Completed
                first PrintingReceipt
                then Completed;

            transition Completed_to_WaitingForRequest
                first Completed
                then WaitingForRequest;

            transition Failed_to_WaitingForRequest
                first Failed
                then WaitingForRequest;
        }

        action def ProcessTransaction {
            in item request : TransactionRequest;
            out item result : TransactionResult;
        }

        action def LogAction {
            in item entry : AuditLogEntry;
        }
    }

    part def CashDispenser {
        port dispenser : DispenserPort;
        attribute dispensedBatches : CashBatch[0..*];

        action def DispenseCash {
            in item batch : CashBatch;
            out item dispensed : CashBatch;
        }
    }

    part def UserDisplay {
        port display : DisplayPort;
        attribute currentMessage : DisplayMessage;

        action def ShowMessage {
            in item message : DisplayMessage;
        }
    }

    part def ReceiptPrinter {
        port receipt : ReceiptPort;
        attribute paperRemaining : MassValue := 100;

        action def PrintReceipt {
            in item receipt : Receipt;
        }
    }

    part def BankingNetworkInterface {
        port authorization : AuthorizationPort;
        attribute isConnected : Boolean := true;

        action def AuthorizeTransaction {
            in item request : AuthorizationRequest;
            out item response : AuthorizationResponse;
        }
    }

    // ===== Top-level System =====
    part def AutomatedCashHandlingSystem {
        port customerTransaction : TransactionRequestPort;
        port customerDisplay : DisplayPort;
        port customerReceipt : ReceiptPort;

        part billAcceptor : BillAcceptor {
            port billOut : BillFlowPort;
            port rejectedOut : RejectedCurrencyPort;
        }

        part coinAcceptor : CoinAcceptor {
            port coinOut : CoinFlowPort;
            port rejectedOut : RejectedCurrencyPort;
        }

        part currencyValidator : CurrencyValidator {
            port billIn : BillFlowPort;
            port coinIn : CoinFlowPort;
            port validatedOut : CashBatchPort;
            port rejectedOut : RejectedCurrencyPort;
        }

        part secureVault : SecureVault {
            port command : VaultCommandPort;
        }

        part transactionController : TransactionController {
            port transaction : TransactionRequestPort;
            port authorization : AuthorizationPort;
            port vaultCommand : VaultCommandPort;
            port display : DisplayPort;
            port receipt : ReceiptPort;
            port auditLog : AuditLogPort;
        }

        part cashDispenser : CashDispenser {
            port dispenser : DispenserPort;
        }

        part userDisplay : UserDisplay {
            port display : DisplayPort;
        }

        part receiptPrinter : ReceiptPrinter {
            port receipt : ReceiptPort;
        }

        part bankingNetworkInterface : BankingNetworkInterface {
            port authorization : AuthorizationPort;
        }

        // Connections
        connection billAcceptor.billOut to currencyValidator.billIn;
        connection coinAcceptor.coinOut to currencyValidator.coinIn;
        connection currencyValidator.validatedOut to secureVault.command;
        connection currencyValidator.rejectedOut to billAcceptor.rejectedOut;
        connection currencyValidator.rejectedOut to coinAcceptor.rejectedOut;
        connection transactionController.vaultCommand to secureVault.command;
        connection secureVault.command.dispenseBatch to cashDispenser.dispenser.batch;
        connection transactionController.authorization to bankingNetworkInterface.authorization;
        connection transactionController.display to userDisplay.display;
        connection transactionController.receipt to receiptPrinter.receipt;
        connection customerTransaction to transactionController.transaction;
        connection transactionController.display to customerDisplay;
        connection transactionController.receipt to customerReceipt;
    }

    // ===== Requirements =====
    requirement def SecurityRequirement {
        doc "The system shall securely manage physical currency transactions.";
        attribute tamperResistance : Boolean;
        constraint { tamperResistance == true; }
    }

    requirement def AccuracyRequirement {
        doc "The system shall accurately count and validate all deposited and dispensed currency.";
        attribute countingAccuracy : Real; // percentage
        constraint { countingAccuracy >= 99.99; }
    }

    requirement def AuthenticationRequirement {
        doc "The system shall authenticate all currency before accepting or dispensing.";
        attribute counterfeitDetectionRate : Real;
        constraint { counterfeitDetectionRate >= 99.9; }
    }

    requirement def AuditTrailRequirement {
        doc "The system shall log every action to ensure a complete and auditable history.";
        attribute logCompleteness : Boolean;
        constraint { logCompleteness == true; }
    }

    requirement def ReliabilityRequirement {
        doc "The system shall maintain high reliability in processing cash transactions.";
        attribute meanTimeBetweenFailures : Real; // hours
        constraint { meanTimeBetweenFailures >= 10000; }
    }

    requirement def TransactionAuthorizationRequirement {
        doc "All transactions shall be authorized by an external banking network before execution.";
        attribute authorizationRequired : Boolean;
        constraint { authorizationRequired == true; }
    }

    requirement def ReceiptGenerationRequirement {
        doc "The system shall generate a physical receipt after each completed transaction.";
        attribute receiptOnCompletion : Boolean;
        constraint { receiptOnCompletion == true; }
    }

    requirement cashHandlingSecurityRequirement : SecurityRequirement {
        tamperResistance = true;
    }

    requirement cashHandlingAccuracyRequirement : AccuracyRequirement {
        countingAccuracy = 99.99;
    }

    requirement counterfeitDetectionRequirement : AuthenticationRequirement {
        counterfeitDetectionRate = 99.9;
    }

    requirement auditTrailReq : AuditTrailRequirement {
        logCompleteness = true;
    }

    requirement reliabilityReq : ReliabilityRequirement {
        meanTimeBetweenFailures = 10000;
    }

    requirement transactionAuthReq : TransactionAuthorizationRequirement {
        authorizationRequired = true;
    }

    requirement receiptReq : ReceiptGenerationRequirement {
        receiptOnCompletion = true;
    }

    // ===== Satisfaction =====
    satisfaction cashHandlingSecurityRequirement by secureVault;
    satisfaction cashHandlingAccuracyRequirement by currencyValidator;
    satisfaction counterfeitDetectionRequirement by currencyValidator;
    satisfaction auditTrailReq by transactionController;
    satisfaction reliabilityReq by AutomatedCashHandlingSystem;
    satisfaction transactionAuthReq by transactionController;
    satisfaction receiptReq by receiptPrinter;
}
