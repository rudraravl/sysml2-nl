package NestThermostatSystem {
    private import ScalarValues::*;

    attribute def Temperature;
    attribute def Humidity;
    attribute def Duration;
    attribute def Power;
    attribute def Energy;
    attribute def Decibel;
    attribute def Percentage;
    attribute def TimeOfDay;

    enum OccupancyStatus {
        Occupied;
        Empty;
        Sleeping;
    }

    enum HVACMode {
        Heating;
        Cooling;
        Idle;
        EnergySaving;
    }

    enum DayOfWeek {
        Monday;
        Tuesday;
        Wednesday;
        Thursday;
        Friday;
        Saturday;
        Sunday;
    }

    item def HvacCommand;
    item def HeatCommand :> HvacCommand;
    item def CoolCommand :> HvacCommand;
    item def IdleCommand :> HvacCommand;
    item def EnergySaveCommand :> HvacCommand;
    item def UserInput;
    item def TempOverride :> UserInput;
    item def ModeSwitch :> UserInput;
    item def StatusReport;

    item def UserAdjustment {
        attribute newTemperature : Temperature;
        attribute time : TimeOfDay;
        attribute day : DayOfWeek;
        attribute occupancy : OccupancyStatus;
    }

    item def LearnedSchedule {
        attribute scheduleData : String;
        attribute adjustmentCount : Integer;
    }

    port def HvacControlPort {
        out item command : HvacCommand;
    }
    port def HvacCommandPort {
        in item command : HvacCommand;
    }
    port def TempDataPort {
        attribute temperature : Temperature;
        attribute humidity : Humidity;
    }
    port def OccupancyDataPort {
        attribute status : OccupancyStatus;
        attribute motionLevel : Real;
    }
    port def UserCommandPort {
        in item userInput : UserInput;
    }
    port def DisplayPort {
        out item status : StatusReport;
    }
    port def NetworkPort {
        in item remoteInput : UserInput;
        out item remoteStatus : StatusReport;
    }

    requirement def ClimateRegulationReqDef {
        doc /* The thermostat shall maintain indoor temperature within 0.5 degrees of the setpoint. */
        attribute setTemp : Temperature;
        attribute actualTemp : Temperature;
        require constraint { abs(actualTemp - setTemp) <= 0.5 }
    }
    requirement def EnergySavingReqDef {
        doc /* The thermostat shall enter energy-saving mode when the home is unoccupied for over 30 minutes. */
        attribute emptyDuration : Duration;
        attribute threshold : Duration;
        require constraint { emptyDuration >= threshold }
    }
    requirement def LearningScheduleReqDef {
        doc /* The learning engine shall build a personalized weekly schedule from observed user adjustments. */
        attribute learnedAdjustments : Integer;
        attribute minAdjustments : Integer;
        require constraint { learnedAdjustments >= minAdjustments }
    }
    requirement def ResponseTimeReqDef {
        doc /* The thermostat shall respond to user inputs within 1 second. */
        attribute responseTime : Duration;
        attribute maxResponseTime : Duration;
        require constraint { responseTime <= maxResponseTime }
    }
    requirement def PowerConsumptionReqDef {
        doc /* The HVAC system shall minimize energy consumption. */
        attribute energyUsed : Energy;
        attribute maxEnergyUsed : Energy;
        require constraint { energyUsed <= maxEnergyUsed }
    }
    requirement def RemoteAccessReqDef {
        doc /* The thermostat shall allow remote access via a network connection. */
        attribute remoteAccessEnabled : Boolean;
        require constraint { remoteAccessEnabled == true }
    }
    requirement def NoiseLevelReqDef {
        doc /* The HVAC system shall operate with noise levels below 40 dB. */
        attribute noiseLevel : Decibel;
        attribute maxNoiseLevel : Decibel;
        require constraint { noiseLevel <= maxNoiseLevel }
    }
    requirement def ReliabilityReqDef {
        doc /* The thermostat shall operate reliably for at least 5 years. */
        attribute operationalYears : Integer;
        attribute minOperationalYears : Integer;
        require constraint { operationalYears >= minOperationalYears }
    }
    requirement def OccupancyDetectionReqDef {
        doc /* The thermostat shall detect occupancy with at least 95 percent accuracy. */
        attribute detectionAccuracy : Percentage;
        attribute minAccuracy : Percentage;
        require constraint { detectionAccuracy >= minAccuracy }
    }

    part def TemperatureSensor {
        attribute measuredTemperature : Temperature;
        attribute measuredHumidity : Humidity;
        port tempOut : TempDataPort;
        action senseEnvironment {
            then action sendReading;
        }
        action sendReading;
    }

    part def OccupancySensor {
        attribute motionDetected : Real;
        port motionOut : OccupancyDataPort;
        action detectMotion {
            then action sendMotionReading;
        }
        action sendMotionReading;
    }

    part def LearningEngine {
        attribute weekday : DayOfWeek;
        attribute timeOfDay : TimeOfDay;
        attribute isOccupied : Boolean;
        attribute setPoint : Temperature;
        attribute learnedAdjustments : Integer;
        action learnFromUserAdjustment {
            in adjustment : Temperature;
            in time : TimeOfDay;
            in day : DayOfWeek;
            in occupied : Boolean;
            then action updateSchedule;
        }
        action updateSchedule {
            in newAdjustment : Temperature;
            in newTime : TimeOfDay;
            in newDay : DayOfWeek;
            in newOccupied : Boolean;
        }
        action buildWeeklySchedule;
    }

    part def PhysicalDisplay {
        port userIn : UserCommandPort;
        port displayOut : DisplayPort;
        action showStatus {
            in status : StatusReport;
        }
        action receiveUserInput {
            in input : UserInput;
        }
    }

    part def NetworkInterface {
        port netPort : NetworkPort;
        attribute remoteAccessEnabled : Boolean;
        action receiveRemoteInput {
            in input : UserInput;
        }
        action sendRemoteStatus {
            in status : StatusReport;
        }
    }

    part def ThermostatController {
        attribute targetTemp : Temperature;
        attribute currentTemp : Temperature;
        attribute currentHumidity : Humidity;
        attribute currentOccupancy : OccupancyStatus;
        attribute emptyDuration : Duration;
        attribute currentMode : HVACMode;
        attribute threshold : Duration;
        port tempIn : TempDataPort;
        port occIn : OccupancyDataPort;
        port userIn : UserCommandPort;
        port displayOut : DisplayPort;
        port netOut : NetworkPort;
        port hvacOut : HvacControlPort;
        part tempSensor : TemperatureSensor;
        part occSensor : OccupancySensor;
        part learningEngine : LearningEngine;
        part display : PhysicalDisplay;
        part networkInterface : NetworkInterface;
        bind tempIn = tempSensor.tempOut;
        bind occIn = occSensor.motionOut;
        bind userIn = display.userIn;
        bind displayOut = display.displayOut;
        bind netOut = networkInterface.netPort;
        action processUserInput {
            in input : UserInput;
            then action updateTargetTemp;
        }
        action updateTargetTemp {
            in newTarget : Temperature;
        }
        action sendHvacCommand {
            in cmd : HvacCommand;
        }
        state ControllerBehavior {
            entry; then idle;
            state idle;
            accept UserInput via userIn
                then evaluate;
            accept UserInput via netOut
                then evaluate;
            transition from idle to heating
                when tempIn.temperature < targetTemp
                    && occIn.status == OccupancyStatus::Occupied;
            transition from idle to cooling
                when tempIn.temperature > targetTemp
                    && occIn.status == OccupancyStatus::Occupied;
            transition from idle to energySaving
                when occIn.status == OccupancyStatus::Empty
                    && emptyDuration >= threshold;
            state evaluate;
            transition from evaluate to heating
                when tempIn.temperature < targetTemp;
            transition from evaluate to cooling
                when tempIn.temperature > targetTemp;
            transition from evaluate to energySaving
                when occIn.status == OccupancyStatus::Empty;
            transition from evaluate to idle
                when tempIn.temperature == targetTemp;
            state heating;
            transition from heating to idle
                when tempIn.temperature >= targetTemp;
            transition from heating to energySaving
                when occIn.status == OccupancyStatus::Empty
                    && emptyDuration >= threshold;
            state cooling;
            transition from cooling to idle
                when tempIn.temperature <= targetTemp;
            transition from cooling to energySaving
                when occIn.status == OccupancyStatus::Empty
                    && emptyDuration >= threshold;
            state energySaving;
            transition from energySaving to evaluate
                when occIn.status == OccupancyStatus::Occupied;
            accept UserInput via userIn
                then evaluate;
            accept UserInput via netOut
                then evaluate;
        }
    }

    part def HvacUnit {
        port hvacIn : HvacCommandPort;
        attribute powerConsumption : Power;
        attribute noiseLevel : Decibel;
        state HvacState {
            entry; then standby;
            state standby;
            accept HeatCommand via hvacIn
                then heating;
            accept CoolCommand via hvacIn
                then cooling;
            accept IdleCommand via hvacIn
                then standby;
            accept EnergySaveCommand via hvacIn
                then energySaving;
            state heating;
            accept CoolCommand via hvacIn
                then cooling;
            accept IdleCommand via hvacIn
                then standby;
            accept EnergySaveCommand via hvacIn
                then energySaving;
            state cooling;
            accept HeatCommand via hvacIn
                then heating;
            accept IdleCommand via hvacIn
                then standby;
            accept EnergySaveCommand via hvacIn
                then energySaving;
            state energySaving;
            accept HeatCommand via hvacIn
                then heating;
            accept CoolCommand via hvacIn
                then cooling;
            accept IdleCommand via hvacIn
                then standby;
        }
    }

    part def Home {
        attribute indoorTemperature : Temperature;
        attribute indoorHumidity : Humidity;
        part thermostat : ThermostatController;
        part hvac : HvacUnit;
        interface hvacConnection connect thermostat.hvacOut to hvac.hvacIn {
            flow commandFlow of HvacCommand
                from thermostat.hvacOut.command to hvac.hvacIn.command;
        }
    }

    requirement thermostatClimateReq : ClimateRegulationReqDef {
        attribute setTemp = 22;
        attribute actualTemp = 22;
    }
    requirement thermostatEnergyReq : EnergySavingReqDef {
        attribute emptyDuration = 30;
        attribute threshold = 30;
    }
    requirement thermostatLearningReq : LearningScheduleReqDef {
        attribute learnedAdjustments = 7;
        attribute minAdjustments = 7;
    }
    requirement thermostatResponseReq : ResponseTimeReqDef {
        attribute responseTime = 0.5;
        attribute maxResponseTime = 1;
    }
    requirement thermostatRemoteReq : RemoteAccessReqDef {
        attribute remoteAccessEnabled = true;
    }
    requirement thermostatNoiseReq : NoiseLevelReqDef {
        attribute noiseLevel = 35;
        attribute maxNoiseLevel = 40;
    }
    requirement thermostatReliabilityReq : ReliabilityReqDef {
        attribute operationalYears = 5;
        attribute minOperationalYears = 5;
    }
    requirement thermostatOccupancyReq : OccupancyDetectionReqDef {
        attribute detectionAccuracy = 95;
        attribute minAccuracy = 95;
    }
}
