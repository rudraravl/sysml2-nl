package HomeApplianceSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def TemperatureValue :> Real;
    attribute def PowerValue :> Real;
    attribute def VolumeValue :> Real;
    attribute def TimeValue :> Real;
    attribute def PressureValue :> Real;
    
    enum def ApplianceMode {
        off;
        standby;
        active;
        maintenance;
        fault;
    }
    
    enum def WashCycleType {
        normal;
        delicate;
        heavy;
        quick;
        eco;
    }
    
    enum def DryerHeatLevel {
        noHeat;
        low;
        medium;
        high;
    }
    
    item def Laundry {
        attribute weight : Real;
        attribute moistureContent : Real;
    }
    
    item def Water {
        attribute temperature : TemperatureValue;
        attribute volume : VolumeValue;
    }
    
    item def Detergent {
        attribute amount : VolumeValue;
    }
    
    port def PowerPort {
        attribute voltage : Real;
        attribute current : Real;
        attribute frequency : Real;
    }
    
    port def WaterSupplyPort {
        in item waterIn : Water;
        attribute pressure : PressureValue;
        attribute flowRate : Real;
    }
    
    port def DrainPort {
        out item wasteWater : Water;
    }
    
    port def ControlPort {
        attribute commandSignal : String;
        attribute statusSignal : String;
    }
    
    part def WashingMachine {
        attribute maxLoadCapacity : VolumeValue;
        attribute currentLoad : VolumeValue;
        attribute waterTemp : TemperatureValue;
        attribute spinSpeed : Real;
        attribute operatingMode : ApplianceMode;
        attribute selectedCycle : WashCycleType;
        attribute energyConsumption : PowerValue;
        
        port powerIn : PowerPort;
        port waterSupply : WaterSupplyPort;
        port drain : DrainPort;
        port control : ControlPort;
        
        part drum {
            attribute capacity : VolumeValue;
            attribute rotationSpeed : Real;
            attribute currentPosition : Real;
        }
        
        part motor {
            attribute ratedPower : PowerValue;
            attribute maxRPM : Real;
            attribute efficiency : Real;
        }
        
        part waterHeater {
            attribute heatingPower : PowerValue;
            attribute maxTemperature : TemperatureValue;
            attribute currentTemperature : TemperatureValue;
        }
        
        part drainPump {
            attribute pumpPower : PowerValue;
            attribute maxFlowRate : Real;
        }
        
        part detergentDispenser {
            attribute capacity : VolumeValue;
            attribute remainingDetergent : VolumeValue;
        }
        
        part controlUnit {
            attribute cycleTimeRemaining : TimeValue;
            attribute totalCycleTime : TimeValue;
        }
        
        perform action executeWashCycle;
    }
    
    part def Dryer {
        attribute maxLoadCapacity : VolumeValue;
        attribute currentLoad : VolumeValue;
        attribute dryingTemp : TemperatureValue;
        attribute operatingMode : ApplianceMode;
        attribute heatLevel : DryerHeatLevel;
        attribute energyConsumption : PowerValue;
        
        port powerIn : PowerPort;
        port ventilation;
        port control : ControlPort;
        
        part drum {
            attribute capacity : VolumeValue;
            attribute rotationSpeed : Real;
        }
        
        part heatingElement {
            attribute heatingPower : PowerValue;
            attribute maxTemperature : TemperatureValue;
        }
        
        part blowerFan {
            attribute airflowRate : Real;
            attribute fanPower : PowerValue;
        }
        
        part moistureSensor {
            attribute currentMoistureLevel : Real;
            attribute targetMoistureLevel : Real;
        }
        
        part temperatureSensor {
            attribute currentTemp : TemperatureValue;
        }
        
        part controlUnit {
            attribute cycleTimeRemaining : TimeValue;
            attribute totalCycleTime : TimeValue;
        }
        
        perform action executeDryCycle;
    }
    
    part def SmartLaundrySystem {
        attribute totalPowerDraw : PowerValue;
        attribute systemStatus : ApplianceMode;
        
        part washer : WashingMachine {
            attribute :>> maxLoadCapacity = 20.0;
            attribute :>> operatingMode = ApplianceMode::standby;
            attribute :>> selectedCycle = WashCycleType::normal;
        }
        
        part dryer : Dryer {
            attribute :>> maxLoadCapacity = 20.0;
            attribute :>> operatingMode = ApplianceMode::standby;
            attribute :>> heatLevel = DryerHeatLevel::medium;
        }
        
        part electricalPanel {
            attribute mainVoltage = 240.0;
            attribute mainFrequency = 60.0;
            attribute maxCircuitLoad : PowerValue = 6000.0;
        }
        
        part waterMain {
            attribute supplyPressure = 60.0;
            attribute supplyTemperature = 15.0;
        }
        
        part drainageSystem {
            attribute drainCapacity : Real;
        }
        
        part centralController {
            attribute systemMode : ApplianceMode;
            attribute energyOptimizationEnabled : Boolean;
        }
        
        connection powerToWasher connect electricalPanel to washer.powerIn;
        connection powerToDryer connect electricalPanel to dryer.powerIn;
        connection waterToWasher connect waterMain to washer.waterSupply;
        connection washerToDrain connect washer.drain to drainageSystem;
        connection controlToWasher connect centralController to washer.control;
        connection controlToDryer connect centralController to dryer.control;
        
        assert constraint totalPowerLimit {
            totalPowerDraw <= electricalPanel.maxCircuitLoad
        }
        
        assert constraint loadBalance {
            washer.currentLoad <= washer.maxLoadCapacity and
            dryer.currentLoad <= dryer.maxLoadCapacity
        }
        
        perform action completeFullLaundryCycle;
    }
    
    action def FillWaterTank {
        in targetVolume : VolumeValue;
        in targetTemperature : TemperatureValue;
        out actualVolume : VolumeValue;
        out actualTemperature : TemperatureValue;
    }
    
    action def AddDetergent {
        in detergentAmount : VolumeValue;
    }
    
    action def AgitateDrum {
        in agitationDuration : TimeValue;
        in drumSpeed : Real;
    }
    
    action def SpinCycle {
        in spinSpeed : Real;
        in spinDuration : TimeValue;
    }
    
    action def DrainWaterTank {
        out drainedVolume : VolumeValue;
    }
    
    action def ExecuteWashCycle {
        first start;
        then action prewash : FillWaterTank {
            in targetVolume : VolumeValue;
            in targetTemperature : TemperatureValue;
            out actualVolume : VolumeValue;
            out actualTemperature : TemperatureValue;
        }
        then action addDetergent : AddDetergent {
            in detergentAmount : VolumeValue;
        }
        then action mainWash : AgitateDrum {
            in agitationDuration : TimeValue;
            in drumSpeed : Real;
        }
        then action drainWash : DrainWaterTank {
            out drainedVolume : VolumeValue;
        }
        then action rinse1 : FillWaterTank {
            in targetVolume : VolumeValue;
            in targetTemperature : TemperatureValue;
            out actualVolume : VolumeValue;
            out actualTemperature : TemperatureValue;
        }
        then action agitateRinse : AgitateDrum {
            in agitationDuration : TimeValue;
            in drumSpeed : Real;
        }
        then action drainRinse : DrainWaterTank {
            out drainedVolume : VolumeValue;
        }
        then action finalSpin : SpinCycle {
            in spinSpeed : Real;
            in spinDuration : TimeValue;
        }
        then done;
    }
    
    action def HeatDryerAir {
        in targetTemperature : TemperatureValue;
        out actualTemperature : TemperatureValue;
    }
    
    action def CirculateHotAir {
        in airflowRate : Real;
        in circulationDuration : TimeValue;
    }
    
    action def RotateDryerDrum {
        in rotationSpeed : Real;
        in rotationDuration : TimeValue;
    }
    
    action def CheckMoistureLevel {
        out currentMoisture : Real;
    }
    
    action def CoolDown {
        in cooldownDuration : TimeValue;
    }
    
    action def ExecuteDryCycle {
        first start;
        then merge continueDrying;
        then action heatAir : HeatDryerAir {
            in targetTemperature : TemperatureValue;
            out actualTemperature : TemperatureValue;
        }
        then action rotateDrum : RotateDryerDrum {
            in rotationSpeed : Real;
            in rotationDuration : TimeValue;
        }
        then action circulateAir : CirculateHotAir {
            in airflowRate : Real;
            in circulationDuration : TimeValue;
        }
        then action checkMoisture : CheckMoistureLevel {
            out currentMoisture : Real;
        }
        then decide;
            if checkMoisture.currentMoisture > 3.0 then continueDrying;
            if checkMoisture.currentMoisture <= 3.0 then cooldown;
        action cooldown : CoolDown {
            in cooldownDuration : TimeValue;
        }
        then done;
    }
    
    action def TransferLaundry {
        doc /* Manual or automated transfer of laundry from washer to dryer */
    }
    
    action def CompleteFullLaundryCycle {
        first start;
        then action washPhase : ExecuteWashCycle;
        then action transferPhase : TransferLaundry;
        then action dryPhase : ExecuteDryCycle;
        then done;
    }
    
    state machine LaundrySystemStates {
        entry; then systemOff;
        
        state systemOff;
        accept at systemOff
            then systemStandby;
        
        state systemStandby;
        accept at systemStandby
            then washing;
        
        state washing;
        accept at washing
            then transferring;
        
        state transferring;
        accept at transferring
            then drying;
        
        state drying;
        accept at drying
            then complete;
        
        state complete;
        accept at complete
            then systemStandby;
        
        state errorState;
        accept at errorState
            then systemStandby;
    }
    
    requirement <'REQ-LS-001'> primaryFunction {
        doc /* The Smart Laundry System shall provide automated washing and drying 
             * of clothing and textiles through an integrated appliance system. */
        subject system : SmartLaundrySystem;
    }
    
    requirement <'REQ-LS-002'> washerCapacity {
        doc /* The washing machine shall accommodate a minimum load capacity of 20 liters. */
        subject washer : SmartLaundrySystem::washer;
        assert constraint {
            washer.maxLoadCapacity >= 20.0
        }
    }
    
    requirement <'REQ-LS-003'> dryerCapacity {
        doc /* The dryer shall accommodate a minimum load capacity of 20 liters. */
        subject dryer : SmartLaundrySystem::dryer;
        assert constraint {
            dryer.maxLoadCapacity >= 20.0
        }
    }
    
    requirement <'REQ-LS-004'> powerLimit {
        doc /* The total system power consumption shall not exceed 6000 watts. */
        subject system : SmartLaundrySystem;
        assert constraint {
            system.totalPowerDraw <= 6000.0
        }
    }
    
    requirement <'REQ-LS-005'> waterTemperatureRange {
        doc /* The washing machine shall support water temperatures from 15 to 95 degrees Celsius. */
        subject washer : SmartLaundrySystem::washer;
        assert constraint {
            washer.waterTemp >= 15.0 and washer.waterTemp <= 95.0
        }
    }
    
    requirement <'REQ-LS-006'> multipleCycles {
        doc /* The washing machine shall provide at least five distinct wash cycle types. */
        subject washer : SmartLaundrySystem::washer;
    }
    
    requirement <'REQ-LS-007'> moistureDetection {
        doc /* The dryer shall automatically detect moisture levels and terminate 
             * the drying cycle when target dryness is achieved. */
        subject dryer : SmartLaundrySystem::dryer;
    }
    
    requirement <'REQ-LS-008'> energyEfficiency {
        doc /* The system shall optimize energy consumption through intelligent 
             * cycle management and load balancing. */
        subject system : SmartLaundrySystem;
    }
    
    part smartLaundrySystem : SmartLaundrySystem {
        perform action completeCycle references CompleteFullLaundryCycle;
        exhibit state lifecycle : LaundrySystemStates;
        
        part :>> washer {
            perform executeWashCycle references ExecuteWashCycle;
        }
        
        part :>> dryer {
            perform executeDryCycle references ExecuteDryCycle;
        }
    }
    
    satisfy primaryFunction by smartLaundrySystem;
    satisfy washerCapacity by smartLaundrySystem.washer;
    satisfy dryerCapacity by smartLaundrySystem.dryer;
    satisfy powerLimit by smartLaundrySystem.totalPowerLimit;
    satisfy waterTemperatureRange by smartLaundrySystem.washer;
    satisfy multipleCycles by smartLaundrySystem.washer;
    satisfy moistureDetection by smartLaundrySystem.dryer;
    satisfy energyEfficiency by smartLaundrySystem.centralController;
}
