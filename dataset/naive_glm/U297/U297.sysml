package MedicalEquipmentManagementSystem {
    import ISQ::*; 
    import ScalarValues::*;
    
    // ---------- Value Types ----------
    value def DeviceId :> String;
    value def LocationId :> String;
    value def PatientId :> String;
    value def StaffId :> String;
    value def WorkOrderId :> String;
    
    value def OperatingHours :> Real { 
        unit "h" 
    }
    value def BatteryLevel :> Real { 
        unit "%" 
    }
    value def Distance :> Real { 
        unit "m" 
    }
    value def Timestamp :> DateTime;
    value def UtilizationRate :> Real { 
        unit "%" 
    }
    
    // ---------- Enumerations ----------
    enum def OperationalStatus {
        available;
        inUse;
        underMaintenance;
        outOfService;
        retired;
    }
    
    enum def EquipmentType {
        ventilator;
        infusionPump;
        patientMonitor;
    }
    
    enum def MaintenancePriority {
        low;
        medium;
        high;
        critical;
    }
    
    enum def AlertSeverity {
        info;
        warning;
        critical;
    }
    
    enum def WorkOrderStatus {
        open;
        assigned;
        inProgress;
        completed;
        overdue;
    }
    
    // ---------- Item Types ----------
    item def EquipmentRecord {
        attribute id : DeviceId;
        attribute type : EquipmentType;
        attribute location : LocationId;
        attribute status : OperationalStatus;
        attribute operatingHours : OperatingHours;
        attribute batteryLevel : BatteryLevel;
        attribute lastMaintenance : Timestamp;
        attribute lastCalibration : Timestamp;
        attribute registrationDate : Timestamp;
    }
    
    item def UsageEvent {
        attribute deviceId : DeviceId;
        attribute patientId : PatientId;
        attribute startTime : Timestamp;
        attribute endTime : Timestamp;
        attribute duration : OperatingHours;
        attribute location : LocationId;
    }
    
    item def MaintenanceRecord {
        attribute workOrderId : WorkOrderId;
        attribute deviceId : DeviceId;
        attribute technicianId : StaffId;
        attribute description : String;
        attribute priority : MaintenancePriority;
        attribute status : WorkOrderStatus;
        attribute scheduledDate : Timestamp;
        attribute completedDate : Timestamp;
    }
    
    item def CalibrationRecord {
        attribute workOrderId : WorkOrderId;
        attribute deviceId : DeviceId;
        attribute technicianId : StaffId;
        attribute targetAccuracy : Real;
        attribute measuredAccuracy : Real;
        attribute status : WorkOrderStatus;
        attribute scheduledDate : Timestamp;
        attribute completedDate : Timestamp;
    }
    
    item def AllocationRequest {
        attribute requestId : String;
        attribute equipmentType : EquipmentType;
        attribute patientId : PatientId;
        attribute requestingStaff : StaffId;
        attribute targetLocation : LocationId;
        attribute requestTime : Timestamp;
        attribute priority : MaintenancePriority;
    }
    
    item def AllocationResponse {
        attribute requestId : String;
        attribute assignedDeviceId : DeviceId;
        attribute deliveryDistance : Distance;
        attribute success : Boolean;
        attribute message : String;
    }
    
    item def AlertNotification {
        attribute alertId : String;
        attribute deviceId : DeviceId;
        attribute severity : AlertSeverity;
        attribute message : String;
        attribute recipientStaff : StaffId;
        attribute timestamp : Timestamp;
    }
    
    item def UtilizationReport {
        attribute reportId : String;
        attribute period : String;
        attribute averageUtilization : UtilizationRate;
        attribute deviceBreakdown : String;
        attribute recommendations : String;
        attribute generatedTime : Timestamp;
    }
    
    // ---------- Port Definitions ----------
    port def InventoryAccessPort {
        out item records : EquipmentRecord;
        in item updates : EquipmentRecord;
    }
    
    port def LocationQueryPort {
        in item queries : DeviceId;
        out item locations : LocationId;
    }
    
    port def AllocationRequestPort {
        in item requests : AllocationRequest;
        out item responses : AllocationResponse;
    }
    
    port def MaintenancePort {
        in item workOrders : MaintenanceRecord;
        out item completions : MaintenanceRecord;
    }
    
    port def CalibrationPort {
        in item workOrders : CalibrationRecord;
        out item completions : CalibrationRecord;
    }
    
    port def UsageDataPort {
        out item usageEvents : UsageEvent;
    }
    
    port def AlertPort {
        out item notifications : AlertNotification;
    }
    
    port def ReportPort {
        out item reports : UtilizationReport;
    }
    
    // ---------- Abstract Equipment ----------
    abstract part def MedicalDevice {
        attribute id : DeviceId;
        attribute type : EquipmentType;
        attribute location : LocationId;
        attribute status : OperationalStatus := OperationalStatus::available;
        attribute operatingHours : OperatingHours := 0;
        attribute batteryLevel : BatteryLevel := 100;
        attribute lastMaintenance : Timestamp;
        attribute lastCalibration : Timestamp;
        
        port inventoryUpdate : InventoryAccessPort;
        port usageOut : UsageDataPort;
        port alertOut : AlertPort;
        
        exhibit state LifecycleBehavior {
            entry action { status := OperationalStatus::available; }
            
            state Available {
                entry action { status := OperationalStatus::available; }
                transition to InUse 
                    when inventoryUpdate.updates.status == OperationalStatus::inUse
                    guard inventoryUpdate.updates.id == id;
            }
            
            state InUse {
                entry action { 
                    status := OperationalStatus::inUse;
                    operatingHours := operatingHours + 1;
                    usageOut.usageEvents.send(UsageEvent{deviceId = id, duration = 1});
                }
                transition to UnderMaintenance 
                    when batteryLevel < 20 or operatingHours > 500;
                transition to Available 
                    when inventoryUpdate.updates.status == OperationalStatus::available
                    guard inventoryUpdate.updates.id == id;
            }
            
            state UnderMaintenance {
                entry action { status := OperationalStatus::underMaintenance; }
                transition to Available 
                    when inventoryUpdate.updates.status == OperationalStatus::available
                    guard inventoryUpdate.updates.id == id;
            }
            
            state Retired {
                entry action { status := OperationalStatus::retired; }
            }
            
            transition Available to Retired 
                when inventoryUpdate.updates.status == OperationalStatus::retired
                guard inventoryUpdate.updates.id == id;
            transition InUse to Retired 
                when inventoryUpdate.updates.status == OperationalStatus::retired
                guard inventoryUpdate.updates.id == id;
            transition UnderMaintenance to Retired 
                when inventoryUpdate.updates.status == OperationalStatus::retired
                guard inventoryUpdate.updates.id == id;
        }
    }
    
    // ---------- Concrete Equipment ----------
    part def Ventilator :> MedicalDevice {
        attribute type := EquipmentType::ventilator;
        attribute maintenanceIntervalHours : OperatingHours := 1000;
        attribute calibrationIntervalHours : OperatingHours := 500;
    }
    
    part def InfusionPump :> MedicalDevice {
        attribute type := EquipmentType::infusionPump;
        attribute maintenanceIntervalHours : OperatingHours := 800;
        attribute calibrationIntervalHours : OperatingHours := 400;
        attribute lowBatteryThreshold : BatteryLevel := 15;
    }
    
    part def PatientMonitor :> MedicalDevice {
        attribute type := EquipmentType::patientMonitor;
        attribute maintenanceIntervalHours : OperatingHours := 1200;
        attribute calibrationIntervalHours : OperatingHours := 600;
    }
    
    // ---------- Staff ----------
    part def Technician {
        attribute id : StaffId;
        attribute name : String;
        attribute specialization : EquipmentType;
        attribute assignedWorkOrders : WorkOrderId[0..*];
        
        port maintenanceIn : MaintenancePort;
        port calibrationIn : CalibrationPort;
        
        exhibit state WorkState {
            state Idle;
            state Assigned;
            state Working;
            state Completed;
            
            transition Idle to Assigned 
                when maintenanceIn.workOrders.status == WorkOrderStatus::assigned;
            transition Assigned to Working 
                when maintenanceIn.workOrders.status == WorkOrderStatus::inProgress;
            transition Working to Completed 
                when maintenanceIn.workOrders.status == WorkOrderStatus::completed;
            transition Completed to Idle;
        }
    }
    
    part def ClinicalStaff {
        attribute id : StaffId;
        attribute name : String;
        attribute department : String;
        
        port allocationRequest : AllocationRequestPort;
        port alertIn : AlertPort;
    }
    
    // ---------- Inventory Database ----------
    part def InventoryDatabase {
        attribute totalVentilators : Integer := 15;
        attribute totalInfusionPumps : Integer := 25;
        attribute totalPatientMonitors : Integer := 20;
        
        port inventoryAccess : InventoryAccessPort;
        port locationQuery : LocationQueryPort;
        
        attribute records : EquipmentRecord[0..*];
        
        exhibit action UpdateRecord {
            in item update : EquipmentRecord;
            then action FindRecord {
                in item update;
            }
            then action MergeRecord;
            then action BroadcastUpdate {
                out item broadcast : EquipmentRecord;
            }
        }
        
        exhibit action RegisterDevice {
            in item newRecord : EquipmentRecord;
            then action ValidateRecord;
            then action AddToInventory;
            then action ConfirmRegistration;
        }
        
        exhibit action RetireDevice {
            in item deviceId : DeviceId;
            then action MarkRetired;
            then action ArchiveRecord;
        }
    }
    
    // ---------- Location Tracker ----------
    part def LocationTracker {
        port inventoryAccess : InventoryAccessPort;
        port locationQuery : LocationQueryPort;
        
        attribute deviceLocations : DeviceId[0..*];
        
        exhibit action TrackLocation {
            in item deviceId : DeviceId;
            then action QuerySensor {
                out item rawLocation : LocationId;
            }
            then action UpdateDatabase {
                out item updatedRecord : EquipmentRecord;
            }
        }
        
        exhibit action FindNearestAvailable {
            in item equipmentType : EquipmentType;
            in item targetLocation : LocationId;
            then action QueryAvailable;
            then action CalculateDistances;
            then action SelectNearest {
                out item nearestDeviceId : DeviceId;
                out item distance : Distance;
            }
        }
    }
    
    // ---------- Allocation Manager ----------
    part def AllocationManager {
        port allocationRequest : AllocationRequestPort;
        port inventoryAccess : InventoryAccessPort;
        port locationQuery : LocationQueryPort;
        
        exhibit action ProcessAllocationRequest {
            in item request : AllocationRequest;
            then action ValidateRequest;
            then action FindNearestAvailable {
                out item deviceId : DeviceId;
                out item distance : Distance;
            }
            then action AssignDevice {
                out item updatedRecord : EquipmentRecord;
            }
            then action CoordinateDelivery {
                out item response : AllocationResponse;
            }
        }
        
        exhibit state AllocationState {
            state Idle;
            state Processing;
            state Assigned;
            state Delivered;
            
            transition Idle to Processing 
                when allocationRequest.requests.size > 0;
            transition Processing to Assigned 
                when allocationRequest.responses.success == true;
            transition Processing to Idle 
                when allocationRequest.responses.success == false;
            transition Assigned to Delivered;
            transition Delivered to Idle;
        }
    }
    
    // ---------- Maintenance Scheduler ----------
    part def MaintenanceScheduler {
        port inventoryAccess : InventoryAccessPort;
        port maintenanceOut : MaintenancePort;
        
        attribute maintenanceIntervalHours : OperatingHours := 1000;
        attribute overdueThresholdDays : Integer := 30;
        
        exhibit action CheckMaintenanceDue {
            in item record : EquipmentRecord;
            then action EvaluateOperatingHours;
            then action EvaluateTimeSinceLastMaintenance;
            then action GenerateWorkOrder {
                out item workOrder : MaintenanceRecord;
            }
        }
        
        exhibit action AssignWorkOrder {
            in item workOrder : MaintenanceRecord;
            in item technicians : Technician[0..*];
            then action MatchSpecialization;
            then action AssignToTechnician {
                out item assignedWorkOrder : MaintenanceRecord;
            }
        }
        
        exhibit action TrackWorkOrder {
            in item workOrder : MaintenanceRecord;
            then action CheckStatus;
            then action FlagOverdue {
                out item flaggedWorkOrder : MaintenanceRecord;
            }
        }
        
        exhibit state SchedulerState {
            state Monitoring;
            state Generating;
            state Assigning;
            state Tracking;
            
            transition Monitoring to Generating 
                when inventoryAccess.records.operatingHours > maintenanceIntervalHours;
            transition Generating to Assigning;
            transition Assigning to Tracking;
            transition Tracking to Monitoring;
        }
    }
    
    // ---------- Calibration Manager ----------
    part def CalibrationManager {
        port inventoryAccess : InventoryAccessPort;
        port calibrationOut : CalibrationPort;
        
        attribute calibrationIntervalHours : OperatingHours := 500;
        attribute accuracyTolerance : Real := 0.05;
        
        exhibit action CheckCalibrationDue {
            in item record : EquipmentRecord;
            then action EvaluateOperatingHours;
            then action GenerateCalibrationOrder {
                out item workOrder : CalibrationRecord;
            }
        }
        
        exhibit action AssignCalibration {
            in item workOrder : CalibrationRecord;
            in item technicians : Technician[0..*];
            then action MatchSpecialization;
            then action AssignToTechnician {
                out item assignedWorkOrder : CalibrationRecord;
            }
        }
        
        exhibit action VerifyCalibration {
            in item workOrder : CalibrationRecord;
            then action CompareAccuracy;
            then action ApproveOrReject {
                out item completedWorkOrder : CalibrationRecord;
            }
        }
        
        exhibit state CalibrationState {
            state Monitoring;
            state Generating;
            state Assigning;
            state Verifying;
            state Completed;
            
            transition Monitoring to Generating 
                when inventoryAccess.records.operatingHours > calibrationIntervalHours;
            transition Generating to Assigning;
            transition Assigning to Verifying;
            transition Verifying to Completed 
                when calibrationOut.completions.status == WorkOrderStatus::completed;
            transition Completed to Monitoring;
        }
    }
    
    // ---------- Utilization Analyzer ----------
    part def UtilizationAnalyzer {
        port usageDataIn : UsageDataPort;
        port reportOut : ReportPort;
        
        attribute collectedEvents : UsageEvent[0..*];
        attribute reportingPeriod : String := "monthly";
        
        exhibit action CollectUsageData {
            in item event : UsageEvent;
            then action StoreEvent;
        }
        
        exhibit action GenerateReport {
            then action AggregateUsageByType;
            then action CalculateUtilizationRates {
                out item rates : UtilizationRate[0..*];
            }
            then action IdentifyUnderutilized;
            then action FormulateRecommendations;
            then action PublishReport {
                out item report : UtilizationReport;
            }
        }
        
        exhibit state AnalyzerState {
            state Collecting;
            state Analyzing;
            state Reporting;
            
            transition Collecting to Analyzing 
                when collectedEvents.size > 100;
            transition Analyzing to Reporting;
            transition Reporting to Collecting;
        }
    }
    
    // ---------- Alert System ----------
    part def AlertSystem {
        port inventoryAccess : InventoryAccessPort;
        port alertOut : AlertPort;
        port maintenanceIn : MaintenancePort;
        port allocationIn : AllocationRequestPort;
        
        attribute activeAlerts : AlertNotification[0..*];
        
        exhibit action MonitorEquipment {
            in item record : EquipmentRecord;
            then action CheckMalfunction;
            then action CheckBatteryLevel;
            then action CheckMaintenanceOverdue;
        }
        
        exhibit action CheckBatteryLevel {
            in item record : EquipmentRecord;
            then action EvaluateThreshold {
                guard record.batteryLevel < 20;
            }
            then action GenerateAlert {
                out item alert : AlertNotification;
            }
        }
        
        exhibit action CheckMaintenanceOverdue {
            in item record : EquipmentRecord;
            then action EvaluateSchedule {
                guard record.status == OperationalStatus::underMaintenance;
            }
            then action GenerateAlert {
                out item alert : AlertNotification;
            }
        }
        
        exhibit action CheckAllocationFailure {
            in item request : AllocationRequest;
            then action EvaluateAvailability;
            then action GenerateAlert {
                out item alert : AlertNotification;
            }
        }
        
        exhibit state AlertState {
            state Idle;
            state Detecting;
            state Notifying;
            state Acknowledged;
            
            transition Idle to Detecting 
                when inventoryAccess.records.batteryLevel < 20 
                or inventoryAccess.records.status == OperationalStatus::outOfService;
            transition Detecting to Notifying;
            transition Notifying to Acknowledged;
            transition Acknowledged to Idle;
        }
    }
    
    // ---------- System Composition ----------
    part def MedicalEquipmentManagementSystem {
        port externalAllocation : AllocationRequestPort;
        port externalAlerts : AlertPort;
        port externalReports : ReportPort;
        
        part inventoryDatabase : InventoryDatabase {
            attribute totalVentilators := 15;
            attribute totalInfusionPumps := 25;
            attribute totalPatientMonitors := 20;
        }
        
        part locationTracker : LocationTracker;
        part allocationManager : AllocationManager;
        part maintenanceScheduler : MaintenanceScheduler;
        part calibrationManager : CalibrationManager;
        part utilizationAnalyzer : UtilizationAnalyzer;
        part alertSystem : AlertSystem;
        
        part ventilators : Ventilator[15];
        part infusionPumps : InfusionPump[25];
        part patientMonitors : PatientMonitor[20];
        
        part technicians : Technician[5];
        part clinicalStaff : ClinicalStaff[10];
        
        // Connections
        connection inventoryDatabase.inventoryAccess to locationTracker.inventoryAccess;
        connection inventoryDatabase.inventoryAccess to allocationManager.inventoryAccess;
        connection inventoryDatabase.inventoryAccess to maintenanceScheduler.inventoryAccess;
        connection inventoryDatabase.inventoryAccess to calibrationManager.inventoryAccess;
        connection inventoryDatabase.inventoryAccess to alertSystem.inventoryAccess;
        
        connection locationTracker.locationQuery to allocationManager.locationQuery;
        connection locationTracker.locationQuery to inventoryDatabase.locationQuery;
        
        connection externalAllocation to allocationManager.allocationRequest;
        connection allocationManager.allocationRequest to externalAllocation;
        
        connection maintenanceScheduler.maintenanceOut to technicians.maintenanceIn;
        connection calibrationManager.calibrationOut to technicians.calibrationIn;
        
        connection ventilators.usageOut to utilizationAnalyzer.usageDataIn;
        connection infusionPumps.usageOut to utilizationAnalyzer.usageDataIn;
        connection patientMonitors.usageOut to utilizationAnalyzer.usageDataIn;
        
        connection utilizationAnalyzer.reportOut to externalReports;
        
        connection alertSystem.alertOut to externalAlerts;
        connection alertSystem.alertOut to clinicalStaff.alertIn;
        
        connection ventilators.inventoryUpdate to inventoryDatabase.inventoryAccess;
        connection infusionPumps.inventoryUpdate to inventoryDatabase.inventoryAccess;
        connection patientMonitors.inventoryUpdate to inventoryDatabase.inventoryAccess;
        
        connection ventilators.alertOut to alertSystem.inventoryAccess;
        connection infusionPumps.alertOut to alertSystem.inventoryAccess;
        connection patientMonitors.alertOut to alertSystem.inventoryAccess;
    }
    
    // ---------- Requirements ----------
    requirement def EquipmentTrackingRequirement {
        subject system : MedicalEquipmentManagementSystem;
        objective "Maintain real-time records of all medical equipment including ID, location, status, usage history, and maintenance records."
        assume system.inventoryDatabase.totalVentilators == 15;
        assume system.inventoryDatabase.totalInfusionPumps == 25;
        assume system.inventoryDatabase.totalPatientMonitors == 20;
    }
    
    requirement def LocationTrackingRequirement {
        subject system : MedicalEquipmentManagementSystem;
        objective "Track physical position of each device within the facility to enable quick retrieval and prevent loss."
        require system.locationTracker.locationQuery.locations.size == system.inventoryDatabase.records.size;
    }
    
    requirement def AllocationRequirement {
        subject system : MedicalEquipmentManagementSystem;
        objective "Handle allocation requests from clinical staff by finding nearest available unit, assigning it, and coordinating delivery."
        require system.allocationManager.allocationRequest.responses.success == true 
            when system.allocationManager.allocationRequest.requests.size > 0;
    }
    
    requirement def PreventiveMaintenanceRequirement {
        subject system : MedicalEquipmentManagementSystem;
        objective "Automatically generate work orders for preventive maintenance based on operating hours or time-based schedules."
        require system.maintenanceScheduler.maintenanceOut.workOrders.size > 0 
            when system.inventoryDatabase.records.operatingHours > 1000;
    }
    
    requirement def CalibrationRequirement {
        subject system : MedicalEquipmentManagementSystem;
        objective "Automatically generate calibration work orders and track them to completion ensuring accuracy compliance."
        require system.calibrationManager.calibrationOut.workOrders.size > 0 
            when system.inventoryDatabase.records.operatingHours > 500;
    }
    
    requirement def UtilizationReportingRequirement {
        subject system : MedicalEquipmentManagementSystem;
        objective "Continuously collect usage data and generate reports on equipment utilization efficiency."
        require system.utilizationAnalyzer.reportOut.reports.size > 0;
    }
    
    requirement def AlertRequirement {
        subject system : MedicalEquipmentManagementSystem;
        objective "Monitor all equipment for critical issues and send notifications for malfunctions, low battery, overdue maintenance, or unavailable devices."
        require system.alertSystem.alertOut.notifications.size > 0 
            when system.inventoryDatabase.records.batteryLevel < 20;
    }
    
    requirement def LifecycleComplianceRequirement {
        subject system : MedicalEquipmentManagementSystem;
        objective "Automate entire equipment lifecycle from registration through monitoring, allocation, maintenance, and retirement while ensuring traceability and regulatory compliance."
        require system.inventoryDatabase.records.status == OperationalStatus::retired 
            implies system.inventoryDatabase.records.lastMaintenance != null;
    }
    
    requirement EquipmentManagementSystemRequirements {
        subject system : MedicalEquipmentManagementSystem;
        satisfy EquipmentTrackingRequirement;
        satisfy LocationTrackingRequirement;
        satisfy AllocationRequirement;
        satisfy PreventiveMaintenanceRequirement;
        satisfy CalibrationRequirement;
        satisfy UtilizationReportingRequirement;
        satisfy AlertRequirement;
        satisfy LifecycleComplianceRequirement;
    }
}
