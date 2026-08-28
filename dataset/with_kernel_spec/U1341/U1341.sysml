package HomeSeerAutomationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        item def SensorData;
        item def TemperatureData :> SensorData { attribute value : TemperatureValue; }
        item def HumidityData :> SensorData { attribute value : Real; }
        item def MotionData :> SensorData { attribute detected : Boolean; attribute location : String; }
        item def LightData :> SensorData { attribute level : IlluminanceValue; }

        item def Command;
        enum def LightState { on; off; dim; }
        item def LightCommand :> Command { attribute lightState : LightState; attribute dimLevel : Real; attribute target : String; }
        item def ThermostatCommand :> Command { attribute setpoint : TemperatureValue; }
        item def PlugCommand :> Command { attribute enabled : Boolean; attribute target : String; }
        item def LockCommand :> Command { attribute locked : Boolean; attribute target : String; }

        item def DeviceRegisteredSignal { attribute deviceId : String; attribute deviceType : String; }
        item def MaintenanceSignal;
        item def ErrorSignal { attribute code : Integer; attribute description : String; }
        item def ResetSignal;

        port def SensorPort { out data : SensorData; }
        port def ActuatorPort { in cmd : Command; }

        action def DiscoverDevices { out registered : Boolean; }
        action def CollectSensorData {
            out temperature : TemperatureValue;
            out humidity : Real;
            out motionHallway : Boolean;
            out motionBedroom : Boolean;
            out ambientLight : IlluminanceValue;
        }
        action def EvaluateRules {
            in temperature : TemperatureValue;
            in humidity : Real;
            in motionHallway : Boolean;
            in motionBedroom : Boolean;
            in ambientLight : IlluminanceValue;
            in targetTemp : TemperatureValue;
            out hasCommands : Boolean;
        }
        action def DispatchCommands { out successful : Boolean; }
        action def PerformDiagnostics { out status : String; }
        action def LogError;

        state def ControllerStates {
            action discoverDevices : DiscoverDevices;
            action collectSensorData : CollectSensorData;
            action evaluateRules : EvaluateRules;
            action dispatchCommands : DispatchCommands;
            action performDiagnostics : PerformDiagnostics;
            action logError : LogError;

            entry; then initialization;

            state initialization {
                do discoverDevices;
            }
            transition init_to_idle
                first initialization
                accept DeviceRegisteredSignal
                then idle;

            state idle;
            transition idle_to_monitoring
                first idle
                accept after 1 [s]
                then monitoring;
            transition idle_to_maintenance
                first idle
                accept MaintenanceSignal
                then maintenance;

            state monitoring {
                do collectSensorData;
            }
            transition monitoring_to_processing
                first monitoring
                then processing;
            transition monitoring_to_error
                first monitoring
                accept ErrorSignal
                then errorRecovery;

            state processing {
                do evaluateRules;
            }
            transition processing_to_executing
                first processing
                if evaluateRules.hasCommands
                then executing;
            transition processing_to_idle
                first processing
                if not evaluateRules.hasCommands
                then idle;

            state executing {
                do dispatchCommands;
            }
            transition executing_to_idle
                first executing
                if dispatchCommands.successful
                then idle;
            transition executing_to_error
                first executing
                accept ErrorSignal
                then errorRecovery;

            state maintenance {
                do performDiagnostics;
            }
            transition maintenance_to_idle
                first maintenance
                accept ResetSignal
                then idle;

            state errorRecovery {
                entry logError;
                do performDiagnostics;
            }
            transition error_to_idle
                first errorRecovery
                if performDiagnostics.status == "Nominal"
                then idle;
        }

        state def LightStates {
            entry; then off;
            state off;
            state on;
            state dimmed;
            transition off_to_on
                first off
                accept cmd : LightCommand if cmd.lightState == LightState::on
                then on;
            transition off_to_dimmed
                first off
                accept cmd : LightCommand if cmd.lightState == LightState::dim
                then dimmed;
            transition on_to_off
                first on
                accept cmd : LightCommand if cmd.lightState == LightState::off
                then off;
            transition on_to_dimmed
                first on
                accept cmd : LightCommand if cmd.lightState == LightState::dim
                then dimmed;
            transition dimmed_to_off
                first dimmed
                accept cmd : LightCommand if cmd.lightState == LightState::off
                then off;
            transition dimmed_to_on
                first dimmed
                accept cmd : LightCommand if cmd.lightState == LightState::on
                then on;
        }

        state def PlugStates {
            entry; then off;
            state off;
            state on;
            transition off_to_on
                first off
                accept cmd : PlugCommand if cmd.enabled
                then on;
            transition on_to_off
                first on
                accept cmd : PlugCommand if not cmd.enabled
                then off;
        }

        state def LockStates {
            entry; then locked;
            state locked;
            state unlocked;
            transition locked_to_unlocked
                first locked
                accept cmd : LockCommand if not cmd.locked
                then unlocked;
            transition unlocked_to_locked
                first unlocked
                accept cmd : LockCommand if cmd.locked
                then locked;
        }

        part def Sensor {
            attribute location : String;
            port sensorOut : SensorPort;
        }
        part def TemperatureHumiditySensor :> Sensor {
            attribute sampleRate : FrequencyValue;
            port tempOut : SensorPort;
            port humOut : SensorPort;
            perform action senseEnvironment {
                out temperature : TemperatureValue;
                out humidity : Real;
            }
        }
        part def MotionDetector :> Sensor {
            attribute sensitivity : Real;
            attribute detectionTimeout : DurationValue;
            port motionOut : SensorPort;
            perform action detectMotion { out motion : Boolean; }
        }
        part def LightSensor :> Sensor {
            attribute luxThreshold : IlluminanceValue;
            port lightOut : SensorPort;
            perform action senseAmbientLight { out level : IlluminanceValue; }
        }

        part def Actuator {
            attribute location : String;
            port actuatorIn : ActuatorPort;
        }
        part def SmartLight :> Actuator {
            attribute maxLumens : LuminousFluxValue;
            port lightCmdIn : ActuatorPort;
            perform action turnOn;
            perform action turnOff;
            perform action setDimLevel { in level : Real; }
            exhibit state lightState : LightStates;
        }
        part def SmartThermostat :> Actuator {
            attribute targetTemperature : TemperatureValue;
            port thermoCmdIn : ActuatorPort;
            perform action setTemperature { in temp : TemperatureValue; }
        }
        part def SmartPlug :> Actuator {
            attribute maxLoad : PowerValue;
            port plugCmdIn : ActuatorPort;
            perform action enablePower;
            perform action disablePower;
            exhibit state plugState : PlugStates;
        }
        part def SmartLock :> Actuator {
            attribute autoLockDelay : DurationValue;
            port lockCmdIn : ActuatorPort;
            perform action lockDoor;
            perform action unlockDoor;
            exhibit state lockState : LockStates;
        }

        part def HomeSeerController {
            attribute targetTemp : TemperatureValue;
            attribute maxTempThreshold : TemperatureValue;
            attribute minLightThreshold : IlluminanceValue;
            attribute maintenanceInterval : DurationValue;

            port sensorIn : SensorPort[*];
            port actuatorOut : ActuatorPort[*];

            perform action discoverDevices : DiscoverDevices;
            perform action collectSensorData : CollectSensorData;
            perform action evaluateRules : EvaluateRules;
            perform action dispatchCommands : DispatchCommands;
            perform action performDiagnostics : PerformDiagnostics;

            exhibit state controllerStates : ControllerStates;
        }

        requirement def ComfortRequirement {
            doc /* The system shall maintain indoor temperature between 20 and 24 degrees Celsius when occupied. */
            subject controller : HomeSeerController;
            objective { doc /* Ensure a comfortable living environment for occupants. */ }
            assume { doc /* Temperature and humidity sensors are operational and calibrated. */ }
        }
        requirement def SecurityRequirement {
            doc /* The system shall lock all external doors when no motion is detected for 30 minutes or at 10 PM local time. */
            subject controller : HomeSeerController;
            objective { doc /* Ensure home security through automated door lock management. */ }
        }
        requirement def EnergyEfficiencyRequirement {
            doc /* The system shall turn off lights and smart plugs in unoccupied rooms after 15 minutes of no motion. */
            subject controller : HomeSeerController;
            objective { doc /* Minimize energy consumption by disabling devices when not needed. */ }
        }
        requirement def LightingAutomationRequirement {
            doc /* When ambient light drops below 100 lux and motion is detected in a room, the system shall turn on the light in that room. */
            subject controller : HomeSeerController;
            objective { doc /* Provide automated lighting responsive to occupancy and ambient conditions. */ }
        }
    }

    package Usages {
        private import Definitions::*;

        part homeSystem {
            part controller : HomeSeerController {
                attribute targetTemp = 22 [degC];
                attribute maxTempThreshold = 25 [degC];
                attribute minLightThreshold = 100 [lx];
                attribute maintenanceInterval = 4320 [h];
            }

            part livingRoomTempHumSensor : TemperatureHumiditySensor {
                attribute location = "LivingRoom";
                attribute sampleRate = 0.0167 [Hz];
            }
            part hallwayMotionDetector : MotionDetector {
                attribute location = "Hallway";
                attribute sensitivity = 0.8;
                attribute detectionTimeout = 30 [s];
            }
            part bedroomMotionDetector : MotionDetector {
                attribute location = "Bedroom";
                attribute sensitivity = 0.7;
                attribute detectionTimeout = 60 [s];
            }
            part outdoorLightSensor : LightSensor {
                attribute location = "Outdoor";
                attribute luxThreshold = 100 [lx];
            }

            part livingRoomLight : SmartLight {
                attribute location = "LivingRoom";
                attribute maxLumens = 1600 [lm];
            }
            part hallwayLight : SmartLight {
                attribute location = "Hallway";
                attribute maxLumens = 800 [lm];
            }
            part bedroomLight : SmartLight {
                attribute location = "Bedroom";
                attribute maxLumens = 800 [lm];
            }
            part centralThermostat : SmartThermostat {
                attribute location = "LivingRoom";
                attribute targetTemperature = 22 [degC];
            }
            part coffeeMakerPlug : SmartPlug {
                attribute location = "Kitchen";
                attribute maxLoad = 1500 [W];
            }
            part lampPlug : SmartPlug {
                attribute location = "LivingRoom";
                attribute maxLoad = 100 [W];
            }
            part frontDoorLock : SmartLock {
                attribute location = "FrontDoor";
                attribute autoLockDelay = 60 [s];
            }
            part backDoorLock : SmartLock {
                attribute location = "BackDoor";
                attribute autoLockDelay = 60 [s];
            }

            connect livingRoomTempHumSensor.tempOut to controller.sensorIn;
            connect livingRoomTempHumSensor.humOut to controller.sensorIn;
            connect hallwayMotionDetector.motionOut to controller.sensorIn;
            connect bedroomMotionDetector.motionOut to controller.sensorIn;
            connect outdoorLightSensor.lightOut to controller.sensorIn;

            connect controller.actuatorOut to livingRoomLight.lightCmdIn;
            connect controller.actuatorOut to hallwayLight.lightCmdIn;
            connect controller.actuatorOut to bedroomLight.lightCmdIn;
            connect controller.actuatorOut to centralThermostat.thermoCmdIn;
            connect controller.actuatorOut to coffeeMakerPlug.plugCmdIn;
            connect controller.actuatorOut to lampPlug.plugCmdIn;
            connect controller.actuatorOut to frontDoorLock.lockCmdIn;
            connect controller.actuatorOut to backDoorLock.lockCmdIn;

            requirement comfort : ComfortRequirement { subject controller; }
            requirement security : SecurityRequirement { subject controller; }
            requirement energyEfficiency : EnergyEfficiencyRequirement { subject controller; }
            requirement lightingAutomation : LightingAutomationRequirement { subject controller; }
        }
    }
}
