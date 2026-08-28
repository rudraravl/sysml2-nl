package VendingMachineSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types ----
    value type CurrencyValue :> Real {
        unit unit "USD";
    }

    value type Quantity :> Integer {
        unit unit "count";
    }

    value type ProductCode :> String {
        readonly;
    }

    // ---- Enumerations ----
    enum CoinType { nickel, dime, quarter, dollar }

    enum DispenseResult { success, outOfStock, insufficientFunds, cancelled }

    // ---- Item definitions ----
    item def Coin {
        attribute coinType : CoinType;
        attribute value : CurrencyValue;
    }

    item def Product {
        attribute code : ProductCode;
        attribute name : String;
        attribute price : CurrencyValue;
        attribute stock : Quantity;
    }

    // ---- Port definitions ----
    port def CoinInsertionPort {
        in item insertedCoin : Coin;
    }

    port def CoinReturnPort {
        out item returnedCoin : Coin;
    }

    port def SelectionPort {
        in attribute selectedCode : ProductCode;
    }

    port def DisplayPort {
        out attribute message : String;
    }

    port def DispenseControlPort {
        in attribute requestCode : ProductCode;
        out attribute result : DispenseResult;
        out item dispensedProduct : Product;
    }

    port def InventoryQueryPort {
        in attribute queryCode : ProductCode;
        out attribute available : Boolean;
        out attribute price : CurrencyValue;
        out attribute stock : Quantity;
    }

    port def CreditQueryPort {
        out attribute currentCredit : CurrencyValue;
    }

    port def CreditCommandPort {
        in attribute resetCredit : Boolean;
        in attribute deductAmount : CurrencyValue;
    }

    // ---- Coin Acceptor ----
    part def CoinAcceptor {
        attribute accumulatedCredit : CurrencyValue := 0.0 [USD];
        attribute coinInventory : CoinType[0..*];

        port coinIn : CoinInsertionPort;
        port coinOut : CoinReturnPort;
        port creditQuery : CreditQueryPort;
        port creditCmd : CreditCommandPort;

        private attribute coinValues : CurrencyValue[*] = (
            CoinType::nickel => 0.05,
            CoinType::dime => 0.10,
            CoinType::quarter => 0.25,
            CoinType::dollar => 1.00
        );

        action def AcceptCoin {
            in coin : Coin;
            // Add coin value to accumulated credit
        }

        action def DispenseChange {
            in amount : CurrencyValue;
            // Return coins totaling amount
        }

        action def RefundFull {
            // Return all accumulated credit
        }

        state def CoinAcceptorBehavior {
            entry;
            state Idle;
            state Accepting {
                entry;
                do AcceptCoin;
            }
            state DispensingChange {
                do DispenseChange;
            }
            state Refunding {
                do RefundFull;
            }
            transition idle_to_accepting
                source Idle
                target Accepting
                when coinIn.insertedCoin->notEmpty();
            transition accepting_to_idle
                source Accepting
                target Idle
                when creditCmd.resetCredit;
            transition to_dispense_change
                source Accepting
                target DispensingChange
                when creditCmd.deductAmount->notEmpty();
            transition to_refund
                source Accepting
                target Refunding
                when creditCmd.resetCredit;
            transition change_to_idle
                source DispensingChange
                target Idle;
            transition refund_to_idle
                source Refunding
                target Idle;
        }

        behavior coinAcceptorStateMachine : CoinAcceptorBehavior;

        // Provide current credit on query
        action provideCredit {
            when creditQuery.currentCredit->isEmpty();
            then creditQuery.currentCredit := accumulatedCredit;
        }
    }

    // ---- Selection Panel ----
    part def SelectionPanel {
        attribute enteredCode : ProductCode;

        port selection : SelectionPort;
        port display : DisplayPort;

        action def ReceiveSelection {
            in code : ProductCode;
            // Store entered code and forward to control module
        }

        action def UpdateDisplay {
            in msg : String;
        }

        state def SelectionPanelBehavior {
            state WaitingForInput;
            state CodeEntered;
            transition input_received
                source WaitingForInput
                target CodeEntered
                when selection.selectedCode->notEmpty();
            transition reset
                source CodeEntered
                target WaitingForInput;
        }

        behavior selectionPanelStateMachine : SelectionPanelBehavior;
    }

    // ---- Dispensing Mechanism ----
    part def DispensingMechanism {
        attribute products : Product[0..*] = (
            Product{code = "A1"; name = "Soda"; price = 1.25; stock = 10;},
            Product{code = "A2"; name = "Water"; price = 1.00; stock = 8;},
            Product{code = "B1"; name = "Chips"; price = 1.50; stock = 0;},
            Product{code = "B2"; name = "Candy"; price = 0.75; stock = 12;}
        );

        port dispenseCtrl : DispenseControlPort;
        port inventoryQuery : InventoryQueryPort;

        action def CheckStock {
            in code : ProductCode;
            out available : Boolean;
            out price : CurrencyValue;
            out stock : Quantity;
        }

        action def ReleaseProduct {
            in code : ProductCode;
            out product : Product;
            out result : DispenseResult;
        }

        action def Restock {
            in code : ProductCode;
            in quantity : Quantity;
        }

        state def DispenserBehavior {
            state Ready;
            state Querying {
                do CheckStock;
            }
            state Dispensing {
                do ReleaseProduct;
            }
            state DispenseFailed;
            transition query_requested
                source Ready
                target Querying
                when inventoryQuery.queryCode->notEmpty();
            transition query_complete
                source Querying
                target Ready;
            transition dispense_requested
                source Ready
                target Dispensing
                when dispenseCtrl.requestCode->notEmpty();
            transition dispense_complete
                source Dispensing
                target Ready;
            transition dispense_failed
                source Dispensing
                target DispenseFailed;
            transition failed_reset
                source DispenseFailed
                target Ready;
        }

        behavior dispenserStateMachine : DispenserBehavior;

        // Handle inventory queries
        action handleInventoryQuery {
            when inventoryQuery.queryCode->notEmpty();
            then {
                attribute foundProduct : Product := products->select(p | p.code == inventoryQuery.queryCode)->first();
                if foundProduct->notEmpty() {
                    inventoryQuery.available := foundProduct.stock > 0;
                    inventoryQuery.price := foundProduct.price;
                    inventoryQuery.stock := foundProduct.stock;
                } else {
                    inventoryQuery.available := false;
                    inventoryQuery.price := 0.0;
                    inventoryQuery.stock := 0;
                }
            }
        }

        // Handle dispense requests
        action handleDispense {
            when dispenseCtrl.requestCode->notEmpty();
            then {
                attribute targetProduct : Product := products->select(p | p.code == dispenseCtrl.requestCode)->first();
                if targetProduct->notEmpty() and targetProduct.stock > 0 {
                    targetProduct.stock := targetProduct.stock - 1;
                    dispenseCtrl.dispensedProduct := targetProduct;
                    dispenseCtrl.result := DispenseResult::success;
                } else {
                    dispenseCtrl.dispensedProduct := null;
                    dispenseCtrl.result := DispenseResult::outOfStock;
                }
            }
        }
    }

    // ---- Control Module ----
    part def ControlModule {
        attribute currentCredit : CurrencyValue := 0.0 [USD];
        attribute selectedCode : ProductCode;
        attribute selectedPrice : CurrencyValue;
        attribute selectedStock : Quantity;

        port creditQueryIn : CreditQueryPort;
        port creditCmdOut : CreditCommandPort;
        port selectionIn : SelectionPort;
        port displayOut : DisplayPort;
        port dispenseCtrlOut : DispenseControlPort;
        port inventoryQueryOut : InventoryQueryPort;

        action def ValidateTransaction {
            in credit : CurrencyValue;
            in price : CurrencyValue;
            in stock : Quantity;
            out sufficientFunds : Boolean;
            out inStock : Boolean;
        }

        action def CompleteTransaction {
            // Deduct price, dispense product, return change
        }

        action def CancelTransaction {
            // Refund full credit
        }

        action def WaitForMoreCoins {
            // Display message, wait
        }

        state def ControlModuleBehavior {
            entry;
            state Idle {
                entry;
                // Reset transaction state
            }
            state TrackingCredit {
                // Monitor credit from coin acceptor
            }
            state Validating {
                do ValidateTransaction;
            }
            state Dispensing {
                do CompleteTransaction;
            }
            state WaitingForCoins {
                do WaitForMoreCoins;
            }
            state Cancelling {
                do CancelTransaction;
            }
            state Complete;

            transition idle_to_tracking
                source Idle
                target TrackingCredit
                when creditQueryIn.currentCredit > 0.0;
            transition tracking_to_validating
                source TrackingCredit
                target Validating
                when selectionIn.selectedCode->notEmpty();
            transition validating_to_dispensing
                source Validating
                target Dispensing
                when (currentCredit >= selectedPrice) and (selectedStock > 0);
            transition validating_to_waiting
                source Validating
                target WaitingForCoins
                when currentCredit < selectedPrice and selectedStock > 0;
            transition validating_to_cancelling
                source Validating
                target Cancelling
                when selectedStock == 0;
            transition waiting_to_validating
                source WaitingForCoins
                target Validating
                when creditQueryIn.currentCredit >= selectedPrice;
            transition waiting_to_cancelling
                source WaitingForCoins
                target Cancelling
                when selectionIn.selectedCode->isEmpty() and creditQueryIn.currentCredit == 0.0;
            transition dispensing_to_complete
                source Dispensing
                target Complete;
            transition cancelling_to_complete
                source Cancelling
                target Complete;
            transition complete_to_idle
                source Complete
                target Idle;
        }

        behavior controlStateMachine : ControlModuleBehavior;

        // Validation logic
        action performValidation {
            when controlStateMachine.activeState == ControlModuleBehavior::Validating;
            then {
                // Query inventory
                inventoryQueryOut.queryCode := selectionIn.selectedCode;
                // Wait for response
                if inventoryQueryOut.available {
                    selectedPrice := inventoryQueryOut.price;
                    selectedStock := inventoryQueryOut.stock;
                    // Query credit
                    currentCredit := creditQueryIn.currentCredit;
                } else {
                    selectedStock := 0;
                }
            }
        }

        // Complete transaction: dispense product, deduct price, return change
        action performCompleteTransaction {
            when controlStateMachine.activeState == ControlModuleBehavior::Dispensing;
            then {
                dispenseCtrlOut.requestCode := selectionIn.selectedCode;
                if dispenseCtrlOut.result == DispenseResult::success {
                    creditCmdOut.deductAmount := selectedPrice;
                    attribute change : CurrencyValue := currentCredit - selectedPrice;
                    if change > 0.0 {
                        // Trigger coin acceptor to dispense change
                    }
                    displayOut.message := "Product dispensed. Thank you!";
                } else {
                    displayOut.message := "Dispense failed.";
                }
            }
        }

        // Cancel transaction: full refund
        action performCancellation {
            when controlStateMachine.activeState == ControlModuleBehavior::Cancelling;
            then {
                creditCmdOut.resetCredit := true;
                displayOut.message := "Transaction cancelled. Full refund issued.";
            }
        }
    }

    // ---- Vending Machine (top-level assembly) ----
    part def VendingMachine {
        attribute machineId : String;
        attribute location : String;

        part coinAcceptor : CoinAcceptor {
            attribute accumulatedCredit : CurrencyValue := 0.0 [USD];
        }
        part selectionPanel : SelectionPanel;
        part dispensingMechanism : DispensingMechanism;
        part controlModule : ControlModule;

        // External user-facing ports
        port userCoinSlot : CoinInsertionPort;
        port userCoinReturn : CoinReturnPort;
        port userKeypad : SelectionPort;
        port userDisplay : DisplayPort;
        port productDelivery : DispenseControlPort;

        // Internal connections
        connection def CoinToControlConnection {
            end source : CoinInsertionPort;
            end target : CreditQueryPort;
        }

        connection coinAcceptor_to_control_credit : CoinToControlConnection connect
            coinAcceptor.creditQuery to controlModule.creditQueryIn;

        connection def ControlToCoinConnection {
            end source : CreditCommandPort;
            end target : CreditCommandPort;
        }

        connection control_to_coinAcceptor_cmd : ControlToCoinConnection connect
            controlModule.creditCmdOut to coinAcceptor.creditCmd;

        connection def SelectionToControlConnection {
            end source : SelectionPort;
            end target : SelectionPort;
        }

        connection selectionPanel_to_control : SelectionToControlConnection connect
            selectionPanel.selection to controlModule.selectionIn;

        connection def ControlToDisplayConnection {
            end source : DisplayPort;
            end target : DisplayPort;
        }

        connection control_to_display : ControlToDisplayConnection connect
            controlModule.displayOut to selectionPanel.display;

        connection def ControlToDispenserConnection {
            end source : DispenseControlPort;
            end target : DispenseControlPort;
        }

        connection control_to_dispenser_ctrl : ControlToDispenserConnection connect
            controlModule.dispenseCtrlOut to dispensingMechanism.dispenseCtrl;

        connection def ControlToInventoryConnection {
            end source : InventoryQueryPort;
            end target : InventoryQueryPort;
        }

        connection control_to_dispenser_query : ControlToInventoryConnection connect
            controlModule.inventoryQueryOut to dispensingMechanism.inventoryQuery;

        // External port bindings
        binding userCoinSlot.insertedCoin = coinAcceptor.coinIn.insertedCoin;
        binding userCoinReturn.returnedCoin = coinAcceptor.coinOut.returnedCoin;
        binding userKeypad.selectedCode = selectionPanel.selection.selectedCode;
        binding userDisplay.message = selectionPanel.display.message;
        binding productDelivery.dispensedProduct = dispensingMechanism.dispenseCtrl.dispensedProduct;
    }

    // ---- Requirements ----
    requirement def VendingMachineRequirements {

        requirement SelfContainedOperation {
            doc "The vending machine shall operate as a self-contained unit managing the entire sales process without a human cashier."
        }

        requirement CoinAcceptanceAndValidation {
            doc "The Coin Acceptor shall accept and validate coins inserted by a user and accumulate the total credit."
            subject coinAcceptor : CoinAcceptor;
        }

        requirement ChangeDispensing {
            doc "The Coin Acceptor shall dispense the correct change after a purchase."
            subject coinAcceptor : CoinAcceptor;
        }

        requirement FullRefundOnCancel {
            doc "The Coin Acceptor shall provide a full refund if a transaction is cancelled."
            subject coinAcceptor : CoinAcceptor;
        }

        requirement ProductSelection {
            doc "The Selection Panel shall allow a customer to choose a product by entering its specific code."
            subject selectionPanel : SelectionPanel;
        }

        requirement InventoryManagement {
            doc "The Dispensing Mechanism shall manage the product inventory and physically release the selected item to the customer."
            subject dispensingMechanism : DispensingMechanism;
        }

        requirement CentralCoordination {
            doc "The Control Module shall coordinate the Coin Acceptor, Selection Panel, and Dispensing Mechanism to ensure a smooth transaction."
            subject controlModule : ControlModule;
        }

        requirement TransactionValidation {
            doc "The Control Module shall validate a transaction by checking that accumulated credit is sufficient for the item price and that the item is in stock."
            subject controlModule : ControlModule;
        }

        requirement InsufficientFundsHandling {
            doc "If the customer has not inserted enough money, the machine shall wait for more coins."
            subject vendingMachine : VendingMachine;
        }

        requirement OutOfStockHandling {
            doc "If the selected product is out of stock, the transaction shall be cancelled and the system shall refund the full amount inserted."
            subject vendingMachine : VendingMachine;
        }

        requirement SuccessfulDispense {
            doc "If credit is sufficient and the item is in stock, the dispenser shall release the product and the coin acceptor shall return any leftover change."
            subject vendingMachine : VendingMachine;
        }

        requirement TransactionCompleteness {
            doc "Every transaction shall be complete: the customer either receives their product and correct change, or they get all their money back."
            subject vendingMachine : VendingMachine;
        }

        requirement IdleInitialState {
            doc "The machine shall begin in an idle state and transition to tracking credit when a customer inserts coins."
            subject controlModule : ControlModule;
        }
    }

    // ---- Verification ----
    verification def VendingMachineVerification {
        subject vendingMachine : VendingMachine;

        objective {
            doc "Verify that the vending machine satisfies all functional requirements."
        }

        action def TestSuccessfulPurchase {
            in productCode : ProductCode;
            in insertedAmount : CurrencyValue;
            out result : Boolean;
        }

        action def TestInsufficientFunds {
            in productCode : ProductCode;
            in insertedAmount : CurrencyValue;
            out result : Boolean;
        }

        action def TestOutOfStockRefund {
            in productCode : ProductCode;
            in insertedAmount : CurrencyValue;
            out result : Boolean;
        }

        action def TestChangeCalculation {
            in productPrice : CurrencyValue;
            in insertedAmount : CurrencyValue;
            out expectedChange : CurrencyValue;
            out result : Boolean;
        }

        action runTests {
            // Execute all test cases
            then TestSuccessfulPurchase{productCode = "A1"; insertedAmount = 1.50;};
            then TestInsufficientFunds{productCode = "A1"; insertedAmount = 1.00;};
            then TestOutOfStockRefund{productCode = "B1"; insertedAmount = 2.00;};
            then TestChangeCalculation{productPrice = 1.25; insertedAmount = 1.50;};
        }
    }

    // ---- Instantiation ----
    part vendingMachineInstance : VendingMachine {
        attribute machineId := "VM-001";
        attribute location := "Building A - Floor 1";

        // Initialize product inventory
        part dispensingMechanism {
            attribute products := (
                Product{code = "A1"; name = "Cola"; price = 1.25; stock = 15;},
                Product{code = "A2"; name = "Water"; price = 1.00; stock = 10;},
                Product{code = "B1"; name = "Chips"; price = 1.50; stock = 7;},
                Product{code = "B2"; name = "Candy Bar"; price = 0.75; stock = 20;},
                Product{code = "C1"; name = "Gum"; price = 0.50; stock = 25;}
            );
        }

        // Initialize coin inventory for change
        part coinAcceptor {
            attribute coinInventory := (
                CoinType::nickel, CoinType::nickel, CoinType::nickel,
                CoinType::dime, CoinType::dime, CoinType::dime,
                CoinType::quarter, CoinType::quarter, CoinType::quarter,
                CoinType::dollar, CoinType::dollar
            );
        }
    }

    // ---- Requirement satisfaction ----
    satisfaction satisfySelfContained : VendingMachineRequirements::SelfContainedOperation {
        subject vendingMachineInstance;
    }

    satisfaction satisfyCoinAcceptance : VendingMachineRequirements::CoinAcceptanceAndValidation {
        subject vendingMachineInstance.coinAcceptor;
    }

    satisfaction satisfyChangeDispensing : VendingMachineRequirements::ChangeDispensing {
        subject vendingMachineInstance.coinAcceptor;
    }

    satisfaction satisfyFullRefund : VendingMachineRequirements::FullRefundOnCancel {
        subject vendingMachineInstance.coinAcceptor;
    }

    satisfaction satisfyProductSelection : VendingMachineRequirements::ProductSelection {
        subject vendingMachineInstance.selectionPanel;
    }

    satisfaction satisfyInventory : VendingMachineRequirements::InventoryManagement {
        subject vendingMachineInstance.dispensingMechanism;
    }

    satisfaction satisfyCoordination : VendingMachineRequirements::CentralCoordination {
        subject vendingMachineInstance.controlModule;
    }

    satisfaction satisfyValidation : VendingMachineRequirements::TransactionValidation {
        subject vendingMachineInstance.controlModule;
    }

    satisfaction satisfyInsufficientFunds : VendingMachineRequirements::InsufficientFundsHandling {
        subject vendingMachineInstance;
    }

    satisfaction satisfyOutOfStock : VendingMachineRequirements::OutOfStockHandling {
        subject vendingMachineInstance;
    }

    satisfaction satisfySuccessfulDispense : VendingMachineRequirements::SuccessfulDispense {
        subject vendingMachineInstance;
    }

    satisfaction satisfyCompleteness : VendingMachineRequirements::TransactionCompleteness {
        subject vendingMachineInstance;
    }

    satisfaction satisfyIdleState : VendingMachineRequirements::IdleInitialState {
        subject vendingMachineInstance.controlModule;
    }

}
