package QIVICON_Smart_Home {
    private import ScalarValues::*;

    item def Command;
    item def Status;
    item def Alert;
    item def Trigger;
    item def Done;

    attribute def 'setAway';
    attribute def 'setHome';
    attribute def 'setNight';

    attribute def TemperatureValue :> Real;
    attribute def PowerValue :> Real;
    attribute def EnergyValue :> Real;
    attribute def BrightnessValue :> Real;
    attribute def ColorTempValue :> Real;

    port def DeviceCommandPort {
        in command : Command;
        out status : Status;
        out alert : Alert;
    }

    port def NetworkPort {
        in rx : Command;
        out tx : Status;
    }

    port def CloudAppPort {
        in userCommand : Command;
        out deviceStatus : Status;
    }

    part def SmartDevice {
        port devicePort : DeviceCommandPort;
    }

    action def ThermostatRegulation {
        in currentTemp : TemperatureValue;
        in setpoint : TemperatureValue;
    }

    part def HeatingThermostat :> SmartDevice {
        attribute currentTemp : TemperatureValue;
        attribute setpoint : TemperatureValue;
        perform action regulate : ThermostatRegulation;
    }

    action def LightAdjustment {
        in brightness : BrightnessValue;
        in colorTemp : ColorTempValue;
    }

    part def SmartLightBulb :> SmartDevice {
        attribute brightness : BrightnessValue;
        attribute colorTemp : ColorTempValue;
        perform action adjust : LightAdjustment;
    }

    action def DoorWindowMonitoring {
        out isOpen : Boolean;
    }

    part def DoorWindowSensor :> SmartDevice {
        attribute isOpen : Boolean;
        perform action monitor : DoorWindowMonitoring;
    }

    action def MotionDetection {
        out motionDetected : Boolean;
    }

    part def MotionSensor :> SmartDevice {
        attribute motionDetected : Boolean;
        perform action detect : MotionDetection;
    }

    action def PowerMeasurement {
        out powerConsumption : PowerValue;
        out totalEnergy : EnergyValue;
    }

    part def SmartPlug :> SmartDevice {
        attribute powerConsumption : PowerValue;
        attribute totalEnergy : EnergyValue;
        perform action measure : PowerMeasurement;
    }

    action def CommandRouting {
        in command : Command;
        out routedCommand : Command;
    }

    state def HomeBaseStates {
        entry; then home;
        state home;
        accept 'setAway' then away;
        state away;
        accept 'setHome' then home;
        accept 'setNight' then night;
        state night;
        accept 'setHome' then home;
    }

    part def HomeBase {
        port cloudPort : NetworkPort;
        port devicePort : ~DeviceCommandPort;
        exhibit state HomeBaseStates;
        perform action routeCommand : CommandRouting;
    }

    action def AutomationEngine {
        in trigger : Trigger;
        out command : Command;
    }

    action def Authentication {
        in userCommand : Command;
        out authenticatedCommand : Command;
    }

    state def CloudOperation {
        entry; then idle;
        state idle;
        accept Trigger then processing;
        state processing;
        accept Done then idle;
    }

    part def CloudBackend {
        port appPort : CloudAppPort;
        port basePort : ~NetworkPort;
        exhibit state CloudOperation;
        perform action runAutomation : AutomationEngine;
        perform action authenticate : Authentication;
    }

    action def UIRendering {
        in deviceStatus : Status;
    }

    part def MobileApp {
        port cloudPort : ~CloudAppPort;
        perform action renderUI : UIRendering;
    }

    interface def AppCloudInterface {
        end appEnd : ~CloudAppPort;
        end cloudEnd : CloudAppPort;
        flow commandFlow of Command from appEnd.userCommand to cloudEnd.userCommand;
        flow statusFlow of Status from cloudEnd.deviceStatus to appEnd.deviceStatus;
    }

    interface def CloudBaseInterface {
        end cloudEnd : ~NetworkPort;
        end baseEnd : NetworkPort;
        flow commandFlow of Command from cloudEnd.rx to baseEnd.rx;
        flow statusFlow of Status from baseEnd.tx to cloudEnd.tx;
    }

    interface def BaseDeviceInterface {
        end baseEnd : ~DeviceCommandPort;
        end deviceEnd : DeviceCommandPort;
        flow commandFlow of Command from baseEnd.command to deviceEnd.command;
        flow statusFlow of Status from deviceEnd.status to baseEnd.status;
        flow alertFlow of Alert from deviceEnd.alert to baseEnd.alert;
    }

    requirement def RemoteAccess {
        doc /* The system shall allow users to monitor and control home devices from anywhere via the mobile app. */
    }
    requirement def SecurityMonitoring {
        doc /* The system shall provide security modes (home, away, night) that alter sensor behavior and alerting. */
    }
    requirement def AutomatedRoutines {
        doc /* The system shall support automation rules that trigger actions based on sensor data and time conditions. */
    }
    requirement def EnergyMonitoring {
        doc /* The system shall collect and report real-time power consumption and cumulative energy usage for smart plugs. */
    }

    part qiviconSystem {
        part homeBase : HomeBase;
        part cloud : CloudBackend;
        part app : MobileApp;

        part thermostat : HeatingThermostat;
        part lightBulb : SmartLightBulb;
        part doorSensor : DoorWindowSensor;
        part motionSensor : MotionSensor;
        part smartPlug : SmartPlug;

        requirement remoteAccessReq : RemoteAccess;
        requirement securityMonitoringReq : SecurityMonitoring;
        requirement automatedRoutinesReq : AutomatedRoutines;
        requirement energyMonitoringReq : EnergyMonitoring;

        interface appCloud : AppCloudInterface connect app.cloudPort to cloud.appPort;
        interface cloudBase : CloudBaseInterface connect cloud.basePort to homeBase.cloudPort;

        interface baseThermostat : BaseDeviceInterface connect homeBase.devicePort to thermostat.devicePort;
        interface baseLight : BaseDeviceInterface connect homeBase.devicePort to lightBulb.devicePort;
        interface baseDoor : BaseDeviceInterface connect homeBase.devicePort to doorSensor.devicePort;
        interface baseMotion : BaseDeviceInterface connect homeBase.devicePort to motionSensor.devicePort;
        interface basePlug : BaseDeviceInterface connect homeBase.devicePort to smartPlug.devicePort;

        satisfy remoteAccessReq by app;
        satisfy securityMonitoringReq by homeBase;
        satisfy automatedRoutinesReq by cloud;
        satisfy energyMonitoringReq by smartPlug;
    }
}
