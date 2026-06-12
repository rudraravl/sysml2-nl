package VendingMachineModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def CurrencyValue {
        attribute amount : Real;
        attribute currencyCode : String;
    }

    attribute def TemperatureValue {
        attribute celsius : Real;
    }

    attribute def InventoryCount {
        attribute quantity : Integer;
    }

    item def Coin {
        attribute denomination : CurrencyValue;
        attribute diameter_mm : Real;
        attribute mass_g : Real;
    }

    item def Banknote {
        attribute denomination : CurrencyValue;
        attribute width_mm : Real;
        attribute length_mm : Real;
    }

    item def PaymentToken {
        attribute tokenId : String;
        attribute approvedAmount : CurrencyValue;
        attribute authorizationCode : String;
    }

    item def Product {
        attribute productId : String;
        attribute name : String;
        attribute price : CurrencyValue;
        attribute mass_g : Real;
        attribute targetStorageTemperature : TemperatureValue;
    }

    item def DispensedProduct :> Product {
        attribute dispensedAtDoor : Boolean;
    }

    item def Refund {
        attribute value : CurrencyValue;
        attribute reason : String;
    }

    item def SelectionCommand {
        attribute productId : String;
        attribute quantity : Integer;
    }

    item def MaintenanceCommand {
        attribute commandCode : String;
        attribute authorizedTechnicianId : String;
    }

    item def StatusReport {
        attribute ready : Boolean;
        attribute selectedProductAvailable : Boolean;
        attribute currentCredit : CurrencyValue;
        attribute faultCode : String;
        attribute internalTemperature : TemperatureValue;
    }

    port def CoinInputPort {
        in item coin : Coin;
    }

    port def BanknoteInputPort {
        in item banknote : Banknote;
    }

    port def CardPaymentPort {
        in item token : PaymentToken;
        out item approvalStatus : StatusReport;
    }

    port def ProductSelectionPort {
        in item selection : SelectionCommand;
        out item status : StatusReport;
    }

    port def ProductDeliveryPort {
        out item product : DispensedProduct;
    }

    port def RefundPort {
        out item refund : Refund;
    }

    port def MaintenancePort {
        in item command : MaintenanceCommand;
        out item report : StatusReport;
    }

    port def PowerPort {
        in attribute supplyVoltage_V : Real;
        in attribute supplyFrequency_Hz : Real;
    }

    port def CoolingAirPort {
        in attribute ambientTemperature : TemperatureValue;
        out attribute rejectedHeat_W : Real;
    }

    part def VendingMachine {
        attribute machineId : String;
        attribute location : String;
        attribute operational : Boolean;
        attribute currentCredit : CurrencyValue;
        attribute selectedProductId : String;
        attribute vendCycleTime_s : Real;
        attribute maxStoredProducts : InventoryCount;
        attribute internalTemperature : TemperatureValue;

        port coinSlot : CoinInputPort;
        port banknoteSlot : BanknoteInputPort;
        port cardReaderPort : CardPaymentPort;
        port selectionPanelPort : ProductSelectionPort;
        port deliveryDoorPort : ProductDeliveryPort;
        port refundTrayPort : RefundPort;
        port maintenanceInterfacePort : MaintenancePort;
        port electricalPowerPort : PowerPort;
        port condenserAirPort : CoolingAirPort;

        part controller : MachineController;
        part paymentSubsystem : PaymentSubsystem;
        part inventorySubsystem : InventorySubsystem;
        part dispensingSubsystem : DispensingSubsystem;
        part userInterface : UserInterface;
        part refrigerationSubsystem : RefrigerationSubsystem;
        part powerSubsystem : PowerSubsystem;
        part maintenanceSubsystem : MaintenanceSubsystem;

        connect coinSlot to paymentSubsystem.coinInput;
        connect banknoteSlot to paymentSubsystem.banknoteInput;
        connect cardReaderPort to paymentSubsystem.cardPayment;
        connect paymentSubsystem.paymentStatus to controller.paymentStatusInput;

        connect selectionPanelPort to userInterface.selectionInput;
        connect userInterface.selectionOutput to controller.selectionInput;

        connect controller.inventoryQuery to inventorySubsystem.queryPort;
        connect controller.dispenseCommand to dispensingSubsystem.dispenseInput;
        connect dispensingSubsystem.productOutput to deliveryDoorPort;

        connect controller.refundCommand to paymentSubsystem.refundInput;
        connect paymentSubsystem.refundOutput to refundTrayPort;

        connect electricalPowerPort to powerSubsystem.externalPowerInput;
        connect powerSubsystem.controlPowerOutput to controller.powerInput;
        connect powerSubsystem.loadPowerOutput to refrigerationSubsystem.powerInput;

        connect condenserAirPort to refrigerationSubsystem.airInterface;
        connect refrigerationSubsystem.temperatureStatus to controller.temperatureInput;

        connect maintenanceInterfacePort to maintenanceSubsystem.maintenanceInput;
        connect maintenanceSubsystem.serviceCommandOutput to controller.maintenanceInput;
    }

    part def MachineController {
        attribute idleTimeout_s : Real = 30.0;
        attribute maximumVendAttempts : Integer = 2;
        attribute faultCode : String;
        attribute selectedProductId : String;
        attribute creditAccepted : CurrencyValue;

        port paymentStatusInput {
            in item status : StatusReport;
        }

        port selectionInput {
            in item selection : SelectionCommand;
        }

        port inventoryQuery {
            out item selection : SelectionCommand;
            in item status : StatusReport;
        }

        port dispenseCommand {
            out item selection : SelectionCommand;
            in item status : StatusReport;
        }

        port refundCommand {
            out item refund : Refund;
        }

        port temperatureInput {
            in attribute temperature : TemperatureValue;
        }

        port powerInput {
            in attribute supplyVoltage_V : Real;
        }

        port maintenanceInput {
            in item command : MaintenanceCommand;
        }

        state def ControllerBehavior {
            entry action initializeMachine;
            state Off;
            state Initializing;
            state Ready;
            state AcceptingPayment;
            state AwaitingSelection;
            state ValidatingSelection;
            state Dispensing;
            state Refunding;
            state OutOfService;

            transition first Off;
            transition Off to Initializing
                accept PowerAvailable;

            transition Initializing to Ready
                accept InitializationComplete
                if controllerSelfCheckPassed;

            transition Initializing to OutOfService
                accept InitializationComplete
                if not controllerSelfCheckPassed;

            transition Ready to AcceptingPayment
                accept PaymentInserted;

            transition AcceptingPayment to AwaitingSelection
                accept CreditAvailable
                if sufficientCreditExists;

            transition AwaitingSelection to ValidatingSelection
                accept ProductSelected;

            transition ValidatingSelection to Dispensing
                accept ProductAvailable
                if selectedProductAvailable and sufficientCreditExists;

            transition ValidatingSelection to Refunding
                accept ProductUnavailable;

            transition Dispensing to Ready
                accept ProductDelivered
                do completeSale;

            transition Dispensing to Refunding
                accept DispenseFailed
                do recordDispenseFault;

            transition Refunding to Ready
                accept RefundComplete
                do clearCreditAndSelection;

            transition Ready to OutOfService
                accept CriticalFaultDetected;

            transition AcceptingPayment to Refunding
                accept CancelPressed;

            transition AwaitingSelection to Refunding
                accept CancelPressed;

            transition OutOfService to Initializing
                accept MaintenanceReset;
        }

        action initializeMachine {
            out attribute initialized : Boolean;
        }

        action completeSale {
            in item soldProduct : Product;
            out item receiptStatus : StatusReport;
        }

        action recordDispenseFault {
            in attribute faultReason : String;
            out attribute faultCode : String;
        }

        action clearCreditAndSelection {
            out attribute currentCredit : CurrencyValue;
            out attribute selectedProductId : String;
        }
    }

    part def PaymentSubsystem {
        attribute acceptedCurrencyCode : String = "USD";
        attribute storedCashValue : CurrencyValue;
        attribute currentSessionCredit : CurrencyValue;
        attribute maximumCashCredit : CurrencyValue;

        port coinInput : CoinInputPort;
        port banknoteInput : BanknoteInputPort;
        port cardPayment : CardPaymentPort;

        port paymentStatus {
            out item status : StatusReport;
        }

        port refundInput {
            in item refund : Refund;
        }

        port refundOutput : RefundPort;

        part coinValidator : CoinValidator;
        part banknoteValidator : BanknoteValidator;
        part cardProcessor : CardProcessor;
        part cashBox : CashBox;
        part changeDispenser : ChangeDispenser;

        connect coinInput to coinValidator.coinIn;
        connect banknoteInput to banknoteValidator.banknoteIn;
        connect cardPayment to cardProcessor.cardPort;
        connect coinValidator.acceptedCoinOut to cashBox.coinDeposit;
        connect banknoteValidator.acceptedBanknoteOut to cashBox.banknoteDeposit;
        connect refundInput to changeDispenser.refundRequest;
        connect changeDispenser.refundOut to refundOutput;

        action acceptCashPayment {
            in item coin : Coin;
            in item banknote : Banknote;
            out attribute acceptedValue : CurrencyValue;
        }

        action authorizeCardPayment {
            in item token : PaymentToken;
            out attribute approved : Boolean;
            out attribute approvedAmount : CurrencyValue;
        }

        action issueRefund {
            in item refundRequest : Refund;
            out item refundIssued : Refund;
        }
    }

    part def CoinValidator {
        attribute supportedCoinValues : CurrencyValue[4];

        port coinIn : CoinInputPort;

        port acceptedCoinOut {
            out item coin : Coin;
        }

        action validateCoin {
            in item candidate : Coin;
            out attribute accepted : Boolean;
            out attribute value : CurrencyValue;
        }
    }

    part def BanknoteValidator {
        attribute supportedBanknoteValues : CurrencyValue[5];

        port banknoteIn : BanknoteInputPort;

        port acceptedBanknoteOut {
            out item banknote : Banknote;
        }

        action validateBanknote {
            in item candidate : Banknote;
            out attribute accepted : Boolean;
            out attribute value : CurrencyValue;
        }
    }

    part def CardProcessor {
        attribute networkTimeout_s : Real = 5.0;

        port cardPort : CardPaymentPort;

        action requestAuthorization {
            in item token : PaymentToken;
            out attribute approved : Boolean;
            out attribute authorizationCode : String;
        }
    }

    part def CashBox {
        attribute capacityCoins : Integer = 1200;
        attribute capacityBanknotes : Integer = 400;
        attribute storedValue : CurrencyValue;

        port coinDeposit {
            in item coin : Coin;
        }

        port banknoteDeposit {
            in item banknote : Banknote;
        }
    }

    part def ChangeDispenser {
        attribute availableChange : CurrencyValue;
        attribute minimumChangeReserve : CurrencyValue;

        port refundRequest {
            in item refund : Refund;
        }

        port refundOut : RefundPort;

        action dispenseChange {
            in item requestedRefund : Refund;
            out item completedRefund : Refund;
        }
    }

    part def InventorySubsystem {
        attribute totalInventory : InventoryCount;
        attribute lowStockThreshold : InventoryCount = 3;

        port queryPort {
            in item selection : SelectionCommand;
            out item status : StatusReport;
        }

        part slots : ProductSlot[12];

        action checkAvailability {
            in item selection : SelectionCommand;
            out attribute available : Boolean;
            out item product : Product;
        }

        action decrementInventory {
            in item dispensedProduct : Product;
            out attribute remainingQuantity : InventoryCount;
        }
    }

    part def ProductSlot {
        attribute slotId : String;
        attribute quantity : InventoryCount;
        attribute maxQuantity : InventoryCount;
        attribute assignedProduct : Product;
        attribute spiralMotorIndex : Integer;
    }

    part def DispensingSubsystem {
        attribute vendMotorVoltage_V : Real = 24.0;
        attribute deliverySensorBlocked : Boolean;

        port dispenseInput {
            in item selection : SelectionCommand;
            out item status : StatusReport;
        }

        port productOutput : ProductDeliveryPort;

        part vendMotors : VendMotor[12];
        part deliverySensor : DeliverySensor;
        part deliveryDoor : DeliveryDoor;

        connect deliverySensor.productDetectedOutput to deliveryDoor.releaseInput;

        action dispenseSelectedProduct {
            in item selection : SelectionCommand;
            out item product : DispensedProduct;
            out attribute success : Boolean;
        }

        action verifyDelivery {
            out attribute delivered : Boolean;
        }
    }

    part def VendMotor {
        attribute motorId : String;
        attribute ratedVoltage_V : Real = 24.0;
        attribute rotationAngle_deg : Real = 360.0;
        attribute stallCurrent_A : Real = 1.8;

        action rotateOneVendCycle {
            out attribute completed : Boolean;
        }
    }

    part def DeliverySensor {
        attribute sensorType : String = "infrared beam";
        attribute detectionTimeout_s : Real = 4.0;

        port productDetectedOutput {
            out attribute detected : Boolean;
        }

        action detectProductPassage {
            out attribute detected : Boolean;
        }
    }

    part def DeliveryDoor {
        attribute locked : Boolean;
        attribute openTimeout_s : Real = 15.0;

        port releaseInput {
            in attribute detected : Boolean;
        }

        action unlockForPickup {
            out attribute unlocked : Boolean;
        }
    }

    part def UserInterface {
        attribute displayBrightnessPercent : Real = 75.0;
        attribute speakerVolumePercent : Real = 40.0;

        port selectionInput : ProductSelectionPort;

        port selectionOutput {
            out item selection : SelectionCommand;
        }

        part display : Display;
        part keypad : Keypad;
        part cancelButton : CancelButton;

        action showProductMenu {
            in item availableProducts : Product[*];
        }

        action showStatus {
            in item status : StatusReport;
        }

        action captureSelection {
            out item selection : SelectionCommand;
        }
    }

    part def Display {
        attribute diagonalSize_in : Real = 7.0;
        attribute resolutionX_px : Integer = 800;
        attribute resolutionY_px : Integer = 480;
    }

    part def Keypad {
        attribute keyCount : Integer = 16;

        action readKeySequence {
            out attribute productId : String;
        }
    }

    part def CancelButton {
        attribute illuminated : Boolean;

        action detectCancel {
            out attribute cancelRequested : Boolean;
        }
    }

    part def RefrigerationSubsystem {
        attribute targetTemperature : TemperatureValue;
        attribute highTemperatureLimit : TemperatureValue;
        attribute compressorPower_W : Real = 180.0;

        port powerInput {
            in attribute supplyVoltage_V : Real;
        }

        port airInterface : CoolingAirPort;

        port temperatureStatus {
            out attribute temperature : TemperatureValue;
        }

        part compressor : Compressor;
        part evaporatorFan : Fan;
        part temperatureSensor : TemperatureSensor;

        action regulateTemperature {
            in attribute measuredTemperature : TemperatureValue;
            out attribute compressorEnabled : Boolean;
            out attribute fanEnabled : Boolean;
        }
    }

    part def Compressor {
        attribute ratedPower_W : Real = 180.0;
        attribute refrigerantType : String = "R600a";

        action startCompressor {
            out attribute running : Boolean;
        }

        action stopCompressor {
            out attribute running : Boolean;
        }
    }

    part def Fan {
        attribute airflow_m3_per_h : Real = 65.0;
        attribute ratedPower_W : Real = 8.0;

        action circulateAir {
            out attribute running : Boolean;
        }
    }

    part def TemperatureSensor {
        attribute accuracy_C : Real = 0.5;

        action measureTemperature {
            out attribute measuredTemperature : TemperatureValue;
        }
    }

    part def PowerSubsystem {
        attribute nominalInputVoltage_V : Real = 120.0;
        attribute nominalInputFrequency_Hz : Real = 60.0;
        attribute controlBusVoltage_V : Real = 12.0;

        port externalPowerInput : PowerPort;

        port controlPowerOutput {
            out attribute supplyVoltage_V : Real;
        }

        port loadPowerOutput {
            out attribute supplyVoltage_V : Real;
        }

        action convertPower {
            in attribute inputVoltage_V : Real;
            out attribute controlVoltage_V : Real;
            out attribute loadVoltage_V : Real;
        }

        action detectPowerFault {
            out attribute faultDetected : Boolean;
        }
    }

    part def MaintenanceSubsystem {
        attribute lastServiceTechnicianId : String;
        attribute lastServiceOdometerVends : Integer;
        attribute totalVendCount : Integer;

        port maintenanceInput : MaintenancePort;

        port serviceCommandOutput {
            out item command : MaintenanceCommand;
        }

        action runDiagnostics {
            out item report : StatusReport;
        }

        action restockSlot {
            in attribute slotId : String;
            in item product : Product;
            in attribute addedQuantity : InventoryCount;
            out attribute newQuantity : InventoryCount;
        }

        action clearFault {
            in attribute faultCode : String;
            out attribute cleared : Boolean;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The vending machine shall accept valid payment, allow a user to select an available product, dispense exactly the selected paid product through the delivery door, and return any required refund or change. */
        subject machine : VendingMachine;

        require constraint {
            machine.operational == true
        }

        require constraint {
            machine.vendCycleTime_s <= 10.0
        }
    }

    requirement def PaymentAcceptanceRequirement {
        doc /* The vending machine shall accept coins, banknotes, or authorized card payment in USD and shall reject invalid payment media. */
        subject payment : PaymentSubsystem;

        require constraint {
            payment.acceptedCurrencyCode == "USD"
        }
    }

    requirement def InventoryProtectionRequirement {
        doc /* The vending machine shall dispense a product only when the selected slot has at least one unit available. */
        subject inventory : InventorySubsystem;

        require constraint {
            inventory.totalInventory.quantity >= 0
        }
    }

    requirement def RefundRequirement {
        doc /* The vending machine shall provide a refund when the user cancels before dispensing or when dispensing cannot be completed after payment. */
        subject payment : PaymentSubsystem;

        require constraint {
            payment.currentSessionCredit.amount >= 0.0
        }
    }

    requirement def TemperatureControlRequirement {
        doc /* The vending machine shall maintain refrigerated products at or below the configured high temperature limit during normal operation. */
        subject cooling : RefrigerationSubsystem;

        require constraint {
            cooling.targetTemperature.celsius <= cooling.highTemperatureLimit.celsius
        }
    }

    requirement def SafetyPowerRequirement {
        doc /* The vending machine shall enter out-of-service behavior when critical power faults are detected. */
        subject power : PowerSubsystem;

        require constraint {
            power.nominalInputVoltage_V == 120.0
        }
    }

    satisfy PrimaryFunctionRequirement by VendingMachine;
    satisfy PaymentAcceptanceRequirement by PaymentSubsystem;
    satisfy InventoryProtectionRequirement by InventorySubsystem;
    satisfy RefundRequirement by PaymentSubsystem;
    satisfy TemperatureControlRequirement by RefrigerationSubsystem;
    satisfy SafetyPowerRequirement by PowerSubsystem;

    part vendingMachineExample : VendingMachine {
        attribute machineId = "VM-CHICAGO-001";
        attribute location = "Office lobby";
        attribute operational = true;
        attribute vendCycleTime_s = 8.0;
        attribute currentCredit : CurrencyValue {
            attribute amount = 0.0;
            attribute currencyCode = "USD";
        }
        attribute internalTemperature : TemperatureValue {
            attribute celsius = 4.0;
        }

        part inventorySubsystem {
            attribute totalInventory : InventoryCount {
                attribute quantity = 144;
            }

            part slots[0] {
                attribute slotId = "A1";
                attribute quantity : InventoryCount {
                    attribute quantity = 12;
                }
                attribute maxQuantity : InventoryCount {
                    attribute quantity = 12;
                }
                attribute spiralMotorIndex = 1;
                attribute assignedProduct : Product {
                    attribute productId = "WATER-500";
                    attribute name = "Bottled Water 500 mL";
                    attribute price : CurrencyValue {
                        attribute amount = 1.50;
                        attribute currencyCode = "USD";
                    }
                    attribute mass_g = 520.0;
                    attribute targetStorageTemperature : TemperatureValue {
                        attribute celsius = 4.0;
                    }
                }
            }

            part slots[1] {
                attribute slotId = "A2";
                attribute quantity : InventoryCount {
                    attribute quantity = 10;
                }
                attribute maxQuantity : InventoryCount {
                    attribute quantity = 12;
                }
                attribute spiralMotorIndex = 2;
                attribute assignedProduct : Product {
                    attribute productId = "SODA-355";
                    attribute name = "Carbonated Drink 355 mL";
                    attribute price : CurrencyValue {
                        attribute amount = 2.00;
                        attribute currencyCode = "USD";
                    }
                    attribute mass_g = 390.0;
                    attribute targetStorageTemperature : TemperatureValue {
                        attribute celsius = 4.0;
                    }
                }
            }

            part slots[2] {
                attribute slotId = "B1";
                attribute quantity : InventoryCount {
                    attribute quantity = 8;
                }
                attribute maxQuantity : InventoryCount {
                    attribute quantity = 10;
                }
                attribute spiralMotorIndex = 3;
                attribute assignedProduct : Product {
                    attribute productId = "CHIPS-45";
                    attribute name = "Potato Chips 45 g";
                    attribute price : CurrencyValue {
                        attribute amount = 1.75;
                        attribute currencyCode = "USD";
                    }
                    attribute mass_g = 45.0;
                    attribute targetStorageTemperature : TemperatureValue {
                        attribute celsius = 20.0;
                    }
                }
            }
        }

        part refrigerationSubsystem {
            attribute targetTemperature : TemperatureValue {
                attribute celsius = 4.0;
            }
            attribute highTemperatureLimit : TemperatureValue {
                attribute celsius = 7.0;
            }
        }

        part paymentSubsystem {
            attribute storedCashValue : CurrencyValue {
                attribute amount = 250.00;
                attribute currencyCode = "USD";
            }
            attribute maximumCashCredit : CurrencyValue {
                attribute amount = 20.00;
                attribute currencyCode = "USD";
            }
        }
    }
}