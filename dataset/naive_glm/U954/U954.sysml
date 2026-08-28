package SmartHouseSystem {
    import ScalarValues::*;
    import SI::*;

    // ===== Value Types =====
    value def Temperature :> Real { unit "degC"; }
    value def Humidity :> Real { unit "percent"; }
    value def Illuminance :> Real { unit "lux"; }
    value def Power :> Real {> Watt; }
    value def Brightness :> Real { unit "percent"; }
    value def Energy :> Real { unit "kWh"; }
    value def TimeOfDay :> String;

    // ===== Item Definitions =====
    item def SensorData {
        attr roomId : String;
        attr timestamp : DateTime;
    }

    item def TemperatureData :> SensorData {
        attr temperature : Temperature;
    }

    item def HumidityData :> SensorData {
        attr humidity : Humidity;
    }

    item def LightData :> SensorData {
        attr illuminance : Illuminance;
    }

    item def OccupancyData :> SensorData {
        attr occupied : Boolean;
    }

    item def MotionData :> SensorData {
        attr motionDetected : Boolean;
    }

    item def DoorData :> SensorData {
        attr isOpen : Boolean;
    }

    item def PowerData :> SensorData {
        attr power : Power;
    }

    item def Command {
        attr roomId : String;
    }

    item def ClimateCommand :> Command {
        attr targetTemperature : Temperature;
        attr targetHumidity : Humidity;
        attr mode : String;
    }

    item def LightingCommand :> Command {
        attr brightness : Brightness;
        attr on : Boolean;
    }

    item def SecurityCommand :> Command {
        attr armState : String;
    }

    item def EnergyCommand :> Command {
        attr powerLimit : Power;
        attr awayMode : Boolean;
    }

    // ===== Port Definitions =====
    port def SensorOutPort {
        out data : SensorData[*];
    }

    port def SensorInPort {
        in data : SensorData[*];
    }

    port def CommandOutPort {
        out command : Command[*];
    }

    port def CommandInPort {
        in command : Command[*];
    }

    // ===== Sensor Parts =====
    part def Sensor {
        port sensorOut : SensorOutPort;
        attr roomId : String;
        attr location : String;
        attr samplingInterval : Duration = 1 [s];
    }

    part def TemperatureSensor :> Sensor {
        attr currentTemperature : Temperature;
        action def readTemperature {
            out reading : TemperatureData;
        }
        perform readTemperature;
    }

    part def HumiditySensor :> Sensor {
        attr currentHumidity : Humidity;
        action def readHumidity {
            out reading : HumidityData;
        }
        perform readHumidity;
    }

    part def AmbientLightSensor :> Sensor {
        attr currentIlluminance : Illuminance;
        action def readLight {
            out reading : LightData;
        }
        perform readLight;
    }

    part def OccupancySensor :> Sensor {
        attr isOccupied : Boolean;
        action def detectOccupancy {
            out reading : OccupancyData;
        }
        perform detectOccupancy;
    }

    part def MotionSensor :> Sensor {
        attr motionDetected : Boolean;
        action def detectMotion {
            out reading : MotionData;
        }
        perform detectMotion;
    }

    part def DoorSensor :> Sensor {
        attr doorOpen : Boolean;
        action def detectDoorState {
            out reading : DoorData;
        }
        perform detectDoorState;
    }

    // ===== Sensor Network =====
    part def SensorNetwork {
        port networkOut : SensorOutPort;
        port networkIn : SensorInPort;

        part tempSensors : TemperatureSensor[4] {
            attr roomId = {"living", "bedroom", "kitchen", "bathroom"};
        }
        part humiditySensors : HumiditySensor[3] {
            attr roomId = {"living", "bedroom", "kitchen"};
        }
        part lightSensors : AmbientLightSensor[4] {
            attr roomId = {"living", "bedroom", "kitchen", "hallway"};
        }
        part occupancySensors : OccupancySensor[5] {
            attr roomId = {"living", "bedroom", "kitchen", "hallway", "bathroom"};
        }
        part motionSensors : MotionSensor[5] {
            attr roomId = {"living", "bedroom", "kitchen", "hallway", "entry"};
        }
        part doorSensors : DoorSensor[4] {
            attr roomId = {"front", "back", "garage", "patio"};
        }

        connection def aggregateSensorData {
            end tempSensors.sensorOut;
            end networkOut;
        }
    }

    // ===== Control System Parts =====
    part def ClimateControlSystem {
        port cmdIn : CommandInPort;
        port powerOut : SensorOutPort;
        attr currentTemperature : Temperature;
        attr currentHumidity : Humidity;
        attr targetTemperature : Temperature = 22.0 [degC];
        attr targetHumidity : Humidity = 45.0 [percent];
        attr heatingActive : Boolean = false;
        attr coolingActive : Boolean = false;

        state def ClimateStateMachine {
            state Idle {
                entry { heatingActive = false; coolingActive = false; }
            }
            state Heating {
                entry { heatingActive = true; coolingActive = false; }
            }
            state Cooling {
                entry { heatingActive = false; coolingActive = true; }
            }
            transition Idle to Heating
                when currentTemperature < targetTemperature - 1.0 [degC];
            transition Idle to Cooling
                when currentTemperature > targetTemperature + 1.0 [degC];
            transition Heating to Idle
                when currentTemperature >= targetTemperature;
            transition Cooling to Idle
                when currentTemperature <= targetTemperature;
        }

        action def applyClimateCommand {
            in cmd : ClimateCommand;
            then setTargetTemperature;
            action setTargetTemperature {
                in cmd : ClimateCommand;
            }
        }
    }

    part def LightingSystem {
        port cmdIn : CommandInPort;
        port powerOut : SensorOutPort;
        attr brightness : Brightness = 0.0 [percent];
        attr lightsOn : Boolean = false;
        attr roomId : String;

        action def applyLightingCommand {
            in cmd : LightingCommand;
            then if cmd.on then turnOn else turnOff;
            action turnOn { brightness = cmd.brightness; lightsOn = true; }
            action turnOff { lightsOn = false; brightness = 0.0 [percent]; }
        }
    }

    part def SecuritySystem {
        port cmdIn : CommandInPort;
        port sensorIn : SensorInPort;
        port alarmOut : CommandOutPort;
        attr armState : String = "disarmed";
        attr intrusionDetected : Boolean = false;

        state def SecurityStateMachine {
            state Disarmed {
                entry { armState = "disarmed"; intrusionDetected = false; }
            }
            state Armed {
                entry { armState = "armed"; }
                do monitorSensors;
                action monitorSensors {
                    in sensorData : SensorData[*];
                }
            }
            state Alarming {
                entry { armState = "alarming"; intrusionDetected = true; }
                do triggerAlarm;
                action triggerAlarm {
                    out alarm : SecurityCommand;
                }
            }
            transition Disarmed to Armed
                when cmdIn.command->exists(c | c.oclAsType(SecurityCommand).armState = "armed");
            transition Armed to Disarmed
                when cmdIn.command->exists(c | c.oclAsType(SecurityCommand).armState = "disarmed");
            transition Armed to Alarming
                when sensorIn.data->exists(d | d.oclAsType(MotionData).motionDetected = true or d.oclAsType(DoorData).isOpen = true);
            transition Alarming to Disarmed
                when cmdIn.command->exists(c | c.oclAsType(SecurityCommand).armState = "disarmed");
        }
    }

    part def EnergyManagementSystem {
        port cmdIn : CommandInPort;
        port powerFeedback : SensorOutPort;
        attr totalPower : Power = 0.0 [W];
        attr totalEnergy : Energy = 0.0 [kWh];
        attr awayMode : Boolean = false;
        attr powerLimit : Power = 5000.0 [W];

        action def trackPower {
            in powerData : PowerData[*];
            then accumulate;
            action accumulate {
                in powerData : PowerData[*];
            }
        }

        action def applyEnergyCommand {
            in cmd : EnergyCommand;
            then if cmd.awayMode then enableAway else disableAway;
            action enableAway { awayMode = true; powerLimit = cmd.powerLimit; }
            action disableAway { awayMode = false; }
        }
    }

    // ===== Automation Controller =====
    part def AutomationController {
        port sensorInput : SensorInPort;
        port climateCmdOut : CommandOutPort;
        port lightingCmdOut : CommandOutPort;
        port securityCmdOut : CommandOutPort;
        port energyCmdOut : CommandOutPort;
        port energyFeedbackIn : SensorInPort;

        attr houseOccupied : Boolean = true;
        attr timeOfDay : TimeOfDay = "day";
        attr comfortTemperature : Temperature = 22.0 [degC];
        attr awayTemperature : Temperature = 18.0 [degC];
        attr securityArmed : Boolean = false;

        action def analyzeSensorData {
            in data : SensorData[*];
            out climateCmd : ClimateCommand;
            out lightingCmd : LightingCommand;
            out securityCmd : SecurityCommand;
            out energyCmd : EnergyCommand;
            then determineOccupancy;
            action determineOccupancy {
                in data : SensorData[*];
            }
            then evaluateTimeOfDay;
            action evaluateTimeOfDay {
                in data : SensorData[*];
            }
            then generateCommands;
            action generateCommands {
                out climateCmd : ClimateCommand;
                out lightingCmd : LightingCommand;
                out securityCmd : SecurityCommand;
                out energyCmd : EnergyCommand;
            }
        }

        state def ControllerStateMachine {
            state Home {
                entry { houseOccupied = true; }
                do monitorHome;
                action monitorHome {
                    in data : SensorData[*];
                }
                transition Home to Away
                    when sensorInput.data->forAll(d | d.oclAsType(OccupancyData).occupied = false);
            }
            state Away {
                entry { houseOccupied = false; }
                do monitorAway;
                action monitorAway {
                    in data : SensorData[*];
                }
                transition Away to Home
                    when sensorInput.data->exists(d | d.oclAsType(OccupancyData).occupied = true);
            }
        }

        perform analyzeSensorData;
        exhibit ControllerStateMachine;
    }

    // ===== Smart House System =====
    part def SmartHouse {
        part controller : AutomationController;
        part sensors : SensorNetwork;
        part climateControl : ClimateControlSystem;
        part lightingSystem : LightingSystem[5];
        part securitySystem : SecuritySystem;
        part energyManagement : EnergyManagementSystem;

        connection sensorsToController connect sensors.networkOut to controller.sensorInput;
        connection controllerToClimate connect controller.climateCmdOut to climateControl.cmdIn;
        connection controllerToLighting connect controller.lightingCmdOut to lightingSystem.cmdIn;
        connection controllerToSecurity connect controller.securityCmdOut to securitySystem.cmdIn;
        connection controllerToEnergy connect controller.energyCmdOut to energyManagement.cmdIn;
        connection energyToController connect energyManagement.powerFeedback to controller.energyFeedbackIn;
        connection securitySensorFeed connect sensors.networkOut to securitySystem.sensorIn;
        connection climatePowerFeed connect climateControl.powerOut to energyManagement.powerFeedback;
        connection lightingPowerFeed connect lightingSystem.powerOut to energyManagement.powerFeedback;
    }

    // ===== Requirements =====
    req def ComfortRequirement {
        doc "The system shall maintain occupant comfort by regulating temperature and humidity."
        subject smartHouse : SmartHouse;
        objective {
            smartHouse.climateControl.currentTemperature >= 20.0 [degC] and
            smartHouse.climateControl.currentTemperature <= 24.0 [degC]
        }
    }

    req def SecurityRequirement {
        doc "The security system shall detect intrusions when armed and trigger an alarm."
        subject securitySystem : SecuritySystem;
        objective {
            securitySystem.armState = "armed" implies
            (securitySystem.intrusionDetected implies securitySystem.armState = "alarming")
        }
    }

    req def EnergyEfficiencyRequirement {
        doc "The system shall minimize energy consumption when the house is unoccupied."
        subject energyManagement : EnergyManagementSystem;
        objective {
            energyManagement.awayMode = true implies energyManagement.totalPower <= energyManagement.powerLimit
        }
    }

    req def LightingAutomationRequirement {
        doc "The system shall automatically turn on lights when a room is occupied and dark."
        subject lightingSystem : LightingSystem;
        objective {
            lightingSystem.lightsOn = true
        }
    }

    req def OccupancyDetectionRequirement {
        doc "The controller shall determine room occupancy from sensor data."
        subject controller : AutomationController;
        objective {
            controller.houseOccupied = true implies
            controller.sensorInput.data->exists(d | d.oclAsType(OccupancyData).occupied = true)
        }
    }

    part def SmartHouseSystem :> SmartHouse {
        satisfy ComfortRequirement by smartHouse;
        satisfy SecurityRequirement by securitySystem;
        satisfy EnergyEfficiencyRequirement by energyManagement;
        satisfy LightingAutomationRequirement by lightingSystem;
        satisfy OccupancyDetectionRequirement by controller;
    }
}
