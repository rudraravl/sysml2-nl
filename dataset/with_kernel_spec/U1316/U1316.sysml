package SmartLabECS {
    private import ScalarValues::*;

    value def Temperature :> Real;
    value def Humidity :> Real;
    value def Pressure :> Real;
    value def CO2Concentration :> Real;
    value def VOCConcentration :> Real;
    value def ParticulateConcentration :> Real;
    value def TimeValue :> Real;

    item def SensorData {
        attribute temperature : Temperature;
        attribute humidity : Humidity;
        attribute pressure : Pressure;
        attribute co2 : CO2Concentration;
        attribute voc : VOCConcentration;
        attribute particulates : ParticulateConcentration;
    }

    item def ControlCommand {
        attribute targetTemp : Temperature;
        attribute targetHum : Humidity;
        attribute targetPres : Pressure;
    }

    item def ExperimentProfile {
        attribute expId : String;
        attribute reqTemp : Temperature;
        attribute reqHum : Humidity;
        attribute reqPres : Pressure;
        attribute reqCO2 : CO2Concentration;
        attribute duration : TimeValue;
    }

    item def AlertMessage {
        attribute severity : String;
        attribute text : String;
    }

    port def SensorDataOutPort {
        out data : SensorData;
    }
    port def CommandInPort {
        in cmd : ControlCommand;
    }
    port def CommandOutPort {
        out cmd : ControlCommand;
    }
    port def ProfileOutPort {
        out profile : ExperimentProfile;
    }
    port def ProfileInPort {
        in profile : ExperimentProfile;
    }
    port def AlertOutPort {
        out alert : AlertMessage;
    }
    port def AlertInPort {
        in alert : AlertMessage;
    }

    part def SensorSuite {
        part tempSensor {
            out tempOut : Temperature;
        }
        part humSensor {
            out humOut : Humidity;
        }
        part aqSensor {
            out co2Out : CO2Concentration;
            out vocOut : VOCConcentration;
            out partOut : ParticulateConcentration;
        }
        part presSensor {
            out presOut : Pressure;
        }
        port dataOut : SensorDataOutPort;
        
        bind dataOut.data.temperature = tempSensor.tempOut;
        bind dataOut.data.humidity = humSensor.humOut;
        bind dataOut.data.pressure = presSensor.presOut;
        bind dataOut.data.co2 = aqSensor.co2Out;
        bind dataOut.data.voc = aqSensor.vocOut;
        bind dataOut.data.particulates = aqSensor.partOut;
    }

    state machine def DataProcessorStates {
        state idle;
        state conditioning;
        state optimal;
        state suboptimal;
        state critical;
        
        transition initial to idle;
        transition idle to conditioning when profileReceived;
        transition conditioning to optimal when conditionsMet;
        transition optimal to suboptimal when driftDetected;
        transition suboptimal to critical when criticalDeviation;
        transition suboptimal to optimal when conditionsMet;
        transition critical to optimal when conditionsMet;
    }

    part def DataProcessor {
        port dataIn : SensorDataOutPort;
        port cmdOut : CommandOutPort;
        port profileIn : ProfileInPort;
        port alertOut : AlertOutPort;
        
        attribute currentTemp : Temperature;
        attribute currentHum : Humidity;
        attribute currentPres : Pressure;
        
        attribute profileReceived : Boolean = false;
        attribute conditionsMet : Boolean = false;
        attribute driftDetected : Boolean = false;
        attribute criticalDeviation : Boolean = false;
        
        state machine :>> DataProcessorStates;
    }

    part def HVACController {
        port cmdIn : CommandInPort;
    }
    part def HumidityController {
        port cmdIn : CommandInPort;
    }
    part def PressureController {
        port cmdIn : CommandInPort;
    }

    part def ExperimentManager {
        port profileOut : ProfileOutPort;
        port profileIn : ProfileInPort;
    }

    part def UserInterface {
        port uiProfileOut : ProfileOutPort;
        port alertIn : AlertInPort;
    }

    part def SmartLabECS {
        part sensors : SensorSuite;
        part processor : DataProcessor;
        part hvac : HVACController;
        part humidityCtrl : HumidityController;
        part pressureCtrl : PressureController;
        part expManager : ExperimentManager;
        part ui : UserInterface;
        
        flow sensorFlow of SensorData from sensors.dataOut.data to processor.dataIn.data;
        flow cmdFlowHVAC of ControlCommand from processor.cmdOut.cmd to hvac.cmdIn.cmd;
        flow cmdFlowHum of ControlCommand from processor.cmdOut.cmd to humidityCtrl.cmdIn.cmd;
        flow cmdFlowPres of ControlCommand from processor.cmdOut.cmd to pressureCtrl.cmdIn.cmd;
        flow profileFlow of ExperimentProfile from expManager.profileOut.profile to processor.profileIn.profile;
        flow uiProfileFlow of ExperimentProfile from ui.uiProfileOut.profile to expManager.profileIn.profile;
        flow alertFlow of AlertMessage from processor.alertOut.alert to ui.alertIn.alert;
    }

    requirement def EnvironmentalControlReqDef {
        doc /* The system shall maintain temperature, humidity, and pressure within specified limits. */
        attribute actualTemp : Temperature;
        attribute reqTemp : Temperature;
        require constraint { abs(actualTemp - reqTemp) <= 0.5 }
    }

    requirement def AnomalyDetectionReqDef {
        doc /* The processor shall detect and log anomalies in environmental conditions. */
        attribute anomalyDetected : Boolean;
        require constraint { anomalyDetected == true }
    }

    requirement def ExperimentLockReqDef {
        doc /* The system shall lock environmental conditions for the duration of an experiment. */
        attribute isLocked : Boolean;
        require constraint { isLocked == true }
    }

    requirement def SafetyAlarmReqDef {
        doc /* The system shall trigger alarms and emergency protocols in critical states. */
        attribute alarmTriggered : Boolean;
        require constraint { alarmTriggered == true }
    }
}
