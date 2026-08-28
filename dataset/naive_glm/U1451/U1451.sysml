package HospitalAutomatedMedicationDispensingSystem {

	value type MassInMg :> Real;
	value type VolumeInMl :> Real;
	value type TempInC :> Real;
	value type QuantityCount :> Integer;

	item def UserCredential {
	_attribute username : String;
	_attribute passwordHash : String;
	_attribute role : String;
	}

	item def Prescription {
	_attribute prescriptionId : String;
	_attribute patientId : String;
	_attribute medicationName : String;
	_attribute dosageRequired : MassInMg;
	_attribute prescribedBy : String;
	_attribute issueDate : String;
	}

	item def Medication {
	_attribute id : String;
	_attribute name : String;
	_attribute availableQuantity : QuantityCount;
	_attribute expirationDate : String;
	_attribute requiredTemp : TempInC;
	_attribute dosageForm : String;
	_attribute barcodeId : String;
	}

	item def TransactionLog {
	_attribute logId : String;
	_attribute timestamp : String;
	_attribute userId : String;
	_attribute prescriptionId : String;
	_attribute dispensedMedicationId : String;
	_attribute dispensedDosage : MassInMg;
	}

	requirement def SecureManagementReq {
	doc "The system shall securely manage and dispense medications to reduce the risk of human error.";
	}

	requirement def InventoryControlReq {
	doc "The system shall perform real-time inventory checks, tracking quantity, expiration, and storage temperature, and generate low supply alerts.";
	}

	requirement def SafetyVerificationReq {
	doc "The system shall verify that the medication matches the prescription exactly via barcode before dispensing.";
	}

	requirement def DispensingReq {
	doc "The dispensing mechanism shall accurately measure and release the correct dosage if all checks pass.";
	}

	requirement def AuditTrailReq {
	doc "The system shall automatically update inventory records and log complete transactions for a tamper-proof audit trail.";
	}

	requirement def SafetyMonitorReq {
	doc "The system shall oversee status and issue immediate alerts for failed logins, inventory shortages, or verification errors.";
	}

	port def AuthFlowPort {
	in item credential : UserCredential;
	out item authStatus : Boolean;
	}

	port def PrescriptionFlowPort {
	in item patientId : String;
	out item prescriptionData : Prescription;
	}

	port def AuditLogFlowPort {
	in item transactionLog : TransactionLog;
	}

	port def InventoryQueryFlowPort {
	in item medicationName : String;
	out item availableQty : QuantityCount;
	out item stockData : Medication;
	}

	port def VerifyFlowPort {
	in item scannedBarcode : String;
	in item expectedMedName : String;
	in item expectedDosage : MassInMg;
	out item isMatch : Boolean;
	}

	port def DispenseFlowPort {
	in item medName : String;
	in item dosage : MassInMg;
	out item dispensedQty : MassInMg;
	out item dispenseSuccess : Boolean;
	}

	port def SystemAlertPort {
	in item alertType : String;
	in item alertDescription : String;
	}

	port def UIAlertPort {
	in item alertType : String;
	in item alertDescription : String;
	}

	part def UserInterface {
	port authPort : ~AuthFlowPort;
	port rxPort : ~PrescriptionFlowPort;
	port auditPort : ~AuditLogFlowPort;
	port invQueryPort : ~InventoryQueryFlowPort;
	port verifyPort : ~VerifyFlowPort;
	port dispensePort : ~DispenseFlowPort;
	port alertIn : UIAlertPort;

	exhibit state uiStates {
	state idle;
	state authenticating;
	state authenticated;
	state checkingStock;
	state verifyingMed;
	state dispensingMed;
	state loggingTransaction;
	state errorState;

	transition idle -> authenticating;
	transition authenticating -> authenticated when authPort.authStatus == true;
	transition authenticating -> errorState when authPort.authStatus == false;
	transition authenticated -> checkingStock;
	transition checkingStock -> verifyingMed when invQueryPort.availableQty > 0;
	transition checkingStock -> errorState when invQueryPort.availableQty <= 0;
	transition verifyingMed -> dispensingMed when verifyPort.isMatch == true;
	transition verifyingMed -> errorState when verifyPort.isMatch == false;
	transition dispensingMed -> loggingTransaction when dispensePort.dispenseSuccess == true;
	transition dispensingMed -> errorState when dispensePort.dispenseSuccess == false;
	transition loggingTransaction -> idle;
	transition errorState -> idle;
	}
	}

	part def DatabaseServer {
	port authPort : AuthFlowPort;
	port rxPort : PrescriptionFlowPort;
	port auditPort : AuditLogFlowPort;

	attribute users : UserCredential[*];
	attribute prescriptions : Prescription[*];
	attribute auditLogs : TransactionLog[*];

	exhibit action authenticate;
	exhibit action getPrescription;
	exhibit action logTransaction;
	}

	part def InventoryManagementUnit {
	port invQueryPort : InventoryQueryFlowPort;
	port monitorPort : ~SystemAlertPort;

	attribute stock : Medication[*];

	exhibit state invStates {
	state stable;
	state lowStock;
	state updating;

	transition stable -> lowStock when stock->exists(m | m.availableQuantity < 10);
	transition lowStock -> stable when stock->forAll(m | m.availableQuantity >= 10);
	transition stable -> updating;
	transition lowStock -> updating;
	transition updating -> stable;
	}

	exhibit action checkStock;
	}

	part def VerificationModule {
	port verifyPort : VerifyFlowPort;
	port monitorPort : ~SystemAlertPort;

	exhibit state verifyStates {
	state waiting;
	state scanning;
	state matched;
	state mismatched;

	transition waiting -> scanning;
	transition scanning -> matched when verifyPort.isMatch == true;
	transition scanning -> mismatched when verifyPort.isMatch == false;
	}
	}

	part def DispensingMechanism {
	port dispensePort : DispenseFlowPort;

	exhibit state dispenseStates {
	state idle;
	state measuring;
	state releasing;

	transition idle -> measuring;
	transition measuring -> releasing;
	transition releasing -> idle when dispensePort.dispenseSuccess == true;
	}
	}

	part def SafetyMonitor {
	port monitorPort : SystemAlertPort;
	port broadcastPort : ~UIAlertPort;

	exhibit state monitorStates {
	state normal;
	state alerting;

	transition normal -> alerting on monitorPort;
	transition alerting -> normal;
	}

	exhibit action handleAlert;
	}

	part def AutomatedMedicationDispensingSystem {
	satisfy => SecureManagementReq;
	satisfy => InventoryControlReq;
	satisfy => SafetyVerificationReq;
	satisfy => DispensingReq;
	satisfy => AuditTrailReq;
	satisfy => SafetyMonitorReq;

	part ui : UserInterface;
	part db : DatabaseServer;
	part inv : InventoryManagementUnit;
	part verify : VerificationModule;
	part dispense : DispensingMechanism;
	part monitor : SafetyMonitor;

	connect ui.authPort to db.authPort;
	connect ui.rxPort to db.rxPort;
	connect ui.auditPort to db.auditPort;

	connect ui.invQueryPort to inv.invQueryPort;
	connect inv.monitorPort to monitor.monitorPort;

	connect ui.verifyPort to verify.verifyPort;
	connect verify.monitorPort to monitor.monitorPort;

	connect ui.dispensePort to dispense.dispensePort;

	connect monitor.broadcastPort to ui.alertIn;
	}
}
