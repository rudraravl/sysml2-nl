package 'Automated Retail System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ProductID;
	attribute def TransactionID;
	attribute def StockLevel;
	
	attribute def CurrencyValue :> Real;
	
	enumeration def PaymentMethod {
		creditCard;
		debitCard;
		cash;
		mobilePayment;
	}
	
	enumeration def TransactionStatus {
		pending;
		approved;
		declined;
		refunded;
	}
	
	enumeration def DispenseResult {
		success;
		jammed;
		outOfStock;
		mechanicalFailure;
	}
	
	item def Product {
		attribute id : ProductID;
		attribute name : String;
		attribute price : CurrencyValue;
		attribute weight : MassValue;
		attribute stockQuantity : StockLevel;
	}
	
	item def PaymentInfo {
		attribute method : PaymentMethod;
		attribute amount : CurrencyValue;
		attribute token : String;
	}
	
	item def PaymentConfirmation {
		attribute status : TransactionStatus;
		attribute transactionID : TransactionID;
		attribute authorizedAmount : CurrencyValue;
	}
	
	item def Receipt {
		attribute transactionID : TransactionID;
		attribute productName : String;
		attribute amountPaid : CurrencyValue;
		attribute timestamp : String;
	}
	
	port def CustomerInterfacePort {
		in productSelection : ProductID;
		in paymentData : PaymentInfo;
		out displayMessage : String;
		out dispensedProduct : Product;
		out receipt : Receipt;
	}
	
	port def InventoryPort {
		in stockQuery : ProductID;
		out stockStatus : StockLevel;
		in stockUpdate : ProductID;
	}
	
	port def PaymentGatewayPort {
		out paymentRequest : PaymentInfo;
		in paymentResponse : PaymentConfirmation;
	}
	
	port def MaintenancePort {
		out diagnosticData : String;
		in maintenanceCommand : String;
	}
	
	part def UserInterface {
		port customerPort : CustomerInterfacePort;
		
		action def DisplayProductCatalog {
			in availableProducts : Product[*];
			out catalogRendered : Boolean;
		}
		
		action def AcceptProductSelection {
			out selectedProductID : ProductID;
		}
		
		action def AcceptPayment {
			in productPrice : CurrencyValue;
			out paymentInfo : PaymentInfo;
		}
		
		action def ShowStatusMessage {
			in message : String;
			out messageDisplayed : Boolean;
		}
		
		action def DispenseToCustomer {
			in product : Product;
			out dispensed : Boolean;
		}
		
		action def IssueReceipt {
			in receiptData : Receipt;
			out receiptPrinted : Boolean;
		}
	}
	
	part def InventoryManagementSystem {
		port inventoryPort : InventoryPort;
		attribute productCatalog : Product[*];
		attribute lowStockThreshold : StockLevel;
		
		action def CheckProductAvailability {
			in productID : ProductID;
			out available : Boolean;
			out currentStock : StockLevel;
		}
		
		action def ReserveProduct {
			in productID : ProductID;
			out reserved : Boolean;
		}
		
		action def DecrementStock {
			in productID : ProductID;
			out newStockLevel : StockLevel;
		}
		
		action def CheckRestockNeeded {
			in productID : ProductID;
			out restockRequired : Boolean;
		}
		
		action def GetProductDetails {
			in productID : ProductID;
			out product : Product;
		}
	}
	
	part def PaymentProcessingSystem {
		port paymentPort : PaymentGatewayPort;
		
		action def AuthorizePayment {
			in paymentInfo : PaymentInfo;
			in amount : CurrencyValue;
			out confirmation : PaymentConfirmation;
		}
		
		action def ProcessRefund {
			in transactionID : TransactionID;
			in amount : CurrencyValue;
			out refundConfirmation : PaymentConfirmation;
		}
		
		action def ValidatePaymentMethod {
			in method : PaymentMethod;
			out valid : Boolean;
		}
	}
	
	part def DispensingMechanism {
		attribute motorPosition : LengthValue;
		attribute chuteStatus : String;
		
		action def DispenseProduct {
			in productID : ProductID;
			in productWeight : MassValue;
			out result : DispenseResult;
			out product : Product;
		}
		
		action def VerifyDispense {
			in expectedWeight : MassValue;
			out verified : Boolean;
		}
		
		action def ResetMechanism {
			out resetComplete : Boolean;
		}
		
		action def PerformSelfTest {
			out testResult : Boolean;
		}
	}
	
	part def DiagnosticSystem {
		port maintenancePort : MaintenancePort;
		attribute errorLog : String[*];
		
		action def MonitorSystemHealth {
			out healthStatus : String;
		}
		
		action def LogError {
			in errorMessage : String;
			out logged : Boolean;
		}
		
		action def GenerateDiagnosticReport {
			out report : String;
		}
	}
	
	action def ProcessRetailTransaction {
		in selectedProduct : ProductID;
		in payment : PaymentInfo;
		out transactionSuccess : Boolean;
		out dispensedProduct : Product;
		out receipt : Receipt;
	}
	
	action def HandleTransactionFailure {
		in failureReason : String;
		in transactionID : TransactionID;
		out refundIssued : Boolean;
	}
	
	part def AutomatedRetailMachine {
		part ui : UserInterface;
		part inventory : InventoryManagementSystem;
		part paymentSystem : PaymentProcessingSystem;
		part dispenser : DispensingMechanism;
		part diagnostics : DiagnosticSystem;
		
		port customerInterface : CustomerInterfacePort;
		port inventoryInterface : InventoryPort;
		port paymentGateway : PaymentGatewayPort;
		port maintenance : MaintenancePort;
		
		connect ui.customerPort to customerInterface;
		connect inventory.inventoryPort to inventoryInterface;
		connect paymentSystem.paymentPort to paymentGateway;
		connect diagnostics.maintenancePort to maintenance;
		
		perform action operateRetailMachine {
			first start;
			then merge readyForCustomer;
			
			action displayCatalog : ui.DisplayProductCatalog;
			then readyForCustomer;
			
			action awaitSelection : ui.AcceptProductSelection {
				out selectedID : ProductID;
			}
			then checkAvailability;
			
			action checkAvailability : inventory.CheckProductAvailability {
				in productID = awaitSelection.selectedID;
				out isAvailable : Boolean;
				out stock : StockLevel;
			}
			then decide;
				if checkAvailability.isAvailable then reserveProduct;
				if not checkAvailability.isAvailable then notifyOutOfStock;
			
			action notifyOutOfStock : ui.ShowStatusMessage;
			then readyForCustomer;
			
			action reserveProduct : inventory.ReserveProduct {
				in productID = awaitSelection.selectedID;
			}
			then getProductInfo;
			
			action getProductInfo : inventory.GetProductDetails {
				in productID = awaitSelection.selectedID;
				out productDetails : Product;
			}
			then requestPayment;
			
			action requestPayment : ui.AcceptPayment {
				in productPrice = getProductInfo.productDetails.price;
				out paymentData : PaymentInfo;
			}
			then authorizePayment;
			
			action authorizePayment : paymentSystem.AuthorizePayment {
				in paymentInfo = requestPayment.paymentData;
				in amount = getProductInfo.productDetails.price;
				out paymentConfirm : PaymentConfirmation;
			}
			then decide;
				if authorizePayment.paymentConfirm.status == TransactionStatus::approved then dispenseItem;
				if authorizePayment.paymentConfirm.status == TransactionStatus::declined then notifyPaymentFailed;
			
			action notifyPaymentFailed : ui.ShowStatusMessage;
			then readyForCustomer;
			
			action dispenseItem : dispenser.DispenseProduct {
				in productID = awaitSelection.selectedID;
				in productWeight = getProductInfo.productDetails.weight;
				out dispenseOutcome : DispenseResult;
				out dispensedItem : Product;
			}
			then decide;
				if dispenseItem.dispenseOutcome == DispenseResult::success then verifyDispense;
				if dispenseItem.dispenseOutcome != DispenseResult::success then handleDispenseFailure;
			
			action verifyDispense : dispenser.VerifyDispense {
				in expectedWeight = getProductInfo.productDetails.weight;
				out isVerified : Boolean;
			}
			then decide;
				if verifyDispense.isVerified then updateInventory;
				if not verifyDispense.isVerified then handleDispenseFailure;
			
			action handleDispenseFailure {
				action refundAction : paymentSystem.ProcessRefund {
					in transactionID = authorizePayment.paymentConfirm.transactionID;
					in amount = getProductInfo.productDetails.price;
				}
				then action showMessage : ui.ShowStatusMessage;
				then action logErr : diagnostics.LogError;
			}
			then readyForCustomer;
			
			action updateInventory : inventory.DecrementStock {
				in productID = awaitSelection.selectedID;
				out newStock : StockLevel;
			}
			then deliverProduct;
			
			action deliverProduct : ui.DispenseToCustomer {
				in product = dispenseItem.dispensedItem;
			}
			then generateReceipt;
			
			action generateReceipt : ui.IssueReceipt;
			then checkRestock;
			
			action checkRestock : inventory.CheckRestockNeeded {
				in productID = awaitSelection.selectedID;
				out needsRestock : Boolean;
			}
			then decide;
				if checkRestock.needsRestock then alertMaintenance;
				if not checkRestock.needsRestock then readyForCustomer;
			
			action alertMaintenance : diagnostics.GenerateDiagnosticReport;
			then readyForCustomer;
		}
	}
	
	requirement def PrimaryFunctionRequirement {
		doc /* 
			The automated retail system shall autonomously vend products to customers
			by accepting product selections, processing payments, and dispensing items
			without human intervention during normal operation.
		*/
	}
	
	requirement def TransactionTimeRequirement {
		doc /* 
			The system shall complete a full transaction from product selection to
			dispensing within 45 seconds under normal operating conditions.
		*/
		attribute transactionTime : Real;
		require constraint {
			transactionTime <= 45.0
		}
	}
	
	requirement def InventoryAccuracyRequirement {
		doc /* 
			The inventory management system shall maintain stock level accuracy
			of at least 99.5% to prevent overselling and customer dissatisfaction.
		*/
		attribute inventoryAccuracy : Real;
		require constraint {
			inventoryAccuracy >= 0.995
		}
	}
	
	requirement def PaymentSecurityRequirement {
		doc /* 
			All payment transactions shall be encrypted and comply with PCI DSS
			standards to protect customer financial data.
		*/
	}
	
	requirement def SystemAvailabilityRequirement {
		doc /* 
			The system shall maintain operational availability of at least 98%
			during scheduled operating hours.
		*/
		attribute systemUptime : Real;
		require constraint {
			systemUptime >= 0.98
		}
	}
	
	requirement def DispenseReliabilityRequirement {
		doc /* 
			The dispensing mechanism shall successfully dispense products on the
			first attempt with a reliability of at least 99%.
		*/
		attribute dispenseSuccessRate : Real;
		require constraint {
			dispenseSuccessRate >= 0.99
		}
	}
	
	requirement automatedRetailSystemRequirements {
		doc /* 
			Top-level requirements specification for the automated retail system
			encompassing functional, performance, and operational requirements.
		*/
		
		subject machine : AutomatedRetailMachine;
		
		require primaryFunction : PrimaryFunctionRequirement;
		require transactionTime : TransactionTimeRequirement;
		require inventoryAccuracy : InventoryAccuracyRequirement;
		require paymentSecurity : PaymentSecurityRequirement;
		require systemAvailability : SystemAvailabilityRequirement;
		require dispenseReliability : DispenseReliabilityRequirement;
	}
	
	part retailMachine : AutomatedRetailMachine {
		satisfy automatedRetailSystemRequirements;
	}
}
