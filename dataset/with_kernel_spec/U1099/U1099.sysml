package 'Indoor Air Quality System' {
    private import ScalarValues::*;

    attribute def CO2Concentration :> Real { doc /* Unit: ppm */ }
    attribute def VOCConcentration :> Real { doc /* Unit: ppb */ }
    attribute def PM25Concentration :> Real { doc /* Unit: ug/m3 */ }
    attribute def RelativeHumidity :> Real { doc /* Unit: % */ }
    attribute def Temperature :> Real { doc /* Unit: degC */ }
    attribute def AirQualityIndex :> Real;
    attribute def FanSpeed :> Real { doc /* Unit: % */ }
    attribute def PurifierIntensity :> Real { doc /* Unit: % */ }
    attribute def FilterLife :> Real { doc /* Unit: % */ }

    item def SensorData {
        attribute co2 : CO2Concentration;
        attribute voc : VOCConcentration;
        attribute pm25 : PM25Concentration;
        attribute humidity : RelativeHumidity;
        attribute temperature : Temperature;
    }
    item def ControlCommand {
        attribute fanSpeed : FanSpeed;
        attribute purifierIntensity : PurifierIntensity;
        attribute humiditySetpoint : RelativeHumidity;
    }
    item def MaintenanceAlert {
        attribute alertText : String;
    }
    item def DisplayStatus {
        attribute aqi : AirQualityIndex;
        attribute statusText : String;
    }

    port def SensorOutPort { out sensorData : SensorData; }
    port def SensorInPort { in sensorData : SensorData; }
    port def CommandOutPort { out command : ControlCommand; }
    port def CommandInPort { in command : ControlCommand; }
    port def FilterStatusOutPort { out filterLife : FilterLife; }
    port def FilterStatusInPort { in filterLife : FilterLife; }
    port def DisplayOutPort { out status : DisplayStatus; }
    port def DisplayInPort { in status : DisplayStatus; }
    port def AlertOutPort { out alert : MaintenanceAlert; }
    port def AlertInPort { in alert : MaintenanceAlert; }

    part def MultiSensorUnit {
        port sensorOut : SensorOutPort;
    }

    part def VentilationFan {
        port commandIn : CommandInPort;
        attribute currentSpeed : FanSpeed;
    }

    part def AirPurifier {
        port commandIn : CommandInPort;
        port filterStatusOut : FilterStatusOutPort;
        attribute remainingFilterLife : FilterLife;
    }

    part def HumidityRegulator {
        port commandIn : CommandInPort;
    }

    part def UserInterface {
        port displayIn : DisplayInPort;
        port alertIn : AlertInPort;
    }

    part def CentralControlProcessor {
        port sensorIn1 : SensorInPort;
        port sensorIn2 : SensorInPort;
        port sensorIn3 : SensorInPort;
        port fanCommandOut : CommandOutPort;
        port purifierCommandOut : CommandOutPort;
        port humidifierCommandOut : CommandOutPort;
        port filterStatusIn : FilterStatusInPort;
        port displayOut : DisplayOutPort;
        port alertOut : AlertOutPort;

        attribute co2Threshold : CO2Concentration = 1000.0;
        attribute pm25Threshold : PM25Concentration = 35.0;
        attribute vocThreshold : VOCConcentration = 500.0;
        attribute humidityMin : RelativeHumidity = 30.0;
        attribute humidityMax : RelativeHumidity = 60.0;
        attribute currentAQI : AirQualityIndex;
        attribute controlFailure : Boolean = false;
        attribute co2High : Boolean;
        attribute pm25High : Boolean;
        attribute vocHigh : Boolean;

        state machine controlStateMachine {
            entry; then IdleMonitoring;
            state IdleMonitoring;
            state ActiveVentilating;
            state ActivePurifying;
            state FailsafeMode;

            transition idle_to_ventilating first IdleMonitoring
                if co2High
                then ActiveVentilating;
            transition idle_to_purifying first IdleMonitoring
                if pm25High or vocHigh
                then ActivePurifying;
            transition ventilating_to_idle first ActiveVentilating
                if not co2High
                then IdleMonitoring;
            transition purifying_to_idle first ActivePurifying
                if not pm25High and not vocHigh
                then IdleMonitoring;
            transition idle_to_failsafe first IdleMonitoring
                if controlFailure
                then FailsafeMode;
            transition ventilating_to_failsafe first ActiveVentilating
                if controlFailure
                then FailsafeMode;
            transition purifying_to_failsafe first ActivePurifying
                if controlFailure
                then FailsafeMode;
        }

        action calculateAQI {
            in data : SensorData;
            out aqi : AirQualityIndex;
        }
    }

    part def Building {
        part controller : CentralControlProcessor;
        part sensor1 : MultiSensorUnit;
        part sensor2 : MultiSensorUnit;
        part sensor3 : MultiSensorUnit;
        part fan : VentilationFan;
        part purifier : AirPurifier;
        part humidifier : HumidityRegulator;
        part ui : UserInterface;

        flow sensorFlow1 of SensorData from sensor1.sensorOut.sensorData to controller.sensorIn1.sensorData;
        flow sensorFlow2 of SensorData from sensor2.sensorOut.sensorData to controller.sensorIn2.sensorData;
        flow sensorFlow3 of SensorData from sensor3.sensorOut.sensorData to controller.sensorIn3.sensorData;

        flow fanCommandFlow of ControlCommand from controller.fanCommandOut.command to fan.commandIn.command;
        flow purifierCommandFlow of ControlCommand from controller.purifierCommandOut.command to purifier.commandIn.command;
        flow humidifierCommandFlow of ControlCommand from controller.humidifierCommandOut.command to humidifier.commandIn.command;

        flow filterStatusFlow of FilterLife from purifier.filterStatusOut.filterLife to controller.filterStatusIn.filterLife;

        flow displayFlow of DisplayStatus from controller.displayOut.status to ui.displayIn.status;
        flow alertFlow of MaintenanceAlert from controller.alertOut.alert to ui.alertIn.alert;
    }

    requirement def AirQualityMonitoringReqDef {
        doc /* The system shall continuously monitor CO2, VOCs, PM2.5, humidity, and temperature. */
        attribute measuredParameters : Integer = 5;
        require constraint { measuredParameters == 5 }
    }
    requirement def AdaptiveResponseReqDef {
        doc /* The system shall adaptively control fan speed and purification intensity based on air quality degradation. */
        attribute fanSpeed : FanSpeed;
        attribute purificationIntensity : PurifierIntensity;
        attribute degradationLevel : AirQualityIndex;
        require constraint { fanSpeed > 0 and purificationIntensity > 0 implies degradationLevel > 100 }
    }
    requirement def FailsafeReqDef {
        doc /* The system shall default to maximum ventilation in case of a control failure. */
        attribute controlFailure : Boolean;
        attribute ventilationLevel : FanSpeed;
        attribute maxVentilation : FanSpeed = 100.0;
        require constraint { controlFailure == true implies ventilationLevel == maxVentilation }
    }
    requirement def MaintenanceTrackingReqDef {
        doc /* The system shall track component status and issue alerts for maintenance like filter replacement. */
        attribute filterLife : FilterLife;
        attribute filterLifeThreshold : FilterLife = 10.0;
        attribute alertIssued : Boolean;
        require constraint { filterLife <= filterLifeThreshold implies alertIssued == true }
    }
    requirement def HumidityControlReqDef {
        doc /* The system shall maintain optimal moisture levels using a humidity regulator. */
        attribute humidityLevel : RelativeHumidity;
        attribute minHumidity : RelativeHumidity = 30.0;
        attribute maxHumidity : RelativeHumidity = 60.0;
        require constraint { humidityLevel >= minHumidity and humidityLevel <= maxHumidity }
    }
    requirement def UserInterfaceReqDef {
        doc /* The system shall display the current air quality status and index to occupants. */
        attribute displayedAQI : Boolean;
        attribute displayedStatus : Boolean;
        require constraint { displayedAQI == true and displayedStatus == true }
    }
    requirement def SensorRedundancyReqDef {
        doc /* The system shall feature sensor redundancy using three integrated multi-sensor units. */
        attribute sensorCount : Integer = 3;
        require constraint { sensorCount == 3 }
    }
}
