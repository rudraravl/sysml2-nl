package Miele_G7310_Dishwasher {

    import ScalarValues::*;
    import ISQ::*;
    import ISQVolume::*;
    import ISQTemperature::*;
    import ISQPower::*;
    import ISQEnergy::*;
    import ISQPressure::*;
    import ISQMass::*;
    import ISQTime::*;
    import ISQSoundPressureLevel::*;

    // ===== Value Types =====

    value def TemperatureValue :> Real { unit 'degC'; }
    value def VolumeValue :> Real { unit 'L'; }
    value def FlowRateValue :> Real { unit 'L/min'; }
    value def PowerValue :> Real { unit 'W'; }
    value def EnergyValue :> Real { unit 'kWh'; }
    value def PressureValue :> Real { unit 'bar'; }
    value def SoundLevelValue :> Real { unit 'dB'; }
    value def TurbidityValue :> Real { unit 'NTU'; }
    value def DurationValue :> Real { unit 'min'; }
    value def MassValue :> Real { unit 'g'; }
    value def PercentValue :> Real { unit '%'; }

    // ===== Enumerations =====

    enum def WashProgram {
        eco;
        intensive;
        quick;
        automatic;
        powerWash;
        extraQuiet;
    }

    enum def CyclePhase {
        idle;
        doorLocking;
        preWash;
        preWashDrain;
        mainWash;
        mainWashDrain;
        rinse1;
        rinse1Drain;
        rinse2;
        rinse2Drain;
        finalRinse;
        finalRinseDrain;
        drying;
        cooling;
        doorUnlocking;
        complete;
    }

    enum def DoorLockState {
        unlocked;
        locked;
        fault;
    }

    enum def HeaterState {
        off;
        heating;
        maintaining;
        fault;
    }

    enum def PumpState {
        off;
        running;
        fault;
    }

    enum def DispenserState {
        closed;
        open;
        dispensed;
    }

    // ===== Item Types =====

    item def Water {
        attribute temperature : TemperatureValue;
        attribute hardness : Real; // in German degrees
        attribute turbidity : TurbidityValue;
        attribute volume : VolumeValue;
    }

    item def SoftenedWater :> Water {
        constraint { hardness <= 4.0; }
    }

    item def HotWater :> Water {
        constraint { temperature >= 40.0; }
    }

    item def Detergent {
        attribute mass : MassValue;
        attribute type : String;
    }

    item def RinseAid {
        attribute volume : VolumeValue;
    }

    item def Dish {
        attribute soiled : Boolean;
        attribute sanitized : Boolean;
        attribute dry : Boolean;
    }

    item def DishLoad {
        attribute dishes : Dish[0..*];
        attribute placeSettings : Integer;
        constraint { placeSettings <= 14; }
    }

    item def SoilParticle {
        attribute mass : MassValue;
    }

    item def DirtyWater :> Water {
        attribute soilContent : MassValue;
        constraint { turbidity >= 10.0; }
    }

    // ===== Port Definitions =====

    port def WaterInPort {
        in item water : Water;
    }

    port def WaterOutPort {
        out item water : Water;
    }

    port def HotWaterPort {
        out item water : HotWater;
    }

    port def PressurizedWaterPort {
        out item water : HotWater;
        attribute pressure : PressureValue;
    }

    port def DrainPort {
        out item water : DirtyWater;
    }

    port def ElectricalPowerPort {
        attribute voltage : Real = 230;
        attribute frequency : Real = 50;
        in attribute power : PowerValue;
    }

    port def ControlSignalPort {
        attribute command : String;
        attribute value : Real;
    }

    port def SensorDataPort {
        attribute reading : Real;
        attribute unit : String;
        attribute status : String;
    }

    port def DetergentPort {
        out item detergent : Detergent;
    }

    port def RinseAidPort {
        out item rinseAid : RinseAid;
    }

    // ===== Component Part Definitions =====

    part def InletValve {
        port waterSupply : WaterInPort;
        port softenerFeed : WaterOutPort;
        port power : ElectricalPowerPort;
        port control : ControlSignalPort;
        attribute flowRate : FlowRateValue = 8.0;
        attribute isOpen : Boolean = false;
        attribute maxPressure : PressureValue = 10.0;

        action def Open {
            in signal : ControlSignalPort;
            then Flowing;
        }
        action def Flowing {
            out water : Water;
        }
        action def Close {
            then Stopped;
        }
        action def Stopped {}

        exhibit {
            when isOpen then Flowing;
        }
    }

    part def WaterSoftener {
        port inlet : WaterInPort;
        port outlet : WaterOutPort;
        port control : ControlSignalPort;
        attribute resinCapacity : VolumeValue = 20.0;
        attribute regenerationNeeded : Boolean = false;
        attribute saltLevel : PercentValue = 100.0;

        action def Soften {
            in hardWater : Water;
            out softWater : SoftenedWater;
        }

        exhibit {
            perform Soften;
        }
    }

    part def HeatingSystem {
        port waterIn : WaterInPort;
        port waterOut : HotWaterPort;
        port power : ElectricalPowerPort;
        port control : ControlSignalPort;
        port tempFeedback : SensorDataPort;
        attribute maxPower : PowerValue = 2000.0;
        attribute targetTemp : TemperatureValue;
        attribute currentTemp : TemperatureValue;
        attribute state : HeaterState = off;

        state def HeatingBehavior {
            entry; then Off;
            state Off {
                entry { state = HeaterState::off; }
                transition on control.command == "heat" to Heating;
            }
            state Heating {
                entry { state = HeaterState::heating; }
                transition when currentTemp >= targetTemp to Maintaining;
                transition on control.command == "stop" to Off;
            }
            state Maintaining {
                entry { state = HeaterState::maintaining; }
                transition when currentTemp < targetTemp - 2.0 to Heating;
                transition on control.command == "stop" to Off;
            }
            state Fault {
                entry { state = HeaterState::fault; }
            }
        }

        exhibit {
            state machine HeatingBehavior;
        }
    }

    part def TemperatureSensor {
        port data : SensorDataPort;
        port power : ElectricalPowerPort;
        attribute reading : TemperatureValue;
        attribute accuracy : TemperatureValue = 1.0;
        attribute rangeMin : TemperatureValue = 0.0;
        attribute rangeMax : TemperatureValue = 90.0;

        action def Measure {
            out temp : TemperatureValue;
        }

        exhibit {
            perform Measure;
        }
    }

    part def WaterLevelSensor {
        port data : SensorDataPort;
        port power : ElectricalPowerPort;
        attribute reading : VolumeValue;
        attribute threshold : VolumeValue = 5.0;
        attribute overflowThreshold : VolumeValue = 15.0;

        action def Measure {
            out level : VolumeValue;
        }

        exhibit {
            perform Measure;
        }
    }

    part def TurbiditySensor {
        port data : SensorDataPort;
        port power : ElectricalPowerPort;
        attribute reading : TurbidityValue;
        attribute cleanThreshold : TurbidityValue = 15.0;
        attribute dirtyThreshold : TurbidityValue = 100.0;

        action def Measure {
            out turbidity : TurbidityValue;
        }

        exhibit {
            perform Measure;
        }
    }

    part def CirculationPump {
        port waterIn : WaterInPort;
        port waterOut : PressurizedWaterPort;
        port power : ElectricalPowerPort;
        port control : ControlSignalPort;
        attribute maxPressure : PressureValue = 1.5;
        attribute flowRate : FlowRateValue = 25.0;
        attribute state : PumpState = off;
        attribute speed : Integer = 0;

        action def Pump {
            in water : Water;
            out pressurized : HotWater;
        }

        exhibit {
            when state == PumpState::running then Pump;
        }
    }

    part def DrainPump {
        port waterIn : WaterInPort;
        port drainOut : DrainPort;
        port power : ElectricalPowerPort;
        port control : ControlSignalPort;
        attribute flowRate : FlowRateValue = 20.0;
        attribute state : PumpState = off;
        attribute maxHead : Real = 1.5;

        action def Drain {
            in dirtyWater : DirtyWater;
            out drained : DirtyWater;
        }

        exhibit {
            when state == PumpState::running then Drain;
        }
    }

    part def SprayArm {
        port waterIn : PressurizedWaterPort;
        port sprayOut : WaterOutPort;
        attribute position : String;
        attribute rotationSpeed : Real = 30.0;
        attribute nozzles : Integer = 14;
        attribute isRotating : Boolean = false;

        action def Spray {
            in pressurizedWater : HotWater;
            out spray : HotWater;
        }

        exhibit {
            when isRotating then Spray;
        }
    }

    part def DetergentDispenser {
        port detergentOut : DetergentPort;
        port control : ControlSignalPort;
        attribute capacity : MassValue = 50.0;
        attribute currentLoad : MassValue;
        attribute state : DispenserState = closed;
        attribute releaseTime : DurationValue;

        action def Release {
            out detergent : Detergent;
        }

        exhibit {
            when state == DispenserState::open then Release;
        }
    }

    part def RinseAidDispenser {
        port rinseAidOut : RinseAidPort;
        port control : ControlSignalPort;
        attribute capacity : VolumeValue = 0.2;
        attribute currentLevel : VolumeValue;
        attribute state : DispenserState = closed;

        action def Release {
            out rinseAid : RinseAid;
        }

        exhibit {
            when state == DispenserState::open then Release;
        }
    }

    part def DishRack {
        attribute type : String;
        attribute capacity : Integer;
        attribute adjustable : Boolean = true;
        attribute loadedItems : Integer = 0;
        item dishes : Dish[0..*];

        action def Load {
            in load : DishLoad;
        }
        action def Unload {
            out load : DishLoad;
        }
    }

    part def CutleryBasket {
        attribute capacity : Integer = 100;
        attribute loadedItems : Integer = 0;
        item cutlery : Dish[0..*];
    }

    part def WashingChamber {
        part upperRack : DishRack {
            attribute type = "upper";
            attribute capacity = 6;
        }
        part lowerRack : DishRack {
            attribute type = "lower";
            attribute capacity = 8;
        }
        part cutleryBasket : CutleryBasket;
        attribute volume : VolumeValue = 40.0;
        attribute interiorTemp : TemperatureValue;
        attribute humidity : PercentValue;
    }

    part def DoorLock {
        port control : ControlSignalPort;
        port power : ElectricalPowerPort;
        attribute state : DoorLockState = unlocked;
        attribute engagedPhase : CyclePhase;

        state def LockBehavior {
            entry; then Unlocked;
            state Unlocked {
                entry { state = DoorLockState::unlocked; }
                transition on control.command == "lock" to Locked;
            }
            state Locked {
                entry { state = DoorLockState::locked; }
                transition on control.command == "unlock" to Unlocked;
            }
            state Fault {
                entry { state = DoorLockState::fault; }
            }
        }

        exhibit {
            state machine LockBehavior;
        }
    }

    part def LeakProtectionSystem {
        port sensor : SensorDataPort;
        port control : ControlSignalPort;
        attribute active : Boolean = true;
        attribute leakDetected : Boolean = false;
        attribute floatSwitchTriggered : Boolean = false;

        action def Monitor {
            out leakStatus : Boolean;
        }
        action def ShutOff {
            // Closes inlet valve and activates drain pump
        }

        exhibit {
            perform Monitor;
            when leakDetected then ShutOff;
        }
    }

    part def ControlModule {
        port tempSensor : SensorDataPort;
        port levelSensor : SensorDataPort;
        port turbiditySensor : SensorDataPort;
        port leakSensor : SensorDataPort;
        port inletValveControl : ControlSignalPort;
        port softenerControl : ControlSignalPort;
        port heaterControl : ControlSignalPort;
        port circulationPumpControl : ControlSignalPort;
        port drainPumpControl : ControlSignalPort;
        port detergentControl : ControlSignalPort;
        port rinseAidControl : ControlSignalPort;
        port doorLockControl : ControlSignalPort;
        port upperSprayArmControl : ControlSignalPort;
        port lowerSprayArmControl : ControlSignalPort;
        port power : ElectricalPowerPort;
        port userInterface : ControlSignalPort;

        attribute selectedProgram : WashProgram = eco;
        attribute currentPhase : CyclePhase = idle;
        attribute cycleStartTime : DurationValue;
        attribute elapsedCycleTime : DurationValue;
        attribute estimatedRemaining : DurationValue;
        attribute waterUsed : VolumeValue = 0.0;
        attribute energyUsed : EnergyValue = 0.0;
        attribute targetTemp : TemperatureValue;
        attribute cycleComplete : Boolean = false;

        attribute programTemps : TemperatureValue[6] = (50.0, 70.0, 45.0, 55.0, 65.0, 48.0);
        attribute programDurations : DurationValue[6] = (180.0, 150.0, 60.0, 120.0, 90.0, 200.0);
        attribute programWaterUsage : VolumeValue[6] = (8.5, 9.5, 9.0, 8.0, 9.0, 8.0);

        action def ExecuteCycle {
            in program : WashProgram;
            // Full cycle orchestration
        }

        action def SelectProgram {
            in program : WashProgram;
            then ExecuteCycle;
        }

        action def MonitorSensors {
            in temp : TemperatureValue;
            in level : VolumeValue;
            in turbidity : TurbidityValue;
        }

        action def AdjustCycle {
            in turbidity : TurbidityValue;
            // Adjust cycle duration based on turbidity
        }

        state def CycleStateMachine {
            entry; then Idle;
            state Idle {
                entry { currentPhase = CyclePhase::idle; }
                transition on userInterface.command == "start" to DoorLocking;
            }
            state DoorLocking {
                entry { currentPhase = CyclePhase::doorLocking; }
                transition when doorLockControl.status == "locked" to PreWash;
            }
            state PreWash {
                entry { currentPhase = CyclePhase::preWash; }
                // Open inlet valve, run circulation pump with cold water
                transition when elapsedCycleTime >= 5.0 to PreWashDrain;
            }
            state PreWashDrain {
                entry { currentPhase = CyclePhase::preWashDrain; }
                // Run drain pump
                transition when levelSensor.reading <= 0.5 to MainWash;
            }
            state MainWash {
                entry { currentPhase = CyclePhase::mainWash; }
                // Fill, heat, release detergent, circulate
                transition when elapsedCycleTime >= 30.0 to MainWashDrain;
            }
            state MainWashDrain {
                entry { currentPhase = CyclePhase::mainWashDrain; }
                transition when levelSensor.reading <= 0.5 to Rinse1;
            }
            state Rinse1 {
                entry { currentPhase = CyclePhase::rinse1; }
                transition when elapsedCycleTime >= 10.0 to Rinse1Drain;
            }
            state Rinse1Drain {
                entry { currentPhase = CyclePhase::rinse1Drain; }
                transition when levelSensor.reading <= 0.5 to Rinse2;
            }
            state Rinse2 {
                entry { currentPhase = CyclePhase::rinse2; }
                transition when elapsedCycleTime >= 10.0 to Rinse2Drain;
            }
            state Rinse2Drain {
                entry { currentPhase = CyclePhase::rinse2Drain; }
                transition when levelSensor.reading <= 0.5 to FinalRinse;
            }
            state FinalRinse {
                entry { currentPhase = CyclePhase::finalRinse; }
                // Heat to sanitization temperature, release rinse aid
                transition when tempSensor.reading >= 70.0 and elapsedCycleTime >= 8.0 to FinalRinseDrain;
            }
            state FinalRinseDrain {
                entry { currentPhase = CyclePhase::finalRinseDrain; }
                transition when levelSensor.reading <= 0.5 to Drying;
            }
            state Drying {
                entry { currentPhase = CyclePhase::drying; }
                // Condensation drying
                transition when elapsedCycleTime >= 25.0 to Cooling;
            }
            state Cooling {
                entry { currentPhase = CyclePhase::cooling; }
                transition when tempSensor.reading <= 45.0 to DoorUnlocking;
            }
            state DoorUnlocking {
                entry { currentPhase = CyclePhase::doorUnlocking; }
                transition when doorLockControl.status == "unlocked" to Complete;
            }
            state Complete {
                entry { currentPhase = CyclePhase::complete; cycleComplete = true; }
                transition on userInterface.command == "reset" to Idle;
            }
        }

        exhibit {
            state machine CycleStateMachine;
            perform MonitorSensors;
        }
    }

    part def UserInterface {
        port control : ControlSignalPort;
        port power : ElectricalPowerPort;
        attribute display : String;
        attribute selectedProgram : WashProgram;
        attribute remainingTime : DurationValue;
        attribute statusIndicator : CyclePhase;
        attribute buttons : String[0..*] = ("power", "start", "delay", "program", "options");

        action def DisplayStatus {
            out info : String;
        }
        action def AcceptInput {
            in selection : WashProgram;
        }

        exhibit {
            perform DisplayStatus;
            perform AcceptInput;
        }
    }

    // ===== Top-Level Dishwasher Assembly =====

    part def MieleG7310Dishwasher {
        attribute modelNumber : String = "G7310";
        attribute brand : String = "Miele";
        attribute series : String = "G7000";
        attribute energyRating : String = "A+++";
        attribute noiseLevel : SoundLevelValue = 42.0;
        attribute waterConsumption : VolumeValue = 8.5;
        attribute energyConsumption : EnergyValue = 0.83;
        attribute placeSettings : Integer = 14;
        attribute dimensions : String = "845x598x600mm";
        attribute weight : MassValue = 60.0;

        port mainsPower : ElectricalPowerPort;
        port waterSupply : WaterInPort;
        port drainOutlet : DrainPort;

        part controlModule : ControlModule;
        part userInterface : UserInterface;
        part inletValve : InletValve;
        part waterSoftener : WaterSoftener;
        part heatingSystem : HeatingSystem;
        part circulationPump : CirculationPump;
        part drainPump : DrainPump;
        part upperSprayArm : SprayArm {
            attribute position = "upper";
        }
        part lowerSprayArm : SprayArm {
            attribute position = "lower";
        }
        part detergentDispenser : DetergentDispenser;
        part rinseAidDispenser : RinseAidDispenser;
        part temperatureSensor : TemperatureSensor;
        part waterLevelSensor : WaterLevelSensor;
        part turbiditySensor : TurbiditySensor;
        part doorLock : DoorLock;
        part leakProtection : LeakProtectionSystem;
        part washingChamber : WashingChamber;

        // Connections
        connection waterSupply to inletValve.waterSupply;
        connection inletValve.softenerFeed to waterSoftener.inlet;
        connection waterSoftener.outlet to heatingSystem.waterIn;
        connection heatingSystem.waterOut to circulationPump.waterIn;
        connection circulationPump.waterOut to upperSprayArm.waterIn;
        connection circulationPump.waterOut to lowerSprayArm.waterIn;
        connection upperSprayArm.sprayOut to washingChamber[1];
        connection lowerSprayArm.sprayOut to washingChamber[1];
        connection washingChamber to drainPump.waterIn;
        connection drainPump.drainOut to drainOutlet;

        // Detergent and rinse aid
        connection detergentDispenser.detergentOut to washingChamber[1];
        connection rinseAidDispenser.rinseAidOut to washingChamber[1];

        // Sensor connections
        connection temperatureSensor.data to controlModule.tempSensor;
        connection waterLevelSensor.data to controlModule.levelSensor;
        connection turbiditySensor.data to controlModule.turbiditySensor;
        connection leakProtection.sensor to controlModule.leakSensor;

        // Control connections
        connection controlModule.inletValveControl to inletValve.control;
        connection controlModule.softenerControl to waterSoftener.control;
        connection controlModule.heaterControl to heatingSystem.control;
        connection controlModule.circulationPumpControl to circulationPump.control;
        connection controlModule.drainPumpControl to drainPump.control;
        connection controlModule.detergentControl to detergentDispenser.control;
        connection controlModule.rinseAidControl to rinseAidDispenser.control;
        connection controlModule.doorLockControl to doorLock.control;
        connection controlModule.userInterface to userInterface.control;

        // Heater feedback
        connection heatingSystem.tempFeedback to controlModule.tempSensor;

        // Power distribution
        connection mainsPower to controlModule.power;
        connection mainsPower to inletValve.power;
        connection mainsPower to heatingSystem.power;
        connection mainsPower to circulationPump.power;
        connection mainsPower to drainPump.power;
        connection mainsPower to doorLock.power;
        connection mainsPower to userInterface.power;
        connection mainsPower to temperatureSensor.power;
        connection mainsPower to waterLevelSensor.power;
        connection mainsPower to turbiditySensor.power;
    }

    // ===== Requirements =====

    package Requirements {

        requirement def CleaningPerformanceRequirement {
            doc /* The dishwasher shall achieve cleaning performance rated A per EN 50242. */
            attribute cleaningClass : String = "A";
            subject : MieleG7310Dishwasher;
            require { cleaningClass == "A"; }
        }

        requirement def DryingPerformanceRequirement {
            doc /* The dishwasher shall achieve drying performance rated A per EN 50242. */
            attribute dryingClass : String = "A";
            subject : MieleG7310Dishwasher;
            require { dryingClass == "A"; }
        }

        requirement def WaterEfficiencyRequirement {
            doc /* The dishwasher shall use less than 10 liters of water per standard cycle. */
            attribute maxWaterPerCycle : VolumeValue = 10.0;
            subject : MieleG7310Dishwasher;
            require { waterConsumption < maxWaterPerCycle; }
        }

        requirement def EnergyEfficiencyRequirement {
            doc /* The dishwasher shall achieve A+++ energy rating. */
            attribute requiredRating : String = "A+++";
            subject : MieleG7310Dishwasher;
            require { energyRating == requiredRating; }
        }

        requirement def NoiseLevelRequirement {
            doc /* The dishwasher shall operate below 44 dB during normal operation. */
            attribute maxNoiseLevel : SoundLevelValue = 44.0;
            subject : MieleG7310Dishwasher;
            require { noiseLevel < maxNoiseLevel; }
        }

        requirement def CapacityRequirement {
            doc /* The dishwasher shall accommodate at least 14 place settings. */
            attribute minPlaceSettings : Integer = 14;
            subject : MieleG7310Dishwasher;
            require { placeSettings >= minPlaceSettings; }
        }

        requirement def SanitizationRequirement {
            doc /* The final rinse shall reach at least 70 degC for sanitization. */
            attribute minFinalRinseTemp : TemperatureValue = 70.0;
            subject : MieleG7310Dishwasher;
            require { heatingSystem.targetTemp >= minFinalRinseTemp; }
        }

        requirement def DoorLockSafetyRequirement {
            doc /* The door lock shall engage before cycle start and remain locked until interior temperature is safe. */
            attribute maxUnlockTemp : TemperatureValue = 45.0;
            subject : MieleG7310Dishwasher;
            require {
                doorLock.state == DoorLockState::locked
                when controlModule.currentPhase not in {CyclePhase::idle, CyclePhase::doorUnlocking, CyclePhase::complete}
            }
        }

        requirement def LeakProtectionRequirement {
            doc /* The dishwasher shall include active leak protection that shuts off water inlet upon leak detection. */
            subject : MieleG7310Dishwasher;
            require {
                leakProtection.active == true
                and leakProtection.leakDetected implies inletValve.isOpen == false
            }
        }

        requirement def WaterSofteningRequirement {
            doc /* The water softener shall reduce water hardness to below 4 German degrees. */
            attribute maxHardness : Real = 4.0;
            subject : MieleG7310Dishwasher;
            require { waterSoftener.outlet.water.hardness <= maxHardness; }
        }

        requirement def SprayCoverageRequirement {
            doc /* The dishwasher shall have upper and lower spray arms for multi-angle coverage. */
            subject : MieleG7310Dishwasher;
            require {
                upperSprayArm.position == "upper"
                and lowerSprayArm.position == "lower"
            }
        }

        requirement def ProgramFlexibilityRequirement {
            doc /* The dishwasher shall offer at least 6 wash programs including eco, intensive, and quick. */
            attribute minPrograms : Integer = 6;
            subject : MieleG7310Dishwasher;
            require { WashProgram::members->size() >= minPrograms; }
        }

        requirement def TemperatureControlRequirement {
            doc /* The control module shall regulate heating based on temperature sensor feedback. */
            subject : MieleG7310Dishwasher;
            require {
                heatingSystem.state == HeaterState::heating
                when temperatureSensor.reading < controlModule.targetTemp
            }
        }

        requirement def TurbidityAdaptationRequirement {
            doc /* The dishwasher shall adjust cycle duration based on turbidity sensor readings. */
            subject : MieleG7310Dishwasher;
            require {
                turbiditySensor.reading > turbiditySensor.dirtyThreshold
                implies controlModule.estimatedRemaining > controlModule.programDurations[selectedProgram]
            }
        }

        requirement def DetergentReleaseRequirement {
            doc /* The detergent dispenser shall release detergent during the main wash phase. */
            subject : MieleG7310Dishwasher;
            require {
                detergentDispenser.state == DispenserState::open
                when controlModule.currentPhase == CyclePhase::mainWash
            }
        }

        requirement def DrainRequirement {
            doc /* The drain pump shall expel all soiled water between wash and rinse phases. */
            subject : MieleG7310Dishwasher;
            require {
                drainPump.state == PumpState::running
                when controlModule.currentPhase in {CyclePhase::preWashDrain, CyclePhase::mainWashDrain,
                    CyclePhase::rinse1Drain, CyclePhase::rinse2Drain, CyclePhase::finalRinseDrain}
            }
        }

        requirement def CondensationDryingRequirement {
            doc /* The dishwasher shall use condensation drying during the drying phase. */
            subject : MieleG7310Dishwasher;
            require { controlModule.currentPhase == CyclePhase::drying implies heatingSystem.state == HeaterState::off; }
        }

        requirement def CycleCompletionRequirement {
            doc /* The dishwasher shall unlock the door and indicate completion after cycle and cooling. */
            subject : MieleG7310Dishwasher;
            require {
                controlModule.cycleComplete == true
                implies doorLock.state == DoorLockState::unlocked
            }
        }

        requirement def PowerRequirement {
            doc /* The dishwasher shall operate on 230V 50Hz mains power. */
            attribute requiredVoltage : Real = 230;
            attribute requiredFrequency : Real = 50;
            subject : MieleG7310Dishwasher;
            require {
                mainsPower.voltage == requiredVoltage
                and mainsPower.frequency == requiredFrequency
            }
        }

        requirement def DishwasherRequirements {
            subject : MieleG7310Dishwasher;
            satisfy cleaningPerformance : CleaningPerformanceRequirement;
            satisfy dryingPerformance : DryingPerformanceRequirement;
            satisfy waterEfficiency : WaterEfficiencyRequirement;
            satisfy energyEfficiency : EnergyEfficiencyRequirement;
            satisfy noiseLevel : NoiseLevelRequirement;
            satisfy capacity : CapacityRequirement;
            satisfy sanitization : SanitizationRequirement;
            satisfy doorLockSafety : DoorLockSafetyRequirement;
            satisfy leakProtection : LeakProtectionRequirement;
            satisfy waterSoftening : WaterSofteningRequirement;
            satisfy sprayCoverage : SprayCoverageRequirement;
            satisfy programFlexibility : ProgramFlexibilityRequirement;
            satisfy temperatureControl : TemperatureControlRequirement;
            satisfy turbidityAdaptation : TurbidityAdaptationRequirement;
            satisfy detergentRelease : DetergentReleaseRequirement;
            satisfy drain : DrainRequirement;
            satisfy condensationDrying : CondensationDryingRequirement;
            satisfy cycleCompletion : CycleCompletionRequirement;
            satisfy power : PowerRequirement;
        }
    }

    // ===== Verification =====

    package Verification {

        verification WaterEfficiencyTest {
            subject : MieleG7310Dishwasher;
            objective { verify waterConsumption < 10.0; }
            method { Run standard EN 50242 eco cycle and measure total water intake. }
        }

        verification NoiseLevelTest {
            subject : MieleG7310Dishwasher;
            objective { verify noiseLevel < 44.0; }
            method { Measure sound pressure level at 1m distance during full eco cycle in anechoic chamber. }
        }

        verification SanitizationTest {
            subject : MieleG7310Dishwasher;
            objective { verify heatingSystem.targetTemp >= 70.0 during final rinse; }
            method { Run intensive program and log temperature sensor readings during final rinse phase. }
        }

        verification LeakProtectionTest {
            subject : MieleG7310Dishwasher;
            objective { verify inletValve.isOpen == false when leakProtection.leakDetected == true; }
            method { Simulate leak condition and verify inlet valve closure within 2 seconds. }
        }

        verification CapacityTest {
            subject : MieleG7310Dishwasher;
            objective { verify placeSettings >= 14; }
            method { Load 14 standard place settings per EN 50242 and verify fit in racks and cutlery basket. }
        }

        verification EnergyRatingTest {
            subject : MieleG7310Dishwasher;
            objective { verify energyConsumption <= 0.83; }
            method { Run standard EN 50242 cycle and measure total energy consumption. }
        }
    }
}
