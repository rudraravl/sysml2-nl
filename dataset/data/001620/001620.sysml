package VendingMachineSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	
	attribute def Currency;
	attribute def ProductCode :> String;
	
	attribute def Money :> Real;
	attribute def Quantity :> Integer;
	
	item def Coin {
		attribute denomination : Money;
	}
	
	item def Product {
		attribute code : ProductCode;
		attribute name : String;
		attribute price : Money;
	}
	
	item def Change {
		attribute amount : Money;
	}
	
	item def Selection {
		attribute productCode : ProductCode;
	}
	
	port def PaymentInputPort {
		in item coinInserted : Coin;
		out item changeReturned : Change;
		attribute currentCredit : Money;
	}
	
	port def SelectionInputPort {
		in item userSelection : Selection;
	}
	
	port def ProductOutputPort {
		out item dispensedProduct : Product;
	}
	
	port def InventoryPort {
		attribute stockLevel : Quantity;
		in item stockQuery : ProductCode;
		out item stockStatus : Boolean;
	}
	
	part def CoinAcceptor {
		port paymentPort : PaymentInputPort;
		attribute accumulatedCredit : Money;
		
		action def AcceptCoin {
			in coin : Coin;
			out updatedCredit : Money;
		}
		
		action def DispenseChange {
			in changeAmount : Money;
			out change : Change;
		}
	}
	
	part def SelectionPanel {
		port selectionPort : SelectionInputPort;
		
		action def CaptureSelection {
			in userInput : ProductCode;
			out selection : Selection;
		}
	}
	
	part def DispensingMechanism {
		port productPort : ProductOutputPort;
		port inventoryPort : InventoryPort;
		
		action def ReleaseProduct {
			in productCode : ProductCode;
			out product : Product;
		}
		
		action def VerifyStock {
			in productCode : ProductCode;
			out available : Boolean;
		}
	}
	
	part def ControlModule {
		attribute transactionCredit : Money;
		attribute selectedProductCode : ProductCode;
		attribute selectedProductPrice : Money;
		
		action def ValidateTransaction {
			in credit : Money;
			in price : Money;
			out isValid : Boolean;
		}
		
		action def CalculateChange {
			in credit : Money;
			in price : Money;
			out changeAmount : Money;
		}
	}
	
	part def VendingMachine {
		part coinAcceptor : CoinAcceptor;
		part selectionPanel : SelectionPanel;
		part dispenser : DispensingMechanism;
		part controller : ControlModule;
		
		connect coinAcceptor.paymentPort to controller;
		connect selectionPanel.selectionPort to controller;
		connect controller to dispenser.productPort;
		
		perform action vendingCycle[*] ordered references VendingOperation;
	}
	
	action def AcceptPayment {
		in coin : Coin;
		out totalCredit : Money;
	}
	
	action def GetProductSelection {
		in userChoice : ProductCode;
		out selectedProduct : Product;
	}
	
	action def CheckSufficientFunds {
		in availableCredit : Money;
		in requiredPrice : Money;
		out fundsSufficient : Boolean;
	}
	
	action def VerifyInventory {
		in requestedProduct : ProductCode;
		out inStock : Boolean;
	}
	
	action def DispenseProduct {
		in product : Product;
	}
	
	action def ReturnChange {
		in changeAmount : Money;
		out change : Change;
	}
	
	action VendingOperation {
		first start;
		then merge awaitPayment;
		
		action collectPayment : AcceptPayment {
			out credit : Money;
		}
		then awaitPayment;
		
		action captureSelection : GetProductSelection {
			in userChoice : ProductCode;
			out product : Product;
		}
		then action checkFunds : CheckSufficientFunds {
			in availableCredit = collectPayment.credit;
			in requiredPrice = captureSelection.product.price;
			out fundsSufficient : Boolean;
		}
		
		then decide;
			if checkFunds.fundsSufficient then verifyStock;
			if not checkFunds.fundsSufficient then insufficientPayment;
		
		action verifyStock : VerifyInventory {
			in requestedProduct = captureSelection.product.code;
			out inStock : Boolean;
		}
		then decide;
			if verifyStock.inStock then dispense;
			if not verifyStock.inStock then outOfStock;
		
		action dispense : DispenseProduct {
			in product = captureSelection.product;
		}
		then action returnChangeAction : ReturnChange {
			in changeAmount = collectPayment.credit - captureSelection.product.price;
			out change : Change;
		}
		then done;
		
		action insufficientPayment {
			then awaitPayment;
		}
		
		action outOfStock {
			then action returnRefund : ReturnChange {
				in changeAmount = collectPayment.credit;
				out change : Change;
			}
			then done;
		}
	}
	
	state def VendingMachineStates {
		entry; then idle;
		
		state idle {
			entry assign transactionCredit = 0.0;
		}
		accept at idle
			if CoinInsertedEvent
			then acceptingPayment;
		
		state acceptingPayment {
			do action accumulateCredit;
		}
		accept at acceptingPayment
			if SelectionMadeEvent
			then validating;
		accept at acceptingPayment
			if AdditionalCoinEvent
			then acceptingPayment;
		
		state validating {
			do action validateFunds;
			do action checkInventory;
		}
		accept at validating
			if ValidationSuccessEvent
			then dispensing;
		accept at validating
			if InsufficientFundsEvent
			then acceptingPayment;
		accept at validating
			if OutOfStockEvent
			then refunding;
		
		state dispensing {
			do action activateDispenser;
		}
		accept at dispensing
			if ProductDispensedEvent
			then returningChange;
		
		state returningChange {
			do action releaseChange;
		}
		accept at returningChange
			if ChangeReturnedEvent
			then idle;
		
		state refunding {
			do action returnFullAmount;
		}
		accept at refunding
			if RefundCompleteEvent
			then idle;
	}
	
	part vendingMachine : VendingMachine {
		part coinAcceptor : CoinAcceptor {
			perform VendingOperation.collectPayment;
			perform VendingOperation.returnChangeAction;
		}
		
		part selectionPanel : SelectionPanel {
			perform VendingOperation.captureSelection;
		}
		
		part dispenser : DispensingMechanism {
			perform VendingOperation.verifyStock;
			perform VendingOperation.dispense;
		}
		
		part controller : ControlModule {
			perform VendingOperation.checkFunds;
		}
	}
	
	requirement <'VM-REQ-001'> primaryVendingFunction {
		doc /* The vending machine shall accept payment in the form of coins, 
		       allow the user to select a product, verify sufficient funds and 
		       product availability, dispense the selected product, and return 
		       correct change to complete the transaction. */
		
		subject vendingMachine;
		
		require constraint paymentAcceptance {
			doc /* The system shall accept coins and accumulate credit until 
			       a product selection is made. */
		}
		
		require constraint selectionValidation {
			doc /* The system shall validate that accumulated credit meets or 
			       exceeds the price of the selected product before dispensing. */
		}
		
		require constraint inventoryVerification {
			doc /* The system shall verify product availability in inventory 
			       before attempting to dispense. */
		}
		
		require constraint productDispensing {
			doc /* The system shall dispense exactly one unit of the selected 
			       product when payment and inventory conditions are satisfied. */
		}
		
		require constraint changeReturn {
			doc /* The system shall calculate and return change equal to the 
			       difference between accumulated credit and product price. */
		}
	}
	
	requirement <'VM-REQ-002'> transactionAtomicity {
		doc /* The vending machine shall ensure that each transaction is atomic: 
		       either the product is dispensed with correct change returned, or 
		       the full payment is refunded without dispensing. */
		
		subject VendingOperation;
		
		require constraint completeOrRevert {
			doc /* No partial transaction states shall persist beyond a single 
			       vending cycle. */
		}
	}
	
	requirement <'VM-REQ-003'> inventoryManagement {
		doc /* The vending machine shall maintain accurate inventory counts and 
		       prevent dispensing when a product is out of stock. */
		
		subject vendingMachine.dispenser;
		
		require constraint accurateStockTracking {
			doc /* Each product slot shall maintain a current quantity count. */
		}
		
		require constraint stockDepletionHandling {
			doc /* When a product quantity reaches zero, the system shall reject 
			       selection attempts and refund payment. */
		}
	}
}
