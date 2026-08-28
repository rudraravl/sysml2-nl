package SmartThermostatSystem {

    import ISQ::*;
    import ScalarValues::*;

    // ---------- Value Types ----------
    def type TemperatureValue :> Real { unit = '°C'; }
    def type HumidityValue :> Real { unit = '%'; }
    def type PowerValue :> Real { unit = 'W'; }
    def type TimeOfDay :> Real { unit = 'h'; }
    def type DayOfWeek :> String;
    def type TemperatureDelta :> Real { unit = 'K'; }

    // ---------- Enumerations ----------
    enum def OperatingMode {
        OFF;
        HEATING;
        COOLING;
        FAN_ONLY;
    }

    enum def SetpointSource {
        REMOTE;
        MANUAL;
        SCHEDULE;
    }

    enum def FanMode {
        AUTO;
        ON;
        OFF;
    }

    enum def OccupancyState {
        OCCUPIED;
        UNOCCUPIED;
    }

    enum def NetworkCommandKind {
        SET_SETPOINT;
        SET_MODE;
        SET_FAN_MODE;
        QUERY_STATUS;
    }

    // ---------- Item Types ----------
    item def TemperatureReading {
        attribute value : TemperatureValue;
        attribute timestamp : TimeOfDay;
    }

    item def HumidityReading {
        attribute value : HumidityValue;
        attribute timestamp : TimeOfDay;
    }

    item def OccupancyReading {
        attribute state : OccupancyState;
        attribute timestamp : TimeOfDay;
    }

    item def RemoteCommand {
        attribute kind : NetworkCommandKind;
        attribute setpoint : TemperatureValue optional;
        attribute mode : OperatingMode optional;
        attribute fanMode : FanMode optional;
    }

    item def StatusReport {
        attribute currentTemp : TemperatureValue;
        attribute currentHumidity : HumidityValue;
        attribute setpoint : TemperatureValue;
        attribute mode : OperatingMode;
        attribute fanMode : FanMode;
        attribute source : SetpointSource;
    }

    item def ScheduleEntry {
        attribute day : DayOfWeek;
        attribute startTime : TimeOfDay;
        attribute endTime : TimeOfDay;
        attribute setpoint : TemperatureValue;
        attribute mode : OperatingMode;
    }

    item def HVACCommand {
        attribute mode : OperatingMode;
        attribute fanMode : FanMode;
        attribute targetSetpoint : TemperatureValue;
    }

    // ---------- Port Definitions ----------
    port def TempSensorOut {
        out reading : TemperatureReading;
    }

    port def HumiditySensorOut {
        out reading : HumidityReading;
    }

    port def OccupancySensorOut {
        out reading : OccupancyReading;
    }

    port def NetworkPort {
        in cmd : RemoteCommand;
        out report : StatusReport;
    }

    port def DisplayPort {
        in report : StatusReport;
        out manualSetpoint : TemperatureValue optional;
    }

    port def SchedulePort {
        out entry : ScheduleEntry;
    }

    port def ControlOutPort {
        out cmd : HVACCommand;
    }

    port def HVACInPort {
        in cmd : HVACCommand;
    }

    // ---------- Requirements ----------
    requirement def ComfortControlRequirement {
        doc "The thermostat shall maintain indoor temperature within a defined comfort band around the setpoint.";
        attribute deadband : TemperatureDelta = 1.0;
        subject thermostat : SmartThermostatUnit;
        objective {
            assert thermostat.controlLogic.currentError.abs <= deadband
        }
    }

    requirement def EnergyEfficiencyRequirement {
        doc "The thermostat shall minimize HVAC activation cycles by using a temperature deadband and occupancy-aware scheduling.";
        attribute minCycleTime : TimeOfDay = 0.083; // 5 minutes
        subject thermostat : SmartThermostatUnit;
    }

    requirement def RemoteControlRequirement {
        doc "The thermostat shall accept remote commands via the network module and prioritize them over manual and schedule setpoints.";
        subject thermostat : SmartThermostatUnit;
    }

    requirement def StatusReportingRequirement {
        doc "The thermostat shall continuously report current temperature, mode, and setpoint locally and over the network.";
        subject thermostat : SmartThermostatUnit;
    }

    // ---------- Sensor Parts ----------
    part def TemperatureSensor {
        port out sensorOut : TempSensorOut;
        attribute currentValue : TemperatureValue = 21.0;
        action def senseTemperature {
            out reading : TemperatureReading;
        }
        perform senseTemperature;
    }

    part def HumiditySensor {
        port out sensorOut : HumiditySensorOut;
        attribute currentValue : HumidityValue = 45.0;
        action def senseHumidity {
            out reading : HumidityReading;
        }
        perform senseHumidity;
    }

    part def OccupancySensor {
        port out sensorOut : OccupancySensorOut;
        attribute currentState : OccupancyState = OccupancyState::UNOCCUPIED;
        action def senseOccupancy {
            out reading : OccupancyReading;
        }
        perform senseOccupancy;
    }

    // ---------- Network Communication Module ----------
    part def NetworkCommunicationModule {
        port netPort : NetworkPort;
        attribute connected : Boolean = true;
        attribute lastCommand : RemoteCommand optional;

        action def receiveRemoteCommand {
            in cmd : RemoteCommand;
            out processed : RemoteCommand;
        }

        action def sendStatusReport {
            in report : StatusReport;
        }

        perform receiveRemoteCommand then sendStatusReport;
    }

    // ---------- User Display ----------
    part def UserDisplay {
        port displayPort : DisplayPort;
        attribute localSetpoint : TemperatureValue = 21.0;
        attribute backlightOn : Boolean = true;

        action def displayStatus {
            in report : StatusReport;
        }

        action def acceptManualInput {
            out setpoint : TemperatureValue;
        }

        perform displayStatus;
    }

    // ---------- Schedule Controller ----------
    part def ScheduleController {
        port schedPort : SchedulePort;
        attribute entries : ScheduleEntry[0..*];
        attribute activeEntry : ScheduleEntry optional;

        action def evaluateSchedule {
            in day : DayOfWeek;
            in time : TimeOfDay;
            out entry : ScheduleEntry;
        }

        perform evaluateSchedule;
    }

    // ---------- Control Logic ----------
    part def ControlLogic {
        port in tempInput : TempSensorOut;
        port in humidityInput : HumiditySensorOut;
        port in occupancyInput : OccupancySensorOut;
        port in netInput : NetworkPort;
        port in displayInput : DisplayPort;
        port in scheduleInput : SchedulePort;
        port out controlOutput : ControlOutPort;

        attribute currentTemp : TemperatureValue;
        attribute currentHumidity : HumidityValue;
        attribute currentOccupancy : OccupancyState;
        attribute activeSetpoint : TemperatureValue = 21.0;
        attribute activeSource : SetpointSource = SetpointSource::SCHEDULE;
        attribute deadband : TemperatureDelta = 1.0;
        attribute currentMode : OperatingMode = OperatingMode::OFF;
        attribute currentFanMode : FanMode = FanMode::AUTO;
        attribute currentError : TemperatureDelta;

        action def evaluateSetpoint {
            in remoteCmd : RemoteCommand optional;
            in manualSetpoint : TemperatureValue optional;
            in scheduleEntry : ScheduleEntry optional;
            out setpoint : TemperatureValue;
            out source : SetpointSource;
        }

        action def computeHVACCommand {
            in temp : TemperatureValue;
            in setpoint : TemperatureValue;
            in occupancy : OccupancyState;
            out cmd : HVACCommand;
        }

        action def generateStatusReport {
            out report : StatusReport;
        }

        perform evaluateSetpoint then computeHVACCommand then generateStatusReport;

        state def ControlLogicBehavior {
            entry; then Idle;
            state Idle;
            state Evaluating;
            state ActivatingHVAC;
            state Reporting;
            transition Idle to Evaluating
                when tempInput.reading.value != activeSetpoint;
            transition Evaluating to ActivatingHVAC
                when currentError.abs > deadband;
            transition Evaluating to Reporting
                when currentError.abs <= deadband;
            transition ActivatingHVAC to Reporting
                when currentMode != OperatingMode::OFF;
            transition Reporting to Idle
                when true;
        }

        exhibit ControlLogicBehavior;
    }

    // ---------- HVAC Equipment ----------
    part def Furnace {
        port in cmdPort : HVACInPort;
        attribute powerOutput : PowerValue = 20000;
        attribute active : Boolean = false;
        state def FurnaceState {
            entry; then Off;
            state Off;
            state On;
            transition Off to On
                when cmdPort.cmd.mode == OperatingMode::HEATING;
            transition On to Off
                when cmdPort.cmd.mode != OperatingMode::HEATING;
        }
        exhibit FurnaceState;
    }

    part def AirConditioner {
        port in cmdPort : HVACInPort;
        attribute powerOutput : PowerValue = 15000;
        attribute active : Boolean = false;
        state def ACState {
            entry; then Off;
            state Off;
            state On;
            transition Off to On
                when cmdPort.cmd.mode == OperatingMode::COOLING;
            transition On to Off
                when cmdPort.cmd.mode != OperatingMode::COOLING;
        }
        exhibit ACState;
    }

    part def BlowerFan {
        port in cmdPort : HVACInPort;
        attribute powerOutput : PowerValue = 500;
        attribute active : Boolean = false;
        state def FanState {
            entry; then Off;
            state Off;
            state On;
            transition Off to On
                when cmdPort.cmd.fanMode == FanMode::ON
                    or cmdPort.cmd.mode != OperatingMode::OFF;
            transition On to Off
                when cmdPort.cmd.fanMode == FanMode::OFF
                    and cmdPort.cmd.mode == OperatingMode::OFF;
        }
        exhibit FanState;
    }

    // ---------- HVAC Equipment Assembly ----------
    part def HVACEquipment {
        port in hvacInput : HVACInPort;
        part furnace : Furnace;
        part airConditioner : AirConditioner;
        part blowerFan : BlowerFan;

        connection hvacInput to furnace.cmdPort;
        connection hvacInput to airConditioner.cmdPort;
        connection hvacInput to blowerFan.cmdPort;
    }

    // ---------- Main Thermostat Unit ----------
    part def SmartThermostatUnit {
        port netPort : NetworkPort;
        port displayPort : DisplayPort;
        port out hvacPort : ControlOutPort;

        part temperatureSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part occupancySensor : OccupancySensor;
        part networkModule : NetworkCommunicationModule;
        part userDisplay : UserDisplay;
        part scheduleController : ScheduleController;
        part controlLogic : ControlLogic;
        part hvacEquipment : HVACEquipment;

        // Internal connections: sensors to control logic
        connection temperatureSensor.sensorOut to controlLogic.tempInput;
        connection humiditySensor.sensorOut to controlLogic.humidityInput;
        connection occupancySensor.sensorOut to controlLogic.occupancyInput;

        // Network module to control logic
        connection networkModule.netPort to controlLogic.netInput;

        // User display to control logic
        connection userDisplay.displayPort to controlLogic.displayInput;

        // Schedule controller to control logic
        connection scheduleController.schedPort to controlLogic.scheduleInput;

        // Control logic to HVAC equipment
        connection controlLogic.controlOutput to hvacEquipment.hvacInput;

        // External-facing port bindings
        connection netPort to networkModule.netPort;
        connection displayPort to userDisplay.displayPort;
        connection controlLogic.controlOutput to hvacPort;

        // Requirements satisfaction
        satisfy ComfortControlRequirement by controlLogic;
        satisfy EnergyEfficiencyRequirement by controlLogic;
        satisfy RemoteControlRequirement by networkModule;
        satisfy StatusReportingRequirement by controlLogic;
    }

    // ---------- Top-level System ----------
    part SmartThermostatSystem {
        part thermostat : SmartThermostatUnit;
        part hvac : HVACEquipment;

        connection thermostat.hvacPort to hvac.hvacInput;

        // System-level requirements
        satisfy ComfortControlRequirement by thermostat;
        satisfy EnergyEfficiencyRequirement by thermostat;
        satisfy RemoteControlRequirement by thermostat;
        satisfy StatusReportingRequirement by thermostat;
    }

}
