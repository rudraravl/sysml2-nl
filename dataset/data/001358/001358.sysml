package AutomatedTellerMachineSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def TransactionID :> String;
    attribute def AccountNumber :> String;
    attribute def PIN :> String;
    attribute def CurrencyAmount :> Real;
    
    enum def TransactionType {
        withdrawal;
        balanceInquiry;
        deposit;
        transfer;
    }
    
    enum def TransactionStatus {
        pending;
        approved;
        denied;
        completed;
        failed;
    }
    
    item def BankCard {
        attribute accountNumber : AccountNumber;
        attribute cardNumber : String;
        attribute expirationDate : String;
        attribute cvv : String;
    }
    
    item def Cash {
        attribute totalAmount : CurrencyAmount;
        attribute twentyDollarBills : Integer;
        attribute fiftyDollarBills : Integer;
        attribute hundredDollarBills : Integer;
    }
    
    item def Receipt {
        attribute transactionID : TransactionID;
        attribute transactionType : TransactionType;
        attribute timestamp : String;
        attribute amount : CurrencyAmount;
        attribute accountBalance : CurrencyAmount;
        attribute atmLocation : String;
    }
    
    item def AuthenticationRequest {
        attribute accountNumber : AccountNumber;
        attribute pin : PIN;
        attribute timestamp : String;
    }
    
    item def AuthenticationResponse {
        attribute authenticated : Boolean;
        attribute accountNumber : AccountNumber;
        attribute accountBalance : CurrencyAmount;
        attribute dailyLimit : CurrencyAmount;
    }
    
    item def TransactionRequest {
        attribute transactionID : TransactionID;
        attribute accountNumber : AccountNumber;
        attribute transactionType : TransactionType;
        attribute amount : CurrencyAmount;
    }
    
    item def TransactionResponse {
        attribute transactionID : TransactionID;
        attribute status : TransactionStatus;
        attribute newBalance : CurrencyAmount;
        attribute approvalCode : String;
    }
    
    port def CardReaderPort {
        in item cardInserted : BankCard;
        out item cardEjected : BankCard;
        attribute cardPresent : Boolean;
    }
    
    port def CashDispenserPort {
        out item cashDispensed : Cash;
        attribute cashAvailable : CurrencyAmount;
    }
    
    port def DisplayPort {
        out displayMessage : String;
        in userSelection : String;
    }
    
    port def KeypadPort {
        in userInput : String;
        out inputEcho : String;
    }
    
    port def ReceiptPrinterPort {
        out item receiptPrinted : Receipt;
        attribute paperAvailable : Boolean;
    }
    
    port def NetworkPort {
        out item authRequest : AuthenticationRequest;
        in item authResponse : AuthenticationResponse;
        out item transactionRequest : TransactionRequest;
        in item transactionResponse : TransactionResponse;
        attribute connectionActive : Boolean;
    }
    
    part def CardReader {
        port cardPort : CardReaderPort;
        attribute cardPresent : Boolean;
        attribute magneticStripeReader : Boolean;
        attribute chipReader : Boolean;
        
        action readCard {
            in cardPort;
            out cardData : BankCard;
        }
        
        action ejectCard {
            out cardPort;
        }
    }
    
    part def CashDispenser {
        port cashPort : CashDispenserPort;
        attribute cashInventory : CurrencyAmount;
        attribute twentyDollarCount : Integer;
        attribute fiftyDollarCount : Integer;
        attribute hundredDollarCount : Integer;
        attribute minimumCashThreshold : CurrencyAmount;
        
        action dispenseCash {
            in requestedAmount : CurrencyAmount;
            out dispensedCash : Cash;
            out success : Boolean;
        }
        
        action checkInventory {
            out availableCash : CurrencyAmount;
        }
    }
    
    part def Display {
        port displayPort : DisplayPort;
        attribute screenActive : Boolean;
        attribute brightness : Real;
        
        action showMessage {
            in message : String;
        }
        
        action showMenu {
            in menuOptions : String[*];
        }
    }
    
    part def Keypad {
        port keypadPort : KeypadPort;
        attribute numericKeys : Boolean;
        attribute functionKeys : Boolean;
        
        action captureInput {
            out userInput : String;
        }
        
        action capturePIN {
            out pin : PIN;
        }
    }
    
    part def ReceiptPrinter {
        port printerPort : ReceiptPrinterPort;
        attribute paperRemaining : Integer;
        attribute inkLevel : Real;
        
        action printReceipt {
            in receiptData : Receipt;
            out receiptPrinted : Receipt;
        }
    }
    
    part def NetworkInterface {
        port networkPort : NetworkPort;
        attribute connectionStatus : Boolean;
        attribute encryptionEnabled : Boolean;
        attribute lastHeartbeat : String;
        
        action authenticateUser {
            in authRequest : AuthenticationRequest;
            out authResponse : AuthenticationResponse;
        }
        
        action processTransaction {
            in transactionRequest : TransactionRequest;
            out transactionResponse : TransactionResponse;
        }
    }
    
    part def SecurityModule {
        attribute encryptionKey : String;
        attribute tamperDetected : Boolean;
        attribute securityAlarmActive : Boolean;
        
        action encryptData {
            in plainData : String;
            out encryptedData : String;
        }
        
        action validatePIN {
            in enteredPIN : PIN;
            in storedPIN : PIN;
            out isValid : Boolean;
        }
        
        action detectTamper {
            out tamperStatus : Boolean;
        }
    }
    
    part def Controller {
        attribute currentState : String;
        attribute sessionActive : Boolean;
        attribute pinAttemptCount : Integer;
        attribute maxPinAttempts : Integer;
        attribute sessionTimeout : Real;
        attribute currentTransactionID : TransactionID;
        
        action initializeSession {
            out sessionID : String;
        }
        
        action terminateSession {
            in sessionID : String;
        }
        
        action logTransaction {
            in transactionData : TransactionRequest;
        }
    }
    
    action def ProcessBankingTransaction {
        first start;
        then action waitForCard {
            out cardDetected : Boolean;
        }
        
        then action readCardData {
            out cardData : BankCard;
        }
        
        then action promptForPIN {
            out pinPrompt : String;
        }
        
        then action capturePIN {
            out enteredPIN : PIN;
        }
        
        then action authenticateCustomer {
            in accountNumber : AccountNumber;
            in pin : PIN;
            out authRequest : AuthenticationRequest;
            out authResponse : AuthenticationResponse;
            out authenticated : Boolean;
        }
        
        then decide authenticationDecision;
        if authenticateCustomer.authenticated == true then displayMainMenu;
        if authenticateCustomer.authenticated == false then handleAuthenticationFailure;
        
        action handleAuthenticationFailure {
            out errorMessage : String;
        }
        then action retryOrEject;
        then done;
        
        action displayMainMenu {
            out menuOptions : String[*];
        }
        
        then action captureUserSelection {
            out selectedOption : TransactionType;
        }
        
        then decide transactionTypeDecision;
        if captureUserSelection.selectedOption == TransactionType::withdrawal then processWithdrawal;
        if captureUserSelection.selectedOption == TransactionType::balanceInquiry then processBalanceInquiry;
        if captureUserSelection.selectedOption == TransactionType::deposit then processDeposit;
        if captureUserSelection.selectedOption == TransactionType::transfer then processTransfer;
        
        action processWithdrawal {
            in accountBalance : CurrencyAmount;
            out requestedAmount : CurrencyAmount;
            out transactionRequest : TransactionRequest;
            out transactionResponse : TransactionResponse;
        }
        then decide withdrawalApprovalDecision;
        if processWithdrawal.transactionResponse.status == TransactionStatus::approved then dispenseCashAction;
        if processWithdrawal.transactionResponse.status == TransactionStatus::denied then displayDenialMessage;
        
        action dispenseCashAction {
            in approvedAmount : CurrencyAmount;
            out dispensedCash : Cash;
        }
        then merge printReceiptMerge;
        
        action displayDenialMessage {
            out denialReason : String;
        }
        then merge printReceiptMerge;
        
        action processBalanceInquiry {
            in accountNumber : AccountNumber;
            out currentBalance : CurrencyAmount;
        }
        then merge printReceiptMerge;
        
        action processDeposit {
            in depositAmount : CurrencyAmount;
            out transactionRequest : TransactionRequest;
            out transactionResponse : TransactionResponse;
        }
        then merge printReceiptMerge;
        
        action processTransfer {
            in transferAmount : CurrencyAmount;
            in destinationAccount : AccountNumber;
            out transactionRequest : TransactionRequest;
            out transactionResponse : TransactionResponse;
        }
        then merge printReceiptMerge;
        
        merge printReceiptMerge;
        then action printTransactionReceipt {
            in transactionData : Receipt;
            out receiptPrinted : Receipt;
        }
        
        then action promptForAnotherTransaction {
            out continueSession : Boolean;
        }
        
        then decide continueSessionDecision;
        if promptForAnotherTransaction.continueSession == true then displayMainMenu;
        if promptForAnotherTransaction.continueSession == false then ejectCardAction;
        
        action ejectCardAction {
            out cardReturned : BankCard;
        }
        
        then action displayThankYouMessage {
            out message : String;
        }
        
        then done;
    }
    
    part def ATM {
        attribute atmID : String;
        attribute location : String;
        attribute operationalStatus : Boolean;
        attribute serviceMode : Boolean;
        attribute totalTransactionsToday : Integer;
        
        part cardReader : CardReader;
        part cashDispenser : CashDispenser {
            attribute :>> cashInventory : CurrencyAmount;
            attribute :>> twentyDollarCount : Integer;
            attribute :>> fiftyDollarCount : Integer;
            attribute :>> hundredDollarCount : Integer;
            attribute :>> minimumCashThreshold = 5000.0;
        }
        part display : Display;
        part keypad : Keypad;
        part receiptPrinter : ReceiptPrinter;
        part networkInterface : NetworkInterface;
        part securityModule : SecurityModule;
        part controller : Controller {
            attribute :>> maxPinAttempts = 3;
            attribute :>> sessionTimeout = 60.0;
        }
        
        connection cardReaderConnection connect 
            cardReader.cardPort to controller;
        connection cashDispenserConnection connect 
            cashDispenser.cashPort to controller;
        connection displayConnection connect 
            display.displayPort to controller;
        connection keypadConnection connect 
            keypad.keypadPort to controller;
        connection printerConnection connect 
            receiptPrinter.printerPort to controller;
        connection networkConnection connect 
            networkInterface.networkPort to controller;
        
        perform action atmOperation[*] ordered references ProcessBankingTransaction;
    }
    
    state def ATMStateMachine {
        entry; then idle;
        
        state idle;
        accept at idle
            if cardInserted
            then readingCard;
        
        state readingCard;
        accept at readingCard
            if cardReadSuccess
            then awaitingPIN;
        accept at readingCard
            if cardReadFailure
            then idle;
        
        state awaitingPIN;
        accept at awaitingPIN
            if pinEntered
            then authenticating;
        accept at awaitingPIN
            if timeout
            then ejectingCard;
        
        state authenticating;
        accept at authenticating
            if authenticationSuccess
            then mainMenu;
        accept at authenticating
            if authenticationFailure
            then awaitingPIN;
        
        state mainMenu;
        accept at mainMenu
            if withdrawalSelected
            then processingWithdrawal;
        accept at mainMenu
            if balanceInquirySelected
            then processingBalanceInquiry;
        accept at mainMenu
            if depositSelected
            then processingDeposit;
        accept at mainMenu
            if transferSelected
            then processingTransfer;
        accept at mainMenu
            if cancelSelected
            then ejectingCard;
        accept at mainMenu
            if timeout
            then ejectingCard;
        
        state processingWithdrawal;
        accept at processingWithdrawal
            if amountEntered
            then authorizingTransaction;
        accept at processingWithdrawal
            if cancelSelected
            then mainMenu;
        
        state authorizingTransaction;
        accept at authorizingTransaction
            if transactionApproved
            then dispensingCash;
        accept at authorizingTransaction
            if transactionDenied
            then displayingError;
        
        state dispensingCash;
        accept at dispensingCash
            if cashDispensed
            then printingReceipt;
        accept at dispensingCash
            if dispenserError
            then displayingError;
        
        state processingBalanceInquiry;
        accept at processingBalanceInquiry
            if balanceRetrieved
            then displayingBalance;
        
        state displayingBalance;
        accept at displayingBalance
            if acknowledged
            then printingReceipt;
        
        state processingDeposit;
        accept at processingDeposit
            if depositAccepted
            then printingReceipt;
        accept at processingDeposit
            if depositRejected
            then displayingError;
        
        state processingTransfer;
        accept at processingTransfer
            if transferComplete
            then printingReceipt;
        accept at processingTransfer
            if transferFailed
            then displayingError;
        
        state printingReceipt;
        accept at printingReceipt
            if receiptPrinted
            then promptingForAnotherTransaction;
        accept at printingReceipt
            if printerError
            then promptingForAnotherTransaction;
        
        state promptingForAnotherTransaction;
        accept at promptingForAnotherTransaction
            if anotherTransactionRequested
            then mainMenu;
        accept at promptingForAnotherTransaction
            if noMoreTransactions
            then ejectingCard;
        accept at promptingForAnotherTransaction
            if timeout
            then ejectingCard;
        
        state displayingError;
        accept at displayingError
            if errorAcknowledged
            then mainMenu;
        accept at displayingError
            if timeout
            then ejectingCard;
        
        state ejectingCard;
        accept at ejectingCard
            if cardEjected
            then idle;
        
        state retainingCard;
        accept at retainingCard
            if securityNotified
            then idle;
    }
    
    requirement <'REQ-ATM-001'> primaryFunction {
        doc /* The ATM system shall provide secure, automated banking 
             * services including cash withdrawal, balance inquiry, 
             * deposits, and transfers to authenticated customers 
             * 24 hours a day, 7 days a week.
             */
        subject atm : ATM;
    }
    
    requirement <'REQ-ATM-002'> userAuthentication {
        doc /* The ATM shall authenticate users by validating both 
             * card data and PIN before allowing access to any 
             * banking services.
             */
        subject atm : ATM;
        require constraint {
            atm.controller.sessionActive implies 
            atm.cardReader.cardPresent && 
            atm.networkInterface.connectionStatus
        }
    }
    
    requirement <'REQ-ATM-003'> cashDispensing {
        doc /* The ATM shall dispense cash only after successful 
             * authentication and transaction authorization from the 
             * central banking system, and only when sufficient cash 
             * inventory is available.
             */
        subject dispenser : ATM::cashDispenser;
        require constraint {
            dispenser.cashInventory >= dispenser.minimumCashThreshold
        }
    }
    
    requirement <'REQ-ATM-004'> securityControls {
        doc /* The ATM shall limit PIN entry attempts to 3 consecutive 
             * failures, after which the card shall be retained and 
             * security personnel notified.
             */
        subject ctrl : ATM::controller;
        require constraint {
            ctrl.pinAttemptCount <= ctrl.maxPinAttempts
        }
    }
    
    requirement <'REQ-ATM-005'> networkConnectivity {
        doc /* The ATM shall maintain secure network connectivity to 
             * the central banking system for all authentication and 
             * transaction processing operations.
             */
        subject network : ATM::networkInterface;
        require constraint {
            network.connectionStatus == true &&
            network.encryptionEnabled == true
        }
    }
    
    requirement <'REQ-ATM-006'> receiptGeneration {
        doc /* The ATM shall provide a printed receipt for every 
             * completed transaction, including transaction type, 
             * amount, date/time, and remaining balance.
             */
        subject printer : ATM::receiptPrinter;
        require constraint {
            printer.paperRemaining > 0
        }
    }
    
    requirement <'REQ-ATM-007'> sessionTimeout {
        doc /* The ATM shall automatically terminate inactive sessions 
             * after 60 seconds of user inactivity and return the card.
             */
        subject ctrl : ATM::controller;
        require constraint {
            ctrl.sessionTimeout == 60.0
        }
    }
    
    requirement <'REQ-ATM-008'> dataEncryption {
        doc /* The ATM shall encrypt all sensitive data including PIN, 
             * account numbers, and transaction details during 
             * transmission to the banking network.
             */
        subject security : ATM::securityModule;
        require constraint {
            security.encryptionKey != ""
        }
    }
    
    part atmSystem : ATM {
        attribute :>> atmID = "ATM-MAIN-001";
        attribute :>> location = "Downtown Branch - 123 Main Street";
        attribute :>> operationalStatus = true;
        attribute :>> serviceMode = false;
        attribute :>> totalTransactionsToday = 0;
        
        part :>> cashDispenser {
            attribute :>> cashInventory = 100000.0;
            attribute :>> twentyDollarCount = 2000;
            attribute :>> fiftyDollarCount = 1000;
            attribute :>> hundredDollarCount = 500;
        }
        
        part :>> controller {
            attribute :>> currentState = "idle";
            attribute :>> sessionActive = false;
            attribute :>> pinAttemptCount = 0;
        }
        
        part :>> networkInterface {
            attribute :>> connectionStatus = true;
            attribute :>> encryptionEnabled = true;
        }
        
        part :>> securityModule {
            attribute :>> tamperDetected = false;
            attribute :>> securityAlarmActive = false;
        }
    }
    
    satisfy primaryFunction by atmSystem;
    satisfy userAuthentication by atmSystem;
    satisfy cashDispensing by atmSystem.cashDispenser;
    satisfy securityControls by atmSystem.controller;
    satisfy networkConnectivity by atmSystem.networkInterface;
    satisfy receiptGeneration by atmSystem.receiptPrinter;
    satisfy sessionTimeout by atmSystem.controller;
    satisfy dataEncryption by atmSystem.securityModule;
}
