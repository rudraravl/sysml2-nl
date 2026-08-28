package MedicalCannulaDeliverySystem {

    import ScalarValues::*;

    // ===== Unit Definitions =====
    unit Pa;
    unit mL;
    unit mLperMin;
    unit mm;
    unit deg;
    unit s;
    unit g;

    // ===== Value Type Definitions =====
    value type PressureValue :> Real {
        :>> unit = Pa;
    }

    value type FlowRateValue :> Real {
        :>> unit = mLperMin;
    }

    value type VolumeValue :> Real {
        :>> unit = mL;
    }

    value type LengthValue :> Real {
        :>> unit = mm;
    }

    value type DiameterValue :> Real {
        :>> unit = mm;
    }

    value type AngleValue :> Real {
        :>> unit = deg;
    }

    value type DurationValue :> Real {
        :>> unit = s;
    }

    value type DepthValue :> Real {
        :>> unit = mm;
    }

    value type ConcentrationValue :> Real {
        :>> unit = g;
    }

    // ===== Item Definitions =====
    item def MedicalFluid {
        attribute name : String;
        attribute concentration : ConcentrationValue;
        attribute viscosity : Real;
    }

    item def SterileMedicalFluid :> MedicalFluid {
        :>> isSterile : Boolean = true;
    }

    item def AirBubble {
        attribute volume : VolumeValue;
    }

    // ===== Port Definitions =====
    port def FluidPort {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        item : SterileMedicalFluid;
    }

    port def PressureSignalPort {
        attribute pressure : PressureValue;
    }

    port def AlarmPort {
        attribute isAlarmed : Boolean = false;
        attribute alarmDescription : String = "none";
        attribute alarmTimestamp : Real;
    }

    port def ControlPort {
        attribute command : String;
        attribute enabled : Boolean = true;
    }

    port def DisplayPort {
        attribute message : String;
        attribute alarmActive : Boolean = false;
        attribute currentPhase : String;
    }

    // ===== Action Definitions =====
    action def VerifySterility {
        out isSterile : Boolean;
    }

    action def PrimeFluidPath {
        in fluidPath : FluidPort;
        out isPrimed : Boolean;
        out expelledAir : AirBubble;
    }

    action def InsertCannula {
        in targetDepth : DepthValue;
        out actualDepth : DepthValue;
        out isInserted : Boolean;
    }

    action def DeliverFluid {
        in targetVolume : VolumeValue;
        in flowRate : FlowRateValue;
        out deliveredVolume : VolumeValue;
    }

    action def MonitorPressure {
        out measuredPressure : PressureValue;
        out isAlarmTriggered : Boolean;
    }

    action def RemoveCannula {
        out isRemoved : Boolean;
        out isDisposed : Boolean;
    }

    // ===== Part Definitions =====

    part def FluidReservoir {
        port out fluidOut : FluidPort;
        port in control : ControlPort;

        attribute capacity : VolumeValue = 100 [mL];
        attribute currentVolume : VolumeValue = 100 [mL];
        attribute isSterile : Boolean = true;
        attribute reservoirType : String = "rigid";

        action dispense {
            in requestedVolume : VolumeValue;
            out dispensedFluid : SterileMedicalFluid;
        }

        action fill {
            in fillVolume : VolumeValue;
        }
    }

    part def FlowController {
        port in fluidIn : FluidPort;
        port out fluidOut : FluidPort;
        port in pressureFeedback : PressureSignalPort;
        port in alarmInput : AlarmPort;
        port out alarmOutput : AlarmPort;
        port in control : ControlPort;
        port out statusDisplay : DisplayPort;

        attribute targetFlowRate : FlowRateValue = 2.0 [mLperMin];
        attribute currentFlowRate : FlowRateValue = 0.0 [mLperMin];
        attribute maxSafePressure : PressureValue = 50000 [Pa];
        attribute isPumping : Boolean = false;
        attribute isPaused : Boolean = false;
        attribute volumeDelivered : VolumeValue = 0.0 [mL];
        attribute targetVolume : VolumeValue = 20 [mL];
        attribute pumpType : String = "peristaltic";

        action regulateFlow {
            out regulatedFlowRate : FlowRateValue;
        }

        action pauseDelivery {
            out isPaused : Boolean = true;
            out currentFlowRate : FlowRateValue = 0.0 [mLperMin];
        }

        action resumeDelivery {
            out isPaused : Boolean = false;
            out currentFlowRate : FlowRateValue;
        }

        action calculateVolumeDelivered {
            in duration : DurationValue;
            in flowRate : FlowRateValue;
            out volume : VolumeValue;
        }
    }

    part def PressureSensor {
        port in fluidIn : FluidPort;
        port out fluidOut : FluidPort;
        port out pressureOutput : PressureSignalPort;
        port out alarmOutput : AlarmPort;
        port in control : ControlPort;

        attribute measuredPressure : PressureValue = 0 [Pa];
        attribute thresholdPressure : PressureValue = 60000 [Pa];
        attribute samplingInterval : DurationValue = 0.1 [s];
        attribute isMonitoring : Boolean = false;
        attribute sensorAccuracy : Real = 0.01;
        attribute sensorRange : PressureValue = 200000 [Pa];

        action monitorPressure {
            out measuredPressure : PressureValue;
            out isAlarmTriggered : Boolean;
        }

        action triggerAlarm {
            in pressure : PressureValue;
            out alarm : AlarmPort;
        }
    }

    part def CannulaTip {
        attribute bevelAngle : AngleValue = 30 [deg];
        attribute isSharp : Boolean = true;
        attribute tipType : String = "hypodermic";
        attribute cuttingEdgeLength : LengthValue = 3.0 [mm];
    }

    part def CannulaShaft {
        attribute length : LengthValue = 80 [mm];
        attribute innerDiameter : DiameterValue = 0.8 [mm];
        attribute outerDiameter : DiameterValue = 1.2 [mm];
        attribute isHollow : Boolean = true;
        attribute wallThickness : DiameterValue = 0.2 [mm];
    }

    part def CannulaHub {
        attribute luerLockStandard : String = "ISO 80369-7";
        attribute luerLockType : String = "Luer Lock";
        attribute isStandardized : Boolean = true;
        attribute connectionDiameter : DiameterValue = 6.0 [mm];
        attribute hubColor : String = "white";
    }

    part def Cannula {
        port in fluidIn : FluidPort;
        port out fluidOut : FluidPort;

        attribute material : String = "Medical-grade stainless steel";
        attribute materialGrade : String = "304";
        attribute isSterile : Boolean = true;
        attribute insertionDepth : DepthValue = 25 [mm];
        attribute isInserted : Boolean = false;
        attribute gaugeSize : String = "18G";
        attribute lotNumber : String;

        part tip : CannulaTip;
        part shaft : CannulaShaft;
        part hub : CannulaHub;

        action insertCannula {
            in targetDepth : DepthValue;
            out actualDepth : DepthValue;
            out isInserted : Boolean;
        }

        action removeCannula {
            out isRemoved : Boolean;
        }

        action disposeCannula {
            out isDisposed : Boolean;
        }
    }

    part def AlarmIndicator {
        port in alarmInput : AlarmPort;
        port out displayOutput : DisplayPort;

        attribute isAudible : Boolean = true;
        attribute isVisual : Boolean = true;
        attribute volumeLevel : Real = 80;
        attribute isAcknowledged : Boolean = false;

        action soundAlarm {
            in alarm : AlarmPort;
            out isSounding : Boolean = true;
        }

        action clearAlarm {
            out isSounding : Boolean = false;
            out isAcknowledged : Boolean = true;
        }
    }

    // ===== State Machine Definition =====
    state def DeliveryProcedureState {
        attribute currentDepth : DepthValue = 0 [mm];
        attribute targetDepth : DepthValue = 25 [mm];
        attribute currentPressure : PressureValue = 0 [Pa];
        attribute thresholdPressure : PressureValue = 60000 [Pa];
        attribute deliveredVolume : VolumeValue = 0 [mL];
        attribute targetVolume : VolumeValue = 20 [mL];
        attribute isSterilityVerified : Boolean = false;
        attribute isFluidPathPrimed : Boolean = false;
        attribute isCannulaInserted : Boolean = false;
        attribute isCannulaRemoved : Boolean = false;
        attribute isCannulaDisposed : Boolean = false;
        attribute isProcedureComplete : Boolean = false;
        attribute isDeliveryPaused : Boolean = false;
        attribute operatorCommand : String = "";
        attribute elapsedDeliveryTime : DurationValue = 0 [s];

        initial state idle {
            entry {
                // System initialized in sterile, idle state
                // All components verified as sterile
                // System ready for operator commands
            }
        }

        state preparation {
            entry {
                // Begin preparation phase
                // Verify sterility of all components
                // Prime fluid path to remove air bubbles
            }
            do {
                // Continuous sterility verification
                // Continuous priming process
                // Expel air from fluid path
            }
            exit {
                // Sterility verified
                // Fluid path fully primed
            }
        }

        state insertion {
            entry {
                // Begin cannula insertion into target tissue
            }
            do {
                // Gradually insert cannula to target depth
                // Monitor insertion depth continuously
            }
            exit {
                // Cannula inserted at correct depth
                // Placement confirmed
            }
        }

        state delivery {
            entry {
                // Begin fluid delivery at preset flow rate
                // Activate flow controller
            }
            do {
                // Deliver fluid at controlled rate
                // Monitor delivered volume
                // Monitor pressure continuously
            }
        }

        state alarm {
            entry {
                // High pressure detected
                // Pause delivery immediately
                // Trigger audible and visual alarm
            }
            do {
                // Wait for operator intervention
                // Maintain alarm condition
            }
            exit {
                // Pressure normalized
                // Alarm acknowledged and cleared
            }
        }

        state removal {
            entry {
                // Begin safe removal of cannula
            }
            do {
                // Remove cannula from tissue safely
                // Dispose of used cannula in sharps container
            }
            exit {
                // Cannula removed and disposed properly
                // Procedure complete
            }
        }

        transition idle to preparation {
            when operatorCommand == "startPreparation";
            effect {
                // Initiate preparation sequence
            }
        }

        transition preparation to insertion {
            when isSterilityVerified && isFluidPathPrimed;
            effect {
                // Begin cannula insertion
            }
        }

        transition insertion to delivery {
            when isCannulaInserted && currentDepth == targetDepth;
            effect {
                // Start fluid delivery
            }
        }

        transition delivery to alarm {
            when currentPressure > thresholdPressure;
            effect {
                // Trigger alarm, pause delivery
                isDeliveryPaused = true;
            }
        }

        transition alarm to delivery {
            when currentPressure <= thresholdPressure && deliveredVolume < targetVolume;
            effect {
                // Resume delivery after alarm cleared
                isDeliveryPaused = false;
            }
        }

        transition alarm to removal {
            when operatorCommand == "abortProcedure";
            effect {
                // Abort procedure, proceed to removal
            }
        }

        transition delivery to removal {
            when deliveredVolume >= targetVolume;
            effect {
                // Full dose delivered, begin removal
            }
        }

        transition removal to idle {
            when isCannulaDisposed;
            effect {
                // System returns to idle state
                isProcedureComplete = true;
            }
        }
    }

    // ===== Main System Definition =====
    part def CannulaDeliverySystem {
        attribute prescribedVolume : VolumeValue = 20 [mL];
        attribute prescribedFlowRate : FlowRateValue = 2.0 [mLperMin];
        attribute maxSystemPressure : PressureValue = 60000 [Pa];
        attribute systemSerialNumber : String = "CDS-001";
        attribute isOperational : Boolean = true;
        attribute deviceClassification : String = "Class IIa";

        port in operatorCommand : ControlPort;
        port out systemStatus : DisplayPort;
        port out systemAlarm : AlarmPort;

        part reservoir : FluidReservoir {
            :>> capacity = 100 [mL];
            :>> currentVolume = 100 [mL];
            :>> isSterile = true;
        }

        part controller : FlowController {
            :>> targetFlowRate = 2.0 [mLperMin];
            :>> maxSafePressure = 50000 [Pa];
            :>> targetVolume = 20 [mL];
        }

        part sensor : PressureSensor {
            :>> thresholdPressure = 60000 [Pa];
            :>> samplingInterval = 0.1 [s];
        }

        part cannula : Cannula {
            :>> material = "Medical-grade stainless steel";
            :>> isSterile = true;
            :>> insertionDepth = 25 [mm];
        }

        part alarmIndicator : AlarmIndicator;

        // Fluid path connections
        connection reservoir.fluidOut to controller.fluidIn;
        connection controller.fluidOut to sensor.fluidIn;
        connection sensor.fluidOut to cannula.fluidIn;

        // Signal connections
        connection sensor.pressureOutput to controller.pressureFeedback;
        connection sensor.alarmOutput to controller.alarmInput;
        connection controller.alarmOutput to alarmIndicator.alarmInput;
        connection alarmIndicator.displayOutput to systemStatus;
        connection controller.statusDisplay to systemStatus;
        connection operatorCommand to controller.control;
        connection operatorCommand to sensor.control;
        connection operatorCommand to reservoir.control;
        connection sensor.alarmOutput to systemAlarm;

        // State machine
        exhibit state DeliveryProcedureState;
    }

    // ===== Requirement Definitions =====

    requirement def AccurateDeliveryRequirement {
        doc /* The system shall deliver the prescribed volume of fluid with accuracy within 5 percent tolerance */;
        subject system : CannulaDeliverySystem;
        constraint {
            abs(system.controller.volumeDelivered - system.prescribedVolume) <= 0.05 * system.prescribedVolume
        }
    }

    requirement def SafePressureRequirement {
        doc /* The system shall maintain fluid pressure below safe threshold to prevent tissue damage */;
        subject system : CannulaDeliverySystem;
        constraint {
            system.sensor.measuredPressure <= system.maxSystemPressure
        }
    }

    requirement def SterilityMaintenanceRequirement {
        doc /* All fluid-contacting components shall remain sterile throughout the entire procedure */;
        subject system : CannulaDeliverySystem;
        constraint {
            system.cannula.isSterile == true && system.reservoir.isSterile == true
        }
    }

    requirement def AlarmTriggerRequirement {
        doc /* The system shall trigger an alarm and pause delivery when pressure exceeds the configured threshold */;
        subject system : CannulaDeliverySystem;
        constraint {
            system.sensor.measuredPressure > system.sensor.thresholdPressure implies
            system.controller.isPaused == true
        }
    }

    requirement def FlowRateAccuracyRequirement {
        doc /* The flow controller shall maintain delivery within 10 percent of the preset flow rate */;
        subject system : CannulaDeliverySystem;
        constraint {
            abs(system.controller.currentFlowRate - system.controller.targetFlowRate) <=
            0.10 * system.controller.targetFlowRate
        }
    }

    requirement def MaterialRequirement {
        doc /* The cannula shall be constructed from medical-grade stainless steel */;
        subject cannula : Cannula;
        constraint {
            cannula.material == "Medical-grade stainless steel"
        }
    }

    requirement def LuerLockConnectionRequirement {
        doc /* The cannula hub shall use a standardized Luer Lock connection compliant with ISO 80369-7 */;
        subject cannula : Cannula;
        constraint {
            cannula.hub.luerLockType == "Luer Lock" &&
            cannula.hub.isStandardized == true
        }
    }

    requirement def InsertionDepthRequirement {
        doc /* The cannula shall be inserted to the prescribed depth of 25 mm in the target tissue */;
        subject system : CannulaDeliverySystem;
        constraint {
            system.cannula.insertionDepth == 25 [mm]
        }
    }

    requirement def DoseCompletionRequirement {
        doc /* The full prescribed dose shall be administered before the procedure is completed */;
        subject system : CannulaDeliverySystem;
        constraint {
            system.controller.volumeDelivered >= system.prescribedVolume
        }
    }

    requirement def SharpTipRequirement {
        doc /* The cannula tip shall be sharp with a 30 degree bevel angle for tissue penetration */;
        subject cannula : Cannula;
        constraint {
            cannula.tip.isSharp == true &&
            cannula.tip.bevelAngle == 30 [deg]
        }
    }

    requirement def HollowShaftRequirement {
        doc /* The cannula shaft shall be hollow to serve as a fluid conduit with specified dimensions */;
        subject cannula : Cannula;
        constraint {
            cannula.shaft.isHollow == true &&
            cannula.shaft.innerDiameter > 0 [mm] &&
            cannula.shaft.length > 0 [mm]
        }
    }

    requirement def PressureMonitoringRequirement {
        doc /* The pressure sensor shall continuously monitor system pressure at intervals no greater than 0.1 seconds */;
        subject sensor : PressureSensor;
        constraint {
            sensor.samplingInterval <= 0.1 [s]
        }
    }

    requirement def ReservoirCapacityRequirement {
        doc /* The fluid reservoir shall have sufficient capacity to hold the full prescribed dose plus a safety margin */;
        subject reservoir : FluidReservoir;
        constraint {
            reservoir.capacity >= 50 [mL]
        }
    }

    // ===== Satisfaction Relationships =====
    satisfy AccurateDeliveryRequirement by CannulaDeliverySystem;
    satisfy SafePressureRequirement by CannulaDeliverySystem;
    satisfy SterilityMaintenanceRequirement by CannulaDeliverySystem;
    satisfy AlarmTriggerRequirement by CannulaDeliverySystem;
    satisfy FlowRateAccuracyRequirement by FlowController;
    satisfy MaterialRequirement by Cannula;
    satisfy LuerLockConnectionRequirement by CannulaHub;
    satisfy InsertionDepthRequirement by Cannula;
    satisfy DoseCompletionRequirement by FlowController;
    satisfy SharpTipRequirement by CannulaTip;
    satisfy HollowShaftRequirement by CannulaShaft;
    satisfy PressureMonitoringRequirement by PressureSensor;
    satisfy ReservoirCapacityRequirement by FluidReservoir;

    // ===== Verification Definitions =====

    verification def AccuracyVerification {
        doc /* Verify delivery accuracy by comparing delivered volume to prescribed volume within 5 percent */;
        subject system : CannulaDeliverySystem;
        objective {
            doc /* Measure delivered volume after procedure completion and compare against prescribed volume */;
        }
    }

    verification def SafetyVerification {
        doc /* Verify pressure does not exceed safe threshold during all operational phases */;
        subject system : CannulaDeliverySystem;
        objective {
            doc /* Monitor pressure throughout entire delivery and confirm alarm triggers at threshold */;
        }
    }

    verification def SterilityVerification {
        doc /* Verify sterility of all fluid-contacting components before and during use */;
        subject system : CannulaDeliverySystem;
        objective {
            doc /* Perform sterility testing on reservoir, cannula, and fluid path components */;
        }
    }

    verification def FlowRateVerification {
        doc /* Verify flow rate accuracy under nominal operating conditions */;
        subject controller : FlowController;
        objective {
            doc /* Measure actual flow rate and compare against target within 10 percent */;
        }
    }

    verification def AlarmResponseVerification {
        doc /* Verify alarm triggers and delivery pauses when pressure exceeds threshold */;
        subject system : CannulaDeliverySystem;
        objective {
            doc /* Simulate overpressure condition and verify alarm and pause response */;
        }
    }
}
