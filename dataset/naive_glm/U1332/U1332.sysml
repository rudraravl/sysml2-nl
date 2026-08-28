package EcobeeThermostatSystem {
    import ScalarValues::*;

    // ===== Units =====
    unit degC;
    unit percent;
    unit kW;
    unit kWh;
    unit hour;
    unit usdPerKWh;

    // ===== Value Types =====
    value def TemperatureValue :> Real { unit degC; }
    value def HumidityValue :> Real { unit percent; }
    value def PowerValue :> Real { unit kW; }
    value def EnergyValue :> Real { unit kWh; }
    value def DurationValue :> Real { unit hour; }
    value def PriceValue :> Real { unit usdPerKWh; }

    // ===== Item Types =====
    item def SensorData {
        attribute sensorId : String;
        attribute temperature : TemperatureValue;
        attribute occupied : Boolean;
        attribute timestamp : DurationValue;
    }

    item def WeatherForecast {
        attribute outdoorTemp : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute condition : String;
    }

    item def ElectricityPrice {
        attribute price : PriceValue;
        attribute timestamp : DurationValue;
    }

    item def HVACCommand {
        attribute heatOn : Boolean;
        attribute coolOn : Boolean;
        attribute fanOn : Boolean;
    }

    item def EnergyReport {
        attribute totalRuntime : DurationValue;
        attribute energyUsed : EnergyValue;
        attribute estimatedCost : Real;
        attribute summary : String;
    }

    item def MaintenanceAlert {
        attribute alertType : String;
        attribute message : String;
        attribute runtimeThreshold : DurationValue;
    }

    // ===== Port Definitions =====
    port def SensorDataPort {
        out sensorData : SensorData;
    }

    port def HVACControlPort {
        out command : HVACCommand;
    }

    port def WiFiPort {
        in weather : WeatherForecast;
        in price : ElectricityPrice;
        in remoteCommand : String;
        out status : String;
    }

    port def DisplayPort {
        out content : String;
        in touchInput : String;
    }

    // ===== Component Part Definitions =====
    part def RemoteSensor {
        port sensorOut : SensorDataPort;
        attribute sensorId : String;
        attribute batteryLevel : Real;
        attribute measuredTemp : TemperatureValue;
        attribute occupied : Boolean;

        action def measureTemperature {
            out temp : TemperatureValue;
        }

        action def detectOccupancy {
            out occ : Boolean;
        }

        action def transmitData {
            out data : SensorData;
        }

        perform measureTemperature;
        perform detectOccupancy;
        perform transmitData;
    }

    part def TouchscreenDisplay {
        port displayIf : DisplayPort;

        action def renderUI {
            in content : String;
        }

        action def handleTouch {
            out input : String;
        }
    }

    part def PrimaryTempSensor {
        port tempOut : SensorDataPort;
        attribute temperature : TemperatureValue;

        action def measure {
            out temp : TemperatureValue;
        }
    }

    part def MotionDetector {
        port motionOut : SensorDataPort;
        attribute motionDetected : Boolean;

        action def detectMotion {
            out motion : Boolean;
        }
    }

    part def WiFiModule {
        port wifiIf : WiFiPort;
        attribute connected : Boolean;

        action def fetchWeather {
            out forecast : WeatherForecast;
        }

        action def fetchPrice {
            out price : ElectricityPrice;
        }

        action def receiveRemoteCommand {
            out cmd : String;
        }

        action def sendStatus {
            in statusText : String;
        }
    }

    part def Furnace {
        port control : HVACControlPort;
        attribute running : Boolean;
        attribute runtime : DurationValue;
    }

    part def AirConditioner {
        port control : HVACControlPort;
        attribute running : Boolean;
        attribute runtime : DurationValue;
    }

    part def Fan {
        port control : HVACControlPort;
        attribute running : Boolean;
        attribute runtime : DurationValue;
    }

    part def HVACSystem {
        part furnace : Furnace;
        part ac : AirConditioner;
        part fan : Fan;
    }

    // ===== Thermostat Unit =====
    part def ThermostatUnit {
        port sensorIn : SensorDataPort;
        port hvacOut : HVACControlPort;
        port wifiPort : WiFiPort;
        port displayPort : DisplayPort;

        part display : TouchscreenDisplay;
        part primarySensor : PrimaryTempSensor;
        part motion : MotionDetector;
        part wifi : WiFiModule;

        attribute setpoint : TemperatureValue;
        attribute currentAvgTemp : TemperatureValue;
        attribute indoorHumidity : HumidityValue;
        attribute occupancyPattern : String;
        attribute schedule : String;
        attribute totalRuntime : DurationValue;
        attribute energyUsed : EnergyValue;
        attribute filterNeedsChange : Boolean;
        attribute noOccupancyDuration : DurationValue;
        attribute occupancyDetected : Boolean;
        attribute ecoModeEnabled : Boolean;
        attribute fanRequested : Boolean;
        attribute filterServiceInterval : DurationValue;

        action def calculateAverageTemp {
            in readings : SensorData[0..*];
            out avg : TemperatureValue;
        }

        action def decideHVAC {
            in avgTemp : TemperatureValue;
            in setpointVal : TemperatureValue;
            out cmd : HVACCommand;
        }

        action def learnOccupancy {
            in data : SensorData[0..*];
            out pattern : String;
        }

        action def optimizeSchedule {
            in pattern : String;
            in weather : WeatherForecast;
            in price : ElectricityPrice;
            out sched : String;
        }

        action def generateEnergyReport {
            in runtime : DurationValue;
            in price : PriceValue;
            out report : EnergyReport;
        }

        action def checkMaintenance {
            in runtime : DurationValue;
            in threshold : DurationValue;
            out alert : MaintenanceAlert;
        }

        action def activateHeating;
        action def deactivateHeating;
        action def activateCooling;
        action def deactivateCooling;
        action def activateFan;
        action def deactivateFan;
        action def enterEcoMode;
        action def exitEcoMode;
        action def enterSmartAway;
        action def exitSmartAway;

        state def ThermostatStates {
            entry; then Off;

            state Off;

            state Heating {
                entry perform activateHeating;
                exit perform deactivateHeating;
            }

            state Cooling {
                entry perform activateCooling;
                exit perform deactivateCooling;
            }

            state FanOnly {
                entry perform activateFan;
                exit perform deactivateFan;
            }

            state Eco {
                entry perform enterEcoMode;
                exit perform exitEcoMode;
            }

            state SmartAway {
                entry perform enterSmartAway;
                exit perform exitSmartAway;
            }

            transition off_to_heating
                first Off
                then Heating
                if currentAvgTemp < setpoint - 1.0;

            transition heating_to_off
                first Heating
                then Off
                if currentAvgTemp >= setpoint;

            transition off_to_cooling
                first Off
                then Cooling
                if currentAvgTemp > setpoint + 1.0;

            transition cooling_to_off
                first Cooling
                then Off
                if currentAvgTemp <= setpoint;

            transition off_to_fanonly
                first Off
                then FanOnly
                if fanRequested;

            transition fanonly_to_off
                first FanOnly
                then Off
                if !fanRequested;

            transition off_to_eco
                first Off
                then Eco
                if ecoModeEnabled;

            transition eco_to_off
                first Eco
                then Off
                if !ecoModeEnabled;

            transition off_to_smartaway
                first Off
                then SmartAway
                if noOccupancyDuration > 2.0;

            transition smartaway_to_off
                first SmartAway
                then Off
                if occupancyDetected;

            transition heating_to_smartaway
                first Heating
                then SmartAway
                if noOccupancyDuration > 2.0;

            transition cooling_to_smartaway
                first Cooling
                then SmartAway
                if noOccupancyDuration > 2.0;

            transition heating_to_eco
                first Heating
                then Eco
                if ecoModeEnabled;

            transition cooling_to_eco
                first Cooling
                then Eco
                if ecoModeEnabled;
        }

        exhibit ThermostatStates;
    }

    // ===== System Assembly =====
    part def EcobeeSystem {
        part thermostat : ThermostatUnit;
        part sensors : RemoteSensor[1..*];
        part hvac : HVACSystem;

        connection sensorLinks connect sensors.sensorOut to thermostat.sensorIn;
        connection hvacFurnaceLink connect thermostat.hvacOut to hvac.furnace.control;
        connection hvacACLink connect thermostat.hvacOut to hvac.ac.control;
        connection hvacFanLink connect thermostat.hvacOut to hvac.fan.control;

        // Requirement usages
        requirement climateControlReq : ClimateControlRequirement;
        requirement energyEfficiencyReq : EnergyEfficiencyRequirement;
        requirement remoteSensingReq : RemoteSensingRequirement;
        requirement maintenanceAlertReq : MaintenanceAlertRequirement;
        requirement remoteControlReq : RemoteControlRequirement;
        requirement weatherAwareReq : WeatherAwareRequirement;
        requirement humidityMonitoringReq : HumidityMonitoringRequirement;
        requirement energyReportingReq : EnergyReportingRequirement;
        requirement occupancyLearningReq : OccupancyLearningRequirement;

        satisfy climateControlReq by thermostat;
        satisfy energyEfficiencyReq by thermostat;
        satisfy remoteSensingReq by sensors;
        satisfy maintenanceAlertReq by thermostat;
        satisfy remoteControlReq by thermostat.wifi;
        satisfy weatherAwareReq by thermostat;
        satisfy humidityMonitoringReq by thermostat;
        satisfy energyReportingReq by thermostat;
        satisfy occupancyLearningReq by thermostat;
    }

    // ===== Requirement Definitions =====
    requirement def ClimateControlRequirement {
        subject system : EcobeeSystem;
        objective 'Maintain home temperature within setpoint +/- 1.0 degC using distributed sensor data';
    }

    requirement def EnergyEfficiencyRequirement {
        subject system : EcobeeSystem;
        objective 'Reduce energy usage by at least 20 percent via Smart Away mode and schedule optimization';
    }

    requirement def RemoteSensingRequirement {
        subject system : EcobeeSystem;
        objective 'Compute average temperature across occupied rooms using wireless remote sensors';
    }

    requirement def MaintenanceAlertRequirement {
        subject system : EcobeeSystem;
        objective 'Alert user when HVAC runtime exceeds air filter service interval';
    }

    requirement def RemoteControlRequirement {
        subject system : EcobeeSystem;
        objective 'Allow remote control and monitoring via mobile app over Wi-Fi';
    }

    requirement def WeatherAwareRequirement {
        subject system : EcobeeSystem;
        objective 'Incorporate weather forecasts into scheduling decisions';
    }

    requirement def HumidityMonitoringRequirement {
        subject system : EcobeeSystem;
        objective 'Monitor and report indoor humidity levels';
    }

    requirement def EnergyReportingRequirement {
        subject system : EcobeeSystem;
        objective 'Generate energy usage reports and cost estimates based on HVAC runtime and electricity pricing';
    }

    requirement def OccupancyLearningRequirement {
        subject system : EcobeeSystem;
        objective 'Learn household occupancy patterns and optimize schedule accordingly';
    }
}
