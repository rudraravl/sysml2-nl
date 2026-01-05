package WangensteenSuctionSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    attribute def PressureValue :> ISQ::PressureValue;
    attribute def VolumeValue :> ISQ::VolumeValue;
    attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;
    attribute def LengthValue :> ISQ::LengthValue;
    attribute def TimeValue :> ISQ::TimeValue;

    enum def SuctionMode {
        off;
        continuous;
        intermittent;
    }

    enum def SystemState {
        idle;
        priming;
        operating;
        alarm;
        maintenance;
    }

    item def GastricFluid {
        attribute volume : VolumeValue;
        attribute viscosity : Real;
    }

    item def Air;

    port def FluidPort {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        in item gastricContent : GastricFluid[*];
        out item airFlow : Air[*];
    }

    port def ControlPort {
        in attribute commandMode : SuctionMode;
        out attribute statusReady : Boolean;
        out attribute alarmSignal : Boolean;
    }

    part def NasogastricTube {
        doc /* Flexible tube inserted through nose into stomach for drainage. */
        attribute length : LengthValue;
        attribute innerDiameter : LengthValue;
        port patientEnd : FluidPort;
        port systemEnd : FluidPort;
        
        assert constraint tubePatency {
            systemEnd.flowRate >= 0.0
        }
    }

    part def SuctionRegulator {
        doc /* Controls and maintains desired negative pressure level. */
        attribute targetPressure : PressureValue;
        attribute actualPressure : PressureValue;
        attribute tolerance : PressureValue;
        port pressureInput : FluidPort;
        port pressureOutput : FluidPort;
        port control : ControlPort;
        
        assert constraint regulationAccuracy {
            actualPressure >= targetPressure - tolerance and
            actualPressure <= targetPressure + tolerance
        }
    }

    part def CollectionBottle {
        doc /* Graduated container for collecting and measuring drainage. */
        attribute capacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute graduations : VolumeValue[*];
        port inlet : FluidPort;
        port outlet : FluidPort;
        port vent : FluidPort;
        
        assert constraint volumeLimit {
            currentVolume <= capacity
        }
        
        assert constraint overflowProtection {
            currentVolume <= 0.9 * capacity
        }
    }

    part def WaterSealChamber {
        doc /* Provides one-way valve function and pressure indication. */
        attribute waterLevel : LengthValue;
        attribute sealDepth : LengthValue;
        port fluidInlet : FluidPort;
        port atmosphericVent : FluidPort;
        
        assert constraint sealIntegrity {
            waterLevel >= sealDepth
        }
    }

    part def VacuumPump {
        doc /* Generates controlled negative pressure for suction. */
        attribute maxVacuum : PressureValue;
        attribute currentVacuum : PressureValue;
        attribute operatingMode : SuctionMode;
        port vacuumPort : FluidPort;
        port control : ControlPort;
        
        assert constraint vacuumLimit {
            currentVacuum >= maxVacuum and
            currentVacuum <= 0.0
        }
    }

    part def PressureGauge {
        doc /* Displays current suction pressure level. */
        attribute displayedPressure : PressureValue;
        attribute minReading : PressureValue;
        attribute maxReading : PressureValue;
        port measurementPort : FluidPort;
    }

    part def SafetyValve {
        doc /* Prevents excessive negative pressure that could harm tissue. */
        attribute releaseThreshold : PressureValue;
        attribute isOpen : Boolean;
        port pressureMonitor : FluidPort;
        
        assert constraint safetyActivation {
            isOpen == (pressureMonitor.pressure < releaseThreshold)
        }
    }

    part def ControlUnit {
        doc /* Manages system operation modes and safety monitoring. */
        attribute selectedMode : SuctionMode;
        attribute pressureSetting : PressureValue;
        attribute alarmActive : Boolean;
        attribute intermittentOnTime : TimeValue;
        attribute intermittentOffTime : TimeValue;
        port systemControl : ControlPort;
    }

    part def WangensteenSuctionApparatus {
        doc /* Complete gastric decompression system using controlled negative pressure 
             * to continuously or intermittently drain gastric and intestinal contents,
             * preventing distension and promoting healing after surgery or obstruction. */
        
        attribute systemPressure : PressureValue;
        attribute totalDrainageVolume : VolumeValue;
        attribute operationalMode : SuctionMode;
        attribute systemStatus : SystemState;
        
        part ngTube : NasogastricTube {
            attribute :>> length;
            attribute :>> innerDiameter;
        }
        
        part collectionBottle : CollectionBottle {
            attribute :>> capacity;
            attribute :>> currentVolume;
        }
        
        part waterSeal : WaterSealChamber {
            attribute :>> waterLevel;
            attribute :>> sealDepth;
        }
        
        part regulator : SuctionRegulator {
            attribute :>> targetPressure;
            attribute :>> tolerance;
        }
        
        part pump : VacuumPump {
            attribute :>> maxVacuum;
            attribute :>> operatingMode;
        }
        
        part gauge : PressureGauge {
            attribute :>> minReading;
            attribute :>> maxReading;
        }
        
        part safetyValve : SafetyValve {
            attribute :>> releaseThreshold;
            attribute :>> isOpen;
        }
        
        part controlUnit : ControlUnit {
            attribute :>> selectedMode;
            attribute :>> pressureSetting;
            attribute :>> intermittentOnTime;
            attribute :>> intermittentOffTime;
        }
        
        connection tubeToBottle connect ngTube.systemEnd to collectionBottle.inlet;
        connection bottleToSeal connect collectionBottle.outlet to waterSeal.fluidInlet;
        connection sealToRegulator connect waterSeal.atmosphericVent to regulator.pressureInput;
        connection regulatorToPump connect regulator.pressureOutput to pump.vacuumPort;
        connection gaugeMonitoring connect gauge.measurementPort to regulator.pressureOutput;
        connection safetyMonitoring connect safetyValve.pressureMonitor to regulator.pressureOutput;
        connection pumpControl connect pump.control to controlUnit.systemControl;
        connection regulatorControl connect regulator.control to controlUnit.systemControl;
        
        assert constraint pressureConsistency {
            systemPressure == regulator.actualPressure
        }
        
        assert constraint drainageTracking {
            totalDrainageVolume == collectionBottle.currentVolume
        }
    }

    action def InitializeSystem {
        out systemReady : Boolean;
        out primeComplete : Boolean;
    }

    action def MonitorDrainage {
        in currentVolume : VolumeValue;
        in capacity : VolumeValue;
        out volumeStatus : Boolean;
        out alertRequired : Boolean;
    }

    action def RegulateVacuum {
        in targetPressure : PressureValue;
        in currentPressure : PressureValue;
        out adjustment : Real;
    }

    action def CycleIntermittent {
        in onDuration : TimeValue;
        in offDuration : TimeValue;
        out cycleComplete : Boolean;
    }

    action def EmptyCollectionBottle {
        in bottleVolume : VolumeValue;
        out emptyComplete : Boolean;
        out volumeRecorded : VolumeValue;
    }

    action def ActivateSafetyRelease {
        in pressureExceeded : Boolean;
        out valveOpened : Boolean;
        out alarmTriggered : Boolean;
    }

    state def SuctionOperationStates {
        entry; then idle;
        
        state idle;
        state priming;
        
        state operating {
            state continuousSuction;
            
            state intermittentSuction {
                state suctionActive;
                state suctionPaused;
                
                transition cycleOn
                    first suctionPaused
                    then suctionActive;
                    
                transition cycleOff
                    first suctionActive
                    then suctionPaused;
            }
            
            transition selectContinuous
                first operating
                then continuousSuction;
                
            transition selectIntermittent
                first operating
                then intermittentSuction;
        }
        
        state alarm;
        state maintenance;
        
        transition startSystem
            first idle
            then priming;
            
        transition beginOperation
            first priming
            then operating;
            
        transition bottleFullAlarm
            first operating
            then alarm;
            
        transition pressureAlarm
            first operating
            then alarm;
            
        transition clearAlarm
            first alarm
            then idle;
            
        transition enterMaintenance
            first idle
            then maintenance;
            
        transition exitMaintenance
            first maintenance
            then idle;
            
        transition emergencyStop
            first operating
            then idle;
    }

    action def PerformGastricDecompression {
        doc /* Primary operational sequence for gastric drainage and decompression. */
        
        first start;
        then merge monitoringLoop;
        
        then action initialize : InitializeSystem {
            out systemReady : Boolean;
            out primeComplete : Boolean;
        }
        
        then action monitor : MonitorDrainage {
            in currentVolume : VolumeValue;
            in capacity : VolumeValue;
            out volumeStatus : Boolean;
            out alertRequired : Boolean;
        }
        
        then decide;
            if monitor.alertRequired then handleAlert;
            if not monitor.alertRequired and monitor.volumeStatus then regulate;
            if not monitor.volumeStatus then emptyBottle;
        
        action regulate : RegulateVacuum {
            in targetPressure : PressureValue;
            in currentPressure : PressureValue;
            out adjustment : Real;
        }
        then monitoringLoop;
        
        action emptyBottle : EmptyCollectionBottle {
            in bottleVolume : VolumeValue;
            out emptyComplete : Boolean;
            out volumeRecorded : VolumeValue;
        }
        then monitoringLoop;
        
        action handleAlert : ActivateSafetyRelease {
            in pressureExceeded : Boolean;
            out valveOpened : Boolean;
            out alarmTriggered : Boolean;
        }
        then done;
    }

    requirement <'REQ-WS-100'> primaryFunctionRequirement {
        doc /* The Wangensteen suction system shall provide controlled negative pressure
             * drainage of gastric and intestinal contents to prevent abdominal distension,
             * reduce nausea and vomiting, and promote healing following gastrointestinal
             * surgery or in cases of intestinal obstruction. */
        subject apparatus : WangensteenSuctionApparatus;
    }

    requirement <'REQ-WS-101'> pressureControlRequirement {
        doc /* The system shall maintain suction pressure within therapeutic range
             * to ensure effective drainage without causing mucosal damage. */
        subject apparatus : WangensteenSuctionApparatus;
        
        assert constraint {
            apparatus.systemPressure >= -120.0 and
            apparatus.systemPressure <= -40.0
        }
    }

    requirement <'REQ-WS-102'> collectionCapacityRequirement {
        doc /* The collection system shall have minimum capacity of 2000 mL
             * with visible graduated markings for accurate volume measurement. */
        subject bottle : CollectionBottle;
        
        assert constraint {
            bottle.capacity >= 2000.0
        }
    }

    requirement <'REQ-WS-103'> safetyRequirement {
        doc /* The system shall include automatic pressure relief mechanism
             * to prevent excessive suction that could cause tissue trauma or bleeding. */
        subject apparatus : WangensteenSuctionApparatus;
        
        assert constraint {
            apparatus.safetyValve.releaseThreshold >= -150.0
        }
    }

    requirement <'REQ-WS-104'> operationalModeRequirement {
        doc /* The system shall support both continuous and intermittent
             * suction modes to accommodate different clinical protocols. */
        subject apparatus : WangensteenSuctionApparatus;
        
        assert constraint {
            apparatus.operationalMode == SuctionMode::continuous or
            apparatus.operationalMode == SuctionMode::intermittent
        }
    }

    requirement <'REQ-WS-105'> waterSealRequirement {
        doc /* The system shall incorporate water seal chamber to prevent
             * atmospheric air from entering the drainage system and to
             * provide visual indication of system patency. */
        subject seal : WaterSealChamber;
        
        assert constraint {
            seal.waterLevel >= seal.sealDepth
        }
    }

    part wangensteenSystem : WangensteenSuctionApparatus {
        perform action decompressionOperation : PerformGastricDecompression;
        exhibit state operationStateMachine : SuctionOperationStates;
    }

    satisfy primaryFunctionRequirement by wangensteenSystem;
    satisfy pressureControlRequirement by wangensteenSystem;
    satisfy collectionCapacityRequirement by wangensteenSystem.collectionBottle;
    satisfy safetyRequirement by wangensteenSystem;
    satisfy operationalModeRequirement by wangensteenSystem;
    satisfy waterSealRequirement by wangensteenSystem.waterSeal;
}
