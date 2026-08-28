package 'Medical Equipment Management System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import Time::*;
    private import ISQ::DurationValue;
    private import SI::d;
    private import SI::s;
    
    item def EquipmentID;
    item def Location;
    item def WorkOrder;
    item def MaintenanceRecord;
    item def UsageRecord;
    item def Notification;
    item def UtilizationReport;
    
    item def AllocationRequest;
    item def ReturnEquipment;
    item def MaintenanceComplete;
    item def CalibrationComplete;
    item def RetireEquipment;
    
    enum def EquipmentStatus {
        available;
        inUse;
        underMaintenance;
        calibrationDue;
        retired;
    }
    
    enum def AlertType {
        malfunction;
        lowBattery;
        overdueMaintenance;
        unavailableRequest;
    }
    
    attribute def Request {
        attribute equipmentType : String;
        attribute requester : String;
        attribute urgency : String;
    }
    
    attribute def Assignment {
        attribute equipmentID : EquipmentID;
        attribute assignedTo : String;
        attribute deliveryLocation : Location;
    }
    
    attribute def Alert {
        attribute alertType : AlertType;
        attribute alertMessage : String;
        attribute timestamp : TimeInstantValue;
    }
    
    part def MedicalEquipment {
        attribute id : EquipmentID;
        attribute status : EquipmentStatus := EquipmentStatus::available;
        attribute location : Location;
        attribute operatingHours : DurationValue := 0 [s];
        attribute maintenanceDue : TimeInstantValue;
        attribute calibrationDue : TimeInstantValue;
        attribute batteryLevel : Real := 100;
        
        out port statusPort : MedicalEquipment;
        out port alertPort : Alert;
        in port commandPort;
        
        state lifecycle {
            entry; then Available;
            state Available;
            accept AllocationRequest
                then InUse;
            state InUse {
                entry assign status := EquipmentStatus::inUse;
            }
            accept ReturnEquipment
                then Available;
            accept at maintenanceDue
                then UnderMaintenance;
            state UnderMaintenance {
                entry assign status := EquipmentStatus::underMaintenance;
            }
            accept MaintenanceComplete
                then Available;
            accept at calibrationDue
                then Calibration;
            state Calibration {
                entry assign status := EquipmentStatus::calibrationDue;
            }
            accept CalibrationComplete
                then Available;
            accept RetireEquipment
                then Retired;
            state Retired {
                entry assign status := EquipmentStatus::retired;
            }
        }
    }
    
    part def Ventilator :> MedicalEquipment;
    part def InfusionPump :> MedicalEquipment;
    part def PatientMonitor :> MedicalEquipment;
    
    part def InventoryDatabase {
        attribute equipmentRecords : MedicalEquipment[*];
        in port updatePort : MedicalEquipment;
        out port queryPort : MedicalEquipment[*];
    }
    
    part def LocationTracker {
        in port equipmentPort : MedicalEquipment;
        out port locationPort : Location;
    }
    
    part def AllocationManager {
        in port requestPort : Request;
        out port assignmentPort : Assignment;
        in port equipmentStatusPort : MedicalEquipment[*];
    }
    
    part def MaintenanceScheduler {
        in port usagePort : MedicalEquipment;
        out port workOrderPort : WorkOrder;
        attribute maintenanceInterval : DurationValue := 180 [d];
    }
    
    part def CalibrationManager {
        in port usagePort : MedicalEquipment;
        out port workOrderPort : WorkOrder;
        attribute calibrationInterval : DurationValue := 90 [d];
    }
    
    part def UtilizationAnalyzer {
        in port usageDataPort : MedicalEquipment;
        out port reportPort : UtilizationReport;
    }
    
    part def AlertSystem {
        in port monitorPort : MedicalEquipment;
        out port notificationPort : Notification;
    }
    
    action def HandleRequest {
        in req : Request;
        in availableEquipment : MedicalEquipment[*];
        out assign : Assignment;
    }
    
    action def ScheduleMaintenance {
        in eq : MedicalEquipment;
        out wo : WorkOrder;
    }
    
    action def ScheduleCalibration {
        in eq : MedicalEquipment;
        out wo : WorkOrder;
    }
    
    action def AnalyzeUtilization {
        in data : MedicalEquipment[*];
        out report : UtilizationReport;
    }
    
    action def MonitorAlerts {
        in equipment : MedicalEquipment;
        out alert : Notification;
    }
    
    part def 'Medical Equipment Management System' {
        part inventoryDB : InventoryDatabase;
        part locationTracker : LocationTracker;
        part allocationMgr : AllocationManager;
        part maintenanceSched : MaintenanceScheduler;
        part calibrationMgr : CalibrationManager;
        part utilizationAnalyzer : UtilizationAnalyzer;
        part alertSystem : AlertSystem;
        
        part ventilators : Ventilator[15];
        part infusionPumps : InfusionPump[25];
        part patientMonitors : PatientMonitor[20];
        
        connect ventilators.statusPort to inventoryDB.updatePort;
        connect infusionPumps.statusPort to inventoryDB.updatePort;
        connect patientMonitors.statusPort to inventoryDB.updatePort;
        
        connect inventoryDB.queryPort to allocationMgr.equipmentStatusPort;
        connect inventoryDB.queryPort to maintenanceSched.usagePort;
        connect inventoryDB.queryPort to calibrationMgr.usagePort;
        connect inventoryDB.queryPort to utilizationAnalyzer.usageDataPort;
        connect inventoryDB.queryPort to alertSystem.monitorPort;
        
        connect maintenanceSched.workOrderPort to inventoryDB.updatePort;
        connect calibrationMgr.workOrderPort to inventoryDB.updatePort;
    }
    
    requirement def EquipmentTrackingRequirement {
        doc /* "The system must track the location and status of all medical equipment." */
    }
    
    requirement def MaintenanceComplianceRequirement {
        doc /* "The system must ensure all equipment undergoes scheduled maintenance and calibration." */
    }
    
    requirement def AllocationEfficiencyRequirement {
        doc /* "The system shall find the nearest available equipment and assign it to a request." */
    }
    
    requirement def UtilizationReportingRequirement {
        doc /* "The system shall collect usage data and generate utilization reports." */
    }
    
    requirement def AlertGenerationRequirement {
        doc /* "The system shall send alerts for equipment malfunctions, low battery, overdue maintenance, and unavailability." */
    }
    
    requirement def FleetSizeRequirement {
        doc /* "The system shall manage a fleet of 15 ventilators, 25 infusion pumps, and 20 patient monitors." */
    }
    
    satisfy EquipmentTrackingRequirement by 'Medical Equipment Management System'::locationTracker;
    satisfy MaintenanceComplianceRequirement by 'Medical Equipment Management System'::maintenanceSched;
    satisfy AllocationEfficiencyRequirement by 'Medical Equipment Management System'::allocationMgr;
    satisfy UtilizationReportingRequirement by 'Medical Equipment Management System'::utilizationAnalyzer;
    satisfy AlertGenerationRequirement by 'Medical Equipment Management System'::alertSystem;
    satisfy FleetSizeRequirement by 'Medical Equipment Management System'::ventilators;
    satisfy FleetSizeRequirement by 'Medical Equipment Management System'::infusionPumps;
    satisfy FleetSizeRequirement by 'Medical Equipment Management System'::patientMonitors;
}
