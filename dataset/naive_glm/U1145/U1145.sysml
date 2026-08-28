package ThermostatSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // ===== Value Types =====
    value def Temperature :> Real { unit '°C'; }
    value def Humidity :> Real { unit '%'; }
    value def Duration :> Real { unit 'min'; }
    value def Power :> Real { unit 'W'; }
    value def OccupancyCount :> Integer;

    // ===== Item Types =====
    item def TemperatureReading {
        attribute value : Temperature;
        attribute humidity : Humidity;
        attribute timestamp : DateTime;
    }
    item def OccupancyReading {
        attribute state : OccupancyState;
        attribute timestamp : DateTime;
    }
    item def UserCommand {
        attribute targetTemp : Temperature;
        attribute modeOverride : HVACMode;
        attribute timestamp : DateTime;
    }
    item def HVACCommand {
        attribute mode : HVACMode;
        attribute targetTemp : Temperature;
        attribute fanSpeed : Real;
    }
    item def ScheduleEntry {
        attribute dayOfWeek : Integer;
        attribute startHour : Integer;
        attribute startMinute : Integer;
        attribute targetTemp : Temperature;
        attribute occupancyState : OccupancyState;
    }
    item def DisplayStatus {
        attribute currentTemp : Temperature;
        attribute targetTemp : Temperature;
        attribute currentMode : HVACMode;
        attribute occupancyState : OccupancyState;
        attribute energySaving : Boolean;
    }

    // ===== Enumerations =====
    enum def OccupancyState { empty; occupied; sleeping; }
    enum def HVACMode { heating; cooling; idle; energySaving; }

    // ===== Port Definitions =====
    port def TempSensorOut { out tempReading : TemperatureReading; }
    port def OccupancySensorOut { out occReading : OccupancyReading; }
    port def HVACCommandPort { out command : HVACCommand; }
    port def UserInputPort { in userCmd : UserCommand; }
    port def DisplayPort { out status : DisplayStatus; }
    port def NetworkPort { in remoteCmd : UserCommand; out remoteStatus : DisplayStatus; }
    port def SchedulePort { out schedule : ScheduleEntry[*]; }

    // ===== Requirements =====
    requirement def ComfortRequirement {
        doc "Maintain indoor temperature within comfortable range."
        attribute minComfort : Temperature = 18.0;
        attribute maxComfort : Temperature = 24.0;
        subject indoorTemp : Temperature;
        constraint { indoorTemp >= minComfort and indoorTemp <= maxComfort }
    }

    requirement def EnergyEfficiencyRequirement {
        doc "Minimize energy consumption when home is unoccupied."
        subject hvacPower : Power;
        constraint { hvacPower <= 1000.0 }
    }

    requirement def LearningRequirement {
        doc "Learn user habits and build weekly schedule automatically."
        subject schedule : ScheduleEntry[*];
        constraint { schedule->size() > 0 }
    }

    requirement def ResponsivenessRequirement {
        doc "Respond to user override within 5 seconds."
        attribute maxResponseTime : Duration = 5.0;
        subject responseTime : Duration;
        constraint { responseTime <= maxResponseTime }
    }

    // ===== Parts =====
    part def TemperatureSensor {
        port tempOut : TempSensorOut;
        attribute currentTemp : Temperature;
        attribute currentHumidity : Humidity;
        action def sense : TemperatureReading {
            out reading : TemperatureReading;
        }
        perform action sensePeriodic : sense[1..*] {
            out reading : TemperatureReading = tempReading;
        }
    }

    part def OccupancySensor {
        port occOut : OccupancySensorOut;
        attribute currentState : OccupancyState = OccupancyState::empty;
        action def detect : OccupancyReading {
            out reading : OccupancyReading;
        }
        perform action detectMotion : detect[1..*] {
            out reading : OccupancyReading = occReading;
        }
    }

    part def LearningEngine {
        port scheduleOut : SchedulePort;
        attribute learnedSchedule : ScheduleEntry[*];
        attribute manualAdjustments : UserCommand[*];
        attribute occupancyHistory : OccupancyReading[*];

        action def recordAdjustment {
            in cmd : UserCommand;
            out updatedSchedule : ScheduleEntry[*];
        }
        action def buildSchedule {
            in adjustments : UserCommand[*];
            in occupancy : OccupancyReading[*];
            out schedule : ScheduleEntry[*];
        }
        perform action learn : buildSchedule[1..*] {
            in adjustments = manualAdjustments;
            in occupancy = occupancyHistory;
            out schedule = learnedSchedule;
        }
    }

    part def HVACUnit {
        port cmdIn : HVACCommandPort;
        attribute operatingMode : HVACMode = HVACMode::idle;
        attribute powerConsumption : Power = 0.0;
        attribute currentTarget : Temperature;

        state def HVACStateMachine {
            entry; then Idle;
            state Idle;
            state Heating;
            state Cooling;
            state EnergySaving;
            transition idle_to_heat
                first Idle
                accept cmdIn.command when cmdIn.command.mode == HVACMode::heating
                then Heating;
            transition idle_to_cool
                first Idle
                accept cmdIn.command when cmdIn.command.mode == HVACMode::cooling
                then Cooling;
            transition heat_to_idle
                first Heating
                accept cmdIn.command when cmdIn.command.mode == HVACMode::idle
                then Idle;
            transition cool_to_idle
                first Cooling
                accept cmdIn.command when cmdIn.command.mode == HVACMode::idle
                then Idle;
            transition any_to_energy
                first (Idle | Heating | Cooling)
                accept cmdIn.command when cmdIn.command.mode == HVACMode::energySaving
                then EnergySaving;
            transition energy_to_idle
                first EnergySaving
                accept cmdIn.command when cmdIn.command.mode == HVACMode::idle
                then Idle;
        }
        exhibit state behavior : HVACStateMachine;
    }

    part def Display {
        port displayOut : DisplayPort;
        port userInput : UserInputPort;
        attribute currentStatus : DisplayStatus;
        action def render {
            in status : DisplayStatus;
        }
        perform action updateDisplay : render[1..*];
    }

    part def NetworkInterface {
        port netPort : NetworkPort;
        attribute connected : Boolean = false;
        action def receiveRemote {
            out cmd : UserCommand;
        }
        action def sendStatus {
            in status : DisplayStatus;
        }
    }

    part def ThermostatController {
        port tempIn : TempSensorOut;
        port occIn : OccupancySensorOut;
        port hvacCmd : HVACCommandOut;
        port displayPort : DisplayPort;
        port userPort : UserInputPort;
        port netPort : NetworkPort;
        port schedulePort : SchedulePort;

        attribute currentTemp : Temperature;
        attribute targetTemp : Temperature = 21.0;
        attribute currentMode : HVACMode = HVACMode::idle;
        attribute occupancyState : OccupancyState = OccupancyState::empty;
        attribute energySavingActive : Boolean = false;
        attribute emptyDuration : Duration = 0.0;
        attribute energySavingThreshold : Duration = 30.0;

        part tempSensor : TemperatureSensor;
        part occSensor : OccupancySensor;
        part learner : LearningEngine;
        part hvac : HVACUnit;
        part display : Display;
        port def ControllerTempIn : TempSensorOut;
        port def ControllerOccIn : OccupancySensorOut;
        port def ControllerHVACOut : HVACCommandPort;
        port def ControllerDisplayOut : DisplayPort;
        port def ControllerUserIn : UserInputPort;
        port def ControllerNet : NetworkPort;
        port def ControllerSchedOut : SchedulePort;

        bind tempSensor.tempOut = tempIn;
        bind occSensor.occOut = occIn;
        bind hvac.cmdIn = hvacCmd;
        bind display.displayOut = displayPort;
        bind display.userInput = userPort;
        bind learner.scheduleOut = schedulePort;

        action def evaluateConditions {
            in temp : Temperature;
            in occ : OccupancyState;
            in target : Temperature;
            out mode : HVACMode;
            out cmd : HVACCommand;
        }
        action def processUserOverride {
            in cmd : UserCommand;
            out newTarget : Temperature;
            out newMode : HVACMode;
        }
        action def checkEnergySaving {
            in emptyTime : Duration;
            in threshold : Duration;
            out activate : Boolean;
        }

        state def ControllerStateMachine {
            entry; then Normal;
            state Normal {
                entry { currentMode = HVACMode::idle; }
                do evaluateConditions;
            }
            state Heating {
                entry { currentMode = HVACMode::heating; }
            }
            state Cooling {
                entry { currentMode = HVACMode::cooling; }
            }
            state EnergySaving {
                entry { currentMode = HVACMode::energySaving; energySavingActive = true; }
                exit { energySavingActive = false; }
            }
            transition normal_to_heat
                first Normal
                when currentTemp < targetTemp and occupancyState != OccupancyState::empty
                then Heating;
            transition normal_to_cool
                first Normal
                when currentTemp > targetTemp and occupancyState != OccupancyState::empty
                then Cooling;
            transition heat_to_normal
                first Heating
                when currentTemp >= targetTemp
                then Normal;
            transition cool_to_normal
                first Cooling
                when currentTemp <= targetTemp
                then Normal;
            transition any_to_energy
                first (Normal | Heating | Cooling)
                when emptyDuration >= energySavingThreshold
                then EnergySaving;
            transition energy_to_normal
                first EnergySaving
                when occupancyState == OccupancyState::occupied
                then Normal;
        }
        exhibit state behavior : ControllerStateMachine;

        satisfy ComfortRequirement {
            subject indoorTemp = currentTemp;
        }
        satisfy EnergyEfficiencyRequirement {
            subject hvacPower = hvac.powerConsumption;
        }
        satisfy LearningRequirement {
            subject schedule = learner.learnedSchedule;
        }
        satisfy ResponsivenessRequirement {
            subject responseTime = 3.0;
        }
    }

    part def Home {
        part thermostat : ThermostatController;
        part hvacUnit : HVACUnit;
        attribute indoorTemp : Temperature;
        attribute indoorHumidity : Humidity;
        bind thermostat.hvacCmd = hvacUnit.cmdIn;
    }

    part def ThermostatSystem {
        part home : Home;
        part controller : ThermostatController = home.thermostat;
        part hvac : HVACUnit = home.hvacUnit;
    }
}
