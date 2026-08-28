package SmartLabECS {
    import ISQ::*;
    import ScalarValues::*;
    import ScalarFunctions::*;

    // ===== Value Types =====
    value def TemperatureCelsius :> Real {
        unit "°C";
    }
    value def HumidityPercent :> Real {
        unit "%";
    }
    value def PressurePascal :> Real {
        unit "Pa";
    }
    value def CO2Concentration :> Real {
        unit "ppm";
    }
    value def VOCConcentration :> Real {
        unit "ppb";
    }
    value def ParticulateCount :> Real {
        unit "particles/m³";
    }
    value def AirflowRate :> Real {
        unit "m³/s";
    }
    value def Power :> Real {
        unit "W";
    }

    // ===== Item Definitions =====
    item def SensorReading {
        attribute timestamp : DateTime;
        attribute sensorId : String;
        attribute value : Real;
        attribute unit : String;
    }
    item def TemperatureReading :> SensorReading {
        redefines attribute value : TemperatureCelsius;
    }
    item def HumidityReading :> SensorReading {
        redefines attribute value : HumidityPercent;
    }
    item def PressureReading :> SensorReading {
        redefines attribute value : PressurePascal;
    }
    item def AirQualityReading :> SensorReading {
        attribute co2 : CO2Concentration;
        attribute voc : VOCConcentration;
        attribute particulates : ParticulateCount;
    }
    item def ControlCommand {
        attribute commandId : String;
        attribute target : String;
        attribute setpoint : Real;
        attribute priority : Integer;
    }
    item def ExperimentProfile {
        attribute experimentId : String;
        attribute name : String;
        attribute startTime : DateTime;
        attribute endTime : DateTime;
        attribute targetTemp : TemperatureCelsius;
        attribute targetHumidity : HumidityPercent;
        attribute targetPressure : PressurePascal;
        attribute maxCO2 : CO2Concentration;
        attribute maxVOC : VOCConcentration;
        attribute maxParticulates : ParticulateCount;
    }
    item def Alert {
        attribute alertId : String;
        attribute severity : String;
        attribute message : String;
        attribute timestamp : DateTime;
    }
    item def DataLog {
        attribute logId : String;
        attribute timestamp : DateTime;
        attribute readings : SensorReading[0..*];
        attribute experimentId : String;
    }

    // ===== Port Definitions =====
    port def SensorOutPort {
        out reading : SensorReading;
    }
    port def CommandOutPort {
        out command : ControlCommand;
    }
    port def CommandInPort {
        in command : ControlCommand;
    }
    port def AlertOutPort {
        out alert : Alert;
    }
    port def ProfilePort {
        out profile : ExperimentProfile;
        in profile : ExperimentProfile;
    }
    port def StatusPort {
        out status : String;
        out currentTemp : TemperatureCelsius;
        out currentHumidity : HumidityPercent;
        out currentPressure : PressurePascal;
    }

    // ===== Sensor Parts =====
    part def TemperatureSensor {
        port sensorOut : SensorOutPort;
        attribute sensorId : String = "TEMP-001";
        attribute samplingRateHz : Real = 1.0;
        attribute currentValue : TemperatureCelsius;
        
        action def sample :> Action {
            out reading : TemperatureReading;
        }
        perform sample every 1.0 / samplingRateHz;
    }

    part def HumiditySensor {
        port sensorOut : SensorOutPort;
        attribute sensorId : String = "HUM-001";
        attribute samplingRateHz : Real = 0.5;
        attribute currentValue : HumidityPercent;
        
        action def sample :> Action {
            out reading : HumidityReading;
        }
        perform sample every 1.0 / samplingRateHz;
    }

    part def AirQualitySensor {
        port sensorOut : SensorOutPort;
        attribute sensorId : String = "AQ-001";
        attribute samplingRateHz : Real = 0.2;
        attribute currentCO2 : CO2Concentration;
        attribute currentVOC : VOCConcentration;
        attribute currentParticulates : ParticulateCount;
        
        action def sample :> Action {
            out reading : AirQualityReading;
        }
        perform sample every 1.0 / samplingRateHz;
    }

    part def PressureSensor {
        port sensorOut : SensorOutPort;
        attribute sensorId : String = "PRES-001";
        attribute samplingRateHz : Real = 1.0;
        attribute currentValue : PressurePascal;
        
        action def sample :> Action {
            out reading : PressureReading;
        }
        perform sample every 1.0 / samplingRateHz;
    }

    part def SensorSuite {
        port tempOut : SensorOutPort;
        port humOut : SensorOutPort;
        port aqOut : SensorOutPort;
        port presOut : SensorOutPort;
        
        part tempSensor : TemperatureSensor {
            port sensorOut = tempOut;
        }
        part humSensor : HumiditySensor {
            port sensorOut = humOut;
        }
        part aqSensor : AirQualitySensor {
            port sensorOut = aqOut;
        }
        part presSensor : PressureSensor {
            port sensorOut = presOut;
        }
    }

    // ===== Data Processor =====
    part def DataProcessor {
        in port tempIn : SensorOutPort;
        in port humIn : SensorOutPort;
        in port aqIn : SensorOutPort;
        in port presIn : SensorOutPort;
        in port profileIn : ProfilePort;
        out port cmdOut : CommandOutPort;
        out port alertOut : AlertOutPort;
        out port statusOut : StatusPort;
        
        attribute currentTemp : TemperatureCelsius;
        attribute currentHumidity : HumidityPercent;
        attribute currentPressure : PressurePascal;
        attribute currentCO2 : CO2Concentration;
        attribute currentVOC : VOCConcentration;
        attribute currentParticulates : ParticulateCount;
        attribute activeProfile : ExperimentProfile;
        attribute systemState : String = "idle";
        attribute tempTolerance : TemperatureCelsius = 0.5;
        attribute humTolerance : HumidityPercent = 2.0;
        attribute presTolerance : PressurePascal = 50.0;
        attribute co2Limit : CO2Concentration = 1000.0;
        attribute vocLimit : VOCConcentration = 500.0;
        attribute particulateLimit : ParticulateCount = 10000.0;
        
        action def analyzeReadings :> Action {
            in temp : TemperatureReading;
            in hum : HumidityReading;
            in aq : AirQualityReading;
            in pres : PressureReading;
            out command : ControlCommand;
            out alert : Alert;
        }
        
        action def logData :> Action {
            in readings : SensorReading[0..*];
            out log : DataLog;
        }
        
        action def detectAnomaly :> Action {
            in reading : SensorReading;
            out isAnomaly : Boolean;
            out alert : Alert;
        }
        
        perform analyzeReadings when (tempIn.reading | humIn.reading | aqIn.reading | presIn.reading);
        perform logData every 60.0;
    }

    // ===== Environmental Controllers =====
    part def HVACSystem {
        in port cmdIn : CommandInPort;
        attribute currentSetpoint : TemperatureCelsius;
        attribute maxPower : Power = 5000.0;
        attribute currentPower : Power;
        attribute airflow : AirflowRate;
        attribute isHeating : Boolean = false;
        attribute isCooling : Boolean = false;
        
        action def regulateTemperature :> Action {
            in command : ControlCommand;
            out setpoint : TemperatureCelsius;
        }
        perform regulateTemperature when cmdIn.command;
    }

    part def HumidityController {
        in port cmdIn : CommandInPort;
        attribute currentSetpoint : HumidityPercent;
        attribute isHumidifying : Boolean = false;
        attribute isDehumidifying : Boolean = false;
        attribute maxRate : Real = 0.5;
        
        action def regulateHumidity :> Action {
            in command : ControlCommand;
            out setpoint : HumidityPercent;
        }
        perform regulateHumidity when cmdIn.command;
    }

    part def PressureController {
        in port cmdIn : CommandInPort;
        attribute currentSetpoint : PressurePascal;
        attribute roomAPressure : PressurePascal;
        attribute roomBPressure : PressurePascal;
        attribute differential : PressurePascal;
        
        action def regulatePressure :> Action {
            in command : ControlCommand;
            out setpoint : PressurePascal;
        }
        perform regulatePressure when cmdIn.command;
    }

    part def EnvironmentalControllerSuite {
        in port hvacCmd : CommandInPort;
        in port humCmd : CommandInPort;
        in port presCmd : CommandInPort;
        
        part hvac : HVACSystem {
            port cmdIn = hvacCmd;
        }
        part humidityCtrl : HumidityController {
            port cmdIn = humCmd;
        }
        part pressureCtrl : PressureController {
            port cmdIn = presCmd;
        }
    }

    // ===== Experiment Manager =====
    part def ExperimentManager {
        port profileOut : ProfilePort;
        attribute scheduledExperiments : ExperimentProfile[0..*];
        attribute activeExperiment : ExperimentProfile;
        attribute isExperimentActive : Boolean = false;
        
        action def scheduleExperiment :> Action {
            in profile : ExperimentProfile;
            out scheduled : Boolean;
        }
        
        action def prepareLab :> Action {
            in profile : ExperimentProfile;
            out ready : Boolean;
        }
        
        action def validateConditions :> Action {
            in profile : ExperimentProfile;
            in temp : TemperatureCelsius;
            in hum : HumidityPercent;
            in pres : PressurePascal;
            out valid : Boolean;
        }
        
        action def lockConditions :> Action {
            in profile : ExperimentProfile;
            out locked : Boolean;
        }
        
        action def endExperiment :> Action {
            out ended : Boolean;
        }
    }

    // ===== User Interface =====
    part def UserInterface {
        in port statusIn : StatusPort;
        in port alertIn : AlertOutPort;
        out port profileOut : ProfilePort;
        attribute displayState : String;
        attribute alertQueue : Alert[0..*];
        
        action def displayStatus :> Action {
            in status : String;
            in temp : TemperatureCelsius;
            in hum : HumidityPercent;
            in pres : PressurePascal;
        }
        
        action def receiveAlert :> Action {
            in alert : Alert;
        }
        
        action def adjustSettings :> Action {
            out profile : ExperimentProfile;
        }
        
        perform displayStatus every 1.0;
        perform receiveAlert when alertIn.alert;
    }

    // ===== Alarm System =====
    part def AlarmSystem {
        in port alertIn : AlertOutPort;
        attribute isAudibleAlarmActive : Boolean = false;
        attribute isVisualAlarmActive : Boolean = false;
        attribute emergencyProtocolActive : Boolean = false;
        
        action def triggerAlarm :> Action {
            in alert : Alert;
            out audible : Boolean;
            out visual : Boolean;
        }
        
        action def activateEmergencyProtocol :> Action {
            out activated : Boolean;
        }
        
        perform triggerAlarm when alertIn.alert;
    }

    // ===== System State Machine =====
    state def SystemStateMachine {
        entry action initSystem {
            // Initialize all subsystems
        }
        
        state idle {
            entry action enterIdle {
                // System waiting for experiment profile or manual command
            }
        }
        
        state conditioning {
            entry action enterConditioning {
                // Actively adjusting environmental controllers to reach setpoints
            }
        }
        
        state optimal {
            entry action enterOptimal {
                // Conditions within tolerance, holding steady
            }
        }
        
        state suboptimal {
            entry action enterSuboptimal {
                // Conditions drifting, attempting correction
            }
        }
        
        state critical {
            entry action enterCritical {
                // Significant deviation, trigger alarms and emergency protocols
            }
        }
        
        transition t_idle_to_conditioning
            from idle to conditioning
            when (activeProfile != null);
        
        transition t_conditioning_to_optimal
            from conditioning to optimal
            when (abs(currentTemp - activeProfile.targetTemp) <= tempTolerance
                and abs(currentHumidity - activeProfile.targetHumidity) <= humTolerance
                and abs(currentPressure - activeProfile.targetPressure) <= presTolerance);
        
        transition t_optimal_to_suboptimal
            from optimal to suboptimal
            when (abs(currentTemp - activeProfile.targetTemp) > tempTolerance
                or abs(currentHumidity - activeProfile.targetHumidity) > humTolerance
                or abs(currentPressure - activeProfile.targetPressure) > presTolerance);
        
        transition t_suboptimal_to_optimal
            from suboptimal to optimal
            when (abs(currentTemp - activeProfile.targetTemp) <= tempTolerance
                and abs(currentHumidity - activeProfile.targetHumidity) <= humTolerance
                and abs(currentPressure - activeProfile.targetPressure) <= presTolerance);
        
        transition t_suboptimal_to_critical
            from suboptimal to critical
            when (currentCO2 > co2Limit
                or currentVOC > vocLimit
                or currentParticulates > particulateLimit
                or abs(currentTemp - activeProfile.targetTemp) > tempTolerance * 5.0);
        
        transition t_optimal_to_critical
            from optimal to critical
            when (currentCO2 > co2Limit
                or currentVOC > vocLimit
                or currentParticulates > particulateLimit);
        
        transition t_critical_to_conditioning
            from critical to conditioning
            when (currentCO2 <= co2Limit
                and currentVOC <= vocLimit
                and currentParticulates <= particulateLimit);
        
        transition t_optimal_to_idle
            from optimal to idle
            when (activeProfile == null);
    }

    // ===== Top-Level System =====
    part def SmartLabEnvironmentalControlSystem {
        attribute systemName : String = "SmartLabECS";
        attribute facilityId : String = "LAB-001";
        attribute isOperational : Boolean = true;
        
        port sensorTempOut : SensorOutPort;
        port sensorHumOut : SensorOutPort;
        port sensorAqOut : SensorOutPort;
        port sensorPresOut : SensorOutPort;
        port processorCmdOut : CommandOutPort;
        port processorAlertOut : AlertOutPort;
        port processorStatusOut : StatusPort;
        port uiProfileOut : ProfilePort;
        
        part sensorSuite : SensorSuite {
            port tempOut = sensorTempOut;
            port humOut = sensorHumOut;
            port aqOut = sensorAqOut;
            port presOut = sensorPresOut;
        }
        
        part dataProcessor : DataProcessor {
            port tempIn = sensorTempOut;
            port humIn = sensorHumOut;
            port aqIn = sensorAqOut;
            port presIn = sensorPresOut;
            port cmdOut = processorCmdOut;
            port alertOut = processorAlertOut;
            port statusOut = processorStatusOut;
        }
        
        part controllerSuite : EnvironmentalControllerSuite {
            port hvacCmd = processorCmdOut;
            port humCmd = processorCmdOut;
            port presCmd = processorCmdOut;
        }
        
        part experimentManager : ExperimentManager {
            port profileOut = uiProfileOut;
        }
        
        part userInterface : UserInterface {
            port statusIn = processorStatusOut;
            port alertIn = processorAlertOut;
            port profileOut = uiProfileOut;
        }
        
        part alarmSystem : AlarmSystem {
            port alertIn = processorAlertOut;
        }
        
        // Internal connections
        connect sensorSuite.tempOut to dataProcessor.tempIn;
        connect sensorSuite.humOut to dataProcessor.humIn;
        connect sensorSuite.aqOut to dataProcessor.aqIn;
        connect sensorSuite.presOut to dataProcessor.presIn;
        connect dataProcessor.cmdOut to controllerSuite.hvacCmd;
        connect dataProcessor.cmdOut to controllerSuite.humCmd;
        connect dataProcessor.cmdOut to controllerSuite.presCmd;
        connect dataProcessor.alertOut to alarmSystem.alertIn;
        connect dataProcessor.alertOut to userInterface.alertIn;
        connect dataProcessor.statusOut to userInterface.statusIn;
        connect experimentManager.profileOut to dataProcessor.profileIn;
        connect userInterface.profileOut to experimentManager.profileOut;
        
        // State machine
        exhibit state behavior : SystemStateMachine;
    }

    // ===== Requirements =====
    requirement def EnvironmentalMonitoringRequirement {
        doc "The system shall continuously monitor temperature, humidity, air pressure, and air quality in the laboratory."
        attribute samplingInterval : Real = 1.0;
        subject : SmartLabEnvironmentalControlSystem;
        require sensorSuite.tempSensor.samplingRateHz >= 1.0;
        require sensorSuite.humSensor.samplingRateHz >= 0.5;
        require sensorSuite.presSensor.samplingRateHz >= 1.0;
        require sensorSuite.aqSensor.samplingRateHz >= 0.2;
    }

    requirement def TemperatureControlRequirement {
        doc "The system shall maintain laboratory temperature within ±0.5°C of the experiment-defined setpoint."
        subject : SmartLabEnvironmentalControlSystem;
        require abs(dataProcessor.currentTemp - dataProcessor.activeProfile.targetTemp) <= dataProcessor.tempTolerance;
    }

    requirement def HumidityControlRequirement {
        doc "The system shall maintain laboratory humidity within ±2% of the experiment-defined setpoint."
        subject : SmartLabEnvironmentalControlSystem;
        require abs(dataProcessor.currentHumidity - dataProcessor.activeProfile.targetHumidity) <= dataProcessor.humTolerance;
    }

    requirement def PressureDifferentialRequirement {
        doc "The system shall maintain pressure differentials between rooms to prevent cross-contamination."
        subject : SmartLabEnvironmentalControlSystem;
        require abs(dataProcessor.currentPressure - dataProcessor.activeProfile.targetPressure) <= dataProcessor.presTolerance;
    }

    requirement def AirQualityRequirement {
        doc "The system shall ensure CO2 remains below 1000 ppm, VOCs below 500 ppb, and particulates below 10000 particles/m³."
        subject : SmartLabEnvironmentalControlSystem;
        require dataProcessor.currentCO2 <= dataProcessor.co2Limit;
        require dataProcessor.currentVOC <= dataProcessor.vocLimit;
        require dataProcessor.currentParticulates <= dataProcessor.particulateLimit;
    }

    requirement def DataLoggingRequirement {
        doc "The system shall log all sensor readings at least every 60 seconds for historical records."
        subject : SmartLabEnvironmentalControlSystem;
        require dataProcessor.logData.interval <= 60.0;
    }

    requirement def AnomalyDetectionRequirement {
        doc "The system shall detect and flag anomalies or deviations from optimal conditions."
        subject : SmartLabEnvironmentalControlSystem;
        require dataProcessor.detectAnomaly.isAnomaly == true
            when (abs(dataProcessor.currentTemp - dataProcessor.activeProfile.targetTemp) > dataProcessor.tempTolerance);
    }

    requirement def AlarmRequirement {
        doc "The system shall trigger audible and visual alarms and activate emergency protocols upon entering a critical state."
        subject : SmartLabEnvironmentalControlSystem;
        require alarmSystem.isAudibleAlarmActive == true when (dataProcessor.systemState == "critical");
        require alarmSystem.isVisualAlarmActive == true when (dataProcessor.systemState == "critical");
        require alarmSystem.emergencyProtocolActive == true when (dataProcessor.systemState == "critical");
    }

    requirement def ExperimentManagementRequirement {
        doc "The system shall allow researchers to schedule experiments, define environmental conditions, prepare the lab, validate conditions, and lock them for the experiment duration."
        subject : SmartLabEnvironmentalControlSystem;
        require experimentManager.scheduleExperiment.scheduled == true;
        require experimentManager.prepareLab.ready == true;
        require experimentManager.validateConditions.valid == true;
        require experimentManager.lockConditions.locked == true;
    }

    requirement def UserInterfaceRequirement {
        doc "The system shall provide a user interface for personnel to monitor status, adjust settings, and receive alerts."
        subject : SmartLabEnvironmentalControlSystem;
        require userInterface.displayStatus.status != null;
        require userInterface.receiveAlert.alert != null;
    }

    requirement def StateTransitionRequirement {
        doc "The system shall operate through idle, conditioning, optimal, suboptimal, and critical states with defined transitions."
        subject : SmartLabEnvironmentalControlSystem;
        require dataProcessor.systemState in {"idle", "conditioning", "optimal", "suboptimal", "critical"};
    }

    requirement def SystemRequirements {
        doc "Top-level requirements for the Smart Laboratory Environmental Control System."
        subject : SmartLabEnvironmentalControlSystem;
        satisfy EnvironmentalMonitoringRequirement;
        satisfy TemperatureControlRequirement;
        satisfy HumidityControlRequirement;
        satisfy PressureDifferentialRequirement;
        satisfy AirQualityRequirement;
        satisfy DataLoggingRequirement;
        satisfy AnomalyDetectionRequirement;
        satisfy AlarmRequirement;
        satisfy ExperimentManagementRequirement;
        satisfy UserInterfaceRequirement;
        satisfy StateTransitionRequirement;
    }
}
