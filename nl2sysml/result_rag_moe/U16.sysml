// Model a vending machine that is able to dispose items.
package VendingMachineSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Types {
        attribute def ProductCode : String;
        attribute def Currency : String;

        item def Money {
            attribute amount : Real;
            attribute currency : Currency;
        }

        abstract item def Product {
            attribute code : ProductCode;
            attribute price : Real;
        }

        item def Beverage :> Product {
            attribute volume : VolumeValue;
        }

        item def Snack :> Product {
            attribute expirationDate : String;
        }

        item def Waste {
            attribute mass : MassValue;
        }
    }

    package Interfaces {
        private import Types::*;

        port def PaymentPort {
            in item payment : Money;
            out item change : Money;
        }

        port def ProductDispensePort {
            out item product : Product;
        }

        port def WasteDisposalPort {
            in item waste : Waste;
        }

        port def UserInterfacePort {
            in value selection : ProductCode;
            out value statusMessage : String;
        }
    }

    package Components {
        private import Types::*;
        private import Interfaces::*;

        part def PaymentProcessor {
            port paymentIO : PaymentPort;
            attribute credit : Real = 0.0;
            
            action processPayment(in requiredAmount : Real, in payment : Money) {
                out change : Money;
                out isSufficient : Boolean;
            }
        }

        part def Dispenser {
            port productOut : ProductDispensePort;
            action dispense(in product : Product);
        }

        part def Inventory {
            item stock : Product[50];
            action findProduct(in code : ProductCode) {
                out product : Product;
                out isAvailable : Boolean;
            }
        }

        part def WasteCompactor {
            port wasteIn : WasteDisposalPort;
            attribute capacity : MassValue;
            attribute currentFill : MassValue = 0[kg];
            
            action compactWaste(in newWaste : Waste) {
                out isFull : Boolean;
            }
        }

        part def Controller {
            port ui : UserInterfacePort;
            port payment : ~PaymentPort;
            port dispenserCmd;
            port inventoryCheck;
            port compactorCmd;

            exhibit state machine ControllerLogic;
        }
    }

    package Behavior {
        private import Types::*;
        private import Components::*;

        action def FullVendingCycle {
            in selection : ProductCode;
            in payment : Money;
            in waste : Waste;
            out product : Product;
            out change : Money;
            out status : String;

            action checkStock : Inventory::findProduct;
            action processPay : PaymentProcessor::processPayment;
            action doDispense : Dispenser::dispense;
            action handleWaste : WasteCompactor::compactWaste;

            bind checkStock.code = selection;
            bind processPay.payment = payment;
            bind doDispense.product = checkStock.product;
            bind handleWaste.newWaste = waste;

            succession flow checkStock.product to processPay.requiredAmount {
                rep language "kerml" /* processPay.requiredAmount = checkStock.product.price; */
            }
            succession checkStock then processPay;
            succession processPay then doDispense;
            succession doDispense then handleWaste;
        }

        state machine ControllerLogic {
            initial state Idle;
            state AwaitingPayment;
            state Dispensing;
            state AwaitingWaste;
            state Compacting;

            transition from Idle to AwaitingPayment 
                on receive(ui.selection) {
                guard { rep language "kerml" /* Inventory.findProduct(selection).isAvailable */ }
                action { 
                    send ui.statusMessage = "Please insert payment.";
                }
            }

            transition from AwaitingPayment to Dispensing
                on receive(payment.payment) {
                guard { rep language "kerml" /* PaymentProcessor.processPayment(payment).isSufficient */ }
                action {
                    send ui.statusMessage = "Dispensing item...";
                    send dispenserCmd;
                }
            }

            transition from Dispensing to AwaitingWaste {
                action {
                    send ui.statusMessage = "Please dispose of any waste.";
                }
            }

            transition from AwaitingWaste to Compacting
                on receive(compactorCmd) {
                action {
                    send ui.statusMessage = "Thank you. Compacting waste.";
                }
            }

            transition from Compacting to Idle;
            transition from AwaitingWaste to Idle; // Timeout or no waste
            transition from AwaitingPayment to Idle; // Timeout or cancel
        }
    }

    package Assembly {
        private import Types::*;
        private import Interfaces::*;
        private import Components::*;
        private import Behavior::*;

        part def VendingMachine {
            port customerPayment : PaymentPort;
            port productOutput : ProductDispensePort;
            port wasteInput : WasteDisposalPort;
            port customerInterface : UserInterfacePort;

            part controller : Controller;
            part paymentSystem : PaymentProcessor;
            part dispenser : Dispenser;
            part inventory : Inventory;
            part compactor : WasteCompactor;

            connect customerInterface to controller.ui;
            connect customerPayment to paymentSystem.paymentIO;
            connect dispenser.productOut to productOutput;
            connect wasteInput to compactor.wasteIn;

            // Internal control and data flows would be modeled here
            // For brevity, these are implied by the Controller's state machine logic
        }
    }

    package Requirements {
        private import Assembly::*;
        private import Components::*;

        requirement def R_DispenseProduct {
            doc "The vending machine shall dispense the correct product upon receipt of sufficient payment.";
            subject vm : VendingMachine;
            require vm.dispenser.dispense;
        }

        requirement def R_AcceptWaste {
            doc "The vending machine shall provide a means for users to dispose of waste, such as product packaging.";
            subject vm : VendingMachine;
            require vm.compactor.compactWaste;
        }

        requirement def R_WasteCapacity {
            doc "The waste compactor shall have a minimum capacity of 5 kilograms.";
            subject wc : WasteCompactor;
            constraint { wc.capacity >= 5[kg] }
        }
    }
}
