package LawnMowerSystem {
    import ScalarValues::*;
    
    // ---- Unit Definitions ----
    unit cm;
    unit mm;
    unit L;
    unit kW;
    unit Nm;
    unit rpm;
    unit degC;
    
    // ---- Value Type Definitions ----
    value def CuttingWidth :> Real { unit cm; }
    value def CuttingHeight :> Real { unit mm; }
    value def BagCapacityValue :> Real { unit L; }
    value def GrassVolume :> Real { unit L; }
    value def FuelVolume :> Real { unit L; }
    value def Torque :> Real { unit Nm; }
    value def Power :> Real { unit kW; }
    value def RotationalSpeed :> Real { unit rpm; }
    value def Temperature :> Real { unit degC; }
    value def Area :> Real;
    
    // ---- Enumeration Definitions ----
    enum def EngineState { off; starting; running; stalled; }
    enum def BladeState { disengaged; engaged; }
    enum def BagStatus { empty; partiallyFull; full; }
    enum def MowerOperationalState { idle; settingHeight; safetyCheck; startingEngine; bladesEngaged; mowing; bagFullPaused; shuttingDown; }
    enum def ControlCommand { start; stop; engage; disengage; setHeight; empty; reset; }
    enum def DischargeMode { sideDischarge; rearDischarge; bagging; mulching; }
    
    // ---- Item Definitions ----
    item def Fuel;
    item def Air;
    item def ExhaustGas;
    item def GrassClipping;
    item def GrassSward;
    
    // ---- Port Definitions ----
    port def FuelPort {
        in fuel : Fuel;
    }
    port def AirPort {
        in air : Air;
    }
    port def ExhaustPort {
        out exhaust : ExhaustGas;
    }
    port def TorqueOutputPort {
        out torque : Torque;
    }
    port def TorqueInputPort {
        in torque : Torque;
    }
    port def ClippingOutputPort {
        out clipping : GrassClipping;
    }
    port def ClippingInputPort {
        in clipping : GrassClipping;
    }
    port def ControlPort {
        in command : ControlCommand;
        out status : ControlCommand;
    }
    port def SafetySignalPort {
        out operatorPresent : Boolean;
        out safetyBarEngaged : Boolean;
        out engagementPermitted : Boolean;
    }
    port def HeightAdjustmentPort {
        out currentHeight : CuttingHeight;
    }
    port def BagStatusPort {
        out fillLevel : GrassVolume;
        out status : BagStatus;
    }
    
    // ---- Engine Part Definition ----
    part def Engine {
        attribute ratedPower : Power = 3.0;
        attribute maxTorque : Torque = 8.5;
        attribute operatingSpeed : RotationalSpeed = 2900;
        attribute fuelTankCapacity : FuelVolume = 1.0;
        attribute currentFuelLevel : FuelVolume = 1.0;
        attribute engineTemperature : Temperature = 20.0;
        attribute state : EngineState = EngineState::off;
        
        port fuelIn : FuelPort;
        port airIn : AirPort;
        port exhaustOut : ExhaustPort;
        port torqueOut : TorqueOutputPort;
        port control : ControlPort;
        
        action generateTorque {
            in fuel : Fuel;
            in air : Air;
            out torque : Torque;
            out exhaust : ExhaustGas;
        }
        
        action consumeFuel {
            in fuel : Fuel;
            out remaining : FuelVolume;
        }
        
        state machine EngineStateMachine {
            entry; then Off;
            
            state Off {
                entry action turnOff;
            }
            state Starting {
                entry action crankEngine;
            }
            state Running {
                entry action sustainCombustion;
                do action generateTorque;
            }
            state Stalled {
                entry action flagFault;
            }
            
            transition off_to_starting
                first Off
                then Starting
                when control.command == ControlCommand::start;
            
            transition starting_to_running
                first Starting
                then Running
                when currentFuelLevel > 0;
            
            transition starting_to_off
                first Starting
                then Off
                when currentFuelLevel == 0;
            
            transition running_to_off
                first Running
                then Off
                when control.command == ControlCommand::stop;
            
            transition running_to_stalled
                first Running
                then Stalled
                when currentFuelLevel == 0;
            
            transition stalled_to_off
                first Stalled
                then Off
                when control.command == ControlCommand::reset;
        }
    }
    
    // ---- Blade Part Definition ----
    part def Blade {
        attribute bladeLength : CuttingWidth = 53;
        attribute tipSpeed : RotationalSpeed;
        attribute state : BladeState = BladeState::disengaged;
        attribute sharpness : Real = 1.0;
        
        port torqueIn : TorqueInputPort;
        
        action cutGrass {
            in torque : Torque;
            in sward : GrassSward;
            out clipping : GrassClipping;
        }
        
        action spin {
            in torque : Torque;
            out rotationalSpeed : RotationalSpeed;
        }
    }
    
    // ---- Cutting Deck Part Definition ----
    part def CuttingDeck {
        attribute deckWidth : CuttingWidth = 53;
        attribute currentHeight : CuttingHeight = 50;
        attribute minHeight : CuttingHeight = 25;
        attribute maxHeight : CuttingHeight = 100;
        attribute dischargeMode : DischargeMode = DischargeMode::bagging;
        attribute bladeState : BladeState = BladeState::disengaged;
        
        port torqueIn : TorqueInputPort;
        port clippingOut : ClippingOutputPort;
        port control : ControlPort;
        port heightIn : HeightAdjustmentPort;
        
        part blade : Blade;
        
        action spinBlades {
            in torque : Torque;
            out clipping : GrassClipping;
        }
        
        action dischargeClippings {
            in clipping : GrassClipping;
            out clipping : GrassClipping;
        }
        
        action engageBlades {
            out engaged : Boolean;
        }
        
        action disengageBlades {
            out disengaged : Boolean;
        }
    }
    
    // ---- Height Adjuster Part Definition ----
    part def HeightAdjuster {
        attribute minHeight : CuttingHeight = 25;
        attribute maxHeight : CuttingHeight = 100;
        attribute currentHeight : CuttingHeight = 50;
        attribute stepCount : Integer = 5;
        attribute stepSize : CuttingHeight = 18.75;
        
        port control : ControlPort;
        port heightOut : HeightAdjustmentPort;
        
        action adjustHeight {
            in targetHeight : CuttingHeight;
            out deckPosition : CuttingHeight;
        }
        
        action raiseDeck {
            out newHeight : CuttingHeight;
        }
        
        action lowerDeck {
            out newHeight : CuttingHeight;
        }
    }
    
    // ---- Safety Interlock Part Definition ----
    part def SafetyInterlock {
        attribute operatorPresent : Boolean = false;
        attribute safetyBarEngaged : Boolean = false;
        attribute bladeEngagementPermitted : Boolean = false;
        attribute faultDetected : Boolean = false;
        
        port control : ControlPort;
        port safetyOut : SafetySignalPort;
        port operatorSensorIn : SafetySignalPort;
        
        action checkSafety {
            in operatorPresent : Boolean;
            in safetyBarEngaged : Boolean;
            out permitted : Boolean;
        }
        
        action evaluateConditions {
            out permitted : Boolean;
        }
        
        action disableBlades {
            out disabled : Boolean;
        }
        
        state machine SafetyStateMachine {
            entry; then Unsafe;
            
            state Unsafe {
                entry action disableBlades;
                do action monitorSensors;
            }
            state Safe {
                do action monitorSensors;
            }
            
            transition unsafe_to_safe
                first Unsafe
                then Safe
                when operatorSensorIn.operatorPresent == true 
                    && operatorSensorIn.safetyBarEngaged == true;
            
            transition safe_to_unsafe
                first Safe
                then Unsafe
                when operatorSensorIn.operatorPresent == false 
                    || operatorSensorIn.safetyBarEngaged == false;
        }
    }
    
    // ---- Operator Presence Sensor Part Definition ----
    part def OperatorPresenceSensor {
        attribute detected : Boolean = false;
        attribute safetyBarPressed : Boolean = false;
        
        port safetyOut : SafetySignalPort;
        
        action detectOperator {
            out detected : Boolean;
        }
        
        action monitorSafetyBar {
            out pressed : Boolean;
        }
    }
    
    // ---- Collection Bag Part Definition ----
    part def CollectionBag {
        attribute capacity : BagCapacityValue = 60;
        attribute currentFillLevel : GrassVolume = 0;
        attribute status : BagStatus = BagStatus::empty;
        attribute fillSensorThreshold : GrassVolume = 58;
        
        port clippingIn : ClippingInputPort;
        port control : ControlPort;
        port bagStatusOut : BagStatusPort;
        
        action collectClippings {
            in clipping : GrassClipping;
            out fillLevel : GrassVolume;
        }
        
        action detectFull {
            out status : BagStatus;
        }
        
        action emptyBag {
            out status : BagStatus;
        }
        
        state machine BagStateMachine {
            entry; then Empty;
            
            state Empty {
                do action collectClippings;
            }
            state PartiallyFull {
                do action collectClippings;
            }
            state Full {
                entry action signalFull;
            }
            
            transition empty_to_partial
                first Empty
                then PartiallyFull
                when currentFillLevel > 0 && currentFillLevel < fillSensorThreshold;
            
            transition partial_to_full
                first PartiallyFull
                then Full
                when currentFillLevel >= fillSensorThreshold;
            
            transition full_to_empty
                first Full
                then Empty
                when control.command == ControlCommand::empty;
        }
    }
    
    // ---- Drive Shaft Part Definition ----
    part def DriveShaft {
        attribute maxTorque : Torque = 12.0;
        attribute efficiency : Real = 0.95;
        
        port torqueIn : TorqueInputPort;
        port torqueOut : TorqueOutputPort;
        
        action transferTorque {
            in torque : Torque;
            out torque : Torque;
        }
    }
    
    // ---- Clutch Part Definition ----
    part def Clutch {
        attribute engaged : Boolean = false;
        attribute state : BladeState = BladeState::disengaged;
        
        port torqueIn : TorqueInputPort;
        port torqueOut : TorqueOutputPort;
        port control : ControlPort;
        port safetyIn : SafetySignalPort;
        
        action engage {
            out engaged : Boolean;
        }
        
        action disengage {
            out disengaged : Boolean;
        }
        
        action transferTorque {
            in torque : Torque;
            out torque : Torque;
        }
    }
    
    // ---- Wheel Assembly Part Definition ----
    part def WheelAssembly {
        attribute wheelDiameter : CuttingWidth = 20;
        attribute count : Integer = 4;
        
        action supportDeck {
            out height : CuttingHeight;
        }
        
        action roll {
            in torque : Torque;
        }
    }
    
    // ---- Handle Assembly Part Definition ----
    part def HandleAssembly {
        attribute heightAdjustable : Boolean = true;
        attribute safetyBarPresent : Boolean = true;
        
        part safetyBar;
        
        action pushMower {
            out force : Real;
        }
    }
    
    // ---- Lawn Mower System Part Definition ----
    part def LawnMower {
        attribute modelName : String = "Residential Gas Mower GLM-53";
        attribute manufacturer : String = "GreenCut";
        attribute cuttingWidth : CuttingWidth = 53;
        attribute weight : Real = 28.0;
        attribute operationalState : MowerOperationalState = MowerOperationalState::idle;
        attribute targetCuttingHeight : CuttingHeight = 50;
        attribute lawnArea : Area = 500.0;
        
        port fuelIn : FuelPort;
        port control : ControlPort;
        
        part engine : Engine;
        part driveShaft : DriveShaft;
        part clutch : Clutch;
        part cuttingDeck : CuttingDeck;
        part heightAdjuster : HeightAdjuster;
        part safetyInterlock : SafetyInterlock;
        part operatorSensor : OperatorPresenceSensor;
        part collectionBag : CollectionBag;
        part wheels : WheelAssembly;
        part handle : HandleAssembly;
        
        // Connections
        connection fuelFeed connect fuelIn to engine.fuelIn;
        connection engineTorque connect engine.torqueOut to driveShaft.torqueIn;
        connection shaftToClutch connect driveShaft.torqueOut to clutch.torqueIn;
        connection clutchToDeck connect clutch.torqueOut to cuttingDeck.torqueIn;
        connection deckTorqueToBlade connect cuttingDeck.torqueIn to cuttingDeck.blade.torqueIn;
        connection clippingFlow connect cuttingDeck.clippingOut to collectionBag.clippingIn;
        connection operatorSafety connect operatorSensor.safetyOut to safetyInterlock.operatorSensorIn;
        connection safetyToClutch connect safetyInterlock.safetyOut to clutch.safetyIn;
        connection heightAdjust connect heightAdjuster.heightOut to cuttingDeck.heightIn;
        connection engineControl connect control to engine.control;
        connection clutchControl connect control to clutch.control;
        connection deckControl connect control to cuttingDeck.control;
        connection heightControl connect control to heightAdjuster.control;
        connection safetyControl connect control to safetyInterlock.control;
        connection bagControl connect control to collectionBag.control;
        connection bagStatus connect collectionBag.bagStatusOut to control;
        
        // Overall Mower State Machine
        state machine MowerOperationStateMachine {
            entry; then Idle;
            
            state Idle {
                entry action initializeSystem;
            }
            state SettingHeight {
                do action heightAdjuster.adjustHeight;
            }
            state SafetyCheck {
                do action safetyInterlock.checkSafety;
            }
            state StartingEngine {
                do action engine.generateTorque;
            }
            state BladesEngaged {
                do action clutch.engage;
            }
            state Mowing {
                do action cuttingDeck.spinBlades;
                do action collectionBag.collectClippings;
            }
            state BagFullPaused {
                entry action pauseOperation;
                do action collectionBag.detectFull;
            }
            state ShuttingDown {
                do action clutch.disengage;
                do action engine.consumeFuel;
            }
            
            transition idle_to_settingHeight
                first Idle
                then SettingHeight
                when control.command == ControlCommand::setHeight;
            
            transition settingHeight_to_safetyCheck
                first SettingHeight
                then SafetyCheck
                when heightAdjuster.currentHeight >= heightAdjuster.minHeight 
                    && heightAdjuster.currentHeight <= heightAdjuster.maxHeight;
            
            transition safetyCheck_to_startingEngine
                first SafetyCheck
                then StartingEngine
                when safetyInterlock.bladeEngagementPermitted == true;
            
            transition safetyCheck_to_idle
                first SafetyCheck
                then Idle
                when safetyInterlock.bladeEngagementPermitted == false;
            
            transition startingEngine_to_bladesEngaged
                first StartingEngine
                then BladesEngaged
                when engine.state == EngineState::running;
            
            transition bladesEngaged_to_mowing
                first BladesEngaged
                then Mowing
                when clutch.state == BladeState::engaged;
            
            transition mowing_to_bagFullPaused
                first Mowing
                then BagFullPaused
                when collectionBag.status == BagStatus::full;
            
            transition bagFullPaused_to_mowing
                first BagFullPaused
                then Mowing
                when collectionBag.status == BagStatus::empty;
            
            transition mowing_to_shuttingDown
                first Mowing
                then ShuttingDown
                when control.command == ControlCommand::stop;
            
            transition shuttingDown_to_idle
                first ShuttingDown
                then Idle
                when engine.state == EngineState::off 
                    && clutch.state == BladeState::disengaged;
        }
        
        // Composite Mowing Operation Action
        action performMowingOperation {
            in targetHeight : CuttingHeight;
            in lawnArea : Area;
            
            action setCuttingHeight {
                in height : CuttingHeight;
                out adjustedHeight : CuttingHeight;
            }
            action verifySafety {
                out permitted : Boolean;
            }
            action startEngine {
                out running : Boolean;
            }
            action engageBlades {
                out engaged : Boolean;
            }
            action cutLawn {
                in area : Area;
                out clipping : GrassClipping;
            }
            action monitorBag {
                out full : Boolean;
            }
            action emptyBagIfNeeded {
                out emptied : Boolean;
            }
            action disengageBlades {
                out disengaged : Boolean;
            }
            action shutdownEngine {
                out off : Boolean;
            }
            
            succession s1 first setCuttingHeight then verifySafety;
            succession s2 first verifySafety then startEngine;
            succession s3 first startEngine then engageBlades;
            succession s4 first engageBlades then cutLawn;
            succession s5 first cutLawn then monitorBag;
            succession s6 first monitorBag then emptyBagIfNeeded;
            succession s7 first emptyBagIfNeeded then disengageBlades;
            succession s8 first disengageBlades then shutdownEngine;
        }
    }
    
    // ---- Requirement Definitions ----
    requirement def CuttingHeightRangeRequirement {
        attribute minCuttingHeight : CuttingHeight = 25;
        attribute maxCuttingHeight : CuttingHeight = 100;
        subject mower : LawnMower;
        require {
            mower.heightAdjuster.minHeight >= minCuttingHeight
            && mower.heightAdjuster.maxHeight <= maxCuttingHeight
            && mower.heightAdjuster.currentHeight >= minCuttingHeight
            && mower.heightAdjuster.currentHeight <= maxCuttingHeight;
        }
    }
    
    requirement def CuttingWidthRequirement {
        attribute requiredWidth : CuttingWidth = 53;
        subject mower : LawnMower;
        require {
            mower.cuttingDeck.deckWidth == requiredWidth;
        }
    }
    
    requirement def SafetyInterlockRequirement {
        subject mower : LawnMower;
        require {
            mower.cuttingDeck.bladeState == BladeState::disengaged
            when mower.safetyInterlock.operatorPresent == false
            || mower.safetyInterlock.safetyBarEngaged == false;
        }
    }
    
    requirement def BladeEngagementSafetyRequirement {
        subject mower : LawnMower;
        require {
            mower.clutch.state == BladeState::disengaged
            when mower.safetyInterlock.bladeEngagementPermitted == false;
        }
    }
    
    requirement def CollectionBagCapacityRequirement {
        attribute requiredCapacity : BagCapacityValue = 60;
        subject mower : LawnMower;
        require {
            mower.collectionBag.capacity >= requiredCapacity;
        }
    }
    
    requirement def BagFullDetectionRequirement {
        subject mower : LawnMower;
        require {
            mower.collectionBag.status == BagStatus::full
            when mower.collectionBag.currentFillLevel >= mower.collectionBag.fillSensorThreshold;
        }
    }
    
    requirement def EnginePowerRequirement {
        attribute minPower : Power = 2.0;
        subject mower : LawnMower;
        require {
            mower.engine.ratedPower >= minPower;
        }
    }
    
    requirement def OperationSequenceRequirement {
        subject mower : LawnMower;
        require {
            mower.safetyInterlock.bladeEngagementPermitted == true
            before mower.clutch.state == BladeState::engaged;
        }
    }
    
    requirement def BagFullPauseRequirement {
        subject mower : LawnMower;
        require {
            mower.operationalState == MowerOperationalState::bagFullPaused
            when mower.collectionBag.status == BagStatus::full;
        }
    }
    
    requirement def FuelCapacityRequirement {
        attribute minFuelCapacity : FuelVolume = 0.8;
        subject mower : LawnMower;
        require {
            mower.engine.fuelTankCapacity >= minFuelCapacity;
        }
    }
    
    requirement def DischargeModeRequirement {
        subject mower : LawnMower;
        require {
            mower.cuttingDeck.dischargeMode == DischargeMode::bagging;
        }
    }
    
    // ---- Requirement Group ----
    requirement mowerSystemRequirements {
        requirement cuttingHeightRangeReq : CuttingHeightRangeRequirement;
        requirement cuttingWidthReq : CuttingWidthRequirement;
        requirement safetyInterlockReq : SafetyInterlockRequirement;
        requirement bladeEngagementSafetyReq : BladeEngagementSafetyRequirement;
        requirement collectionBagCapacityReq : CollectionBagCapacityRequirement;
        requirement bagFullDetectionReq : BagFullDetectionRequirement;
        requirement enginePowerReq : EnginePowerRequirement;
        requirement operationSequenceReq : OperationSequenceRequirement;
        requirement bagFullPauseReq : BagFullPauseRequirement;
        requirement fuelCapacityReq : FuelCapacityRequirement;
        requirement dischargeModeReq : DischargeModeRequirement;
    }
    
    // ---- Verification Definitions ----
    verification verifySafetyInterlock {
        subject mower : LawnMower;
        objective {
            confirm mower.cuttingDeck.bladeState == BladeState::disengaged
            when mower.safetyInterlock.operatorPresent == false;
        }
        method action testOperatorAbsence {
            in mower : LawnMower;
            out result : Boolean;
        }
    }
    
    verification verifyCuttingHeightRange {
        subject mower : LawnMower;
        objective {
            confirm mower.heightAdjuster.currentHeight >= 25
            && mower.heightAdjuster.currentHeight <= 100;
        }
        method action testHeightAdjustment {
            in mower : LawnMower;
            in targetHeight : CuttingHeight;
            out result : Boolean;
        }
    }
    
    verification verifyBagFullDetection {
        subject mower : LawnMower;
        objective {
            confirm mower.collectionBag.status == BagStatus::full
            when mower.collectionBag.currentFillLevel >= mower.collectionBag.fillSensorThreshold;
        }
        method action testBagFill {
            in mower : LawnMower;
            in fillAmount : GrassVolume;
            out result : Boolean;
        }
    }
    
    verification verifyOperationSequence {
        subject mower : LawnMower;
        objective {
            confirm mower.safetyInterlock.bladeEngagementPermitted == true
            before mower.clutch.state == BladeState::engaged;
        }
        method action testSequence {
            in mower : LawnMower;
            out result : Boolean;
        }
    }
    
    // ---- System Instance ----
    part residentialMower : LawnMower {
        attribute serialNumber : String = "GLM-53-2024-0001";
    }
}
