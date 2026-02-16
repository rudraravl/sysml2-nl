package 'Home Automation System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TemperatureSetpoint :> ThermodynamicTemperatureValue;
    attribute def TemperatureReading :> ThermodynamicTemperatureValue;
    attribute def IlluminanceLevel :> IlluminanceValue;
    attribute def OccupancyState :> Boolean;
    attribute def SecurityArmedState :> Boolean;
    attribute def DoorLockState :> Boolean;
    attribute def WindowState :> Boolean;
    attribute def EnergyUsage :> PowerValue;
    attribute def HumidityLevel :> Real;
    attribute def AirQualityIndex :> Real;
    
    enum def HVACMode {
        off;
        heating;
        cooling;
        auto;
    }
    
    enum def LightingMode {
        off;
        on;
        dimmed;
        auto;
    }
    
    enum def SecurityMode {
        disarmed;
        armedStay;
        armedAway;
        alarm;
    }
    
    port def EnvironmentSensorPort {
        out temperature : TemperatureReading;
        out humidity : HumidityLevel;
        out airQuality : AirQualityIndex;
    }
    
    port def OccupancySensorPort {
        out occupied : OccupancyState;
    }
    
    port def LightSensorPort {
        out illuminance : IlluminanceLevel;
    }
    
    port def SecuritySensorPort {
        out doorLocked : DoorLockState;
        out windowClosed : WindowState;
        out motionDetected : OccupancyState;
    }
    
    port def HVACControlPort {
        in mode : HVACMode;
        in setpoint : TemperatureSetpoint;
    }
    
    port def LightingControlPort {
        in mode : LightingMode;
        in brightness : Real;
    }
    
    port def SecurityControlPort {
        in securityMode : SecurityMode;
        in lockCommand : DoorLockState;
    }
    
    port def EnergyMonitorPort {
        out consumption : EnergyUsage;
    }
    
    part def EnvironmentSensor {
        port sensorOut : EnvironmentSensorPort;
        attribute currentTemp : TemperatureReading;
        attribute currentHumidity : HumidityLevel;
        attribute currentAirQuality : AirQualityIndex;
    }
    
    part def OccupancySensor {
        port sensorOut : OccupancySensorPort;
        attribute isOccupied : OccupancyState;
    }
    
    part def LightSensor {
        port sensorOut : LightSensorPort;
        attribute currentIlluminance : IlluminanceLevel;
    }
    
    part def MotionSensor {
        port sensorOut : OccupancySensorPort;
        attribute motionDetected : OccupancyState;
    }
    
    part def DoorWindowSensor {
        port sensorOut : SecuritySensorPort;
        attribute doorLocked : DoorLockState;
        attribute windowClosed : WindowState;
    }
    
    part def HVACUnit {
        port controlIn : HVACControlPort;
        port energyOut : EnergyMonitorPort;
        attribute operatingMode : HVACMode;
        attribute targetTemp : TemperatureSetpoint;
        attribute powerConsumption : EnergyUsage;
    }
    
    part def SmartLight {
        port controlIn : LightingControlPort;
        port energyOut : EnergyMonitorPort;
        attribute lightMode : LightingMode;
        attribute brightnessLevel : Real;
        attribute powerConsumption : EnergyUsage;
    }
    
    part def SmartLock {
        port controlIn : SecurityControlPort;
        attribute lockState : DoorLockState;
    }
    
    part def SecurityPanel {
        port controlIn : SecurityControlPort;
        port sensorIn : SecuritySensorPort;
        attribute currentMode : SecurityMode;
        attribute alarmActive : Boolean;
        
        state securityBehavior {
            entry; then disarmed;
            
            state disarmed;
            state armedStay;
            state armedAway;
            state alarmTriggered;
            
            transition disarmedToStay
                first disarmed
                accept armStayCmd : SecurityMode
                if armStayCmd == SecurityMode::armedStay
                then armedStay;
            
            transition disarmedToAway
                first disarmed
                accept armAwayCmd : SecurityMode
                if armAwayCmd == SecurityMode::armedAway
                then armedAway;
            
            transition stayToDisarmed
                first armedStay
                accept disarmCmd : SecurityMode
                if disarmCmd == SecurityMode::disarmed
                then disarmed;
            
            transition awayToDisarmed
                first armedAway
                accept disarmCmd : SecurityMode
                if disarmCmd == SecurityMode::disarmed
                then disarmed;
            
            transition stayToAlarm
                first armedStay
                accept intrusion : OccupancyState
                if intrusion
                then alarmTriggered;
            
            transition awayToAlarm
                first armedAway
                accept intrusion : OccupancyState
                if intrusion
                then alarmTriggered;
            
            transition alarmToDisarmed
                first alarmTriggered
                accept disarmCmd : SecurityMode
                if disarmCmd == SecurityMode::disarmed
                then disarmed;
        }
    }
    
    part def CentralController {
        port envSensorIn : EnvironmentSensorPort;
        port occupancySensorIn : OccupancySensorPort;
        port lightSensorIn : LightSensorPort;
        port securitySensorIn : SecuritySensorPort;
        port hvacControlOut : HVACControlPort;
        port lightControlOut : LightingControlPort;
        port securityControlOut : SecurityControlPort;
        port energyMonitorIn : EnergyMonitorPort;
        
        attribute userSetpoint : TemperatureSetpoint;
        attribute desiredIlluminance : IlluminanceLevel;
        attribute securityPreference : SecurityMode;
        attribute totalEnergyUsage : EnergyUsage;
        attribute occupancyHistory : OccupancyState[*];
    }
    
    action def MonitorEnvironment {
        in temperature : TemperatureReading;
        in humidity : HumidityLevel;
        in airQuality : AirQualityIndex;
        in occupancy : OccupancyState;
        in illuminance : IlluminanceLevel;
        out environmentStatus : String;
    }
    
    action def ControlClimate {
        in currentTemp : TemperatureReading;
        in setpoint : TemperatureSetpoint;
        in occupied : OccupancyState;
        out hvacMode : HVACMode;
        out targetSetpoint : TemperatureSetpoint;
    }
    
    action def ManageLighting {
        in ambientLight : IlluminanceLevel;
        in desiredLight : IlluminanceLevel;
        in occupied : OccupancyState;
        out lightMode : LightingMode;
        out brightness : Real;
    }
    
    action def EnforceSecurity {
        in securityMode : SecurityMode;
        in motionDetected : OccupancyState;
        in doorLocked : DoorLockState;
        in windowClosed : WindowState;
        out lockCommand : DoorLockState;
        out alarmStatus : Boolean;
    }
    
    action def OptimizeEnergy {
        in currentUsage : EnergyUsage;
        in occupancyPattern : OccupancyState[*];
        in timeOfDay : Real;
        out energyStrategy : String;
        out recommendedActions : String[*];
    }
    
    action def AutomateHomeOperations {
        first start;
        then merge continuousMonitoring;
        
        action monitorEnv : MonitorEnvironment {
            in temperature;
            in humidity;
            in airQuality;
            in occupancy;
            in illuminance;
            out environmentStatus;
        }
        
        then fork parallelControl;
        
        action climateCtrl : ControlClimate {
            in currentTemp = monitorEnv.temperature;
            in setpoint;
            in occupied = monitorEnv.occupancy;
            out hvacMode;
            out targetSetpoint;
        }
        
        action lightMgmt : ManageLighting {
            in ambientLight = monitorEnv.illuminance;
            in desiredLight;
            in occupied = monitorEnv.occupancy;
            out lightMode;
            out brightness;
        }
        
        action securityEnforce : EnforceSecurity {
            in securityMode;
            in motionDetected = monitorEnv.occupancy;
            in doorLocked;
            in windowClosed;
            out lockCommand;
            out alarmStatus;
        }
        
        action energyOpt : OptimizeEnergy {
            in currentUsage;
            in occupancyPattern;
            in timeOfDay;
            out energyStrategy;
            out recommendedActions;
        }
        
        then join controlComplete;
        then continuousMonitoring;
    }
    
    part def HomeAutomationSystem {
        doc /* 
        The home automation system provides intelligent, integrated control of residential 
        climate, lighting, security, and energy management. It continuously monitors environmental 
        conditions and occupancy patterns to automatically adjust HVAC, lighting, and security 
        systems for optimal comfort, safety, and energy efficiency. The system learns from user 
        preferences and adapts its behavior to minimize energy consumption while maintaining 
        desired comfort levels and security posture.
        */
        
        part livingRoomEnvSensor : EnvironmentSensor;
        part bedroomEnvSensor : EnvironmentSensor;
        part kitchenEnvSensor : EnvironmentSensor;
        
        part livingRoomOccupancy : OccupancySensor;
        part bedroomOccupancy : OccupancySensor;
        part kitchenOccupancy : OccupancySensor;
        
        part livingRoomLightSensor : LightSensor;
        part bedroomLightSensor : LightSensor;
        
        part frontDoorSensor : DoorWindowSensor;
        part backDoorSensor : DoorWindowSensor;
        part windowSensors : DoorWindowSensor[4];
        
        part entryMotionSensor : MotionSensor;
        part hallwayMotionSensor : MotionSensor;
        
        part mainHVAC : HVACUnit;
        part bedroomHVAC : HVACUnit;
        
        part livingRoomLights : SmartLight[3];
        part bedroomLights : SmartLight[2];
        part kitchenLights : SmartLight[2];
        part outdoorLights : SmartLight[2];
        
        part frontDoorLock : SmartLock;
        part backDoorLock : SmartLock;
        part garageDoorLock : SmartLock;
        
        part securityPanel : SecurityPanel;
        
        part controller : CentralController {
            attribute userSetpoint = 295.15 [K];
            attribute desiredIlluminance = 500.0 [lx];
            attribute securityPreference = SecurityMode::disarmed;
        }
        
        connect livingRoomEnvSensor.sensorOut to controller.envSensorIn;
        connect livingRoomOccupancy.sensorOut to controller.occupancySensorIn;
        connect livingRoomLightSensor.sensorOut to controller.lightSensorIn;
        connect frontDoorSensor.sensorOut to controller.securitySensorIn;
        connect entryMotionSensor.sensorOut to securityPanel.sensorIn;
        
        connect controller.hvacControlOut to mainHVAC.controlIn;
        connect controller.hvacControlOut to bedroomHVAC.controlIn;
        connect controller.lightControlOut to livingRoomLights[1].controlIn;
        connect controller.securityControlOut to securityPanel.controlIn;
        connect controller.securityControlOut to frontDoorLock.controlIn;
        
        connect mainHVAC.energyOut to controller.energyMonitorIn;
        connect livingRoomLights[1].energyOut to controller.energyMonitorIn;
        
        perform action automateHome : AutomateHomeOperations;
        
        requirement primaryFunctionRequirement {
            doc /* 
            The home automation system shall continuously monitor environmental conditions, 
            occupancy, and security status to automatically control HVAC, lighting, and 
            access control systems, maintaining user-defined comfort levels while optimizing 
            energy consumption and ensuring home security.
            */
        }
        
        requirement comfortRequirement {
            doc /* 
            The system shall maintain indoor temperature within 1 K of the user-defined 
            setpoint when rooms are occupied.
            */
            require constraint {
                livingRoomEnvSensor.currentTemp >= controller.userSetpoint - 1.0 [K] and
                livingRoomEnvSensor.currentTemp <= controller.userSetpoint + 1.0 [K]
            }
        }
        
        requirement lightingRequirement {
            doc /* 
            The system shall automatically adjust lighting to maintain desired illuminance 
            levels based on occupancy and ambient light conditions.
            */
            require constraint {
                livingRoomOccupancy.isOccupied implies 
                    livingRoomLightSensor.currentIlluminance >= controller.desiredIlluminance
            }
        }
        
        requirement securityRequirement {
            doc /* 
            The system shall automatically lock all entry doors and activate motion sensors 
            when security mode is set to armed away, and trigger alarm upon unauthorized 
            entry detection.
            */
            require constraint {
                securityPanel.currentMode == SecurityMode::armedAway implies 
                    (frontDoorLock.lockState == true and backDoorLock.lockState == true)
            }
        }
        
        requirement energyEfficiencyRequirement {
            doc /* 
            The system shall reduce total energy consumption by at least 25% compared to 
            manual operation by optimizing HVAC and lighting based on occupancy patterns 
            and time of day.
            */
            attribute baselineConsumption : EnergyUsage;
            require constraint {
                controller.totalEnergyUsage <= 0.75 * baselineConsumption
            }
        }
        
        requirement responseTimeRequirement {
            doc /* 
            The system shall respond to occupancy changes and adjust climate and lighting 
            controls within 30 seconds.
            */
            attribute maxResponseTime : DurationValue = 30.0 [s];
        }
        
        requirement reliabilityRequirement {
            doc /* 
            The system shall maintain 99.5% uptime and continue basic operations even if 
            individual sensors or actuators fail.
            */
            attribute requiredUptime : Real = 0.995;
        }
    }
    
    part myHome : HomeAutomationSystem;
}
