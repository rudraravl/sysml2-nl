package AutomatedMedicationDispensingSystem {
    private import ScalarValues::String;
    private import ScalarValues::Integer;
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;

    item def Credentials {
        attribute userId : String;
        attribute password : String;
    }

    item def Session {
        attribute token : String;
        attribute userId : String;
        attribute valid : Boolean;
    }

    item def Prescription {
        attribute patientId : String;
        attribute medicationId : String;
        attribute dosage : Real;
    }

    item def Medication {
        attribute id : String;
        attribute name : String;
        attribute availableQuantity : Integer;
        attribute expirationDate : String;
        attribute storageTemperature : Real;
        attribute barcode : String;
    }

    item def PrescriptionRequest {
        attribute patientId : String;
        attribute medicationId : String;
    }

    item def DispenseRequest {
        attribute userId : String;
        attribute prescription : Prescription;
    }

    item def StockCheckRequest {
        attribute medicationId : String;
    }

    item def StockCheckResponse {
        attribute available : Boolean;
        attribute quantity : Integer;
        attribute medication : Medication;
    }

    item def VerificationRequest {
        attribute medicationId : String;
        attribute barcode : String;
    }

    item def VerificationResponse {
        attribute match : Boolean;
    }

    item def DispenseCommand {
        attribute medicationId : String;
        attribute dosage : Real;
    }

    item def DispenseConfirmation {
        attribute success : Boolean;
        attribute medicationId : String;
    }

    item def StockUpdate {
        attribute medicationId : String;
        attribute delta : Integer;
    }

    item def AlertMsg {
        attribute severity : String;
        attribute alertMessage : String;
    }

    item def AuditEntry {
        attribute timestamp : String;
        attribute userId : String;
        attribute actionType : String;
        attribute details : String;
    }

    port def AuthPort {
        in ref credentials : Credentials;
        out ref session : Session;
    }

    port def PrescriptionPort {
        in ref request : PrescriptionRequest;
        out ref prescription : Prescription;
    }

    port def DispenseRequestPort {
        in ref request : DispenseRequest;
    }

    port def InventoryPort {
        in ref stockCheck : StockCheckRequest;
        out ref stockResponse : StockCheckResponse;
        in ref stockUpdate : StockUpdate;
    }

    port def VerificationPort {
        in ref verifyRequest : VerificationRequest;
        out ref verifyResponse : VerificationResponse;
    }

    port def DispensePort {
        in ref command : DispenseCommand;
        out ref confirmation : DispenseConfirmation;
    }

    port def AlertPort {
        in ref alert : AlertMsg;
    }

    port def AuditPort {
        in ref audit : AuditEntry;
    }

    interface def AuthInterface {
        end source : ~AuthPort;
        end target : AuthPort;
    }

    interface def PrescriptionInterface {
        end source : ~PrescriptionPort;
        end target : PrescriptionPort;
    }

    interface def DispenseRequestInterface {
        end source : ~DispenseRequestPort;
        end target : DispenseRequestPort;
    }

    interface def InventoryInterface {
        end source : ~InventoryPort;
        end target : InventoryPort;
    }

    interface def VerificationInterface {
        end source : ~VerificationPort;
        end target : VerificationPort;
    }

    interface def DispenseInterface {
        end source : ~DispensePort;
        end target : DispensePort;
    }

    interface def AlertInterface {
        end source : ~AlertPort;
        end target : AlertPort;
    }

    interface def AuditInterface {
        end source : ~AuditPort;
        end target : AuditPort;
    }

    requirement def SecureAuthentication {
        text "The system shall require authorized medical personnel to authenticate before accessing prescriptions.";
    }

    requirement def RealTimeInventory {
        text "The system shall perform real-time stock checks and generate alerts when medication supplies are low.";
    }

    requirement def VerificationBeforeDispensing {
        text "The system shall verify that the medication matches the prescription via barcode scan before dispensing.";
    }

    requirement def AccurateDispensing {
        text "The system shall accurately measure and release the correct dosage of medication.";
    }

    requirement def SafetyMonitoring {
        text "The system shall continuously monitor for errors and issue immediate alerts.";
    }

    requirement def AuditTrail {
        text "The system shall log all dispensing transactions to create a tamper-proof audit trail.";
    }

    part def UserInterface {
        port authPort : ~AuthPort;
        port prescPort : ~PrescriptionPort;
        port dispenseReqPort : ~DispenseRequestPort;
        port alertPort : ~AlertPort;

        exhibit state uiBehavior {
            entry; then waitForLogin;
            state waitForLogin;
            transition doLogin
                first waitForLogin
                do send new Credentials("nurse1", "pass123") via authPort
                then waitForSession;
            state waitForSession;
            transition receiveValidSession
                first waitForSession
                accept sess : Session via authPort
                if sess.valid
                then waitForRequest;
            transition receiveInvalidSession
                first waitForSession
                accept sess : Session via authPort
                if not sess.valid
                then alertState;
            state alertState;
            transition sendAlert
                first alertState
                do send new AlertMsg("WARNING", "Authentication failed") via alertPort
                then waitForLogin;
            state waitForRequest;
            transition sendPrescRequest
                first waitForRequest
                do send new PrescriptionRequest("patient42", "med1001") via prescPort
                then waitForPrescription;
            state waitForPrescription;
            transition receivePrescription
                first waitForPrescription
                accept presc : Prescription via prescPort
                then sendDispenseRequest;
            state sendDispenseRequest;
            transition doDispenseRequest
                first sendDispenseRequest
                do send new DispenseRequest("nurse1", receivePrescription.presc) via dispenseReqPort
                then waitForRequest;
        }
    }

    part def DatabaseServer {
        port authPort : AuthPort;
        port prescPort : PrescriptionPort;
        port alertPort : ~AlertPort;

        exhibit state dbBehavior {
            entry; then idle;
            state idle;
            transition handleAuth
                first idle
                accept cred : Credentials via authPort
                do send new Session("token123", cred.userId, true) via authPort
                then idle;
            transition handlePrescReq
                first idle
                accept req : PrescriptionRequest via prescPort
                do send new Prescription(req.patientId, req.medicationId, 10.0) via prescPort
                then idle;
        }
    }

    part def InventoryManagementUnit {
        port invPort : InventoryPort;
        port alertPort : ~AlertPort;

        attribute lowStockThreshold : Integer = 10;

        exhibit state invBehavior {
            entry; then idle;
            state idle;
            transition handleCheck
                first idle
                accept req : StockCheckRequest via invPort
                then respondToCheck;
            state respondToCheck;
            transition sendResponse
                first respondToCheck
                do send new StockCheckResponse(true, 5, new Medication("med1001", "Aspirin", 5, "2026-01-01", 25.0, "BC1001")) via invPort
                then checkLowStock;
            state checkLowStock;
            transition isLow
                first checkLowStock
                if 5 < lowStockThreshold
                then sendLowAlert;
            transition notLow
                first checkLowStock
                if 5 >= lowStockThreshold
                then idle;
            state sendLowAlert;
            transition doSendAlert
                first sendLowAlert
                do send new AlertMsg("WARNING", "Low stock detected") via alertPort
                then idle;
            transition handleUpdate
                first idle
                accept upd : StockUpdate via invPort
                then idle;
        }
    }

    part def VerificationModule {
        port verPort : VerificationPort;
        port alertPort : ~AlertPort;

        exhibit state verBehavior {
            entry; then idle;
            state idle;
            transition handleVerify
                first idle
                accept req : VerificationRequest via verPort
                do send new VerificationResponse(true) via verPort
                then idle;
        }
    }

    part def DispensingMechanism {
        port dispPort : DispensePort;
        port alertPort : ~AlertPort;

        exhibit state dispBehavior {
            entry; then idle;
            state idle;
            transition handleDispense
                first idle
                accept cmd : DispenseCommand via dispPort
                do send new DispenseConfirmation(true, cmd.medicationId) via dispPort
                then idle;
        }
    }

    part def SafetyMonitor {
        port alertPort : AlertPort;
        port auditPort : AuditPort;

        exhibit state monitorBehavior {
            entry; then monitoring;
            state monitoring;
            transition handleAlert
                first monitoring
                accept alt : AlertMsg via alertPort
                then monitoring;
            transition handleAudit
                first monitoring
                accept ae : AuditEntry via auditPort
                then monitoring;
        }
    }

    part def DispensingController {
        port dispenseReqPort : DispenseRequestPort;
        port invPort : ~InventoryPort;
        port verPort : ~VerificationPort;
        port dispPort : ~DispensePort;
        port auditPort : ~AuditPort;
        port alertPort : ~AlertPort;

        exhibit state controllerBehavior {
            entry; then idle;
            state idle;
            transition begin
                first idle
                accept req : DispenseRequest via dispenseReqPort
                then checkingInventory;
            state checkingInventory;
            transition sendCheck
                first checkingInventory
                do send new StockCheckRequest(begin.req.prescription.medicationId) via invPort
                then waitForStockResponse;
            state waitForStockResponse;
            transition receiveAvailable
                first waitForStockResponse
                accept resp : StockCheckResponse via invPort
                if resp.available
                then verifying;
            transition receiveUnavailable
                first waitForStockResponse
                accept resp : StockCheckResponse via invPort
                if not resp.available
                then errorState;
            state verifying;
            transition sendVerification
                first verifying
                do send new VerificationRequest(begin.req.prescription.medicationId, receiveAvailable.resp.medication.barcode) via verPort
                then waitForVerification;
            state waitForVerification;
            transition receiveMatch
                first waitForVerification
                accept vResp : VerificationResponse via verPort
                if vResp.match
                then dispensing;
            transition receiveMismatch
                first waitForVerification
                accept vResp : VerificationResponse via verPort
                if not vResp.match
                then errorState;
            state dispensing;
            transition sendDispense
                first dispensing
                do send new DispenseCommand(begin.req.prescription.medicationId, begin.req.prescription.dosage) via dispPort
                then waitForDispenseConfirmation;
            state waitForDispenseConfirmation;
            transition receiveSuccess
                first waitForDispenseConfirmation
                accept conf : DispenseConfirmation via dispPort
                if conf.success
                then updatingStock;
            transition receiveFailure
                first waitForDispenseConfirmation
                accept conf : DispenseConfirmation via dispPort
                if not conf.success
                then errorState;
            state updatingStock;
            transition sendStockUpdate
                first updatingStock
                do send new StockUpdate(begin.req.prescription.medicationId, -1) via invPort
                then logging;
            state logging;
            transition sendAudit
                first logging
                do send new AuditEntry("2025-01-01T10:00", begin.req.userId, "Dispense", begin.req.prescription.medicationId) via auditPort
                then idle;
            state errorState;
            transition sendError
                first errorState
                do send new AlertMsg("ERROR", "Dispensing process failed") via alertPort
                then idle;
        }
    }

    part def DispensingSystem {
        part ui : UserInterface;
        part db : DatabaseServer;
        part inv : InventoryManagementUnit;
        part ver : VerificationModule;
        part disp : DispensingMechanism;
        part mon : SafetyMonitor;
        part ctrl : DispensingController;

        interface auth_if : AuthInterface connect ui.authPort to db.authPort;
        interface presc_if : PrescriptionInterface connect ui.prescPort to db.prescPort;
        interface dispReq_if : DispenseRequestInterface connect ui.dispenseReqPort to ctrl.dispenseReqPort;
        interface inv_if : InventoryInterface connect ctrl.invPort to inv.invPort;
        interface ver_if : VerificationInterface connect ctrl.verPort to ver.verPort;
        interface disp_if : DispenseInterface connect ctrl.dispPort to disp.dispPort;
        interface audit_if : AuditInterface connect ctrl.auditPort to mon.auditPort;
        interface alert_ui_if : AlertInterface connect ui.alertPort to mon.alertPort;
        interface alert_db_if : AlertInterface connect db.alertPort to mon.alertPort;
        interface alert_inv_if : AlertInterface connect inv.alertPort to mon.alertPort;
        interface alert_ver_if : AlertInterface connect ver.alertPort to mon.alertPort;
        interface alert_disp_if : AlertInterface connect disp.alertPort to mon.alertPort;
        interface alert_ctrl_if : AlertInterface connect ctrl.alertPort to mon.alertPort;

        satisfy SecureAuthentication by db;
        satisfy RealTimeInventory by inv;
        satisfy VerificationBeforeDispensing by ver;
        satisfy AccurateDispensing by disp;
        satisfy SafetyMonitoring by mon;
        satisfy AuditTrail by ctrl;
    }
}
