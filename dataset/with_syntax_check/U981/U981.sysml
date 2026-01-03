package 'Automated Cash Handling System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import SequenceFunctions::*;
	
	attribute def CurrencyAmount :> Real;
	attribute def BillSerialNumber :> String;
	attribute def TransactionID :> String;
	attribute def AccountNumber :> String;
	attribute def ValidationResult :> Boolean;
	
	enum def TransactionType {
		deposit;
		withdrawal;
		exchange;
	}
	
	enum def BillDenomination {
		one;
		five;
		ten;
		twenty;
		fifty;
		hundred;
	}
	
	enum def CoinDenomination {
		penny;
		nickel;
		dime;
		quarter;
	}
	
	item def Currency {
		attribute amount : CurrencyAmount;
		attribute isValid : ValidationResult;
	}
	
	item def Bill :> Currency {
		attribute denomination : BillDenomination;
		attribute serialNumber : BillSerialNumber;
	}
	
	item def Coin :> Currency {
		attribute denomination : CoinDenomination;
		attribute weight : ISQ::MassValue;
	}
	
	item def CashBatch {
		attribute bills : Bill[*];
		attribute coins : Coin[*];
		attribute totalAmount : CurrencyAmount;
	}
	
	item def TransactionRecord {
		attribute transactionID : TransactionID;
		attribute transactionType : TransactionType;
		attribute accountNumber : AccountNumber;
		attribute amount : CurrencyAmount;
		attribute timestamp : String;
		attribute status : String;
	}
	
	item def Receipt {
		attribute transactionID : TransactionID;
		attribute amount : CurrencyAmount;
		attribute timestamp : String;
		attribute receiptMessage : String;
	}
	
	port def CashInputPort {
		in item billsIn : Bill[*];
		in item coinsIn : Coin[*];
	}
	
	port def CashOutputPort {
		out item billsOut : Bill[*];
		out item coinsOut : Coin[*];
	}
	
	port def ValidationPort {
		in item currencyToValidate : Currency;
		out attribute validationResult : ValidationResult;
		out item validatedCurrency : Currency;
	}
	
	port def StoragePort {
		in item cashToStore : CashBatch;
		out item cashToDispense : CashBatch;
		out attribute currentBalance : CurrencyAmount;
	}
	
	port def UserInterfacePort {
		in attribute userCommand : String;
		in attribute requestedAmount : CurrencyAmount;
		in attribute accountNumber : AccountNumber;
		out attribute displayMessage : String;
		out attribute transactionStatus : String;
	}
	
	port def ReceiptPort {
		out item receipt : Receipt;
	}
	
	port def NetworkPort {
		in attribute accountData : AccountNumber;
		out attribute transactionData : TransactionRecord;
		out attribute authorizationResult : ValidationResult;
	}
	
	part def BillAcceptor {
		port input : CashInputPort;
		port output : CashOutputPort;
		
		attribute acceptedBills : Bill[*];
		attribute rejectedBills : Bill[*];
		
		perform action acceptBills {
			in billsReceived : Bill[*];
			out billsAccepted : Bill[*];
			out billsRejected : Bill[*];
		}
	}
	
	part def CoinAcceptor {
		port input : CashInputPort;
		port output : CashOutputPort;
		
		attribute acceptedCoins : Coin[*];
		attribute rejectedCoins : Coin[*];
		
		perform action acceptCoins {
			in coinsReceived : Coin[*];
			out coinsAccepted : Coin[*];
			out coinsRejected : Coin[*];
		}
	}
	
	part def CurrencyValidator {
		port validationInterface : ValidationPort;
		
		attribute validationAccuracy : Real;
		
		perform action validateBill {
			in bill : Bill;
			out isAuthentic : ValidationResult;
			out validatedBill : Bill;
		}
		
		perform action validateCoin {
			in coin : Coin;
			out isAuthentic : ValidationResult;
			out validatedCoin : Coin;
		}
	}
	
	part def SecureVault {
		port storageInterface : StoragePort;
		
		attribute storedBills : Bill[*];
		attribute storedCoins : Coin[*];
		attribute totalBalance : CurrencyAmount;
		attribute capacity : CurrencyAmount;
		
		perform action storeCash {
			in batch : CashBatch;
			out storageConfirmed : ValidationResult;
			out newBalance : CurrencyAmount;
		}
		
		perform action retrieveCash {
			in requestedAmount : CurrencyAmount;
			out dispensedBatch : CashBatch;
			out remainingBalance : CurrencyAmount;
		}
	}
	
	part def CashDispenser {
		port output : CashOutputPort;
		
		attribute dispensedBills : Bill[*];
		attribute dispensedCoins : Coin[*];
		
		perform action dispenseCash {
			in batch : CashBatch;
			out dispensedBills : Bill[*];
			out dispensedCoins : Coin[*];
			out dispenseComplete : ValidationResult;
		}
	}
	
	part def TransactionController {
		port userInterface : UserInterfacePort;
		port networkInterface : NetworkPort;
		
		attribute currentTransaction : TransactionRecord;
		attribute transactionHistory : TransactionRecord[*];
		
		perform action initiateTransaction {
			in transactionType : TransactionType;
			in accountNumber : AccountNumber;
			in amount : CurrencyAmount;
			out transactionID : TransactionID;
		}
		
		perform action authorizeTransaction {
			in transactionID : TransactionID;
			in accountNumber : AccountNumber;
			in amount : CurrencyAmount;
			out authorized : ValidationResult;
		}
		
		perform action completeTransaction {
			in transactionID : TransactionID;
			out record : TransactionRecord;
			out success : ValidationResult;
		}
	}
	
	part def ReceiptPrinter {
		port receiptOutput : ReceiptPort;
		
		perform action printReceipt {
			in transactionID : TransactionID;
			in amount : CurrencyAmount;
			in timestamp : String;
			in receiptMessage : String;
			out receipt : Receipt;
		}
	}
	
	part def UserDisplay {
		port displayInterface : UserInterfacePort;
		
		attribute currentMessage : String;
		
		perform action showMessage {
			in displayMessage : String;
		}
		
		perform action promptUser {
			in prompt : String;
			out userResponse : String;
		}
	}
	
	action def ValidateCashBatch {
		in inputBatch : CashBatch;
		out validatedBatch : CashBatch;
		out rejectedBatch : CashBatch;
		out totalValidAmount : CurrencyAmount;
		
		private attribute validBills : Bill[*] := ( );
		private attribute validCoins : Coin[*] := ( );
		private attribute rejectedBills : Bill[*] := ( );
		private attribute rejectedCoins : Coin[*] := ( );
		private attribute runningTotal : CurrencyAmount := 0.0;
		
		first start;
		then action validateAllBills {
			for bill in inputBatch.bills {
				perform action vb : CurrencyValidator::validateBill {
					in bill = bill;
					out isAuthentic;
					out validatedBill;
				}
				then decide;
					if vb.isAuthentic then action {
						assign validBills := validBills->including(vb.validatedBill);
						assign runningTotal := runningTotal + vb.validatedBill.amount;
					}
					if not vb.isAuthentic then action {
						assign rejectedBills := rejectedBills->including(bill);
					}
			}
		}
		then action validateAllCoins {
			for coin in inputBatch.coins {
				perform action vc : CurrencyValidator::validateCoin {
					in coin = coin;
					out isAuthentic;
					out validatedCoin;
				}
				then decide;
					if vc.isAuthentic then action {
						assign validCoins := validCoins->including(vc.validatedCoin);
						assign runningTotal := runningTotal + vc.validatedCoin.amount;
					}
					if not vc.isAuthentic then action {
						assign rejectedCoins := rejectedCoins->including(coin);
					}
			}
		}
		then action assembleResults {
			assign validatedBatch := CashBatch {
				bills = validBills,
				coins = validCoins,
				totalAmount = runningTotal
			};
			assign rejectedBatch := CashBatch {
				bills = rejectedBills,
				coins = rejectedCoins,
				totalAmount = 0.0
			};
			assign totalValidAmount := runningTotal;
		}
		then done;
	}
	
	action def ProcessDeposit {
		in depositedBatch : CashBatch;
		in accountNumber : AccountNumber;
		out receipt : Receipt;
		out success : ValidationResult;
		
		private attribute validatedBatch : CashBatch;
		private attribute rejectedBatch : CashBatch;
		private attribute totalAmount : CurrencyAmount;
		private attribute transactionID : TransactionID;
		
		first start;
		then action initiate : TransactionController::initiateTransaction {
			in transactionType = TransactionType::deposit;
			in accountNumber = accountNumber;
			in amount = depositedBatch.totalAmount;
			out transactionID;
		}
		then action validate : ValidateCashBatch {
			in inputBatch = depositedBatch;
			out validatedBatch;
			out rejectedBatch;
			out totalValidAmount;
		}
		then assign totalAmount := validate.totalValidAmount;
		then decide;
			if totalAmount > 0.0 then processValidDeposit;
			if totalAmount <= 0.0 then rejectDeposit;
		
		action processValidDeposit {
			first action store : SecureVault::storeCash {
				in batch = validate.validatedBatch;
				out storageConfirmed;
				out newBalance;
			}
			then action authorize : TransactionController::authorizeTransaction {
				in transactionID = initiate.transactionID;
				in accountNumber = accountNumber;
				in amount = totalAmount;
				out authorized;
			}
			then decide;
				if authorize.authorized then finalizeDeposit;
				else cancelDeposit;
			
			action finalizeDeposit {
				first action complete : TransactionController::completeTransaction {
					in transactionID = initiate.transactionID;
					out record;
					out success;
				}
				then action print : ReceiptPrinter::printReceipt {
					in transactionID = initiate.transactionID;
					in amount = totalAmount;
					in timestamp = complete.record.timestamp;
					in receiptMessage = "Deposit successful";
					out receipt;
				}
				then assign success := true;
				then mergeEnd;
			}
			
			action cancelDeposit {
				assign success := false;
				then mergeEnd;
			}
		}
		
		action rejectDeposit {
			assign success := false;
			then mergeEnd;
		}
		
		merge mergeEnd;
		then done;
	}
	
	action def ProcessWithdrawal {
		in requestedAmount : CurrencyAmount;
		in accountNumber : AccountNumber;
		out dispensedBatch : CashBatch;
		out receipt : Receipt;
		out success : ValidationResult;
		
		private attribute transactionID : TransactionID;
		private attribute authorized : ValidationResult;
		
		first start;
		then action initiate : TransactionController::initiateTransaction {
			in transactionType = TransactionType::withdrawal;
			in accountNumber = accountNumber;
			in amount = requestedAmount;
			out transactionID;
		}
		then action authorize : TransactionController::authorizeTransaction {
			in transactionID = initiate.transactionID;
			in accountNumber = accountNumber;
			in amount = requestedAmount;
			out authorized;
		}
		then decide;
			if authorize.authorized then processValidWithdrawal;
			else rejectWithdrawal;
		
		action processValidWithdrawal {
			first action retrieve : SecureVault::retrieveCash {
				in requestedAmount = requestedAmount;
				out dispensedBatch;
				out remainingBalance;
			}
			then action dispense : CashDispenser::dispenseCash {
				in batch = retrieve.dispensedBatch;
				out dispensedBills;
				out dispensedCoins;
				out dispenseComplete;
			}
			then action complete : TransactionController::completeTransaction {
				in transactionID = initiate.transactionID;
				out record;
				out success;
			}
			then action print : ReceiptPrinter::printReceipt {
				in transactionID = initiate.transactionID;
				in amount = requestedAmount;
				in timestamp = complete.record.timestamp;
				in receiptMessage = "Withdrawal successful";
				out receipt;
			}
			then assign success := true;
			then mergeEnd;
		}
		
		action rejectWithdrawal {
			assign success := false;
			then mergeEnd;
		}
		
		merge mergeEnd;
		then done;
	}
	
	action def OperateCashHandler {
		in userCommand : String;
		in accountNumber : AccountNumber;
		in requestedAmount : CurrencyAmount;
		in depositedBatch : CashBatch;
		out finalReceipt : Receipt;
		out operationSuccess : ValidationResult;
		
		first start;
		then merge awaitCommand;
		then decide;
			if userCommand == "deposit" then handleDeposit;
			if userCommand == "withdrawal" then handleWithdrawal;
			if userCommand == "exit" then endOperation;
		
		action handleDeposit : ProcessDeposit {
			in depositedBatch = depositedBatch;
			in accountNumber = accountNumber;
			out receipt;
			out success;
		}
		then assign finalReceipt := handleDeposit.receipt;
		then assign operationSuccess := handleDeposit.success;
		then awaitCommand;
		
		action handleWithdrawal : ProcessWithdrawal {
			in requestedAmount = requestedAmount;
			in accountNumber = accountNumber;
			out dispensedBatch;
			out receipt;
			out success;
		}
		then assign finalReceipt := handleWithdrawal.receipt;
		then assign operationSuccess := handleWithdrawal.success;
		then awaitCommand;
		
		action endOperation;
		then done;
	}
	
	part automatedCashHandler : AutomatedCashHandlingSystem {
		doc /* 
		The automated cash handling system provides secure, accurate processing of 
		cash transactions including deposits, withdrawals, and currency exchange. 
		The system accepts physical currency (bills and coins), validates authenticity, 
		securely stores accepted funds, dispenses requested amounts, and generates 
		transaction records and receipts. Primary function: automate cash processing 
		to reduce manual handling, improve accuracy, enhance security, and provide 
		real-time transaction tracking for financial institutions and retail operations.
		*/
		
		part billAcceptor : BillAcceptor;
		part coinAcceptor : CoinAcceptor;
		part validator : CurrencyValidator;
		part vault : SecureVault;
		part dispenser : CashDispenser;
		part controller : TransactionController;
		part printer : ReceiptPrinter;
		part display : UserDisplay;
		
		port cashInput : CashInputPort;
		port cashOutput : CashOutputPort;
		port userInterface : UserInterfacePort;
		port receiptOutput : ReceiptPort;
		port networkConnection : NetworkPort;
		
		connection billInputFlow connect cashInput to billAcceptor.input;
		connection coinInputFlow connect cashInput to coinAcceptor.input;
		connection billValidationFlow connect billAcceptor.output to validator.validationInterface;
		connection coinValidationFlow connect coinAcceptor.output to validator.validationInterface;
		connection validatedToVault connect validator.validationInterface to vault.storageInterface;
		connection vaultToDispenser connect vault.storageInterface to dispenser.output;
		connection dispenserOutput connect dispenser.output to cashOutput;
		connection controllerUI connect controller.userInterface to userInterface;
		connection controllerNetwork connect controller.networkInterface to networkConnection;
		connection printerOutput connect printer.receiptOutput to receiptOutput;
		connection displayUI connect display.displayInterface to userInterface;
		
		perform action mainOperation : OperateCashHandler;
		
		billAcceptor performs mainOperation.handleDeposit.validate;
		coinAcceptor performs mainOperation.handleDeposit.validate;
		validator performs mainOperation.handleDeposit.validate;
		vault performs mainOperation.handleDeposit.processValidDeposit.store;
		vault performs mainOperation.handleWithdrawal.processValidWithdrawal.retrieve;
		dispenser performs mainOperation.handleWithdrawal.processValidWithdrawal.dispense;
		controller performs mainOperation.handleDeposit.initiate;
		controller performs mainOperation.handleWithdrawal.initiate;
		printer performs mainOperation.handleDeposit.processValidDeposit.finalizeDeposit.print;
		printer performs mainOperation.handleWithdrawal.processValidWithdrawal.print;
	}
	
	part def AutomatedCashHandlingSystem {
		doc /* 
		Automated cash handling system for secure processing of currency transactions 
		in banking and retail environments. Provides validation, storage, dispensing, 
		and transaction recording capabilities.
		*/
	}
	
	requirement def CashHandlingRequirements {
		doc /* Requirements for automated cash handling system operations and performance. */
		
		requirement validationAccuracy {
			doc /* The system shall validate currency authenticity with minimum 99.5% accuracy. */
			attribute requiredAccuracy : Real = 0.995;
		}
		
		requirement secureStorage {
			doc /* The system shall provide tamper-resistant secure storage for all accepted currency. */
		}
		
		requirement dispensingAccuracy {
			doc /* The system shall dispense requested amounts with 99.9% accuracy. */
			attribute requiredAccuracy : Real = 0.999;
		}
		
		requirement transactionRecording {
			doc /* The system shall record all transactions with unique identifiers and timestamps. */
		}
		
		requirement receiptGeneration {
			doc /* The system shall generate printed receipts for all completed transactions. */
		}
		
		requirement processingSpeed {
			doc /* The system shall complete standard transactions within 30 seconds. */
			attribute maxDuration : ISQ::TimeValue;
		}
		
		requirement availability {
			doc /* The system shall maintain 99% operational availability during business hours. */
			attribute requiredAvailability : Real = 0.99;
		}
	}
	
	requirement systemRequirements : CashHandlingRequirements {
		doc /* Top-level requirements for the automated cash handling system. */
		
		require validationAccuracy;
		require secureStorage;
		require dispensingAccuracy;
		require transactionRecording;
		require receiptGeneration;
		require processingSpeed;
		require availability;
		
		satisfy validationAccuracy by validator;
		satisfy secureStorage by vault;
		satisfy dispensingAccuracy by dispenser;
		satisfy transactionRecording by controller;
		satisfy receiptGeneration by printer;
	}
}
