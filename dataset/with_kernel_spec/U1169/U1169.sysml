package SmartThermostatSystem {
    private import ScalarValues::*;

    attribute def Temperature :> Real;
    attribute def Humidity :> Real;
    attribute def Power :> Real;
    attribute def Duration :> Real;

    item def TemperatureReading {
        attribute value : Temperature;
    }
    item def HumidityReading {
        attribute value : Humidity;
    }
    item def OccupancyReading {
        attribute occupied : Boolean;
    }
    item def RemoteCommand {
        attribute setpoint : Temperature;
        attribute mode : String;
    }
    item def ManualSetpoint {
        attribute setpoint : Temperature;
    }
    item def ScheduleSetpoint {
        attribute setpoint : Temperature;
        attribute dayOfWeek : Integer;
        attribute hourOfDay : Integer;
    }
    item def HVACCommand {
        attribute heatingOn : Boolean;
        attribute coolingOn : Boolean;
        attribute fanOn : Boolean;
    }
    item def StatusReport {
        attribute currentTemp : Temperature;
        attribute setpoint : Temperature;
        attribute mode : String;
        attribute humidity : Humidity;
    }

    part def TemperatureSensor {
        port tempOut {
            out tempReading : TemperatureReading;
        }
        action sense {
            send new TemperatureReading() to tempOut;
        }
    }

    part def HumiditySensor {
        port humidityOut {
            out humidityReading : HumidityReading;
        }
        action sense {
            send new HumidityReading() to humidityOut;
        }
    }

    part def OccupancySensor {
        port occupancyOut {
            out occupancyReading : OccupancyReading;
        }
        action sense {
            send new OccupancyReading() to occupancyOut;
        }
    }

    part def NetworkModule {
        port remoteOut {
            out remoteCommand : RemoteCommand;
        }
        port statusIn {
            in statusReport : StatusReport;
        }
        action receiveRemote {
            accept RemoteCommand;
            then send new RemoteCommand() to remoteOut;
        }
        action reportStatus {
            accept StatusReport via statusIn;
        }
    }

    part def UserDisplay {
        port manualSetOut {
            out manualSetpoint : ManualSetpoint;
        }
        port statusDisplayIn {
            in statusReport : StatusReport;
        }
        action acceptManualInput {
            send new ManualSetpoint() to manualSetOut;
        }
        action displayStatus {
            accept StatusReport via statusDisplayIn;
        }
    }

    part def ScheduleController {
        port scheduleOut {
            out scheduleSetpoint : ScheduleSetpoint;
        }
        attribute dayOfWeek : Integer;
        attribute hourOfDay : Integer;
        action outputSchedule {
            send new ScheduleSetpoint() to scheduleOut;
        }
    }

    part def Furnace {
        port commandIn {
            in hvacCommand : HVACCommand;
        }
        attribute active : Boolean = false;
        action receiveCommand {
            accept HVACCommand via commandIn;
        }
    }

    part def AirConditioner {
        port commandIn {
            in hvacCommand : HVACCommand;
        }
        attribute active : Boolean = false;
        action receiveCommand {
            accept HVACCommand via commandIn;
        }
    }

    part def BlowerFan {
        port commandIn {
            in hvacCommand : HVACCommand;
        }
        attribute active : Boolean = false;
        action receiveCommand {
            accept HVACCommand via commandIn;
        }
    }

    part def HVACEquipment {
        port commandIn {
            in hvacCommand : HVACCommand;
        }
        part furnace : Furnace;
        part airConditioner : AirConditioner;
        part blowerFan : BlowerFan;
        bind furnace.commandIn = commandIn;
        bind airConditioner.commandIn = commandIn;
        bind blowerFan.commandIn = commandIn;
    }

    state def ThermostatControlState {
        attribute currentTemp : Temperature;
        attribute setpoint : Temperature;
        attribute deadband : Temperature = 1.0;

        initial state Idle;
        state Heating;
        state Cooling;
        state FanOnly;

        transition from Idle to Heating
            when { currentTemp < setpoint - deadband };
        transition from Idle to Cooling
            when { currentTemp > setpoint + deadband };
        transition from Idle to FanOnly
            when { currentTemp >= setpoint - deadband && currentTemp <= setpoint + deadband };
        transition from Heating to Idle
            when { currentTemp >= setpoint };
        transition from Cooling to Idle
            when { currentTemp <= setpoint };
        transition from FanOnly to Idle
            when { currentTemp < setpoint - deadband || currentTemp > setpoint + deadband };
    }

    part def Thermostat {
        port tempSensorIn {
            in tempReading : TemperatureReading;
        }
        port humiditySensorIn {
            in humidityReading : HumidityReading;
        }
        port occupancySensorIn {
            in occupancyReading : OccupancyReading;
        }
        port remoteCommandIn {
            in remoteCommand : RemoteCommand;
        }
        port manualSetpointIn {
            in manualSetpoint : ManualSetpoint;
        }
        port scheduleSetpointIn {
            in scheduleSetpoint : ScheduleSetpoint;
        }
        port hvacCommandOut {
            out hvacCommand : HVACCommand;
        }
        port statusReportOut {
            out statusReport : StatusReport;
        }

        attribute currentTemp : Temperature;
        attribute targetSetpoint : Temperature;
        attribute deadband : Temperature = 1.0;
        attribute operatingMode : String;

        exhibit ThermostatControlState;

        action determineSetpoint {
            accept RemoteCommand via remoteCommandIn;
            then accept ManualSetpoint via manualSetpointIn;
            then accept ScheduleSetpoint via scheduleSetpointIn;
        }

        action reportStatus {
            send new StatusReport() to statusReportOut;
        }
    }

    part thermostatSystem : Thermostat {
        part tempSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part occupancySensor : OccupancySensor;
        part networkModule : NetworkModule;
        part userDisplay : UserDisplay;
        part scheduleController : ScheduleController;
        part hvacEquipment : HVACEquipment;

        flow tempFlow of TemperatureReading
            from tempSensor.tempOut.tempReading to tempSensorIn.tempReading;
        flow humidityFlow of HumidityReading
            from humiditySensor.humidityOut.humidityReading to humiditySensorIn.humidityReading;
        flow occupancyFlow of OccupancyReading
            from occupancySensor.occupancyOut.occupancyReading to occupancySensorIn.occupancyReading;
        flow remoteFlow of RemoteCommand
            from networkModule.remoteOut.remoteCommand to remoteCommandIn.remoteCommand;
        flow manualFlow of ManualSetpoint
            from userDisplay.manualSetOut.manualSetpoint to manualSetpointIn.manualSetpoint;
        flow scheduleFlow of ScheduleSetpoint
            from scheduleController.scheduleOut.scheduleSetpoint to scheduleSetpointIn.scheduleSetpoint;
        flow hvacCommandFlow of HVACCommand
            from hvacCommandOut.hvacCommand to hvacEquipment.commandIn.hvacCommand;
        flow statusNetworkFlow of StatusReport
            from statusReportOut.statusReport to networkModule.statusIn.statusReport;
        flow statusDisplayFlow of StatusReport
            from statusReportOut.statusReport to userDisplay.statusDisplayIn.statusReport;
    }

    occurrence def ThermostatOperation {
        ref part :>> thermostatSystem;
        message tempMessage of TemperatureReading
            from thermostatSystem.tempSensor.tempOut.tempReading
            to thermostatSystem.tempSensorIn.tempReading;
        then message humidityMessage of HumidityReading
            from thermostatSystem.humiditySensor.humidityOut.humidityReading
            to thermostatSystem.humiditySensorIn.humidityReading;
        then message occupancyMessage of OccupancyReading
            from thermostatSystem.occupancySensor.occupancyOut.occupancyReading
            to thermostatSystem.occupancySensorIn.occupancyReading;
        then message remoteMessage of RemoteCommand
            from thermostatSystem.networkModule.remoteOut.remoteCommand
            to thermostatSystem.remoteCommandIn.remoteCommand;
        then message hvacMessage of HVACCommand
            from thermostatSystem.hvacCommandOut.hvacCommand
            to thermostatSystem.hvacEquipment.commandIn.hvacCommand;
        then message statusNetworkMessage of StatusReport
            from thermostatSystem.statusReportOut.statusReport
            to thermostatSystem.networkModule.statusIn.statusReport;
        then message statusDisplayMessage of StatusReport
            from thermostatSystem.statusReportOut.statusReport
            to thermostatSystem.userDisplay.statusDisplayIn.statusReport;
    }

    requirement def TemperatureControlReq {
        doc /* The thermostat shall maintain indoor temperature within the deadband of the setpoint. */
        attribute setpoint : Temperature;
        attribute actualTemp : Temperature;
        attribute deadband : Temperature;
        require constraint { actualTemp - setpoint <= deadband && setpoint - actualTemp <= deadband }
    }

    requirement def DeadbandReq {
        doc /* The thermostat shall use a temperature deadband to prevent short cycling and optimize energy efficiency. */
        attribute deadband : Temperature;
        attribute minDeadband : Temperature;
        require constraint { deadband >= minDeadband }
    }

    requirement def EnergyEfficiencyReq {
        doc /* The thermostat shall optimize energy consumption by leveraging occupancy sensing and scheduled setbacks. */
        attribute powerConsumption : Power;
        attribute maxPowerConsumption : Power;
        require constraint { powerConsumption <= maxPowerConsumption }
    }

    requirement def RemoteControlReq {
        doc /* The thermostat shall accept remote commands via the network module from a smartphone app or web interface. */
        attribute remoteCommandReceived : Boolean;
        require constraint { remoteCommandReceived == true }
    }

    requirement def ScheduleReq {
        doc /* The thermostat shall support a weekly schedule with adjustable setpoints for different times of day and days of the week. */
        attribute scheduleDays : Integer;
        require constraint { scheduleDays >= 7 }
    }

    requirement def SetpointPriorityReq {
        doc /* The thermostat shall prioritize remote commands first, then manual setpoint, then scheduled setpoint. */
        attribute remotePriority : Integer;
        attribute manualPriority : Integer;
        attribute schedulePriority : Integer;
        require constraint {
            remotePriority < manualPriority &&
            manualPriority < schedulePriority
        }
    }

    requirement def OccupancyAdaptationReq {
        doc /* The thermostat shall use occupancy sensor data to optimize climate control when the building is unoccupied. */
        attribute occupancyDetected : Boolean;
        attribute setbackSetpoint : Temperature;
        attribute normalSetpoint : Temperature;
        require constraint { occupancyDetected == true || setbackSetpoint != normalSetpoint }
    }

    requirement def MultiSensorReq {
        doc /* The thermostat shall be equipped with temperature, humidity, and occupancy sensors. */
        attribute tempSensorPresent : Boolean;
        attribute humiditySensorPresent : Boolean;
        attribute occupancySensorPresent : Boolean;
        require constraint {
            tempSensorPresent == true &&
            humiditySensorPresent == true &&
            occupancySensorPresent == true
        }
    }

    requirement def StatusReportingReq {
        doc /* The thermostat shall continuously report status including current temperature, operating mode, and setpoint. */
        attribute reportInterval : Duration;
        attribute maxReportInterval : Duration;
        require constraint { reportInterval <= maxReportInterval }
    }
}
