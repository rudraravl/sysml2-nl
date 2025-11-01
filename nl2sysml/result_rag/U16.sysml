// Model a vending machine that is able to dispose items.
package VendingMachineSystem {
	private import ScalarValues::*;

	package DataTypes {
		unit Currency;
		value def Money {
			attribute amount : Real;
			attribute currency : Currency;
		}
		item def SelectionCode {
			attribute code : String;
		}
		abstract item def VendedItem {
			attribute price : Money;
		}
		item def Snack :> VendedItem;
		item def Drink :> VendedItem;
		enum MachineStatus {
			idle,
			awaitingPayment,
			dispensing,
			outOfStock,
			serviceRequired
		}
	}

	package InterfaceDefs {
		private import DataTypes::*;
		port def UserInteractionPort {
			out item selection : SelectionCode;
			in status : MachineStatus;
		}
		port def PaymentPort {
			in item payment : Money;
			out paymentAccepted : Boolean;
		}
		port def DispenserControlPort {
			in command : SelectionCode;
			out itemDispensed : Boolean;
		}
		port def ItemSourcePort {
			out item vendedItem : VendedItem;
		}
		port def ItemCollectionPort {
			in item vendedItem : VendedItem;
		}
	}

	package ComponentDefs {
		private import DataTypes::*;
		private import InterfaceDefs::*;

		part def UserInterface {
			port interaction : UserInteractionPort;
			attribute displayMessage : String;
			action updateDisplay(in message: String) {
				rep language "alf" /*
				    this.displayMessage = message;
				*/
			}
		}

		part def PaymentAcceptor {
			port payment : ~PaymentPort;
			attribute totalCredit : Money;
		}

		part def ItemStorage {
			port itemSource : ItemSourcePort;
			item stock : VendedItem[50];
		}

		part def ItemDispenser {
			port control : ~DispenserControlPort;
			port itemIn : ~ItemSourcePort;
			port itemOut : ItemCollectionPort;
			action dispense(in code: SelectionCode) {
				// Action to physically move the item
			}
		}

		part def ControlUnit {
			port ui : ~UserInteractionPort;
			port pa : PaymentPort;
			port dc : DispenserControlPort;
			state VendingLogic {
				initial state Idle;
				state AwaitingPayment;
				state Dispensing;
				state OutOfStock;
				transition from Idle to AwaitingPayment
					when ui.selection;
				transition from AwaitingPayment to Dispensing
					when pa.paymentAccepted;
				transition from Dispensing to Idle
					when dc.itemDispensed;
				transition from AwaitingPayment to Idle;
				transition from Idle to OutOfStock;
			}
		}

		part def VendingMachine {
			part ui : UserInterface;
			part pa : PaymentAcceptor;
			part cu : ControlUnit;
			part storage : ItemStorage;
			part dispenser : ItemDispenser;

			port customerInput : UserInteractionPort;
			port paymentSlot : ~PaymentPort;
			port collectionBin : ItemCollectionPort;

			connect ui.interaction to cu.ui;
			connect pa.payment to cu.pa;
			connect cu.dc to dispenser.control;
			connect storage.itemSource to dispenser.itemIn;

			bind self.customerInput to self.ui.interaction;
			bind self.paymentSlot to self.pa.payment;
			bind self.collectionBin to self.dispenser.itemOut;

			action VendItem(in selection: SelectionCode, in payment: Money, out item: VendedItem, out change: Money) {
				action receiveSelection {
					in sel : SelectionCode;
					out status : MachineStatus;
				}
				action processPayment {
					in pay : Money;
					in sel : SelectionCode;
					out paymentOK : Boolean;
				}
				action triggerDispense {
					in sel : SelectionCode;
					out dispensedItem : VendedItem;
				}
				action calculateChange {
					in paidAmount : Money;
					in itemPrice : Money;
					out changeDue : Money;
				}

				bind receiveSelection.sel = selection;
				bind processPayment.pay = payment;
				bind processPayment.sel = selection;
				bind triggerDispense.sel = selection;
				bind calculateChange.paidAmount = payment;
				bind calculateChange.itemPrice = triggerDispense.dispensedItem.price;
				bind self.item = triggerDispense.dispensedItem;
				bind self.change = calculateChange.changeDue;

				first receiveSelection then processPayment;
				succession flow processPayment.paymentOK to triggerDispense;
				first triggerDispense then calculateChange;
			}
		}
	}

	package Requirements {
		private import ComponentDefs::VendingMachine;
		requirement CorrectItemDispensing {
			id = "VM-REQ-01";
			text = "The vending machine shall dispense the item corresponding to the user's valid selection after successful payment.";
		}
		requirement AccuratePaymentHandling {
			id = "VM-REQ-02";
			text = "The vending machine shall accept valid payment and return the correct change if the amount paid exceeds the item price.";
		}
		requirement StockStatusUpdate {
			id = "VM-REQ-03";
			text = "The machine shall indicate via the user interface when a selected item is out of stock.";
		}
		satisfy VendingMachine::VendItem by CorrectItemDispensing;
		satisfy VendingMachine::VendItem::processPayment by AccuratePaymentHandling;
		satisfy VendingMachine::VendItem::calculateChange by AccuratePaymentHandling;
		satisfy VendingMachine::cu::VendingLogic::OutOfStock by StockStatusUpdate;
	}
}
