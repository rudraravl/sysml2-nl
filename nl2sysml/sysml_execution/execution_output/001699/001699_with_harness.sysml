package 'Ecobee Smart Thermostat System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def HVACMode :> String;
    attribute def OccupancyStatus :> String;
    attribute def ScheduleProfile :> String;

    attribute def TemperatureSetpoint :> ISQ::TemperatureValue;
    attribute def HumidityPercentage :> Real;
    attribute def PowerConsumption :> ISQ::PowerValue;

    item def TemperatureReading {
        attribute value :> ISQ::TemperatureValue;
        attribute sensorLocation : String;
        attribute timestamp : String;
    }

    item def OccupancyReading {
        attribute occupied : Boolean;
        attribute motionDetected : Boolean;
        attribute location : String;
    }

    item def WeatherInfo {
        attribute outdoorTemperature :> ISQ::TemperatureValue;
        attribute humidity :> HumidityPercentage;
        attribute forecast : String;
    }

    item def HVACCommand {
        attribute mode : HVACMode;
        attribute targetTemperature :> TemperatureSetpoint;
        attribute fanSpeed : Real;
    }

    item def EnergyReport {
        attribute totalConsumption :> ISQ::EnergyValue;
        attribute runtime :> ISQ::TimeValue;
        attribute estimatedCost : Real;
    }

    port def TemperatureSensorPort {
        out tempReading : TemperatureReading;
    }

    port def OccupancySensorPort {
        out occupancyData : OccupancyReading;
    }

    port def HVACControlPort {
        in command : HVACCommand;
        out status : String;
    }

    port def NetworkInterfacePort {
        in weatherData : WeatherInfo;
        in userInput : String;
        out energyReport : EnergyReport;
        out systemStatus : String;
    }

    part def MainTemperatureSensor {
        port sensorOutput : TemperatureSensorPort;
        attribute accuracy :> ISQ::TemperatureValue;
        attribute calibrationOffset :> ISQ::TemperatureValue;
    }

    part def RemoteRoomSensor {
        port tempOutput : TemperatureSensorPort;
        port occupancyOutput : OccupancySensorPort;
        attribute roomIdentifier : String;
        attribute batteryLevel : Real;
        attribute wirelessSignalStrength : Real;
    }

    part def MotionDetector {
        port motionOutput : OccupancySensorPort;
        attribute detectionRadius :> ISQ::LengthValue;
        attribute sensitivity : Real;
    }

    part def HVACEquipment {
        port controlInput : HVACControlPort;
        attribute heatingCapacity :> ISQ::PowerValue;
        attribute coolingCapacity :> ISQ::PowerValue;
        attribute systemEfficiency : Real;
        attribute currentPowerDraw :> ISQ::PowerValue;
    }

    part def WiFiCommunicationModule {
        port networkInterface : NetworkInterfacePort;
        attribute connectionStatus : Boolean;
        attribute signalQuality : Real;
        attribute cloudServerAddress : String;
    }

    part def UserInterfaceDisplay {
        attribute displaySize :> ISQ::LengthValue;
        attribute touchCapable : Boolean;
        attribute displayTemperature :> ISQ::TemperatureValue;
        attribute displaySetpoint :> TemperatureSetpoint;
        attribute displayMode : HVACMode;
        attribute displayOccupancy : OccupancyStatus;
    }

    action def MeasureTemperature {
        in sensorIdentifier : String;
        in calibrationOffset :> ISQ::TemperatureValue;
        out measuredTemperature :> ISQ::TemperatureValue;
        out readingTimestamp : String;
    }

    action def DetectOccupancy {
        in sensitivityLevel : Real;
        in detectionRadius :> ISQ::LengthValue;
        out occupancyDetected : Boolean;
        out confidenceLevel : Real;
    }

    action def ComputeAverageTemperature {
        in temperatureReadings : TemperatureReading[*];
        in weightingFactors : Real[*];
        out averageTemperature :> ISQ::TemperatureValue;
    }

    action def DetermineTargetTemperature {
        in currentTemperature :> ISQ::TemperatureValue;
        in userSetpoint :> TemperatureSetpoint;
        in occupancyState : OccupancyStatus;
        in currentTime : String;
        in scheduleProfile : ScheduleProfile;
        in weatherForecast : WeatherInfo;
        out targetTemperature :> TemperatureSetpoint;
        out adjustmentReason : String;
    }

    action def SelectHVACMode {
        in currentTemperature :> ISQ::TemperatureValue;
        in targetTemperature :> TemperatureSetpoint;
        in outdoorTemperature :> ISQ::TemperatureValue;
        in temperatureDelta :> ISQ::TemperatureValue;
        out selectedMode : HVACMode;
        out fanSpeedSetting : Real;
    }

    action def OptimizeEnergySchedule {
        in historicalOccupancy : OccupancyReading[*];
        in weatherPrediction : WeatherInfo;
        in electricityPricing : Real[*];
        in userPreferences : String;
        out optimizedSchedule : ScheduleProfile;
        out projectedSavings : Real;
    }

    action def MonitorIndoorAirQuality {
        in currentHumidity :> HumidityPercentage;
        in ventilationStatus : Boolean;
        in filterCondition : Real;
        out airQualityScore : Real;
        out maintenanceAlerts : String;
    }

    action def TrackEnergyUsage {
        in hvacRuntime :> ISQ::TimeValue;
        in powerConsumption :> ISQ::PowerValue;
        in operatingMode : HVACMode;
        out totalEnergy :> ISQ::EnergyValue;
        out costEstimate : Real;
    }

    attribute def SystemActivation;
    attribute def FanOnlyRequest;
    attribute def FanOffRequest;
    attribute def EcoModeActivation;
    attribute def EcoModeDeactivation;
    attribute def OccupancyResumed;

    state def ThermostatControlStates {
        entry; then standby;

        state standby {
            entry assign activeMode := "Standby";
        }

        state activeMonitoring {
            entry assign activeMode := "Monitoring";
        }

        state heatingMode {
            entry assign activeMode := "Heating";
        }

        state coolingMode {
            entry assign activeMode := "Cooling";
        }

        state fanCirculation {
            entry assign activeMode := "Fan Only";
        }

        state ecoMode {
            entry assign activeMode := "Eco";
        }

        state smartAwayMode {
            entry assign activeMode := "Smart Away";
        }

        transition standby_to_monitoring
            first standby
            accept evt : SystemActivation
            then activeMonitoring;

        transition monitoring_to_heating
            first activeMonitoring
            if currentRoomTemp < targetSetpoint
            then heatingMode;

        transition monitoring_to_cooling
            first activeMonitoring
            if currentRoomTemp > targetSetpoint
            then coolingMode;

        transition heating_to_monitoring
            first heatingMode
            if currentRoomTemp >= targetSetpoint
            then activeMonitoring;

        transition cooling_to_monitoring
            first coolingMode
            if currentRoomTemp <= targetSetpoint
            then activeMonitoring;

        transition monitoring_to_fan
            first activeMonitoring
            accept evt : FanOnlyRequest
            then fanCirculation;

        transition fan_to_monitoring
            first fanCirculation
            accept evt : FanOffRequest
            then activeMonitoring;

        transition monitoring_to_eco
            first activeMonitoring
            accept evt : EcoModeActivation
            then ecoMode;

        transition eco_to_monitoring
            first ecoMode
            accept evt : EcoModeDeactivation
            then activeMonitoring;

        transition monitoring_to_smartAway
            first activeMonitoring
            if unoccupiedDuration > 10800.0
            then smartAwayMode;

        transition smartAway_to_monitoring
            first smartAwayMode
            accept evt : OccupancyResumed
            then activeMonitoring;

        attribute activeMode : HVACMode;
        attribute currentRoomTemp :> ISQ::TemperatureValue;
        attribute targetSetpoint :> TemperatureSetpoint;
        attribute unoccupiedDuration :> ISQ::TimeValue;
    }

    action def ManageHomeClimate {
        first start;
        then merge operationLoop;

        action collectSensorData {
            action readMainSensor : MeasureTemperature {
                in sensorIdentifier = "main_unit";
                out measuredTemperature;
                out readingTimestamp;
            }

            action readRemoteSensors : MeasureTemperature[*] {
                out measuredTemperature;
                out readingTimestamp;
            }

            action detectMotion : DetectOccupancy {
                out occupancyDetected;
                out confidenceLevel;
            }
        }

        then action aggregateData {
            action calculateAverage : ComputeAverageTemperature {
                out averageTemperature;
            }

            action assessOccupancy {
                out currentOccupancyState : OccupancyStatus;
            }
        }

        then action determineTarget : DetermineTargetTemperature {
            out targetTemperature;
            out adjustmentReason;
        }

        then action chooseMode : SelectHVACMode {
            out selectedMode;
            out fanSpeedSetting;
        }

        then action issueHVACCommand;

        then action optimizeSchedule : OptimizeEnergySchedule {
            out optimizedSchedule;
            out projectedSavings;
        }

        then action monitorAirQuality : MonitorIndoorAirQuality {
            out airQualityScore;
            out maintenanceAlerts;
        }

        then action recordEnergy : TrackEnergyUsage {
            out totalEnergy;
            out costEstimate;
        }

        then operationLoop;
    }

    requirement def TemperatureAccuracyRequirement {
        doc /* The system shall maintain indoor temperature within tolerance of the user-defined setpoint during occupied periods. */
    }

    requirement def EnergyOptimizationRequirement {
        doc /* The system shall minimize energy consumption while maintaining user comfort through intelligent scheduling and predictive algorithms. */
    }

    requirement def RemoteAccessRequirement {
        doc /* The system shall provide secure remote monitoring and control via internet-connected devices. */
    }

    requirement def MultiZoneCapabilityRequirement {
        doc /* The system shall support distributed temperature sensing and control across multiple rooms. */
    }

    requirement def SystemReliabilityRequirement {
        doc /* The system shall operate reliably under normal residential conditions. */
    }

    requirement <'ECOBEE-SYS-REQ-001'> smartThermostatSystemRequirements {
        doc /* The Ecobee smart thermostat system shall provide intelligent, energy-efficient climate control 
               with multi-zone capability, remote access, and adaptive learning to optimize comfort and minimize 
               energy consumption in residential environments. */

        subject ecobeeSmartThermostat;

        require tempAccuracyReq : TemperatureAccuracyRequirement;
        require energyOptimizationReq : EnergyOptimizationRequirement;
        require remoteAccessReq : RemoteAccessRequirement;
        require multiZoneReq : MultiZoneCapabilityRequirement;
        require reliabilityReq : SystemReliabilityRequirement;
    }

    part def EcobeeThermostat {
        part mainControlUnit {
            part primaryTempSensor : MainTemperatureSensor {
                port sensorOutput;
            }

            part builtInMotionSensor : MotionDetector {
                port motionOutput;
            }

            part touchscreenDisplay : UserInterfaceDisplay;

            part controlProcessor {
                attribute processorSpeed : Real;
                attribute memoryCapacity : Real;
                attribute storageCapacity : Real;
            }

            part wirelessModule : WiFiCommunicationModule {
                port networkInterface;
            }

            part powerManagement {
                attribute inputVoltage :> ISQ::ElectricPotentialValue;
                attribute powerConsumption :> ISQ::PowerValue;
                attribute backupBatteryCapacity :> ISQ::EnergyValue;
            }
        }

        part remoteSensorArray : RemoteRoomSensor[4] {
            port tempOutput;
            port occupancyOutput;
        }

        part hvacInterface : HVACEquipment {
            port controlInput;
        }

        perform action climateManagement : ManageHomeClimate;

        exhibit state thermostatStates : ThermostatControlStates;
    }

    part ecobeeSmartThermostat : EcobeeThermostat {
        doc /* 
            The Ecobee smart thermostat system provides intelligent home climate management by continuously 
            monitoring temperature and occupancy across multiple zones, learning household patterns, and 
            automatically optimizing heating and cooling schedules to maximize comfort while minimizing 
            energy consumption.

            The system integrates real-time weather data, electricity pricing information, and distributed 
            sensor readings to make predictive decisions about climate control. It pre-conditions living 
            spaces based on anticipated occupancy and weather changes, reducing energy waste during 
            unoccupied periods while ensuring comfort when residents are present.

            Remote access capabilities enable users to monitor and adjust their home climate from anywhere 
            using mobile devices or voice commands. The system provides detailed energy usage reports and 
            personalized recommendations to help users understand and reduce their environmental impact.

            Advanced features include smart home integration, geofencing for automatic home/away transitions, 
            humidity control, air quality monitoring, and maintenance reminders to ensure optimal system 
            performance throughout the year.
        */

        satisfy smartThermostatSystemRequirements;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Ecobee Smart Thermostat System'::*;

    part testSubject : EcobeeThermostat {
        exhibit state thermostatStates : ThermostatControlStates;
    }

    action orchestrator {
        action readMainSensorProbe : MeasureTemperature {
            in sensorIdentifier = "";
        }
        first readMainSensorProbe;
    }
}
