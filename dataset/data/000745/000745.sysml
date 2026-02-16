package RectalDilatorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DiameterValue :> LengthValue;
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def ForceValue :> ISQ::ForceValue;
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def DurationValue :> TimeValue;
    
    attribute def SterilizationState {
        attribute sterile : Boolean;
        attribute sterilizationDate : String;
        attribute expiryDate : String;
    }
    
    attribute def TissueCondition {
        attribute elasticity : Real;
        attribute resistance : ForceValue;
        attribute temperature : TemperatureValue;
    }
    
    item def MedicalSilicone {
        attribute biocompatible : Boolean;
        attribute shoreHardness : Real;
        attribute tensileStrength : PressureValue;
    }
    
    item def SurgicalLubricant {
        attribute viscosity : Real;
        attribute sterile : Boolean;
    }
    
    port def MechanicalInterface {
        attribute appliedForce : ForceValue;
        attribute displacement : LengthValue;
    }
    
    port def ControlPort {
        attribute targetDiameter : DiameterValue;
        attribute expansionRate : Real;
        attribute currentDiameter : DiameterValue;
    }
    
    port def PatientContactPort {
        attribute contactPressure : PressureValue;
        attribute tissueResponse : TissueCondition;
    }
    
    part def DilatorTip {
        attribute taperAngle : Real;
        attribute tipDiameter : DiameterValue;
        attribute material : MedicalSilicone;
        
        port patientContact : PatientContactPort;
    }
    
    part def ExpandableShaft {
        attribute currentDiameter : DiameterValue;
        attribute minDiameter : DiameterValue;
        attribute maxDiameter : DiameterValue;
        attribute shaftLength : LengthValue;
        attribute material : MedicalSilicone;
        
        port mechanicalPort : MechanicalInterface;
        port tissueInterface : PatientContactPort;
    }
    
    part def ExpansionMechanism {
        attribute expansionForce : ForceValue;
        attribute currentPosition : LengthValue;
        attribute maxTravel : LengthValue;
        
        port controlInput : ControlPort;
        port mechanicalOutput : MechanicalInterface;
    }
    
    part def PressureMonitor {
        attribute measuredPressure : PressureValue;
        attribute pressureThreshold : PressureValue;
        attribute alarmActive : Boolean;
    }
    
    part def SafetyRelease {
        attribute releaseThreshold : PressureValue;
        attribute activated : Boolean;
    }
    
    part def ControlModule {
        attribute operatorInput : Real;
        attribute targetSize : DiameterValue;
        attribute procedureMode : String;
        
        port controlOutput : ControlPort;
    }
    
    part def RectalDilator {
        doc /* A medical device for controlled gradual dilation of rectal tissue 
               to facilitate examination, treatment, or surgical access while 
               minimizing patient discomfort and tissue trauma. */
        
        part tip : DilatorTip {
            attribute taperAngle = 15.0;
            attribute tipDiameter = 8.0 [SI::mm];
            attribute material = MedicalSilicone {
                biocompatible = true;
                shoreHardness = 40.0;
                tensileStrength = 7.0e6 [SI::Pa];
            }
        }
        
        part shaft : ExpandableShaft {
            attribute currentDiameter = 12.0 [SI::mm];
            attribute minDiameter = 10.0 [SI::mm];
            attribute maxDiameter = 40.0 [SI::mm];
            attribute shaftLength = 120.0 [SI::mm];
        }
        
        part expansionMech : ExpansionMechanism {
            attribute expansionForce = 0.0 [SI::N];
            attribute currentPosition = 0.0 [SI::mm];
            attribute maxTravel = 30.0 [SI::mm];
        }
        
        part pressureMonitor : PressureMonitor {
            attribute measuredPressure = 0.0 [SI::Pa];
            attribute pressureThreshold = 45000.0 [SI::Pa];
            attribute alarmActive = false;
        }
        
        part safetyRelease : SafetyRelease {
            attribute releaseThreshold = 50000.0 [SI::Pa];
            attribute activated = false;
        }
        
        part controller : ControlModule {
            attribute targetSize = 25.0 [SI::mm];
            attribute procedureMode = "gradual";
        }
        
        attribute sterilization : SterilizationState {
            attribute sterile = true;
            attribute sterilizationDate = "2025-01-15";
            attribute expiryDate = "2026-01-15";
        }
        
        connect controller.controlOutput to expansionMech.controlInput;
        connect expansionMech.mechanicalOutput to shaft.mechanicalPort;
        connect shaft.tissueInterface to tip.patientContact;
    }
    
    action def PrepareDilator {
        in device : RectalDilator;
        in lubricant : SurgicalLubricant;
        out prepared : Boolean;
    }
    
    action def VerifySterilization {
        in device : RectalDilator;
        out verified : Boolean;
    }
    
    action def PositionDilator {
        in device : RectalDilator;
        out positioned : Boolean;
    }
    
    action def MonitorTissuePressure {
        in currentPressure : PressureValue;
        in maxPressure : PressureValue;
        out safe : Boolean;
        out pressureReading : PressureValue;
    }
    
    action def IncrementExpansion {
        in currentDiam : DiameterValue;
        in targetDiam : DiameterValue;
        in stepSize : DiameterValue;
        out newDiameter : DiameterValue;
        out targetReached : Boolean;
    }
    
    action def AssessTissueResponse {
        in tissueCondition : TissueCondition;
        in appliedPressure : PressureValue;
        out acceptable : Boolean;
        out responseLevel : Real;
    }
    
    action def MaintainDilation {
        in diameter : DiameterValue;
        in duration : DurationValue;
        out maintained : Boolean;
    }
    
    action def RetractDilator {
        in currentDiam : DiameterValue;
        in retractionRate : Real;
        out retracted : Boolean;
        out finalDiameter : DiameterValue;
    }
    
    action def WithdrawDevice {
        in device : RectalDilator;
        out withdrawn : Boolean;
    }
    
    attribute def VerificationComplete;
    attribute def DevicePositioned;
    attribute def ProcedureComplete;
    attribute def EmergencyStop;
    
    state def DilationProcedureState {
        entry; then initialization;
        
        state initialization;
        transition init_to_preparation
            first initialization
            accept VerificationComplete
            then preparation;
        
        state preparation {
            entry; then sterilityCheck;
            state sterilityCheck;
            transition sterility_to_lubrication
                first sterilityCheck
                then lubrication;
            state lubrication;
            transition lubrication_to_positioning
                first lubrication
                then positioning;
            state positioning;
        }
        transition prep_to_expansion
            first preparation
            accept DevicePositioned
            then expansion;
        
        state expansion {
            entry; then incrementalExpansion;
            
            state incrementalExpansion;
            transition increment_to_monitoring
                first incrementalExpansion
                then monitoring;
            
            state monitoring;
            transition monitoring_to_assessment
                first monitoring
                then assessment;
            
            state assessment;
            transition assessment_to_increment
                first assessment
                then incrementalExpansion;
            
            transition assessment_to_maintenance
                first assessment
                then maintenance;
            
            state maintenance;
        }
        
        transition expansion_to_retraction
            first expansion
            accept ProcedureComplete
            then retraction;
        
        transition emergency_retraction
            first expansion
            accept EmergencyStop
            then retraction;
        
        state retraction {
            entry; then gradualRetraction;
            state gradualRetraction;
            transition retraction_to_withdrawal
                first gradualRetraction
                then withdrawal;
            state withdrawal;
        }
        
        transition retraction_to_complete
            first retraction
            then procedureComplete;
        
        state procedureComplete;
    }
    
    action def PerformDilation {
        in device : RectalDilator;
        in targetDiameter : DiameterValue;
        in maxPressure : PressureValue;
        in holdDuration : DurationValue;
        out success : Boolean;
        out finalDiameter : DiameterValue;
        
        first start;
        
        action verify : VerifySterilization {
            in device = PerformDilation::device;
            out verified;
        }
        
        action prepare : PrepareDilator {
            in device = PerformDilation::device;
            in lubricant = SurgicalLubricant {
                viscosity = 5000.0;
                sterile = true;
            };
            out prepared;
        }
        
        action position : PositionDilator {
            in device = PerformDilation::device;
            out positioned;
        }
        
        merge expansionLoop;
        
        action monitorPressure : MonitorTissuePressure {
            in currentPressure = device.pressureMonitor.measuredPressure;
            in maxPressure = PerformDilation::maxPressure;
            out safe;
            out pressureReading;
        }
        
        decide;
            if monitorPressure.safe and device.shaft.currentDiameter < targetDiameter
                then expand;
            if monitorPressure.safe and device.shaft.currentDiameter >= targetDiameter
                then maintain;
            if not monitorPressure.safe
                then emergencyRetract;
        
        action expand : IncrementExpansion {
            in currentDiam = device.shaft.currentDiameter;
            in targetDiam = targetDiameter;
            in stepSize = 2.0 [SI::mm];
            out newDiameter;
            out targetReached;
        }
        then action assess : AssessTissueResponse {
            in tissueCondition;
            in appliedPressure = monitorPressure.pressureReading;
            out acceptable;
            out responseLevel;
        }
        then decide;
            if assess.acceptable then expansionLoop;
            if not assess.acceptable then emergencyRetract;
        
        action maintain : MaintainDilation {
            in diameter = device.shaft.currentDiameter;
            in duration = holdDuration;
            out maintained;
        }
        then normalRetract;
        
        action normalRetract : RetractDilator {
            in currentDiam = device.shaft.currentDiameter;
            in retractionRate = 1.5;
            out retracted;
            out finalDiameter;
        }
        then withdraw;
        
        action emergencyRetract : RetractDilator {
            in currentDiam = device.shaft.currentDiameter;
            in retractionRate = 3.0;
            out retracted;
            out finalDiameter;
        }
        then withdraw;
        
        action withdraw : WithdrawDevice {
            in device = PerformDilation::device;
            out withdrawn;
        }
        then assign success := withdraw.withdrawn;
        then assign PerformDilation::finalDiameter := normalRetract.finalDiameter;
        then done;
    }
    
    requirement def SafetyRequirement {
        doc /* Safety requirements for rectal dilator operation to prevent tissue damage. */
        
        subject device : RectalDilator;
        
        require constraint maxPressureLimit {
            device.pressureMonitor.pressureThreshold <= 50000.0 [SI::Pa]
        }
        
        require constraint safetyReleaseActive {
            device.safetyRelease.releaseThreshold <= 55000.0 [SI::Pa]
        }
        
        require constraint sterilityMaintained {
            device.sterilization.sterile == true
        }
        
        require constraint biocompatibleMaterial {
            device.shaft.material.biocompatible == true
        }
    }
    
    requirement def FunctionalRequirement {
        doc /* Functional requirements for controlled tissue dilation capability. */
        
        subject device : RectalDilator;
        
        require constraint diameterRange {
            device.shaft.minDiameter >= 8.0 [SI::mm] and
            device.shaft.maxDiameter <= 45.0 [SI::mm]
        }
        
        require constraint gradualExpansion {
            device.expansionMech.maxTravel >= 25.0 [SI::mm]
        }
        
        require constraint adequateLength {
            device.shaft.shaftLength >= 100.0 [SI::mm]
        }
    }
    
    requirement def UsabilityRequirement {
        doc /* Requirements for safe and effective clinical use. */
        
        subject device : RectalDilator;
        
        require constraint controlledOperation {
            device.controller.procedureMode == "gradual" or
            device.controller.procedureMode == "stepped"
        }
    }
    
    requirement <'RD-SYS-001'> primarySystemFunction {
        doc /* The rectal dilator system shall provide controlled, gradual dilation 
               of rectal tissue to facilitate medical examination, therapeutic procedures, 
               or surgical access while maintaining patient safety through continuous 
               pressure monitoring and automatic safety release mechanisms. The system 
               shall minimize tissue trauma and patient discomfort through incremental 
               expansion with real-time tissue response assessment. */
        
        subject dilatorSystem : RectalDilator;
        
        assume constraint properPreparation {
            dilatorSystem.sterilization.sterile == true and
            dilatorSystem.sterilization.expiryDate >= "2025-01-01"
        }
        
        assume constraint qualifiedOperator {
            doc /* Device operated by trained medical professional. */
        }
        
        require safetyReq : SafetyRequirement {
            subject device = dilatorSystem;
        }
        
        require functionalReq : FunctionalRequirement {
            subject device = dilatorSystem;
        }
        
        require usabilityReq : UsabilityRequirement {
            subject device = dilatorSystem;
        }
    }
    
    part rectalDilatorSystem : RectalDilator {
        perform action dilationProcedure : PerformDilation {
            in device = rectalDilatorSystem;
            in targetDiameter = 30.0 [SI::mm];
            in maxPressure = 45000.0 [SI::Pa];
            in holdDuration = 180.0 [SI::s];
            out success;
            out finalDiameter;
        }
        
        satisfy primarySystemFunction {
            subject dilatorSystem = rectalDilatorSystem;
        }
    }
}
