package HomeOSSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def HumidityValue :> Real;
    attribute def LuminousIntensityValue :> ISQ::LuminousIntensityValue;
    attribute def PowerValue :> ISQ::PowerValue;
    attribute def EnergyValue :> ISQ::EnergyValue;

    item def EnvironmentalData {
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute lightLevel : LuminousIntensityValue;
        attribute occupancyDetected : Boolean;
        attribute timestamp : Real;
    }

    item def ControlCommand {
        attribute deviceId : String;
        attribute commandType : String;
        attribute targetValue : Real;
    }

    item def UserPreferences {
        attribute desiredTemperature : TemperatureValue;
        attribute desiredHumidity : HumidityValue;
        attribute lightingSchedule : String;
        attribute securityEnabled : Boolean;
    }

    item def SystemStatus {
        attribute operationalMode : String;
        attribute energyConsumption : EnergyValue;
        attribute alertsActive : Boolean;
    }

    port def SensorDataPort {
        out item environmentData : EnvironmentalData;
    }

    port def ActuatorCommandPort {
        in item command : ControlCommand;
    }

    port def UserInterfacePort {
        in item preferences : UserPreferences;
        out item status : SystemStatus;
    }

    part def EnvironmentalSensor {
        port dataOutput : SensorDataPort;
        
        action def SenseEnvironment {
            out sensorReading : EnvironmentalData;
        }
    }

    part def ClimateController {
        port commandInput : ~ActuatorCommandPort;
        attribute currentTemperature : TemperatureValue;
        attribute targetTemperature : TemperatureValue;
        attribute hvacPower : PowerValue;
        
        action def RegulateClimate {
            in controlCmd : ControlCommand;
            out powerUsed : PowerValue;
        }
    }

    part def LightingSystem {
        port commandInput : ~ActuatorCommandPort;
        attribute brightness : Real;
        attribute isActive : Boolean;
        
        action def AdjustLighting {
            in controlCmd : ControlCommand;
        }
    }

    part def SecurityMonitor {
        port commandInput : ~ActuatorCommandPort;
        attribute armed : Boolean;
        attribute intrusionDetected : Boolean;
        
        action def MonitorSecurity {
            in controlCmd : ControlCommand;
            out alert : Boolean;
        }
    }

    part def EnergyManager {
        attribute totalEnergyUsed : EnergyValue;
        attribute currentPowerDraw : PowerValue;
        
        action def TrackEnergyUsage {
            in powerConsumption : PowerValue;
            in duration : ISQ::TimeValue;
            out energyConsumed : EnergyValue;
        }
    }

    part def HomeOSController {
        port userInterface : ~UserInterfacePort;
        
        action def AnalyzeSensorData {
            in environmentData : EnvironmentalData;
            in userPrefs : UserPreferences;
            out analysisResult : Boolean;
        }
        
        action def GenerateControlCommands {
            in environmentData : EnvironmentalData;
            in userPrefs : UserPreferences;
            out climateCommand : ControlCommand;
            out lightingCommand : ControlCommand;
            out securityCommand : ControlCommand;
        }
        
        action def UpdateSystemStatus {
            in energyData : EnergyValue;
            in securityAlerts : Boolean;
            out currentStatus : SystemStatus;
        }
    }

    requirement def FunctionalRequirement;
    
    requirement <'REQ-001'> automatedHomeManagement : FunctionalRequirement {
        doc /* The HomeOS shall continuously monitor environmental conditions and automatically 
                adjust home systems to maintain user-defined comfort levels while optimizing 
                energy consumption. */
        subject homeOSInstance;
        
        require constraint comfortMaintenance {
            doc /* Temperature shall be maintained within 2 degrees of user preference. */
        }
        
        require constraint energyOptimization {
            doc /* Energy consumption shall be minimized while meeting comfort requirements. */
        }
    }
    
    requirement <'REQ-002'> securityIntegration : FunctionalRequirement {
        doc /* The HomeOS shall integrate security monitoring and respond to intrusion events 
                within 5 seconds. */
        subject homeOSInstance;
    }
    
    requirement <'REQ-003'> userControl : FunctionalRequirement {
        doc /* The HomeOS shall allow users to configure preferences and override automated 
                decisions at any time. */
        subject homeOSInstance;
    }

    action def HomeAutomationControl {
        first start;
        then merge monitoringLoop;
        
        action gatherSensorData {
            out envData : EnvironmentalData;
        }
        
        then action evaluateConditions {
            in sensorData : EnvironmentalData = gatherSensorData.envData;
            in userSettings : UserPreferences;
            out requiresAction : Boolean;
        }
        
        then decide;
            if evaluateConditions.requiresAction then generateCommands;
            if not evaluateConditions.requiresAction then monitoringLoop;
        
        action generateCommands {
            in envData : EnvironmentalData = gatherSensorData.envData;
            in userSettings : UserPreferences;
            out climateCmd : ControlCommand;
            out lightCmd : ControlCommand;
            out securityCmd : ControlCommand;
        }
        
        then action executeCommands {
            in climateControl : ControlCommand = generateCommands.climateCmd;
            in lightControl : ControlCommand = generateCommands.lightCmd;
            in securityControl : ControlCommand = generateCommands.securityCmd;
        }
        
        then action updateEnergy {
            in powerData : PowerValue;
            out energyUpdate : EnergyValue;
        }
        
        then monitoringLoop;
    }

    state def HomeOSOperationalState {
        entry action initializeHomeOS;
        
        state Standby {
            entry action enterLowPowerMode;
        }
        
        transition standbyToActive
            first Standby
            accept userActivityDetected
            then ActiveMonitoring;
        
        state ActiveMonitoring {
            entry action activateAllSensors;
            do action continuousMonitoring;
            
            state NormalOperation;
            
            state ClimateAdjustment {
                do action adjustHVAC;
            }
            
            state LightingAdjustment {
                do action adjustLights;
            }
            
            transition normalToClimate
                first NormalOperation
                if temperatureOutOfRange
                then ClimateAdjustment;
            
            transition normalToLighting
                first NormalOperation
                if lightingAdjustmentNeeded
                then LightingAdjustment;
            
            transition adjustmentToNormal
                first ClimateAdjustment
                accept adjustmentComplete
                then NormalOperation;
        }
        
        transition activeToStandby
            first ActiveMonitoring
            accept noActivityTimeout
            then Standby;
        
        state SecurityAlert {
            entry action triggerAlarm;
            do action notifyAuthorities;
        }
        
        transition monitoringToAlert
            first ActiveMonitoring
            accept intrusionDetected
            then SecurityAlert;
        
        transition alertToMonitoring
            first SecurityAlert
            accept alertCleared
            then ActiveMonitoring;
        
        state MaintenanceMode;
        
        transition anyToMaintenance
            accept maintenanceRequested
            then MaintenanceMode;
        
        transition maintenanceToStandby
            first MaintenanceMode
            accept maintenanceCompleted
            then Standby;
    }

    part homeOSInstance {
        part sensors : EnvironmentalSensor[4] {
            perform action sensing : SenseEnvironment[*];
        }
        
        part climate : ClimateController {
            perform action climateControl : RegulateClimate[*];
        }
        
        part lighting : LightingSystem[6] {
            perform action lightControl : AdjustLighting[*];
        }
        
        part security : SecurityMonitor {
            perform action securityMonitoring : MonitorSecurity[*];
        }
        
        part energyMgr : EnergyManager {
            perform action energyTracking : TrackEnergyUsage[*];
        }
        
        part controller : HomeOSController {
            perform action automationControl[*] ordered references HomeAutomationControl;
        }
        
        connection sensorToController connect sensors.dataOutput to controller;
        connection controllerToClimate connect controller to climate.commandInput;
        connection controllerToLighting connect controller to lighting.commandInput;
        connection controllerToSecurity connect controller to security.commandInput;
    }

    occurrence def HomeOSOperationScenario {
        ref part system :>> homeOSInstance;
        
        message environmentalDataMessage of EnvironmentalData
            from system.sensors.dataOutput to system.controller;
        
        then message climateCommandMessage of ControlCommand
            from system.controller to system.climate.commandInput;
        
        then message lightingCommandMessage of ControlCommand
            from system.controller to system.lighting.commandInput;
        
        then message securityCommandMessage of ControlCommand
            from system.controller to system.security.commandInput;
    }
}
