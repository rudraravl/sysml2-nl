package MedicalEquipmentManagementSystem {

    import ScalarValues::*;
    import ISQ::*;

    attribute def Percentage :> Real {
        unit = "%";
    }

    attribute def CurrencyUSD :> Real {
        unit = "USD";
    }

    attribute def Days :> Real {
        unit = "d";
    }

    attribute def Hours :> Real {
        unit = "h";
    }

    attribute def Minutes :> Real {
        unit = "min";
    }

    attribute def Identifier :> String;
    attribute def Timestamp :> String;

    enum def EquipmentStatus {
        enum available;
        enum reserved;
        enum assigned;
        enum inUse;
        enum cleaning;
        enum maintenanceDue;
        enum underMaintenance;
        enum quarantine;
        enum retired;
    }

    enum def PriorityLevel {
        enum routine;
        enum urgent;
        enum critical;
    }

    enum def WorkOrderStatus {
        enum opened;
        enum triaged;
        enum scheduled;
        enum inProgress;
        enum verified;
        enum closed;
        enum escalated;
    }

    enum def RiskClass {
        enum low;
        enum medium;
        enum high;
        enum lifeSupport;
    }

    item def EquipmentTelemetry {
        attribute equipmentId : Identifier;
        attribute batteryLevel : Percentage;
        attribute temperatureC : Real;
        attribute locationId : Identifier;
        attribute operatingHours : Hours;
        attribute faultCode : String;
        attribute measuredAt : Timestamp;
    }

    item def EquipmentRequest {
        attribute requestId : Identifier;
        attribute requestedType : String;
        attribute requestedByDepartment : String;
        attribute priority : PriorityLevel;
        attribute neededBy : Timestamp;
        attribute patientCareArea : String;
    }

    item def AssignmentRecord {
        attribute assignmentId : Identifier;
        attribute equipmentId : Identifier;
        attribute departmentId : Identifier;
        attribute assignedTo : String;
        attribute assignedAt : Timestamp;
        attribute expectedReturnAt : Timestamp;
    }

    item def MaintenanceWorkOrder {
        attribute workOrderId : Identifier;
        attribute equipmentId : Identifier;
        attribute priority : PriorityLevel;
        attribute status : WorkOrderStatus;
        attribute issueDescription : String;
        attribute openedAt : Timestamp;
        attribute dueWithin : Hours;
    }

    item def CleaningRecord {
        attribute cleaningId : Identifier;
        attribute equipmentId : Identifier;
        attribute disinfectantLot : String;
        attribute completedBy : String;
        attribute completedAt : Timestamp;
        attribute passedInspection : Boolean;
    }

    item def ComplianceReport {
        attribute reportId : Identifier;
        attribute reportingPeriodStart : Timestamp;
        attribute reportingPeriodEnd : Timestamp;
        attribute totalAssets : Integer;
        attribute overdueMaintenanceCount : Integer;
        attribute utilizationRate : Percentage;
        attribute auditPassRate : Percentage;
    }

    item def AlertMessage {
        attribute alertId : Identifier;
        attribute equipmentId : Identifier;
        attribute priority : PriorityLevel;
        attribute message : String;
        attribute createdAt : Timestamp;
        attribute acknowledged : Boolean;
    }

    port def TelemetryInPort {
        in item telemetry : EquipmentTelemetry;
    }

    port def RequestInPort {
        in item request : EquipmentRequest;
    }

    port def AssignmentOutPort {
        out item assignment : AssignmentRecord;
    }

    port def WorkOrderOutPort {
        out item workOrder : MaintenanceWorkOrder;
    }

    port def CleaningOutPort {
        out item cleaningTask : CleaningRecord;
    }

    port def AlertOutPort {
        out item alert : AlertMessage;
    }

    port def ReportOutPort {
        out item report : ComplianceReport;
    }

    port def InventoryQueryPort {
        in item request : EquipmentRequest;
        out item assignment : AssignmentRecord;
    }

    part def MedicalEquipment {
        attribute equipmentId : Identifier;
        attribute serialNumber : String;
        attribute manufacturer : String;
        attribute modelName : String;
        attribute equipmentType : String;
        attribute riskClass : RiskClass;
        attribute status : EquipmentStatus;
        attribute acquisitionCost : CurrencyUSD;
        attribute operatingHours : Hours;
        attribute batteryLevel : Percentage;
        attribute lastKnownLocationId : Identifier;
        attribute lastCleanedAt : Timestamp;
        attribute lastPreventiveMaintenanceAt : Timestamp;
        attribute preventiveMaintenanceInterval : Days;
        attribute calibrationInterval : Days;
        attribute expectedServiceLife : Days;

        port telemetryPort : TelemetryInPort;
        port alertPort : AlertOutPort;

        state def EquipmentLifecycle {
            entry action initializeAsset;
            state Available;
            state Reserved;
            state Assigned;
            state InUse;
            state Cleaning;
            state MaintenanceDue;
            state UnderMaintenance;
            state Quarantine;
            state Retired;

            transition first Available;
            transition Available_to_Reserved
                first Available then Reserved
                accept requestEquipment
                if status == EquipmentStatus::available;

            transition Reserved_to_Assigned
                first Reserved then Assigned
                accept confirmAssignment;

            transition Assigned_to_InUse
                first Assigned then InUse
                accept beginClinicalUse;

            transition InUse_to_Cleaning
                first InUse then Cleaning
                accept endClinicalUse;

            transition Cleaning_to_Available
                first Cleaning then Available
                accept cleaningPassed
                if status != EquipmentStatus::quarantine;

            transition Any_to_MaintenanceDue
                first Available then MaintenanceDue
                accept maintenanceThresholdReached;

            transition MaintenanceDue_to_UnderMaintenance
                first MaintenanceDue then UnderMaintenance
                accept openWorkOrder;

            transition UnderMaintenance_to_Available
                first UnderMaintenance then Available
                accept maintenanceVerified;

            transition Any_to_Quarantine
                first InUse then Quarantine
                accept safetyFaultDetected;

            transition Quarantine_to_UnderMaintenance
                first Quarantine then UnderMaintenance
                accept biomedicalReview;

            transition Any_to_Retired
                first Available then Retired
                accept retireAsset;
        }

        action def UpdateTelemetry {
            in item telemetry : EquipmentTelemetry;
            out item alert : AlertMessage;
        }

        action def DetermineMaintenanceNeed {
            in operatingHours : Hours;
            in preventiveMaintenanceInterval : Days;
            out maintenanceRequired : Boolean;
        }
    }

    part def InventoryRepository {
        attribute totalAssetCount : Integer;
        attribute availableAssetCount : Integer;
        attribute reservedAssetCount : Integer;
        attribute assignedAssetCount : Integer;
        attribute maintenanceAssetCount : Integer;
        attribute quarantinedAssetCount : Integer;

        port requestPort : InventoryQueryPort;
        port assignmentPort : AssignmentOutPort;

        action def FindBestAvailableAsset {
            in item request : EquipmentRequest;
            out item assignment : AssignmentRecord;
        }

        action def ReserveAsset {
            in equipmentId : Identifier;
            in departmentId : Identifier;
            out reservationAccepted : Boolean;
        }

        action def UpdateAssetStatus {
            in equipmentId : Identifier;
            in newStatus : EquipmentStatus;
        }
    }

    part def LocationTrackingSubsystem {
        attribute locationAccuracyMeters : Real;
        attribute updateIntervalMinutes : Minutes;

        port telemetryIn : TelemetryInPort;
        port alertOut : AlertOutPort;

        action def LocateAsset {
            in equipmentId : Identifier;
            out locationId : Identifier;
        }

        action def DetectUnauthorizedMovement {
            in item telemetry : EquipmentTelemetry;
            out unauthorizedMovement : Boolean;
        }
    }

    part def MaintenanceManagementSubsystem {
        attribute preventiveMaintenanceComplianceTarget : Percentage;
        attribute criticalRepairResponseTarget : Hours;
        attribute routineRepairResponseTarget : Hours;

        port telemetryIn : TelemetryInPort;
        port workOrderOut : WorkOrderOutPort;
        port alertOut : AlertOutPort;

        action def CreatePreventiveMaintenanceOrder {
            in equipmentId : Identifier;
            in riskClass : RiskClass;
            out item workOrder : MaintenanceWorkOrder;
        }

        action def CreateCorrectiveMaintenanceOrder {
            in item telemetry : EquipmentTelemetry;
            out item workOrder : MaintenanceWorkOrder;
        }

        action def VerifyMaintenanceCompletion {
            in workOrderId : Identifier;
            out assetReleased : Boolean;
        }

        state def WorkOrderLifecycle {
            state Opened;
            state Triaged;
            state Scheduled;
            state InProgress;
            state Verified;
            state Closed;
            state Escalated;

            transition first Opened;
            transition Opened_to_Triaged first Opened then Triaged accept triageWorkOrder;
            transition Triaged_to_Scheduled first Triaged then Scheduled accept assignTechnician;
            transition Scheduled_to_InProgress first Scheduled then InProgress accept startRepair;
            transition InProgress_to_Verified first InProgress then Verified accept completeRepair;
            transition Verified_to_Closed first Verified then Closed accept releaseAsset;
            transition Triaged_to_Escalated first Triaged then Escalated accept criticalDelay;
            transition Escalated_to_InProgress first Escalated then InProgress accept emergencyDispatch;
        }
    }

    part def CleaningAndSterilizationSubsystem {
        attribute cleaningTurnaroundTarget : Minutes;
        attribute inspectionPassTarget : Percentage;

        port assignmentIn : AssignmentOutPort;
        port cleaningOut : CleaningOutPort;
        port alertOut : AlertOutPort;

        action def ScheduleCleaning {
            in equipmentId : Identifier;
            out item cleaningTask : CleaningRecord;
        }

        action def VerifyCleaning {
            in item cleaningTask : CleaningRecord;
            out releasedToInventory : Boolean;
        }
    }

    part def ClinicalDepartmentInterface {
        attribute departmentId : Identifier;
        attribute departmentName : String;
        attribute authorizedRequesterCount : Integer;

        port requestOut : RequestInPort;
        port assignmentIn : AssignmentOutPort;
        port alertIn : AlertOutPort;

        action def SubmitEquipmentRequest {
            out item request : EquipmentRequest;
        }

        action def AcknowledgeAssignment {
            in item assignment : AssignmentRecord;
            out accepted : Boolean;
        }
    }

    part def ComplianceAndReportingSubsystem {
        attribute auditRetentionPeriodDays : Days;
        attribute reportingIntervalDays : Days;

        port telemetryIn : TelemetryInPort;
        port reportOut : ReportOutPort;
        port alertIn : AlertOutPort;

        action def GenerateComplianceReport {
            in periodStart : Timestamp;
            in periodEnd : Timestamp;
            out item report : ComplianceReport;
        }

        action def AuditAssetHistory {
            in equipmentId : Identifier;
            out auditPassed : Boolean;
        }
    }

    part def AlertingSubsystem {
        attribute unacknowledgedCriticalAlertLimit : Integer;
        attribute escalationDelayMinutes : Minutes;

        port alertIn : AlertOutPort;
        port alertOut : AlertOutPort;

        action def RouteAlert {
            in item alert : AlertMessage;
        }

        action def EscalateAlert {
            in item alert : AlertMessage;
            out escalationSent : Boolean;
        }
    }

    part def MedicalEquipmentManagementSystem {
        attribute systemId : Identifier = "MEMS-001";
        attribute primaryFunction : String =
            "Manage the hospital medical equipment fleet by tracking asset location, availability, assignment, cleaning, maintenance, safety status, and compliance evidence so clinical staff can obtain safe, ready-to-use equipment when needed.";

        attribute minimumAvailabilityTarget : Percentage = 92.0;
        attribute preventiveMaintenanceComplianceTarget : Percentage = 98.0;
        attribute criticalAlertAcknowledgementTarget : Minutes = 5.0;

        part inventory : InventoryRepository;
        part locationTracking : LocationTrackingSubsystem;
        part maintenance : MaintenanceManagementSubsystem;
        part cleaning : CleaningAndSterilizationSubsystem;
        part reporting : ComplianceAndReportingSubsystem;
        part alerting : AlertingSubsystem;
        part emergencyDepartmentInterface : ClinicalDepartmentInterface {
            attribute departmentId = "ED";
            attribute departmentName = "Emergency Department";
        }
        part intensiveCareInterface : ClinicalDepartmentInterface {
            attribute departmentId = "ICU";
            attribute departmentName = "Intensive Care Unit";
        }

        part infusionPump : MedicalEquipment {
            attribute equipmentId = "EQ-INF-0001";
            attribute serialNumber = "IP-77A-39201";
            attribute manufacturer = "CareFlow Medical";
            attribute modelName = "InfusePro 700";
            attribute equipmentType = "Infusion Pump";
            attribute riskClass = RiskClass::high;
            attribute status = EquipmentStatus::available;
            attribute acquisitionCost = 4200.0;
            attribute operatingHours = 1350.0;
            attribute batteryLevel = 96.0;
            attribute lastKnownLocationId = "CENTRAL-STORES-A3";
            attribute preventiveMaintenanceInterval = 180.0;
            attribute calibrationInterval = 365.0;
            attribute expectedServiceLife = 2555.0;
        }

        part ventilator : MedicalEquipment {
            attribute equipmentId = "EQ-VEN-0007";
            attribute serialNumber = "VN-X9-11804";
            attribute manufacturer = "RespiraTech";
            attribute modelName = "Ventisafe X9";
            attribute equipmentType = "Ventilator";
            attribute riskClass = RiskClass::lifeSupport;
            attribute status = EquipmentStatus::assigned;
            attribute acquisitionCost = 38500.0;
            attribute operatingHours = 6220.0;
            attribute batteryLevel = 88.0;
            attribute lastKnownLocationId = "ICU-BED-12";
            attribute preventiveMaintenanceInterval = 90.0;
            attribute calibrationInterval = 180.0;
            attribute expectedServiceLife = 2920.0;
        }

        part defibrillator : MedicalEquipment {
            attribute equipmentId = "EQ-DEF-0012";
            attribute serialNumber = "DF-Z3-80012";
            attribute manufacturer = "CardioSecure";
            attribute modelName = "ShockReady Z3";
            attribute equipmentType = "Defibrillator";
            attribute riskClass = RiskClass::lifeSupport;
            attribute status = EquipmentStatus::available;
            attribute acquisitionCost = 18800.0;
            attribute operatingHours = 742.0;
            attribute batteryLevel = 100.0;
            attribute lastKnownLocationId = "ED-TRAUMA-2";
            attribute preventiveMaintenanceInterval = 60.0;
            attribute calibrationInterval = 180.0;
            attribute expectedServiceLife = 2920.0;
        }

        connect emergencyDepartmentInterface.requestOut to inventory.requestPort;
        connect intensiveCareInterface.requestOut to inventory.requestPort;
        connect inventory.assignmentPort to emergencyDepartmentInterface.assignmentIn;
        connect inventory.assignmentPort to intensiveCareInterface.assignmentIn;

        connect infusionPump.telemetryPort to locationTracking.telemetryIn;
        connect ventilator.telemetryPort to locationTracking.telemetryIn;
        connect defibrillator.telemetryPort to locationTracking.telemetryIn;

        connect infusionPump.telemetryPort to maintenance.telemetryIn;
        connect ventilator.telemetryPort to maintenance.telemetryIn;
        connect defibrillator.telemetryPort to maintenance.telemetryIn;

        connect inventory.assignmentPort to cleaning.assignmentIn;
        connect locationTracking.alertOut to alerting.alertIn;
        connect maintenance.alertOut to alerting.alertIn;
        connect cleaning.alertOut to alerting.alertIn;

        connect maintenance.workOrderOut to reporting.telemetryIn;
        connect locationTracking.telemetryIn to reporting.telemetryIn;
        connect reporting.reportOut to alerting.alertOut;

        action def FulfillClinicalEquipmentNeed {
            in item request : EquipmentRequest;
            out item assignment : AssignmentRecord;

            first start;
            then findAsset : inventory.FindBestAvailableAsset;
            then reserve : inventory.ReserveAsset;
            then notifyDepartment : emergencyDepartmentInterface.AcknowledgeAssignment;
            then done;
        }

        action def MonitorEquipmentFleet {
            in item telemetry : EquipmentTelemetry;
            out item alert : AlertMessage;

            first receiveTelemetry;
            then updateLocation : locationTracking.LocateAsset;
            then checkUnauthorizedMovement : locationTracking.DetectUnauthorizedMovement;
            then checkMaintenance : maintenance.CreateCorrectiveMaintenanceOrder;
            then routeAlert : alerting.RouteAlert;
            then completeMonitoringCycle;
        }

        action def ReturnCleanAndReleaseEquipment {
            in equipmentId : Identifier;
            out releasedToInventory : Boolean;

            first clinicalReturn;
            then scheduleCleaning : cleaning.ScheduleCleaning;
            then verifyCleaning : cleaning.VerifyCleaning;
            then updateAvailable : inventory.UpdateAssetStatus;
            then releaseComplete;
        }
    }

    requirement def HighLevelPrimaryFunctionRequirement {
        id = "REQ-MEMS-001";
        text = "The Medical Equipment Management System shall provide centralized visibility and control of medical equipment availability, location, assignment, cleaning, maintenance, safety status, and compliance records.";
    }

    requirement def AvailabilityRequirement {
        id = "REQ-MEMS-002";
        text = "The system shall maintain at least 92 percent availability for non-retired equipment required for clinical operations.";
        attribute requiredAvailability : Percentage = 92.0;
    }

    requirement def LocationTrackingRequirement {
        id = "REQ-MEMS-003";
        text = "The system shall update asset location records within 2 minutes of receiving telemetry from tracked medical equipment.";
        attribute maximumLocationUpdateDelay : Minutes = 2.0;
    }

    requirement def MaintenanceComplianceRequirement {
        id = "REQ-MEMS-004";
        text = "The system shall identify preventive maintenance due conditions and generate work orders before the equipment exceeds its maintenance interval.";
        attribute requiredCompliance : Percentage = 98.0;
    }

    requirement def CriticalAlertRequirement {
        id = "REQ-MEMS-005";
        text = "The system shall route critical safety and life-support equipment alerts for acknowledgement within 5 minutes.";
        attribute maximumCriticalAcknowledgementTime : Minutes = 5.0;
    }

    requirement def CleaningReleaseRequirement {
        id = "REQ-MEMS-006";
        text = "The system shall prevent returned clinical equipment from being reassigned until cleaning is recorded and inspection is passed.";
    }

    requirement def AuditRequirement {
        id = "REQ-MEMS-007";
        text = "The system shall retain traceable asset history for assignments, cleaning, maintenance, alerts, and compliance reports for at least 2555 days.";
        attribute retentionPeriod : Days = 2555.0;
    }

    satisfy HighLevelPrimaryFunctionRequirement by MedicalEquipmentManagementSystem;
    satisfy AvailabilityRequirement by MedicalEquipmentManagementSystem::inventory;
    satisfy LocationTrackingRequirement by MedicalEquipmentManagementSystem::locationTracking;
    satisfy MaintenanceComplianceRequirement by MedicalEquipmentManagementSystem::maintenance;
    satisfy CriticalAlertRequirement by MedicalEquipmentManagementSystem::alerting;
    satisfy CleaningReleaseRequirement by MedicalEquipmentManagementSystem::cleaning;
    satisfy AuditRequirement by MedicalEquipmentManagementSystem::reporting;

    constraint def AvailabilityCalculation {
        in availableAssets : Integer;
        in totalActiveAssets : Integer;
        in availability : Percentage;
        availability == (availableAssets / totalActiveAssets) * 100.0;
    }

    constraint def MaintenanceDueCondition {
        in daysSinceLastMaintenance : Days;
        in preventiveMaintenanceInterval : Days;
        out maintenanceDue : Boolean;
        maintenanceDue == daysSinceLastMaintenance >= preventiveMaintenanceInterval;
    }

    constraint def BatteryAlertCondition {
        in batteryLevel : Percentage;
        out alertRequired : Boolean;
        alertRequired == batteryLevel <= 20.0;
    }

    constraint def LifeSupportEscalationCondition {
        in riskClass : RiskClass;
        in priority : PriorityLevel;
        out escalate : Boolean;
        escalate == riskClass == RiskClass::lifeSupport and priority == PriorityLevel::critical;
    }

    objective def FleetReadinessObjective {
        doc /* Maximize safe clinical readiness of medical equipment by minimizing search time, avoiding overdue maintenance, enforcing cleaning gates, and preserving auditable compliance evidence. */
    }

    view def ManagementOperationalView {
        expose MedicalEquipmentManagementSystem;
        expose MedicalEquipmentManagementSystem::inventory;
        expose MedicalEquipmentManagementSystem::locationTracking;
        expose MedicalEquipmentManagementSystem::maintenance;
        expose MedicalEquipmentManagementSystem::cleaning;
        expose MedicalEquipmentManagementSystem::reporting;
        expose MedicalEquipmentManagementSystem::alerting;
    }
}