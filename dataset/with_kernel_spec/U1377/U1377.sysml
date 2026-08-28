package 'Automated Aquarium System' {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def WaterTemperature :> TemperatureValue;
    attribute def pHValue :> Real;
    attribute def WaterLevelMeasure :> LengthValue;
    attribute def LightIntensityValue :> Real;
    attribute def FoodMassValue :> MassValue;
    attribute def FlowRateValue :> Real;

    item def Water;
    item def CleanWater :> Water;

    item def WaterFlow {
        attribute rate : FlowRateValue;
    }
    item def TemperatureReading {
        attribute value : WaterTemperature;
    }
    item def PHReading {
        attribute value : pHValue;
    }
    item def LevelReading {
        attribute value : WaterLevelMeasure;
    }
    item def HeaterCommand {
        attribute active : Boolean;
    }
    item def AeratorCommand {
        attribute active : Boolean;
    }
    item def LightingCommand {
        attribute intensity : LightIntensityValue;
    }
    item def FeederCommand {
        attribute amount : FoodMassValue;
    }

    attribute def MaintenanceSignal;
    attribute def EmergencySignal;
    attribute def NormalSignal;
    attribute def DaytimeSignal;
    attribute def NighttimeSignal;
    attribute def FeedingTimeSignal;

    part def Tank {
        port waterOutPort { out waterOut : WaterFlow; }
        port waterInPort { in waterIn : WaterFlow; }
        attribute capacity : VolumeValue;
        attribute currentLevel : WaterLevelMeasure;
    }

    part def Pump {
        port inletPort { in waterIn : WaterFlow; }
        port outletPort { out waterOut : WaterFlow; }
        port commandPort { in cmd : Boolean; }
    }

    part def Filter {
        port inletPort { in waterIn : WaterFlow; }
        port outletPort { out waterOut : WaterFlow; }
    }

    part def MechanicalFilter :> Filter;
    part def BiologicalFilter :> Filter;

    part def Heater {
        port commandPort { in cmd : HeaterCommand; }
        attribute targetTemp : WaterTemperature;
    }

    part def Aerator {
        port commandPort { in cmd : AeratorCommand; }
    }

    part def LightingSystem {
        port commandPort { in cmd : LightingCommand; }
        attribute currentIntensity : LightIntensityValue;
    }

    part def AutomaticFeeder {
        port commandPort { in cmd : FeederCommand; }
        attribute foodRemaining : FoodMassValue;
    }

    part def TemperatureSensor {
        port readingPort { out reading : TemperatureReading; }
    }

    part def PHSensor {
        port readingPort { out reading : PHReading; }
    }

    part def WaterLevelSensor {
        port readingPort { out reading : LevelReading; }
    }

    part def Controller {
        port tempInPort { in reading : TemperatureReading; }
        port pHInPort { in reading : PHReading; }
        port levelInPort { in reading : LevelReading; }
        port heaterCmdPort { out cmd : HeaterCommand; }
        port aeratorCmdPort { out cmd : AeratorCommand; }
        port lightCmdPort { out cmd : LightingCommand; }
        port feederCmdPort { out cmd : FeederCommand; }
        port pumpCmdPort { out cmd : Boolean; }
        attribute maxTemp : WaterTemperature;
        attribute minTemp : WaterTemperature;
        attribute maxPH : pHValue;
        attribute minPH : pHValue;
        attribute minWaterLevel : WaterLevelMeasure;
        attribute targetTemp : WaterTemperature;
    }

    action def 'Sense Temperature' { out reading : TemperatureReading; }
    action def 'Sense pH' { out reading : PHReading; }
    action def 'Sense Water Level' { out reading : LevelReading; }
    action def 'Regulate Temperature' {
        in current : WaterTemperature;
        in target : WaterTemperature;
        out cmd : HeaterCommand;
    }
    action def 'Regulate Oxygenation' {
        out cmd : AeratorCommand;
    }
    action def 'Control Lighting' {
        out cmd : LightingCommand;
    }
    action def 'Dispense Food' {
        out cmd : FeederCommand;
    }
    action def 'Pump Water' {
        in cmd : Boolean;
    }

    state def 'Controller States';

    requirement def WaterCirculationReqDef {
        doc /* The system shall continuously circulate water from the tank through mechanical and biological filters and back to the tank. */
        attribute flowRate : FlowRateValue;
        attribute minFlowRate : FlowRateValue;
        require constraint { flowRate >= minFlowRate }
    }

    requirement def TemperatureRegulationReqDef {
        doc /* The controller shall maintain water temperature at the target setpoint within a tolerance of 1 degree. */
        attribute currentTemp : WaterTemperature;
        attribute targetTemp : WaterTemperature;
        require constraint { abs(currentTemp - targetTemp) <= 1.0 }
    }

    requirement def PHRangeReqDef {
        doc /* The controller shall maintain pH within the safe range for aquatic life. */
        attribute currentPH : pHValue;
        attribute minPH : pHValue;
        attribute maxPH : pHValue;
        require constraint { currentPH >= minPH and currentPH <= maxPH }
    }

    requirement def WaterLevelReqDef {
        doc /* The controller shall maintain water level above the minimum safe level. */
        attribute currentLevel : WaterLevelMeasure;
        attribute minLevel : WaterLevelMeasure;
        require constraint { currentLevel >= minLevel }
    }

    requirement def OxygenationReqDef {
        doc /* The aerator shall be activated as needed to ensure proper oxygenation. */
        attribute aeratorOn : Boolean;
        attribute oxygenLow : Boolean;
        require constraint { oxygenLow implies aeratorOn }
    }

    requirement def LightingCycleReqDef {
        doc /* The lighting system shall simulate a natural day-and-night cycle. */
        attribute dayDuration : TimeValue;
        attribute nightDuration : TimeValue;
        require constraint { dayDuration == 12.0 and nightDuration == 12.0 }
    }

    requirement def FeedingScheduleReqDef {
        doc /* The automatic feeder shall dispense a set amount of food at scheduled times. */
        attribute feedFrequency : Integer;
        attribute dispensedAmount : FoodMassValue;
        attribute setAmount : FoodMassValue;
        require constraint { feedFrequency == 2 and dispensedAmount == setAmount }
    }

    requirement def EmergencyModeReqDef {
        doc /* The system shall enter emergency mode when any critical parameter goes outside safe limits. */
        attribute mode : String;
        attribute tempOutOfRange : Boolean;
        attribute pHOutOfRange : Boolean;
        attribute levelTooLow : Boolean;
        require constraint { (tempOutOfRange or pHOutOfRange or levelTooLow) implies mode == "emergency" }
    }

    requirement def MaintenanceModeReqDef {
        doc /* The system shall support a maintenance mode that allows manual control during cleaning. */
        attribute mode : String;
        attribute maintenanceRequested : Boolean;
        require constraint { maintenanceRequested implies mode == "maintenance" }
    }

    requirement def NormalOperationReqDef {
        doc /* The system shall operate autonomously in normal mode, managing all life-support functions without manual intervention. */
        attribute mode : String;
        attribute autonomous : Boolean;
        require constraint { mode == "normal" implies autonomous == true }
    }

    part 'aquarium system' {
        part tank : Tank;
        part pump : Pump;
        part mechFilter : MechanicalFilter;
        part bioFilter : BiologicalFilter;
        part heater : Heater;
        part aerator : Aerator;
        part lighting : LightingSystem;
        part feeder : AutomaticFeeder;
        part tempSensor : TemperatureSensor;
        part pHSensor : PHSensor;
        part levelSensor : WaterLevelSensor;
        part controller : Controller;

        flow waterFromTank of WaterFlow
            from tank.waterOutPort.waterOut to pump.inletPort.waterIn;
        flow waterToMechFilter of WaterFlow
            from pump.outletPort.waterOut to mechFilter.inletPort.waterIn;
        flow waterToBioFilter of WaterFlow
            from mechFilter.outletPort.waterOut to bioFilter.inletPort.waterIn;
        flow waterReturnToTank of WaterFlow
            from bioFilter.outletPort.waterOut to tank.waterInPort.waterIn;

        flow tempReadingFlow of TemperatureReading
            from tempSensor.readingPort.reading to controller.tempInPort.reading;
        flow pHReadingFlow of PHReading
            from pHSensor.readingPort.reading to controller.pHInPort.reading;
        flow levelReadingFlow of LevelReading
            from levelSensor.readingPort.reading to controller.levelInPort.reading;

        flow heaterCmdFlow of HeaterCommand
            from controller.heaterCmdPort.cmd to heater.commandPort.cmd;
        flow aeratorCmdFlow of AeratorCommand
            from controller.aeratorCmdPort.cmd to aerator.commandPort.cmd;
        flow lightingCmdFlow of LightingCommand
            from controller.lightCmdPort.cmd to lighting.commandPort.cmd;
        flow feederCmdFlow of FeederCommand
            from controller.feederCmdPort.cmd to feeder.commandPort.cmd;
        flow pumpCmdFlow of Boolean
            from controller.pumpCmdPort.cmd to pump.commandPort.cmd;

        action 'sense temperature' : 'Sense Temperature';
        action 'sense pH' : 'Sense pH';
        action 'sense water level' : 'Sense Water Level';
        action 'regulate temperature' : 'Regulate Temperature';
        action 'regulate oxygenation' : 'Regulate Oxygenation';
        action 'control lighting' : 'Control Lighting';
        action 'dispense food' : 'Dispense Food';
        action 'pump water' : 'Pump Water';

        exhibit state 'controller states' : 'Controller States' parallel {
            state 'operating mode' {
                entry; then normal;
                state normal {
                    do 'sense temperature';
                    do 'sense pH';
                    do 'sense water level';
                    do 'regulate temperature';
                    do 'regulate oxygenation';
                    do 'control lighting';
                    do 'dispense food';
                    do 'pump water';
                }
                accept MaintenanceSignal then maintenance;
                accept EmergencySignal then emergency;
                state maintenance {
                    doc /* Automatic actions suspended; manual control allowed during cleaning. */
                }
                accept NormalSignal then normal;
                state emergency {
                    doc /* Critical parameters outside safe limits; non-essential systems shut down. */
                }
                accept NormalSignal then normal;
            }

            state 'daily routine' {
                entry; then daytime;
                state daytime {
                    do 'control lighting';
                    do 'dispense food';
                }
                accept NighttimeSignal then nighttime;
                state nighttime {
                    do 'control lighting';
                }
                accept DaytimeSignal then daytime;
            }
        }
    }
}
