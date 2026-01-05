package MedicalEquipmentManagementSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def EquipmentID;
    attribute def LocationID;
    attribute def TechnicianID;
    attribute def PatientID;
    attribute def WorkOrderID;
    
    enum def EquipmentStatusKind {
        available;
        inUse;
        maintenanceScheduled;
        underMaintenance;
        outOfService;
        calibrationRequired;
    }
    
    enum def AlertSeverity {
        low;
        medium;
        high;
        critical;
    }
    
    attribute def UsageMetrics {
        attribute operatingHours :> ISQ::time;
        attribute cycleCount : Integer;
        attribute utilizationRate : Real;
    }
    
    attribute def MaintenanceRecord {
        attribute workOrderID : WorkOrderID;
        attribute technicianID : TechnicianID;
        attribute taskDescription : String;
        attribute isCompleted : Boolean;
    }
    
    attribute def CalibrationRecord {
        attribute calibratedBy : TechnicianID;
        attribute calibrationStatus : Boolean;
    }
    
    item def MedicalEquipment {
        attribute equipmentID : EquipmentID;
        attribute currentLocation : LocationID;
        attribute status : EquipmentStatusKind;
        attribute assignedPatient : PatientID[0..1];
        attribute usageMetrics : UsageMetrics;
        attribute maintenanceHistory : MaintenanceRecord[*];
        attribute calibrationHistory : CalibrationRecord[*];
        attribute isOperational : Boolean;
    }
    
    item def VentilatorUnit :> MedicalEquipment {
        attribute oxygenLevel :> ISQ::volumeFlowRate;
        attribute pressureLevel :> ISQ::pressure;
        attribute alarmStatus : Boolean;
    }
    
    item def InfusionPump :> MedicalEquipment {
        attribute flowRate :> ISQ::volumeFlowRate;
        attribute volumeDelivered :> ISQ::volume;
        attribute batteryLevel : Real;
        attribute remainingVolume :> ISQ::volume;
    }
    
    item def PatientMonitor :> MedicalEquipment {
        attribute heartRate : Real;
        attribute bloodPressure : Real;
        attribute temperature :> ISQ::temperature;
        attribute spo2Level : Real;
    }
    
    item def LocationUpdate {
        attribute equipmentID : EquipmentID;
        attribute newLocation : LocationID;
    }
    
    item def MaintenanceRequest {
        attribute equipmentID : EquipmentID;
        attribute priority : AlertSeverity;
        attribute reason : String;
    }
    
    item def AllocationRequest {
        attribute equipmentType : String;
        attribute requestedLocation : LocationID;
        attribute patientID : PatientID;
        attribute urgency : AlertSeverity;
    }
    
    item def AllocationResponse {
        attribute equipmentID : EquipmentID;
        attribute allocated : Boolean;
        attribute estimatedDeliveryTime :> ISQ::time;
    }
    
    port def EquipmentDataPort {
        out equipmentStatus : EquipmentStatusKind;
        out usageData : UsageMetrics;
        in controlCommand : String;
        out locationData : LocationID;
    }
    
    port def MaintenancePort {
        in maintenanceRequest : MaintenanceRequest;
        out maintenanceSchedule : MaintenanceRecord;
        out workOrder : MaintenanceRecord;
    }
    
    port def AllocationPort {
        in allocationRequest : AllocationRequest;
        out allocationResponse : AllocationResponse;
    }
    
    port def AlertPort {
        out alertSeverity : AlertSeverity;
        out alertMessage : String;
        out equipmentID : EquipmentID;
    }
    
    action def MonitorEquipmentStatus {
        in equipment : MedicalEquipment;
        out requiresMaintenance : Boolean;
        out requiresCalibration : Boolean;
        out isAvailable : Boolean;
    }
    
    action def UpdateLocation {
        in locationUpdate : LocationUpdate;
        out updated : Boolean;
    }
    
    action def ScheduleMaintenance {
        in equipmentID : EquipmentID;
        in priority : AlertSeverity;
        out maintenanceRecord : MaintenanceRecord;
    }
    
    action def AllocateEquipment {
        in request : AllocationRequest;
        in availableEquipment : MedicalEquipment[*];
        out response : AllocationResponse;
    }
    
    action def PerformMaintenance {
        in workOrder : MaintenanceRecord;
        in equipmentID : EquipmentID;
        out completedRecord : MaintenanceRecord;
    }
    
    action def GenerateAlert {
        in equipmentID : EquipmentID;
        in severity : AlertSeverity;
        in message : String;
        out alertSent : Boolean;
    }
    
    action def CalculateUtilization {
        in equipment : MedicalEquipment[*];
        in period :> ISQ::time;
        out utilizationReport : String;
    }
    
    action def PerformCalibration {
        in equipmentID : EquipmentID;
        out calibrationRecord : CalibrationRecord;
    }
    
    action def ManageEquipmentLifecycle {
        first start;
        then merge continuousMonitoring;
        
        action initializeInventory {
            action loadEquipmentDatabase;
            then action loadMaintenanceSchedules;
            then action initializeTracking;
        }
        
        then continuousMonitoring;
        
        action monitorFleet : MonitorEquipmentStatus[*] {
            in equipment : MedicalEquipment;
            out maintenanceFlag : Boolean;
            out calibrationFlag : Boolean;
            out availabilityFlag : Boolean;
        }
        
        then decide;
            if monitorFleet.maintenanceFlag then scheduleMaintenance;
            if monitorFleet.calibrationFlag then scheduleCalibration;
        
        action scheduleMaintenance {
            action createMaintenanceOrder : ScheduleMaintenance {
                in equipmentID;
                in priority = AlertSeverity::high;
                out maintenanceRecord;
            }
            then action assignTechnician;
            then action notifyMaintenance : GenerateAlert {
                in severity = AlertSeverity::medium;
                out alertSent;
            }
        }
        then performMaintenanceWork;
        
        action scheduleCalibration {
            action createCalibrationOrder;
            then action assignCalibrationTechnician;
        }
        then performCalibrationWork;
        
        action performMaintenanceWork : PerformMaintenance {
            in workOrder;
            in equipmentID;
            out completedRecord;
        }
        then action updateMaintenanceHistory;
        then continuousMonitoring;
        
        action performCalibrationWork : PerformCalibration {
            in equipmentID;
            out calibrationRecord;
        }
        then action updateCalibrationHistory;
        then continuousMonitoring;
        
        action handleAllocationRequest {
            accept request : AllocationRequest;
            then action findAvailableEquipment;
            then action allocateAction : AllocateEquipment {
                in request;
                in availableEquipment;
                out response;
            }
            then decide;
                if allocateAction.response.allocated then assignToPatient;
            
            action assignToPatient {
                action updateEquipmentAssignment;
                then action trackDelivery;
            }
            then continuousMonitoring;
            
            action notifyUnavailable : GenerateAlert {
                in severity = AlertSeverity::high;
                out alertSent;
            }
        }
        then continuousMonitoring;
        
        action handleLocationUpdate {
            accept locationUpdate : LocationUpdate;
            then action updateLoc : UpdateLocation {
                in locationUpdate;
                out updated;
            }
            then action verifyLocation;
        }
        then continuousMonitoring;
        
        action generateUtilizationReports {
            action calculateUtil : CalculateUtilization {
                in equipment;
                in period = 720[h];
                out utilizationReport;
            }
            then action distributeReports;
        }
        then continuousMonitoring;
    }
    
    part def InventoryDatabase {
        attribute registeredEquipment : MedicalEquipment[*];
        
        port equipmentDataPort : EquipmentDataPort[*];
        port maintenancePort : MaintenancePort;
        port allocationPort : AllocationPort;
        
        action def RegisterEquipment {
            in equipment : MedicalEquipment;
            out registered : Boolean;
        }
        
        action def QueryEquipment {
            in equipmentID : EquipmentID;
            out equipment : MedicalEquipment;
        }
        
        action def QueryByLocation {
            in location : LocationID;
            out equipmentList : MedicalEquipment[*];
        }
        
        action def UpdateEquipmentStatus {
            in equipmentID : EquipmentID;
            in newStatus : EquipmentStatusKind;
            out updated : Boolean;
        }
    }
    
    part def MaintenanceScheduler {
        attribute scheduledWork : MaintenanceRecord[*];
        
        port maintenancePort : MaintenancePort;
        
        action def CreateWorkOrder {
            in equipmentID : EquipmentID;
            in priority : AlertSeverity;
            out workOrder : MaintenanceRecord;
        }
        
        action def AssignTechnician {
            in workOrder : MaintenanceRecord;
            out assignedTechnician : TechnicianID;
        }
        
        action def CheckOverdue {
            out overdueEquipment : EquipmentID[*];
        }
    }
    
    part def UtilizationAnalyzer {
        action def TrackUsage {
            in equipmentID : EquipmentID;
            in usageData : UsageMetrics;
        }
        
        action def AnalyzeUtilization {
            in equipmentID : EquipmentID;
            in period :> ISQ::time;
            out utilizationRate : Real;
        }
        
        action def GenerateReport {
            out report : String;
        }
    }
    
    part def LocationTracker {
        action def UpdateEquipmentLocation {
            in locationUpdate : LocationUpdate;
            out updated : Boolean;
        }
        
        action def TrackMovement {
            in equipmentID : EquipmentID;
            out locationHistory : LocationUpdate[*];
        }
        
        action def VerifyLocation {
            in equipmentID : EquipmentID;
            in expectedLocation : LocationID;
            out verified : Boolean;
        }
    }
    
    part def AllocationManager {
        port allocationPort : AllocationPort;
        
        action def ProcessRequest {
            in request : AllocationRequest;
            out response : AllocationResponse;
        }
        
        action def FindAvailableEquipment {
            in equipmentType : String;
            in location : LocationID;
            out availableEquipment : MedicalEquipment[*];
        }
        
        action def AssignEquipment {
            in equipmentID : EquipmentID;
            in patientID : PatientID;
            out assigned : Boolean;
        }
    }
    
    part def AlertSystem {
        port alertPort : AlertPort[*];
        
        action def MonitorConditions {
            in equipment : MedicalEquipment;
            out alertRequired : Boolean;
        }
        
        action def IssueAlert {
            in equipmentID : EquipmentID;
            in severity : AlertSeverity;
            in message : String;
            out alertSent : Boolean;
        }
        
        action def NotifyStaff {
            in alertMessage : String;
            out notified : Boolean;
        }
    }
    
    part def CalibrationManager {
        attribute calibrationSchedule : CalibrationRecord[*];
        
        action def ScheduleCalibration {
            in equipmentID : EquipmentID;
            out scheduled : Boolean;
        }
        
        action def PerformCalibrationCheck {
            in equipmentID : EquipmentID;
            out calibrationValid : Boolean;
        }
        
        action def RecordCalibration {
            in equipmentID : EquipmentID;
            in calibrationRecord : CalibrationRecord;
        }
    }
    
    part medicalEquipmentSystem {
        part inventoryDB : InventoryDatabase {
            port equipmentData : EquipmentDataPort[*];
            port maintenance : MaintenancePort;
            port allocation : AllocationPort;
        }
        
        part maintenanceScheduler : MaintenanceScheduler {
            port maintenance : MaintenancePort;
        }
        
        part utilizationAnalyzer : UtilizationAnalyzer;
        
        part locationTracker : LocationTracker;
        
        part allocationManager : AllocationManager {
            port allocation : AllocationPort;
        }
        
        part alertSystem : AlertSystem {
            port alerts : AlertPort[*];
        }
        
        part calibrationManager : CalibrationManager;
        
        part ventilators : VentilatorUnit[15] {
            port dataPort : EquipmentDataPort;
        }
        
        part infusionPumps : InfusionPump[25] {
            port dataPort : EquipmentDataPort;
        }
        
        part patientMonitors : PatientMonitor[20] {
            port dataPort : EquipmentDataPort;
        }
        
        connect ventilators.dataPort to inventoryDB.equipmentData;
        connect infusionPumps.dataPort to inventoryDB.equipmentData;
        connect patientMonitors.dataPort to inventoryDB.equipmentData;
        
        connect maintenanceScheduler.maintenance to inventoryDB.maintenance;
        connect allocationManager.allocation to inventoryDB.allocation;
        
        perform action manageEquipment : ManageEquipmentLifecycle;
    }
    
    requirement def EquipmentAvailabilityRequirement {
        doc /* Medical equipment shall maintain minimum 95% availability during operational hours to ensure patient care continuity. */
        
        subject equipment : MedicalEquipment;
        
        require constraint {
            equipment.isOperational == true and
            equipment.status != EquipmentStatusKind::outOfService
        }
    }
    
    requirement def MaintenanceComplianceRequirement {
        doc /* All medical equipment shall undergo preventive maintenance every 1000 operating hours or 6 months, whichever occurs first, to ensure safety and reliability. */
        
        subject equipment : MedicalEquipment;
        
        require constraint {
            equipment.usageMetrics.operatingHours <= 1000[h]
        }
    }
    
    requirement def CalibrationRequirement {
        doc /* Critical medical equipment shall be calibrated according to manufacturer specifications and regulatory standards at intervals not exceeding 12 months. */
        
        subject equipment : MedicalEquipment;
    }
    
    requirement def LocationTrackingRequirement {
        doc /* The system shall track equipment location with 98% accuracy to enable rapid deployment and prevent loss. */
    }
    
    requirement def AllocationEfficiencyRequirement {
        doc /* Equipment allocation requests shall be processed and fulfilled within 5 minutes for routine requests and 2 minutes for urgent requests. */
    }
    
    requirement def TraceabilityRequirement {
        doc /* The system shall maintain complete traceability of equipment usage, maintenance activities, calibration records, and patient assignments for regulatory compliance and quality assurance. */
    }
    
    requirement systemRequirements {
        doc /* Medical Equipment Management System shall optimize equipment utilization, ensure maintenance compliance, track asset locations, and support rapid allocation to clinical areas while maintaining complete operational traceability. */
        
        require equipmentAvailability : EquipmentAvailabilityRequirement;
        require maintenanceCompliance : MaintenanceComplianceRequirement;
        require calibrationCompliance : CalibrationRequirement;
        require locationTracking : LocationTrackingRequirement;
        require allocationEfficiency : AllocationEfficiencyRequirement;
        require traceability : TraceabilityRequirement;
    }
}
