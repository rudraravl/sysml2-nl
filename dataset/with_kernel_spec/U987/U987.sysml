package AutomatedRetailMachine {
	private import ISQ::MassValue;
	private import ScalarValues::String;
	private import ScalarValues::Boolean;
	private import ScalarValues::Real;
	private import ScalarValues::Integer;
	private import SI::kg;

	item def Product {
		attribute id : String;
		attribute name : String;
		attribute price : Real;
		attribute weight : MassValue;
	}

	item def ProductSelection {
		ref item product : Product;
		attribute quantity : Integer;
	}

	item def PaymentRequest {
		attribute amount : Real;
		attribute method : String;
	}

	item def PaymentAuthorization {
		attribute transactionId : String;
		attribute amount : Real;
	}

	item def PaymentApproved :> PaymentAuthorization;

	item def PaymentDeclined :> PaymentAuthorization {
		attribute reason : String;
	}

	item def DispenseCommand {
		ref item product : Product;
		attribute quantity : Integer;
	}

	item def DispenseResult {
		attribute transactionId : String;
		attribute actualWeight : MassValue;
	}

	item def DispenseSuccess :> DispenseResult;

	item def DispenseFailure :> DispenseResult {
		attribute reason : String;
	}

	item def RefundRequest {
		attribute transactionId : String;
		attribute amount : Real;
	}

	item def RefundConfirmation {
		attribute transactionId : String;
		attribute refunded : Boolean;
	}

	item def ErrorEvent {
		attribute code : String;
		attribute detail : String;
	}

	item def ErrorLog {
		attribute code : String;
		attribute detail : String;
		attribute timestamp : String;
	}

	item def MaintenanceReport {
		ref item logs : ErrorLog[0..*];
		attribute summary : String;
	}

	item def RefillAlert {
		ref item product : Product;
		attribute currentStock : Integer;
	}

	port def CustomerInteractionPort {
		out item selection : ProductSelection;
		in attribute displayMsg : String;
	}

	port def GatewayCommPort {
		out item request : PaymentRequest;
		in item authorization : PaymentAuthorization;
	}

	port def DispenseCommPort {
		in item command : DispenseCommand;
		out item result : DispenseResult;
	}

	port def RefundCommPort {
		out item refund : RefundRequest;
		in item confirmation : RefundConfirmation;
	}

	port def DiagnosticCommPort {
		in item error : ErrorEvent;
		out item report : MaintenanceReport;
	}

	port def InventoryCommPort {
		out item products : Product[0..*];
		out item refillAlert : RefillAlert;
	}

	port def SensorCommPort {
		out attribute weightReading : MassValue;
	}

	part def WeightSensor {
		port readingPort : SensorCommPort;
		attribute accuracy : MassValue;
	}

	part def ExternalPaymentGateway {
		port gatewayIF : ~GatewayCommPort;
	}

	part def InventoryManagementSystem {
		attribute stockCount : Integer;
		ref item products : Product[0..*];
		attribute lowStockThreshold : Integer;
		port inventoryPort : InventoryCommPort;
	}

	part def UserInterface {
		port customerIF : CustomerInteractionPort;
	}

	part def PaymentProcessingSystem {
		port customerFacingPort : ~CustomerInteractionPort;
		port gatewayPort : GatewayCommPort;
		port refundPort : RefundCommPort;
	}

	part def DispensingMechanism {
		port dispensePort : DispenseCommPort;
		port sensorPort : ~SensorCommPort;
		attribute maxWeight : MassValue;
		part weightSensor : WeightSensor;
	}

	part def DiagnosticSystem {
		port diagnosticPort : DiagnosticCommPort;
		ref item errorLog : ErrorLog[0..*];
	}

	part def AutomatedRetailMachine {
		attribute machineId : String;
		attribute maxCapacity : Integer;
		attribute currentTransactionId : String;

		part inventory : InventoryManagementSystem;
		part ui : UserInterface;
		part payment : PaymentProcessingSystem;
		part dispenser : DispensingMechanism;
		part diagnostics : DiagnosticSystem;
		part gateway : ExternalPaymentGateway;
	}

	state def operationStates {
		in machine : AutomatedRetailMachine;
		entry; then idle;

		state idle;

		accept ProductSelection
			then paymentPending;

		state paymentPending {
			entry assign machine.currentTransactionId := "pending";
		}

		accept PaymentApproved
			then dispensing;

		accept PaymentDeclined
			then errorState;

		state dispensing {
			assert constraint { machine.dispenser.maxWeight > 0 [kg] }
		}

		accept DispenseSuccess
			then idle;

		accept DispenseFailure
			then refunding;

		state refunding;

		accept RefundConfirmation
			then idle;

		state errorState {
			entry assign machine.currentTransactionId := "";
		}

		accept ErrorEvent
			then idle;
	}

	part machineInstance : AutomatedRetailMachine {
		connect ui.customerIF to payment.customerFacingPort;
		connect payment.gatewayPort to gateway.gatewayIF;
		connect dispenser.weightSensor.readingPort to dispenser.sensorPort;

		exhibit operationStates {
			in machine = machineInstance;
		}
	}

	action def ProcessPayment {
		in request : PaymentRequest;
		out authorization : PaymentAuthorization;
	}

	action def DispenseProduct {
		in command : DispenseCommand;
		out result : DispenseResult;
	}

	action def ProcessRefund {
		in request : RefundRequest;
		out confirmation : RefundConfirmation;
	}

	action def LogError {
		in error : ErrorEvent;
		out log : ErrorLog;
	}

	action def GenerateMaintenanceReport {
		in logs : ErrorLog[0..*];
		out report : MaintenanceReport;
	}

	requirement def SuccessfulTransactionRequirement {
		subject machine : AutomatedRetailMachine;
		doc /* The machine must support complete transactions from product selection through dispensing. */
		constraint { machine.maxCapacity > 0 }
	}

	requirement def DispenseVerificationRequirement {
		subject dispenser : DispensingMechanism;
		doc /* The dispensing mechanism must verify product delivery using weight sensors. */
		constraint { dispenser.maxWeight > 0 [kg] }
	}

	requirement def RefillAlertRequirement {
		subject inventory : InventoryManagementSystem;
		doc /* The inventory system must flag low stock for refill. */
		constraint { inventory.lowStockThreshold > 0 }
	}

	requirement def ErrorRecoveryRequirement {
		subject machine : AutomatedRetailMachine;
		doc /* The machine must handle errors and process refunds for failed transactions after payment. */
		constraint { machine.maxCapacity >= 1 }
	}

	requirement def SensorAccuracyRequirement {
		subject sensor : WeightSensor;
		doc /* The weight sensor must have sufficient accuracy for product verification. */
		constraint { sensor.accuracy > 0 [kg] }
	}
}
