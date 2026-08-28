package AutomatedRetailMachineModel {
    import ScalarValues::*;

    // ===== Value Types =====
    value type Currency :> Real { unit "USD"; }
    value type Mass :> Real { unit "kg"; }
    value type Quantity :> Integer;
    value type ProductId :> String;
    value type TransactionId :> String;

    // ===== Enumerations =====
    enum def PaymentMethodKind {
        creditCard;
        debitCard;
        mobilePayment;
    }

    enum def MachineHealthStatus {
        operational;
        degraded;
        faulted;
    }

    // ===== Item Definitions =====
    item def Product {
        attribute id : ProductId;
        attribute name : String;
        attribute price : Currency;
        attribute weight : Mass;
        attribute stockLevel : Quantity;
    }

    item def PaymentRequest {
        attribute transactionId : TransactionId;
        attribute amount : Currency;
        attribute method : PaymentMethodKind;
    }

    item def PaymentResult {
        attribute transactionId : TransactionId;
        attribute approved : Boolean;
        attribute declineReason : String;
    }

    item def DispenseCommand {
        attribute productId : ProductId;
        attribute expectedWeight : Mass;
    }

    item def DispenseResult {
        attribute productId : ProductId;
        attribute success : Boolean;
        attribute measuredWeight : Mass;
    }

    item def ErrorEvent {
        attribute code : String;
        attribute description : String;
        attribute timestamp : String;
    }

    item def RefundRequest {
        attribute transactionId : TransactionId;
        attribute amount : Currency;
        attribute reason : String;
    }

    item def MaintenanceReport {
        attribute reportId : String;
        attribute generatedAt : String;
        attribute errorCount : Integer;
        attribute summary : String;
    }

    // ===== Port Definitions =====
    port def CustomerPort {
        out displayMessage : String;
        out productCatalog : Product[*];
        in productSelection : ProductId;
    }

    port def InventoryQueryPort {
        out productQuery : ProductId;
        in productInfo : Product;
    }

    port def UIPaymentPort {
        out paymentRequest : PaymentRequest;
        in paymentResult : PaymentResult;
    }

    port def GatewayPort {
        out authorizationRequest : PaymentRequest;
        in authorizationResponse : PaymentResult;
        out refundRequest : RefundRequest;
        in refundConfirmation : PaymentResult;
    }

    port def DispenseControlPort {
        out dispenseCommand : DispenseCommand;
        in dispenseResult : DispenseResult;
    }

    port def DiagnosticCommPort {
        in errorEvent : ErrorEvent;
        out maintenanceReport : MaintenanceReport;
    }

    // ===== Requirements =====
    requirement def ProductSelectionRequirement {
        doc "The machine shall allow customers to browse available products and make a selection via the user interface.";
    }

    requirement def PaymentProcessingRequirement {
        doc "The machine shall accept credit cards, debit cards, and mobile payments, and shall authorize charges through an external payment gateway.";
    }

    requirement def DispensingRequirement {
        doc "The machine shall dispense the selected product after successful payment and verify dispensing via weight sensors.";
    }

    requirement def RefundRequirement {
        doc "The machine shall automatically process a refund if dispensing fails after payment approval.";
    }

    requirement def DiagnosticRequirement {
        doc "The machine shall log errors and generate maintenance reports to ensure operational reliability.";
    }

    requirement def InventoryManagementRequirement {
        doc "The machine shall maintain a real-time count of all products and flag items needing refill when stock runs low.";
    }

    // ===== Part Definitions =====
    part def UserInterface {
        port customerPort : CustomerPort;
        port inventoryPort : InventoryQueryPort;
        port paymentPort : UIPaymentPort;

        attribute displayMessage : String;
        attribute productCatalog : Product[*] = ();

        action displayProducts {
            out catalog : Product[*] = productCatalog;
        }

        action acceptSelection {
            in selection : ProductId;
        }

        action promptPayment {
            in product : Product;
            out request : PaymentRequest;
        }

        action displayError {
            in message : String;
        }

        action displaySuccess {
            in message : String;
        }
    }

    part def InventoryManagementSystem {
        port inventoryPort : ~InventoryQueryPort;

        attribute products : Product[*] = ();
        attribute lowStockThreshold : Quantity = 3;

        action updateStock {
            in productId : ProductId;
            in quantitySold : Quantity;
        }

        action checkStock {
            in productId : ProductId;
            out product : Product;
        }

        action flagRefill {
            in productId : ProductId;
            out notification : String;
        }

        state machine InventoryBehavior {
            state InStock;
            state LowStock;
            state OutOfStock;

            transition from InStock to LowStock when stockFallsBelowThreshold;
            transition from LowStock to OutOfStock when stockReachesZero;
            transition from OutOfStock to InStock when stockRefilled;
            transition from LowStock to InStock when stockRefilled;
        }
    }

    part def PaymentProcessingSystem {
        port uiPaymentPort : ~UIPaymentPort;
        port gatewayPort : GatewayPort;
        port dispensePort : DispenseControlPort;
        port diagnosticPort : ~DiagnosticCommPort;

        attribute currentTransaction : PaymentRequest;
        attribute currentResult : PaymentResult;

        action processPayment {
            in request : PaymentRequest;
            out result : PaymentResult;
        }

        action authorizePayment {
            in request : PaymentRequest;
            out response : PaymentResult;
        }

        action processRefund {
            in refund : RefundRequest;
            out confirmation : PaymentResult;
        }

        state machine PaymentBehavior {
            state Idle;
            state AwaitingAuthorization;
            state Approved;
            state Declined;
            state Refunding;

            transition from Idle to AwaitingAuthorization when paymentRequestReceived;
            transition from AwaitingAuthorization to Approved when authorizationApproved;
            transition from AwaitingAuthorization to Declined when authorizationDeclined;
            transition from Approved to Refunding when dispenseFailed;
            transition from Approved to Idle when dispenseSucceeded;
            transition from Declined to Idle when errorDisplayed;
            transition from Refunding to Idle when refundProcessed;
        }
    }

    part def DispensingMechanism {
        port dispensePort : ~DispenseControlPort;
        port diagnosticPort : ~DiagnosticCommPort;

        attribute expectedWeight : Mass;
        attribute measuredWeight : Mass;
        attribute weightTolerance : Mass = 0.05;

        action dispenseProduct {
            in command : DispenseCommand;
        }

        action verifyDispense {
            in measured : Mass;
            in expected : Mass;
            in tolerance : Mass;
            out result : DispenseResult;
        }

        action detectJam {
            out jamDetected : Boolean;
        }

        state machine DispenseBehavior {
            state Ready;
            state Dispensing;
            state Verifying;
            state Jammed;
            state Complete;

            transition from Ready to Dispensing when dispenseCommandReceived;
            transition from Dispensing to Verifying when productReleased;
            transition from Verifying to Complete when weightVerified;
            transition from Verifying to Jammed when weightMismatch;
            transition from Complete to Ready when resultSent;
            transition from Jammed to Ready when jamCleared;
        }
    }

    part def DiagnosticSystem {
        port paymentDiagPort : DiagnosticCommPort;
        port dispenseDiagPort : DiagnosticCommPort;

        attribute errorLog : ErrorEvent[*] = ();
        attribute healthStatus : MachineHealthStatus = operational;

        action logError {
            in event : ErrorEvent;
        }

        action generateReport {
            out report : MaintenanceReport;
        }

        action monitorHealth {
            out status : MachineHealthStatus;
        }

        state machine DiagnosticBehavior {
            state Monitoring;
            state Logging;
            state Reporting;

            transition from Monitoring to Logging when errorEventReceived;
            transition from Logging to Monitoring when errorLogged;
            transition from Monitoring to Reporting when reportRequested;
            transition from Reporting to Monitoring when reportGenerated;
        }
    }

    part def ExternalPaymentGateway {
        port gatewayPort : ~GatewayPort;

        action authorize {
            in request : PaymentRequest;
            out response : PaymentResult;
        }

        action refund {
            in request : RefundRequest;
            out confirmation : PaymentResult;
        }
    }

    // ===== Top-Level System =====
    part def AutomatedRetailMachine {
        port customerPort : CustomerPort;

        part userInterface : UserInterface;
        part inventoryManagement : InventoryManagementSystem;
        part paymentProcessing : PaymentProcessingSystem;
        part dispensingMechanism : DispensingMechanism;
        part diagnosticSystem : DiagnosticSystem;
        part externalGateway : ExternalPaymentGateway;

        requirement productSelectionReq : ProductSelectionRequirement;
        requirement paymentProcessingReq : PaymentProcessingRequirement;
        requirement dispensingReq : DispensingRequirement;
        requirement refundReq : RefundRequirement;
        requirement diagnosticReq : DiagnosticRequirement;
        requirement inventoryMgmtReq : InventoryManagementRequirement;

        satisfy productSelectionReq by userInterface;
        satisfy paymentProcessingReq by paymentProcessing;
        satisfy dispensingReq by dispensingMechanism;
        satisfy refundReq by paymentProcessing;
        satisfy diagnosticReq by diagnosticSystem;
        satisfy inventoryMgmtReq by inventoryManagement;

        connection customerPort to userInterface.customerPort;
        connection userInterface.inventoryPort to inventoryManagement.inventoryPort;
        connection userInterface.paymentPort to paymentProcessing.uiPaymentPort;
        connection paymentProcessing.gatewayPort to externalGateway.gatewayPort;
        connection paymentProcessing.dispensePort to dispensingMechanism.dispensePort;
        connection paymentProcessing.diagnosticPort to diagnosticSystem.paymentDiagPort;
        connection dispensingMechanism.diagnosticPort to diagnosticSystem.dispenseDiagPort;

        state machine MachineBehavior {
            state Idle;
            state Browsing;
            state Selecting;
            state Paying;
            state Dispensing;
            state ErrorHandling;
            state Refunding;

            transition from Idle to Browsing when customerApproaches;
            transition from Browsing to Selecting when productSelected;
            transition from Selecting to Paying when paymentPrompted;
            transition from Paying to Dispensing when paymentApproved;
            transition from Paying to ErrorHandling when paymentDeclined;
            transition from Dispensing to Idle when productDispensed;
            transition from Dispensing to Refunding when dispenseFailed;
            transition from Refunding to Idle when refundProcessed;
            transition from ErrorHandling to Idle when errorAcknowledged;
        }
    }
}
