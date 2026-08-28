package 'Automated Cash Handling System' {
	private import ScalarValues::Real;
	private import ScalarValues::Integer;
	private import ScalarValues::String;
	private import ScalarValues::Boolean;
	private import ISQ::MassValue;
	private import ISQ::CurrencyValue;

	item def Bill {
		attribute denomination : CurrencyValue;
	}
	item def Coin {
		attribute denomination : CurrencyValue;
		attribute mass : MassValue;
	}
	item def CashBatch {
		item bills : Bill[*];
		item coins : Coin[*];
		attribute totalValue : CurrencyValue;
	}
	item def Receipt {
		attribute transactionId : String;
		attribute timestamp : String;
		attribute amount : CurrencyValue;
	}
	item def TransactionRequest {
		attribute amount : CurrencyValue;
		attribute account : String;
	}
	item def Authorization {
		attribute approved : Boolean;
		attribute code : String;
	}
	item def RejectNotice;
	item def DoneSignal;

	port def CashFlowPort {
		out cash : CashBatch;
	}
	port def CashInPort {
		in cash : CashBatch;
	}
	port def RequestPort {
		out request : TransactionRequest;
		in auth : Authorization;
	}
	port def DisplayPort {
		out message : String;
	}
	port def ReceiptPort {
		out receipt : Receipt;
	}

	part def BillAcceptor {
		port billOut : CashFlowPort;
	}
	part def CoinAcceptor {
		port coinOut : CashFlowPort;
	}
	part def CurrencyValidator {
		port billIn : CashInPort;
		port coinIn : CashInPort;
		port validOut : CashFlowPort;
		port rejectOut : CashFlowPort;
	}
	part def SecureVault {
		port storeIn : CashInPort;
		port dispenseOut : CashFlowPort;
		attribute totalValue : CurrencyValue;
	}
	part def CashDispenser {
		port dispenseIn : CashInPort;
		port dispenseOut : CashFlowPort;
	}
	part def TransactionController {
		port bankPort : RequestPort;
		port displayPort : DisplayPort;
		port receiptPort : ReceiptPort;
	}
	part def UserDisplay {
		port displayIn : ~DisplayPort;
	}
	part def ReceiptPrinter {
		port receiptIn : ~ReceiptPort;
	}
	part def BankingNetwork {
		port bankPort : ~RequestPort;
	}
	part def User {
		port cashIn : CashInPort;
	}

	action def ValidateCurrency {
		in cashIn : CashBatch;
		out validCash : CashBatch;
		out rejectedCash : CashBatch;
	}
	action def AuthorizeTransaction {
		in request : TransactionRequest;
		out auth : Authorization;
	}
	action def DispenseCash {
		in batch : CashBatch;
		out done : DoneSignal;
	}

	state machine def ControllerStates {
		state Idle;
		state Processing;
		state Dispensing;
		transition from Idle to Processing accept request : TransactionRequest;
		transition from Processing to Dispensing accept auth : Authorization;
		transition from Dispensing to Idle accept done : DoneSignal;
	}

	part def CashHandlingSystem {
		part billAcceptor : BillAcceptor;
		part coinAcceptor : CoinAcceptor;
		part validator : CurrencyValidator;
		part vault : SecureVault;
		part dispenser : CashDispenser;
		part controller : TransactionController {
			exhibit controllerStates : ControllerStates;
		}
		part display : UserDisplay;
		part printer : ReceiptPrinter;
		part network : BankingNetwork;
		part user : User;

		flow of cash : CashBatch from billAcceptor.billOut.cash to validator.billIn.cash;
		flow of cash : CashBatch from coinAcceptor.coinOut.cash to validator.coinIn.cash;
		flow of cash : CashBatch from validator.validOut.cash to vault.storeIn.cash;
		flow of cash : CashBatch from vault.dispenseOut.cash to dispenser.dispenseIn.cash;
		flow of cash : CashBatch from dispenser.dispenseOut.cash to user.cashIn.cash;
		flow of request : TransactionRequest from controller.bankPort.request to network.bankPort.request;
		flow of auth : Authorization from network.bankPort.auth to controller.bankPort.auth;
		flow of message : String from controller.displayPort.message to display.displayIn.message;
		flow of receipt : Receipt from controller.receiptPort.receipt to printer.receiptIn.receipt;
	}

	requirement def SecurityRequirement {
		subject vault : SecureVault;
		doc /* The SecureVault must be tamper-resistant and prevent unauthorized access to stored currency. */
	}
	requirement def AccuracyRequirement {
		subject validator : CurrencyValidator;
		doc /* The Currency Validator must accurately verify authenticity and denomination of all bills and coins. */
	}
	requirement def AuditabilityRequirement {
		subject controller : TransactionController;
		doc /* The TransactionController must log every action for a complete and auditable history. */
	}

	requirement cashHandlingSecurity : SecurityRequirement;
	requirement cashHandlingAccuracy : AccuracyRequirement;
	requirement cashHandlingAudit : AuditabilityRequirement;

	part systemInstance : CashHandlingSystem {
		satisfy cashHandlingSecurity by vault;
		satisfy cashHandlingAccuracy by validator;
		satisfy cashHandlingAudit by controller;
	}
}
