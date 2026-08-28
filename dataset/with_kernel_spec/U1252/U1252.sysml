package VendingMachineSystem {
	private import ScalarValues::String;
	private import ScalarValues::Boolean;
	private import ScalarValues::Real;
	private import ScalarValues::Integer;

	unit USD;
	value type Money :> Real { unit = USD; }
	item def Coin {
		attribute value : Money;
	}
	item def Product {
		attribute code : String;
		attribute price : Money;
	}
	attribute def ProductCode :> String;

	occurrence def CoinInserted;
	occurrence def SelectionMade {
		attribute code : ProductCode;
	}

	port def CoinInputPort { in coin : Coin; }
	port def CreditPort { out credit : Money; }
	port def ChangePort { in change : Money; }
	port def RefundPort { in refund : Boolean; }
	port def KeypadPort { out code : ProductCode; }
	port def DispensePort { in command : Boolean; }
	port def StockPort { out stock : Boolean; in code : ProductCode; }

	part def CoinAcceptor {
		port coinInput : CoinInputPort;
		port creditOut : CreditPort;
		port changeIn : ChangePort;
		port refundIn : RefundPort;
		attribute totalCredit : Money = 0 [USD];
	}
	part def SelectionPanel {
		port keypadOut : KeypadPort;
	}
	part def DispensingMechanism {
		port dispenseIn : DispensePort;
		port stockOut : StockPort;
		attribute inventory : Integer = 10;
	}

	part def ControlModule {
		port creditIn : CreditPort;
		port keypadIn : KeypadPort;
		port dispenseOut : DispensePort;
		port stockIn : StockPort;
		port changeOut : ChangePort;
		port refundOut : RefundPort;

		attribute currentCredit : Money = 0 [USD];
		attribute selectedCode : ProductCode;
		attribute productPrice : Money = 1.5 [USD];
		attribute inStock : Boolean;

		state def VendingStates;
		state vendingControl : VendingStates {
			entry; then idle;
			state idle;
			accept CoinInserted
				do currentCredit = currentCredit + 1.0 [USD]
				then acceptingCoins;
			state acceptingCoins;
			accept s : SelectionMade
				do selectedCode = s.code
				then validating;
			state validating;
			decide;
				if currentCredit >= productPrice and inStock then dispensing;
				else if not inStock then refunding;
				else then acceptingCoins;
			state dispensing {
				do currentCredit = currentCredit - productPrice;
			}
			then idle;
			state refunding {
				do currentCredit = 0 [USD];
			}
			then idle;
		}
	}

	part def VendingMachine {
		part controlModule : ControlModule;
		part coinAcceptor : CoinAcceptor;
		part selectionPanel : SelectionPanel;
		part dispensingMechanism : DispensingMechanism;

		interface creditInterface connect coinAcceptor.creditOut to controlModule.creditIn;
		interface selectionInterface connect selectionPanel.keypadOut to controlModule.keypadIn;
		interface dispenseInterface connect controlModule.dispenseOut to dispensingMechanism.dispenseIn;
		interface stockInterface connect dispensingMechanism.stockOut to controlModule.stockIn;
		interface changeInterface connect controlModule.changeOut to coinAcceptor.changeIn;
		interface refundInterface connect controlModule.refundOut to coinAcceptor.refundIn;
	}

	requirement def VendingMachineRequirements {
		text "The vending machine shall manage the entire sales process from payment to dispensing without human intervention.";
		requirement sufficientCredit {
			text "If accumulated credit is less than the item price, the machine shall wait for additional coins.";
		}
		requirement stockValidation {
			text "If the selected product is out of stock, the transaction shall be cancelled and a full refund issued.";
		}
		requirement completeTransaction {
			text "Every transaction shall result in either product dispensing with correct change or a full refund.";
		}
	}
}
