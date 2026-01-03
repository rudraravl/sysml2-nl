package 'Google Nest Smart Home System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    alias Temperature for ISQ::ThermodynamicTemperatureValue;
    alias Power for ISQ::PowerValue;
    alias Time for ISQ::TimeValue;
    alias Energy for ISQ::EnergyValue;

    attribute def TemperatureSetpoint :> Temperature;
    attribute def HumidityLevel :> Real;
    attribute def OccupancyState;
    
    enum def HVACModeKind {
        enum heat;
        enum cool;
        enum auto;
        enum off;
    }
    
    enum def FanSpeedKind {
        enum low;
        enum medium;
        enum high;
        enum auto;
    }

    item def ElectricalPower;
    item def ControlSignal;
    item def SensorData;
    item def NetworkData;
    item def TemperatureBelowSetpoint;
    item def TemperatureAtSetpoint;
    item def TemperatureAboveSetpoint;
    item def UnoccupiedExtendedPeriod;
    item def OccupancyResumed;
    item def AwayModeActivated;
    item def HomeModeActivated;

    port def PowerPort {
        in power : ElectricalPower;
    }

    port def TemperatureSensorPort {
        out currentTemperature : Temperature;
    }

    port def HumiditySensorPort {
        out currentHumidity : HumidityLevel;
    }

    port def OccupancySensorPort {
        out occupancyDetected : OccupancyState;
    }

    port def HVACControlPort {
        out mode : HVACModeKind;
        out fanSpeed : FanSpeedKind;
        out targetTemperature : TemperatureSetpoint;
    }

    port def UserInterfacePort {
        in userSetpoint : TemperatureSetpoint;
        in userMode : HVACModeKind;
        out displayTemperature : Temperature;
        out displaySetpoint : TemperatureSetpoint;
    }

    port def NetworkPort {
        in remoteSetpoint : TemperatureSetpoint;
        in remoteMode : HVACModeKind;
        out statusData : SensorData;
    }

    part def TemperatureSensor {
        port sensorOutput : TemperatureSensorPort;
        attribute accuracy : Temperature = 0.5[K];
        attribute samplingRate : FrequencyValue = 1.0[Hz];
        perform action measureTemperature : MeasureTemperature;
    }

    part def HumiditySensor {
        port sensorOutput : HumiditySensorPort;
        attribute accuracy : HumidityLevel = 0.03;
        perform action measureHumidity : MeasureHumidity;
    }

    part def OccupancySensor {
        port sensorOutput : OccupancySensorPort;
        attribute detectionRange : LengthValue = 6.0[m];
        attribute detectionAngle : Real = 120.0;
        perform action detectOccupancy : DetectOccupancy;
    }

    part def TouchDisplay {
        port userInterface : UserInterfacePort;
        attribute screenDiameter : LengthValue = 8.4[cm];
        attribute resolution : String = "480x480";
    }

    part def WiFiModule {
        port networkInterface : NetworkPort;
        attribute protocol : String = "802.11ac";
        attribute frequency : FrequencyValue = 2.4[Hz];
    }

    part def ControlProcessor {
        port powerInput : PowerPort;
        port tempInput : TemperatureSensorPort;
        port humidityInput : HumiditySensorPort;
        port occupancyInput : OccupancySensorPort;
        port hvacControl : HVACControlPort;
        port userInterface : UserInterfacePort;
        port networkInterface : NetworkPort;

        attribute targetTemperature : TemperatureSetpoint = 294.15[K];
        attribute currentMode : HVACModeKind = HVACModeKind::auto;
        attribute learningEnabled : Boolean = true;
        attribute ecoModeEnabled : Boolean = false;
        attribute scheduleActive : Boolean = true;

        perform action manageClimate : ManageClimate;
        perform stateMachine : ThermostatOperatingMode;
    }

    part def HVACSystem {
        port controlInput : HVACControlPort;
        port powerInput : PowerPort;

        part heatingUnit {
            attribute heatingCapacity : Power = 15000[W];
            attribute efficiency : Real = 0.95;
        }

        part coolingUnit {
            attribute coolingCapacity : Power = 12000[W];
            attribute efficiency : Real = 3.5;
        }

        part airHandler {
            attribute maxAirFlow : VolumeFlowRateValue = 1200[m^3/h];
            attribute fanPower : Power = 150[W];
        }

        perform action operateHVAC : OperateHVAC;
    }

    action def MeasureTemperature {
        out temperature : Temperature;
    }

    action def MeasureHumidity {
        out humidity : HumidityLevel;
    }

    action def DetectOccupancy {
        out occupied : OccupancyState;
    }

    action def ReadSensors {
        out currentTemp : Temperature;
        out currentHumidity : HumidityLevel;
        out occupied : OccupancyState;

        action readTemp : MeasureTemperature {
            out temperature;
        }
        then action readHumid : MeasureHumidity {
            out humidity;
        }
        then action readOccup : DetectOccupancy {
            out occupied;
        }
        then assign currentTemp := readTemp.temperature;
        then assign currentHumidity := readHumid.humidity;
        then assign occupied := readOccup.occupied;
    }

    action def DetermineTargetTemperature {
        in currentTemp : Temperature;
        in userSetpoint : TemperatureSetpoint;
        in occupied : OccupancyState;
        in ecoMode : Boolean;
        out targetTemp : TemperatureSetpoint;
    }

    action def CalculateHVACControl {
        in currentTemp : Temperature;
        in targetTemp : TemperatureSetpoint;
        in currentHumidity : HumidityLevel;
        out mode : HVACModeKind;
        out fanSpeed : FanSpeedKind;
        out setpoint : TemperatureSetpoint;
    }

    action def UpdateUserInterface {
        in currentTemp : Temperature;
        in targetTemp : TemperatureSetpoint;
        in mode : HVACModeKind;
    }

    action def LearnUserPreferences {
        in userAdjustments : TemperatureSetpoint[*];
        in occupancyPatterns : OccupancyState[*];
        in timeOfDay : Time[*];
        out optimizedSchedule : TemperatureSetpoint[*];
    }

    action def SyncWithCloud {
        in localData : SensorData;
        out remoteSettings : TemperatureSetpoint;
    }

    action def ManageClimate {
        in attribute userSetpoint : TemperatureSetpoint;
        in attribute learningEnabled : Boolean;
        in attribute ecoMode : Boolean;
        out attribute hvacMode : HVACModeKind;
        out attribute hvacSetpoint : TemperatureSetpoint;

        private attribute currentTemp : Temperature;
        private attribute currentHumidity : HumidityLevel;
        private attribute occupied : OccupancyState;
        private attribute targetTemp : TemperatureSetpoint;

        first start;
        then merge controlLoop;

        then action readSensors : ReadSensors {
            out currentTemp;
            out currentHumidity;
            out occupied;
        }

        then action determineTarget : DetermineTargetTemperature {
            in currentTemp = readSensors.currentTemp;
            in userSetpoint = userSetpoint;
            in occupied = readSensors.occupied;
            in ecoMode = ecoMode;
            out targetTemp;
        }

        then action calculateControl : CalculateHVACControl {
            in currentTemp = readSensors.currentTemp;
            in targetTemp = determineTarget.targetTemp;
            in currentHumidity = readSensors.currentHumidity;
            out mode;
            out fanSpeed;
            out setpoint;
        }

        then action sendControl {
            in mode = calculateControl.mode;
            in fanSpeed = calculateControl.fanSpeed;
            in setpoint = calculateControl.setpoint;
        }
        then assign hvacMode := calculateControl.mode;
        then assign hvacSetpoint := calculateControl.setpoint;

        then action updateUI : UpdateUserInterface {
            in currentTemp = readSensors.currentTemp;
            in targetTemp = determineTarget.targetTemp;
            in mode = calculateControl.mode;
        }

        then decide;
            if learningEnabled then learnPreferences;
            else controlLoop;

        action learnPreferences : LearnUserPreferences {
            in userAdjustments;
            in occupancyPatterns;
            in timeOfDay;
            out optimizedSchedule;
        }

        then controlLoop;
    }

    action def OperateHVAC {
        in mode : HVACModeKind;
        in targetTemp : TemperatureSetpoint;
        in fanSpeed : FanSpeedKind;
        out thermalOutput : Power;
    }

    state def ThermostatOperatingMode {
        entry; then idle;

        state idle {
            entry action monitorConditions;
        }

        transition idle_to_heating
            first idle
            accept TemperatureBelowSetpoint
            then heating;

        state heating {
            entry action activateHeating;
            do action maintainHeating;
            exit action deactivateHeating;
        }

        transition heating_to_idle
            first heating
            accept TemperatureAtSetpoint
            then idle;

        transition idle_to_cooling
            first idle
            accept TemperatureAboveSetpoint
            then cooling;

        state cooling {
            entry action activateCooling;
            do action maintainCooling;
            exit action deactivateCooling;
        }

        transition cooling_to_idle
            first cooling
            accept TemperatureAtSetpoint
            then idle;

        state ecoMode {
            entry action enableEcoSettings;
            do action minimizeEnergyUsage;
        }

        transition to_eco
            first idle
            accept UnoccupiedExtendedPeriod
            then ecoMode;

        transition from_eco
            first ecoMode
            accept OccupancyResumed
            then idle;

        state away {
            entry action setAwayTemperature;
        }

        transition to_away
            first idle
            accept AwayModeActivated
            then away;

        transition from_away
            first away
            accept HomeModeActivated
            then idle;
    }

    part nestThermostatSystem {
        attribute systemName : String = "Nest Learning Thermostat";
        attribute firmwareVersion : String = "6.0.1";
        attribute installationDate : String;

        part powerSupply {
            port powerOutput : PowerPort;
            attribute inputVoltage : Real = 24.0;
            attribute outputPower : Power = 5[W];
        }

        part thermostat {
            port powerInput : PowerPort;

            part tempSensor : TemperatureSensor {
                port sensorOutput;
            }

            part humiditySensor : HumiditySensor {
                port sensorOutput;
            }

            part occupancySensor : OccupancySensor {
                port sensorOutput;
            }

            part display : TouchDisplay {
                port userInterface;
            }

            part wifi : WiFiModule {
                port networkInterface;
            }

            part processor : ControlProcessor {
                port powerInput;
                port tempInput;
                port humidityInput;
                port occupancyInput;
                port hvacControl;
                port userInterface;
                port networkInterface;

                perform action climateControl : ManageClimate;
                perform modeStateMachine : ThermostatOperatingMode;
            }

            connection powerConnection
                connect powerInput to processor.powerInput;

            connection tempConnection
                connect tempSensor.sensorOutput to processor.tempInput;

            connection humidityConnection
                connect humiditySensor.sensorOutput to processor.humidityInput;

            connection occupancyConnection
                connect occupancySensor.sensorOutput to processor.occupancyInput;

            connection displayConnection
                connect processor.userInterface to display.userInterface;

            connection networkConnection
                connect processor.networkInterface to wifi.networkInterface;
        }

        part hvac : HVACSystem {
            port controlInput;
            port powerInput;

            perform action operate : OperateHVAC;
        }

        connection powerToThermostat
            connect powerSupply.powerOutput to thermostat.powerInput;

        connection powerToHVAC
            connect powerSupply.powerOutput to hvac.powerInput;

        connection hvacControlConnection
            connect thermostat.processor.hvacControl to hvac.controlInput;
    }

    requirement def ComfortRequirement {
        doc /* The system shall maintain indoor temperature within the user-specified comfort range with minimal energy consumption. */

        require tempAccuracyReq : TemperatureAccuracyRequirement;
        require responseTimeReq : ResponseTimeRequirement;
        require userControlReq : UserControlRequirement;
    }

    requirement def TemperatureAccuracyRequirement {
        doc /* Temperature sensing shall be accurate to within ±0.5°C of actual room temperature. */

        subject sensor : TemperatureSensor;
    }

    requirement def ResponseTimeRequirement {
        doc /* The system shall detect temperature changes and adjust HVAC operation within 60 seconds. */
    }

    requirement def UserControlRequirement {
        doc /* Users shall be able to adjust temperature settings locally via touch display or remotely via mobile application. */
    }

    requirement def EnergyEfficiencyRequirement {
        doc /* The system shall reduce heating and cooling energy consumption by at least 20% compared to traditional programmable thermostats through intelligent learning and scheduling. */

        require learningCapabilityReq : LearningRequirement;
        require schedulingCapabilityReq : SchedulingRequirement;
        require ecoModeReq : EcoModeRequirement;
    }

    requirement def LearningRequirement {
        doc /* The system shall learn user temperature preferences and occupancy patterns over a 7-day period and automatically optimize heating and cooling schedules. */
    }

    requirement def SchedulingRequirement {
        doc /* The system shall support programmable temperature schedules with at least 4 time periods per day. */
    }

    requirement def EcoModeRequirement {
        doc /* The system shall automatically enter energy-saving mode when no occupancy is detected for 30 minutes. */
    }

    requirement def ConnectivityRequirement {
        doc /* The system shall support remote monitoring and control via WiFi network connectivity and cloud services. */

        subject wirelessModule : WiFiModule;
        require networkSecurityReq : NetworkSecurityRequirement;
    }

    requirement def NetworkSecurityRequirement {
        doc /* All network communications shall be encrypted using industry-standard protocols to protect user data and privacy. */
    }

    requirement def ReliabilityRequirement {
        doc /* The system shall maintain continuous operation with 99.9% uptime, excluding scheduled maintenance. */
    }

    requirement <'NEST-001'> maintainComfort : ComfortRequirement {
        assume constraint { doc /* HVAC system is properly sized for the conditioned space. */ }
        assume constraint { doc /* Thermostat is installed in a location representative of overall room temperature. */ }
        assume constraint { doc /* Building envelope provides adequate insulation. */ }
    }

    requirement <'NEST-002'> improveEfficiency : EnergyEfficiencyRequirement {
        assume constraint { doc /* User permits learning mode to remain enabled. */ }
        assume constraint { doc /* Occupancy patterns are sufficiently regular for learning algorithms. */ }
    }

    requirement <'NEST-003'> enableRemoteAccess : ConnectivityRequirement {
        assume constraint { doc /* Reliable WiFi network is available at installation location. */ }
        assume constraint { doc /* Internet connectivity is maintained for cloud services. */ }
    }

    requirement <'NEST-004'> ensureReliability : ReliabilityRequirement {
        assume constraint { doc /* Power supply is stable and within specified voltage range. */ }
    }

    requirement <'NEST-SYS'> nestSystemRequirements {
        doc /* The Google Nest Learning Thermostat system shall provide intelligent, automated climate control that learns user preferences, optimizes energy consumption, and enables remote monitoring and control while maintaining user comfort. */

        require maintainComfort;
        require improveEfficiency;
        require enableRemoteAccess;
        require ensureReliability;
    }
}
