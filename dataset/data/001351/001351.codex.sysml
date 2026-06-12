package AutomatedCashHandlingSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def CurrencyAmount {
        attribute amount : Real;
        attribute currencyCode : String;
    }

    attribute def CashCount {
        attribute denomination : CurrencyAmount;
        attribute quantity : Integer;
        attribute subtotal : CurrencyAmount;
    }

    attribute def TransactionIdentifier {
        attribute id : String;
    }

    attribute def AuthenticationToken {
        attribute tokenValue : String;
        attribute issuedAt : Time;
        attribute expiresAt : Time;
    }

    attribute def CashHandlingStatus {
        attribute code : String;
        attribute description : String;
    }

    attribute def ErrorCode {
        attribute code : String;
        attribute severity : String;
        attribute description : String;
    }

    item def Banknote {
        attribute denomination : CurrencyAmount;
        attribute serialNumber : String;
        attribute authenticityScore : Real;
        attribute fitnessScore : Real;
    }

    item def Coin {
        attribute denomination : CurrencyAmount;
        attribute diameter : Length;
        attribute mass : Mass;
    }

    item def CashBundle {
        attribute totalValue : CurrencyAmount;
        attribute count : Integer;
        item banknotes : Banknote[*];
        item coins : Coin[*];
    }

    item def DepositRequest {
        attribute transactionId : TransactionIdentifier;
        attribute customerAccountId : String;
        attribute declaredAmount : CurrencyAmount;
    }

    item def WithdrawalRequest {
        attribute transactionId : TransactionIdentifier;
        attribute customerAccountId : String;
        attribute requestedAmount : CurrencyAmount;
    }

    item def DepositReceipt {
        attribute transactionId : TransactionIdentifier;
        attribute acceptedAmount : CurrencyAmount;
        attribute rejectedAmount : CurrencyAmount;
        attribute completedAt : Time;
    }

    item def WithdrawalReceipt {
        attribute transactionId : TransactionIdentifier;
        attribute dispensedAmount : CurrencyAmount;
        attribute completedAt : Time;
    }

    item def CashInventoryReport {
        attribute generatedAt : Time;
        attribute totalStoredValue : CurrencyAmount;
        attribute availableValue : CurrencyAmount;
        attribute rejectedValue : CurrencyAmount;
        attribute counts : CashCount[*];
    }

    item def AuditEvent {
        attribute eventId : String;
        attribute eventTime : Time;
        attribute actorId : String;
        attribute eventType : String;
        attribute transactionId : TransactionIdentifier;
        attribute result : CashHandlingStatus;
    }

    item def MaintenanceCommand {
        attribute commandId : String;
        attribute commandType : String;
        attribute issuedBy : String;
    }

    port def CustomerInterfacePort {
        in item depositRequest : DepositRequest;
        in item withdrawalRequest : WithdrawalRequest;
        out item depositReceipt : DepositReceipt;
        out item withdrawalReceipt : WithdrawalReceipt;
        out item status : CashHandlingStatus;
    }

    port def CashInputPort {
        in item insertedCash : CashBundle;
        out item rejectedCash : CashBundle;
    }

    port def CashOutputPort {
        out item dispensedCash : CashBundle;
    }

    port def BankHostPort {
        in item authorizationToken : AuthenticationToken;
        out item authorizationRequest : TransactionIdentifier;
        out item settlementEvent : AuditEvent;
    }

    port def AuditPort {
        out item auditEvent : AuditEvent;
        out item inventoryReport : CashInventoryReport;
    }

    port def MaintenancePort {
        in item maintenanceCommand : MaintenanceCommand;
        out item maintenanceStatus : CashHandlingStatus;
    }

    port def SensorDataPort {
        out attribute jamDetected : Boolean;
        out attribute counterfeitDetected : Boolean;
        out attribute safeDoorOpen : Boolean;
        out attribute cassetteLevelPercent : Real;
    }

    port def ControlPort {
        in attribute enable : Boolean;
        in attribute reset : Boolean;
        out attribute ready : Boolean;
        out attribute faulted : Boolean;
    }

    part def AutomatedCashHandler {
        attribute supportedCurrency : String = "USD";
        attribute maximumDepositAmount : CurrencyAmount;
        attribute maximumWithdrawalAmount : CurrencyAmount;
        attribute transactionTimeout : Duration;
        attribute storedCashValue : CurrencyAmount;
        attribute availableCashValue : CurrencyAmount;
        attribute operatingStatus : CashHandlingStatus;

        port customerPort : CustomerInterfacePort;
        port cashInput : CashInputPort;
        port cashOutput : CashOutputPort;
        port bankHost : BankHostPort;
        port audit : AuditPort;
        port maintenance : MaintenancePort;

        part controller : TransactionController;
        part cashValidator : CashValidator;
        part cashSorter : CashSorter;
        part cashDispenser : CashDispenser;
        part inventoryManager : CashInventoryManager;
        part secureVault : SecureVault;
        part auditLogger : AuditLogger;
        part operatorPanel : OperatorPanel;
        part safetyMonitor : SafetyMonitor;
        part powerSubsystem : PowerSubsystem;

        connect customerPort to controller.customerPort;
        connect cashInput to cashValidator.cashInput;
        connect cashValidator.validatedCashOut to cashSorter.validatedCashIn;
        connect cashValidator.rejectedCashOut to cashInput.rejectedCash;
        connect cashSorter.acceptedCashOut to secureVault.depositInput;
        connect secureVault.dispenseOutput to cashDispenser.cashSource;
        connect cashDispenser.cashOutput to cashOutput;
        connect controller.bankHost to bankHost;
        connect controller.inventoryCommandPort to inventoryManager.commandPort;
        connect inventoryManager.vaultInventoryPort to secureVault.inventoryPort;
        connect controller.auditPort to auditLogger.auditIn;
        connect auditLogger.auditOut to audit;
        connect maintenance to operatorPanel.maintenancePort;
        connect operatorPanel.controlOut to controller.maintenanceControl;
        connect safetyMonitor.sensorPort to secureVault.sensorPort;
        connect safetyMonitor.controlPort to controller.safetyControl;
        connect powerSubsystem.controlPort to controller.powerControl;

        perform action processDeposit {
            in item request : DepositRequest;
            in item insertedCash : CashBundle;
            out item receipt : DepositReceipt;

            first start;
            then authenticateCustomer;
            then countAndValidateCash;
            then rejectInvalidCash;
            then sortAcceptedCash;
            then storeAcceptedCash;
            then creditCustomerAccount;
            then updateInventory;
            then recordDepositAudit;
            then printDepositReceipt;
            then done;

            action authenticateCustomer;
            action countAndValidateCash;
            action rejectInvalidCash;
            action sortAcceptedCash;
            action storeAcceptedCash;
            action creditCustomerAccount;
            action updateInventory;
            action recordDepositAudit;
            action printDepositReceipt;
        }

        perform action processWithdrawal {
            in item request : WithdrawalRequest;
            out item dispensedCash : CashBundle;
            out item receipt : WithdrawalReceipt;

            first start;
            then authenticateCustomer;
            then verifyCashAvailability;
            then reserveCash;
            then dispenseCash;
            then confirmRemoval;
            then debitCustomerAccount;
            then updateInventory;
            then recordWithdrawalAudit;
            then printWithdrawalReceipt;
            then done;

            action authenticateCustomer;
            action verifyCashAvailability;
            action reserveCash;
            action dispenseCash;
            action confirmRemoval;
            action debitCustomerAccount;
            action updateInventory;
            action recordWithdrawalAudit;
            action printWithdrawalReceipt;
        }

        state machine operationalStates {
            state Off;
            state Initializing;
            state Ready;
            state Authenticating;
            state AcceptingDeposit;
            state ValidatingCash;
            state DispensingCash;
            state Reconciling;
            state Maintenance;
            state Faulted;
            state SecuredShutdown;

            initial then Off;

            transition powerOn
                first Off
                accept PowerEnabled
                then Initializing;

            transition initializationComplete
                first Initializing
                accept SelfTestPassed
                then Ready;

            transition customerDepositStarted
                first Ready
                accept DepositRequestReceived
                then Authenticating;

            transition customerWithdrawalStarted
                first Ready
                accept WithdrawalRequestReceived
                then Authenticating;

            transition authenticationForDepositComplete
                first Authenticating
                accept DepositAuthorized
                then AcceptingDeposit;

            transition authenticationForWithdrawalComplete
                first Authenticating
                accept WithdrawalAuthorized
                then DispensingCash;

            transition cashInserted
                first AcceptingDeposit
                accept CashBundleInserted
                then ValidatingCash;

            transition validationComplete
                first ValidatingCash
                accept CashAccepted
                then Reconciling;

            transition dispensingComplete
                first DispensingCash
                accept CashDispensed
                then Reconciling;

            transition reconciliationComplete
                first Reconciling
                accept TransactionClosed
                then Ready;

            transition maintenanceRequested
                first Ready
                accept AuthorizedMaintenanceCommand
                then Maintenance;

            transition maintenanceComplete
                first Maintenance
                accept MaintenanceReleased
                then Initializing;

            transition recoverableFault
                first Ready
                accept FaultDetected
                then Faulted;

            transition depositFault
                first AcceptingDeposit
                accept FaultDetected
                then Faulted;

            transition validationFault
                first ValidatingCash
                accept FaultDetected
                then Faulted;

            transition dispenseFault
                first DispensingCash
                accept FaultDetected
                then Faulted;

            transition faultCleared
                first Faulted
                accept ResetCommand
                then Initializing;

            transition secureShutdown
                first Faulted
                accept SecurityBreachDetected
                then SecuredShutdown;
        }
    }

    part def TransactionController {
        attribute activeTransactionId : TransactionIdentifier;
        attribute authenticated : Boolean;
        attribute transactionStartTime : Time;

        port customerPort : CustomerInterfacePort;
        port bankHost : BankHostPort;
        port auditPort : AuditPort;
        port inventoryCommandPort : ControlPort;
        port maintenanceControl : ControlPort;
        port safetyControl : ControlPort;
        port powerControl : ControlPort;

        perform action authorizeTransaction {
            in item transactionId : TransactionIdentifier;
            out item token : AuthenticationToken;
        }

        perform action closeTransaction {
            in item transactionId : TransactionIdentifier;
            in attribute success : Boolean;
            out item event : AuditEvent;
        }
    }

    part def CashValidator {
        attribute minimumAuthenticityScore : Real = 0.97;
        attribute minimumFitnessScore : Real = 0.70;
        attribute validationRate : Real;
        attribute counterfeitCount : Integer;

        port cashInput : CashInputPort;
        port validatedCashOut : CashInputPort;
        port rejectedCashOut : CashOutputPort;
        port sensorPort : SensorDataPort;

        perform action validateBanknotes {
            in item insertedCash : CashBundle;
            out item acceptedCash : CashBundle;
            out item rejectedCash : CashBundle;
        }

        perform action validateCoins {
            in item insertedCash : CashBundle;
            out item acceptedCash : CashBundle;
            out item rejectedCash : CashBundle;
        }
    }

    part def CashSorter {
        attribute sortRate : Real;
        attribute destinationCassetteId : String;

        port validatedCashIn : CashInputPort;
        port acceptedCashOut : CashOutputPort;

        perform action sortByDenomination {
            in item cash : CashBundle;
            out item sortedCash : CashBundle;
        }
    }

    part def CashDispenser {
        attribute dispenseRate : Real;
        attribute maximumNotesPerDispense : Integer = 80;
        attribute presentTimeout : Duration;

        port cashSource : CashInputPort;
        port cashOutput : CashOutputPort;
        port sensorPort : SensorDataPort;

        perform action prepareDispenseMix {
            in attribute requestedAmount : CurrencyAmount;
            out item cashToDispense : CashBundle;
        }

        perform action presentCash {
            in item cashToDispense : CashBundle;
            out item dispensedCash : CashBundle;
        }

        state machine dispenserStates {
            state Idle;
            state Picking;
            state Stacking;
            state Presenting;
            state Retracting;
            state Jammed;

            initial then Idle;

            transition startPick first Idle accept DispenseCommand then Picking;
            transition pickComplete first Picking accept NotesPicked then Stacking;
            transition stackComplete first Stacking accept BundleStacked then Presenting;
            transition customerTookCash first Presenting accept CashRemoved then Idle;
            transition timeout first Presenting accept PresentTimeoutExpired then Retracting;
            transition retractComplete first Retracting accept CashRetracted then Idle;
            transition jam first Picking accept JamDetected then Jammed;
            transition clearJam first Jammed accept JamCleared then Idle;
        }
    }

    part def CashInventoryManager {
        attribute totalStoredValue : CurrencyAmount;
        attribute availableWithdrawalValue : CurrencyAmount;
        attribute reservedValue : CurrencyAmount;
        attribute lowCashThreshold : CurrencyAmount;

        port commandPort : ControlPort;
        port vaultInventoryPort : AuditPort;
        port reportPort : AuditPort;

        perform action reserveCashForWithdrawal {
            in attribute requestedAmount : CurrencyAmount;
            out attribute reservationAccepted : Boolean;
        }

        perform action updateAfterDeposit {
            in item acceptedCash : CashBundle;
            out item report : CashInventoryReport;
        }

        perform action updateAfterWithdrawal {
            in item dispensedCash : CashBundle;
            out item report : CashInventoryReport;
        }

        perform action reconcileVault {
            out item report : CashInventoryReport;
        }
    }

    part def SecureVault {
        attribute vaultLocked : Boolean = true;
        attribute doorOpen : Boolean = false;
        attribute maximumStoredValue : CurrencyAmount;
        attribute currentStoredValue : CurrencyAmount;

        port depositInput : CashInputPort;
        port dispenseOutput : CashOutputPort;
        port inventoryPort : AuditPort;
        port sensorPort : SensorDataPort;

        part cassette1 : CashCassette {
            attribute cassetteId = "USD-001";
            attribute denomination.amount = 1.0;
            attribute capacity = 2500;
        }

        part cassette5 : CashCassette {
            attribute cassetteId = "USD-005";
            attribute denomination.amount = 5.0;
            attribute capacity = 2500;
        }

        part cassette10 : CashCassette {
            attribute cassetteId = "USD-010";
            attribute denomination.amount = 10.0;
            attribute capacity = 2500;
        }

        part cassette20 : CashCassette {
            attribute cassetteId = "USD-020";
            attribute denomination.amount = 20.0;
            attribute capacity = 3000;
        }

        part cassette50 : CashCassette {
            attribute cassetteId = "USD-050";
            attribute denomination.amount = 50.0;
            attribute capacity = 2000;
        }

        part cassette100 : CashCassette {
            attribute cassetteId = "USD-100";
            attribute denomination.amount = 100.0;
            attribute capacity = 2000;
        }

        perform action lockVault;
        perform action unlockVault {
            in item token : AuthenticationToken;
            out attribute accessGranted : Boolean;
        }

        perform action storeCash {
            in item acceptedCash : CashBundle;
            out item inventoryReport : CashInventoryReport;
        }

        perform action releaseCash {
            in attribute requestedAmount : CurrencyAmount;
            out item cashBundle : CashBundle;
        }
    }

    part def CashCassette {
        attribute cassetteId : String;
        attribute denomination : CurrencyAmount;
        attribute capacity : Integer;
        attribute currentCount : Integer;
        attribute reservedCount : Integer;
        attribute rejectCount : Integer;
        attribute cassetteLocked : Boolean;

        perform action addCash {
            in item cash : CashBundle;
            out attribute acceptedCount : Integer;
        }

        perform action removeCash {
            in attribute requestedCount : Integer;
            out item cash : CashBundle;
        }
    }

    part def AuditLogger {
        attribute retentionDays : Integer = 2555;
        attribute lastEventId : String;

        port auditIn : AuditPort;
        port auditOut : AuditPort;

        perform action recordEvent {
            in item event : AuditEvent;
        }

        perform action generateInventoryReport {
            in item report : CashInventoryReport;
            out item signedReport : CashInventoryReport;
        }
    }

    part def OperatorPanel {
        attribute operatorAuthenticated : Boolean;
        attribute displayBrightness : Real;

        port maintenancePort : MaintenancePort;
        port controlOut : ControlPort;

        perform action authenticateOperator {
            in item token : AuthenticationToken;
            out attribute accepted : Boolean;
        }

        perform action executeMaintenanceCommand {
            in item command : MaintenanceCommand;
            out item status : CashHandlingStatus;
        }
    }

    part def SafetyMonitor {
        attribute tamperDetected : Boolean;
        attribute jamDetected : Boolean;
        attribute emergencyStopActive : Boolean;
        attribute safeDoorOpen : Boolean;

        port sensorPort : SensorDataPort;
        port controlPort : ControlPort;

        perform action evaluateSafety {
            out item status : CashHandlingStatus;
        }

        perform action inhibitCashMovement {
            out attribute inhibited : Boolean;
        }
    }

    part def PowerSubsystem {
        attribute linePowerAvailable : Boolean;
        attribute batteryChargePercent : Real;
        attribute backupRuntime : Duration;

        port controlPort : ControlPort;

        perform action switchToBackupPower;
        perform action shutdownGracefully;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : AutomatedCashHandler;
        require constraint {
            system shall accept, validate, count, store, dispense, reconcile, and audit physical cash transactions while protecting customer funds, cash inventory, and transaction records.
        }
    }

    requirement def DepositAccuracyRequirement {
        subject system : AutomatedCashHandler;
        require constraint {
            system.cashValidator.minimumAuthenticityScore >= 0.97
        }
    }

    requirement def WithdrawalAvailabilityRequirement {
        subject system : AutomatedCashHandler;
        require constraint {
            system.availableCashValue.amount >= 0.0
        }
    }

    requirement def InventoryCapacityRequirement {
        subject vault : SecureVault;
        require constraint {
            vault.currentStoredValue.amount <= vault.maximumStoredValue.amount
        }
    }

    requirement def TransactionAuditRequirement {
        subject logger : AuditLogger;
        require constraint {
            logger.retentionDays >= 2555
        }
    }

    requirement def SecureVaultRequirement {
        subject vault : SecureVault;
        require constraint {
            vault.vaultLocked == true or vault.doorOpen == false
        }
    }

    requirement def SafeOperationRequirement {
        subject monitor : SafetyMonitor;
        require constraint {
            monitor.emergencyStopActive == false implies monitor.jamDetected == false
        }
    }

    requirement def DispenseLimitRequirement {
        subject dispenser : CashDispenser;
        require constraint {
            dispenser.maximumNotesPerDispense <= 100
        }
    }

    satisfy PrimaryFunctionRequirement by AutomatedCashHandler;
    satisfy DepositAccuracyRequirement by CashValidator;
    satisfy WithdrawalAvailabilityRequirement by CashInventoryManager;
    satisfy InventoryCapacityRequirement by SecureVault;
    satisfy TransactionAuditRequirement by AuditLogger;
    satisfy SecureVaultRequirement by SecureVault;
    satisfy SafeOperationRequirement by SafetyMonitor;
    satisfy DispenseLimitRequirement by CashDispenser;

    part automatedCashHandlingSystem : AutomatedCashHandler {
        attribute supportedCurrency = "USD";
        attribute maximumDepositAmount.amount = 10000.0;
        attribute maximumDepositAmount.currencyCode = "USD";
        attribute maximumWithdrawalAmount.amount = 3000.0;
        attribute maximumWithdrawalAmount.currencyCode = "USD";
        attribute transactionTimeout = 120 [s];
        attribute storedCashValue.amount = 0.0;
        attribute storedCashValue.currencyCode = "USD";
        attribute availableCashValue.amount = 0.0;
        attribute availableCashValue.currencyCode = "USD";
    }
}