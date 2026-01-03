package 'Robotic Fish System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def SwimmingMode;
    attribute def CruiseMode :> SwimmingMode;
    attribute def ManeuverMode :> SwimmingMode;
    attribute def StationKeepingMode :> SwimmingMode;
    attribute def SurfaceMode :> SwimmingMode;
    
    attribute def ObstacleDetected;
    attribute def NavigationCommand;
    attribute def MissionComplete;
    attribute def EmergencySignal;
    
    attribute def WaterDepth :> ISQ::LengthValue;
    attribute def SwimSpeed :> ISQ::SpeedValue;
    attribute def BatteryLevel :> Real;
    attribute def TailBeatFrequency :> ISQ::FrequencyValue;
    attribute def FinAngle :> ISQ::PlaneAngleValue;
    attribute def WaterTemperature :> ISQ::ThermodynamicTemperatureValue;
    attribute def Salinity :> Real;
    
    item def SensorData {
        attribute depth : WaterDepth;
        attribute obstacleDistance : ISQ::LengthValue;
        attribute orientation : ISQ::PlaneAngleValue;
        attribute temperature : WaterTemperature;
        attribute salinity : Salinity;
        attribute timestamp : ISQ::DurationValue;
    }
    
    item def PropulsionCommand {
        attribute tailFrequency : TailBeatFrequency;
        attribute tailAmplitude : ISQ::PlaneAngleValue;
        attribute leftPectoralAngle : FinAngle;
        attribute rightPectoralAngle : FinAngle;
    }
    
    item def EnvironmentalData {
        attribute waterTemp : WaterTemperature;
        attribute salinity : Salinity;
        attribute currentVelocity : ISQ::SpeedValue;
        attribute locationX : ISQ::LengthValue;
        attribute locationY : ISQ::LengthValue;
        attribute locationZ : ISQ::LengthValue;
    }
    
    port def SensorPort {
        out sensorData : SensorData;
    }
    
    port def ActuatorPort {
        in propulsionCmd : PropulsionCommand;
    }
    
    port def PowerPort {
        out batteryLevel : BatteryLevel;
        in powerDraw : ISQ::PowerValue;
    }
    
    port def CommunicationPort {
        out telemetryData : EnvironmentalData;
        in missionCommands : NavigationCommand;
    }
    
    part def TailActuator {
        port actuatorInput : ActuatorPort;
        port powerIn : PowerPort;
        attribute currentFrequency : TailBeatFrequency;
        attribute currentAmplitude : ISQ::PlaneAngleValue;
        attribute maxFrequency : TailBeatFrequency;
    }
    
    part def PectoralFinActuator {
        port actuatorInput : ActuatorPort;
        port powerIn : PowerPort;
        attribute currentAngle : FinAngle;
        attribute maxAngle : FinAngle;
        attribute side : String;
    }
    
    part def ProximitySensor {
        port sensorOutput : SensorPort;
        port powerIn : PowerPort;
        attribute detectionRange : ISQ::LengthValue;
        attribute updateRate : ISQ::FrequencyValue;
    }
    
    part def DepthSensor {
        port sensorOutput : SensorPort;
        port powerIn : PowerPort;
        attribute maxDepth : WaterDepth;
        attribute accuracy : ISQ::LengthValue;
    }
    
    part def InertialMeasurementUnit {
        port sensorOutput : SensorPort;
        port powerIn : PowerPort;
        attribute orientationAccuracy : ISQ::PlaneAngleValue;
        attribute gyroRange : ISQ::AngularVelocityValue;
    }
    
    part def EnvironmentalSensor {
        port sensorOutput : SensorPort;
        port powerIn : PowerPort;
        attribute tempRangeMin : WaterTemperature;
        attribute tempRangeMax : WaterTemperature;
        attribute salinityRangeMin : Real;
        attribute salinityRangeMax : Real;
    }
    
    part def BatteryPack {
        port powerOutput : PowerPort;
        attribute capacity : ISQ::EnergyValue;
        attribute currentCharge : BatteryLevel;
        attribute voltage : ISQ::ElectricPotentialValue;
    }
    
    part def NavigationController {
        port sensorInput : SensorPort;
        port commandOutput : ActuatorPort;
        port powerIn : PowerPort;
        port commPort : CommunicationPort;
        attribute currentMode : SwimmingMode;
        attribute targetDepth : WaterDepth;
        attribute targetSpeed : SwimSpeed;
    }
    
    part def CommunicationModule {
        port commPort : CommunicationPort;
        port powerIn : PowerPort;
        attribute transmitPower : ISQ::PowerValue;
        attribute range : ISQ::LengthValue;
    }
    
    action def SenseEnvironment {
        out environmentData : SensorData;
    }
    
    action def ProcessSensorData {
        in rawData : SensorData;
        out processedData : SensorData;
        out obstacleDetected : ObstacleDetected;
    }
    
    action def DetermineSwimmingMode {
        in sensorData : SensorData;
        in currentMode : SwimmingMode;
        in batteryLevel : BatteryLevel;
        out newMode : SwimmingMode;
    }
    
    action def GeneratePropulsionCommand {
        in mode : SwimmingMode;
        in sensorData : SensorData;
        in targetDepth : WaterDepth;
        in targetSpeed : SwimSpeed;
        out command : PropulsionCommand;
    }
    
    action def ActuateTail {
        in command : PropulsionCommand;
        out thrust : ISQ::ForceValue;
    }
    
    action def ActuatePectoralFins {
        in command : PropulsionCommand;
        out maneuveringForce : ISQ::ForceValue;
        out torque : ISQ::TorqueValue;
    }
    
    action def MonitorBattery {
        out batteryStatus : BatteryLevel;
    }
    
    action def CollectEnvironmentalData {
        in sensorData : SensorData;
        out envData : EnvironmentalData;
    }
    
    action def TransmitTelemetry {
        in envData : EnvironmentalData;
        in batteryStatus : BatteryLevel;
    }
    
    action def AutonomousSwimming {
        out missionData : EnvironmentalData;
        
        first start;
        then merge continuousOperation;
        
        then action sense : SenseEnvironment {
            out environmentData : SensorData;
        }
        
        then action process : ProcessSensorData {
            in rawData = sense.environmentData;
            out processedData : SensorData;
            out obstacleDetected : ObstacleDetected;
        }
        
        then action monitorPower : MonitorBattery {
            out batteryStatus : BatteryLevel;
        }
        
        then decide;
            if monitorPower.batteryStatus < 15.0 then emergencyReturn;
            if monitorPower.batteryStatus >= 15.0 then continueSwimming;
        
        action continueSwimming {
            action determineMode : DetermineSwimmingMode {
                in sensorData = process.processedData;
                in currentMode;
                in batteryLevel = monitorPower.batteryStatus;
                out newMode : SwimmingMode;
            }
            
            then action generateCommand : GeneratePropulsionCommand {
                in mode = determineMode.newMode;
                in sensorData = process.processedData;
                in targetDepth;
                in targetSpeed;
                out command : PropulsionCommand;
            }
            
            then action actuateTail : ActuateTail {
                in command = generateCommand.command;
                out thrust : ISQ::ForceValue;
            }
            
            then action actuateFins : ActuatePectoralFins {
                in command = generateCommand.command;
                out maneuveringForce : ISQ::ForceValue;
                out torque : ISQ::TorqueValue;
            }
            
            then action collectData : CollectEnvironmentalData {
                in sensorData = process.processedData;
                out envData : EnvironmentalData;
            }
            
            then action transmit : TransmitTelemetry {
                in envData = collectData.envData;
                in batteryStatus = monitorPower.batteryStatus;
            }
        }
        
        then continuousOperation;
        
        action emergencyReturn;
        then done;
    }
    
    state def SwimmingStateMachine {
        entry; then idle;
        
        state idle {
            entry assign powerMode : String;
        }
        
        transition idle_to_cruise
            first idle
            accept NavigationCommand
            then cruise;
        
        state cruise {
            entry assign currentSpeed : SwimSpeed;
        }
        
        transition cruise_to_maneuver
            first cruise
            accept ObstacleDetected
            then maneuver;
        
        state maneuver {
            entry assign avoidanceAngle : FinAngle;
        }
        
        transition maneuver_to_cruise
            first maneuver
            then cruise;
        
        transition cruise_to_stationkeeping
            first cruise
            then stationKeeping;
        
        state stationKeeping {
            entry assign holdPositionX : ISQ::LengthValue;
        }
        
        transition stationkeeping_to_cruise
            first stationKeeping
            accept NavigationCommand
            then cruise;
        
        transition cruise_to_surface
            first cruise
            accept EmergencySignal
            then surface;
        
        state surface {
            entry assign targetDepth : WaterDepth;
        }
        
        transition surface_to_idle
            first surface
            then idle;
    }
    
    part def RoboticFish {
        doc /*
            A biomimetic robotic fish system designed for autonomous underwater exploration,
            environmental monitoring, and oceanographic data collection. The system mimics
            natural fish locomotion using an oscillating tail and pectoral fins for propulsion
            and maneuvering, enabling efficient and stealthy operation in aquatic environments.
        */
        
        attribute bodyLength : ISQ::LengthValue;
        attribute maxSwimSpeed : SwimSpeed;
        attribute operatingDepth : WaterDepth;
        attribute missionDuration : ISQ::DurationValue;
        attribute mass : ISQ::MassValue;
    }
    
    part roboticFish : RoboticFish {
        attribute bodyLength = 0.5 [SI::m];
        attribute maxSwimSpeed = 1.5 [SI::'m/s'];
        attribute operatingDepth = 50.0 [SI::m];
        attribute missionDuration = 4.0 [SI::h];
        attribute mass = 3.5 [SI::kg];
        
        perform action autonomousSwim[*] ordered references AutonomousSwimming;
        exhibit states : SwimmingStateMachine;
        
        part navigationCtrl : NavigationController {
            perform autonomousSwim.continueSwimming.determineMode;
            perform autonomousSwim.continueSwimming.generateCommand;
        }
        
        part tailActuator : TailActuator {
            attribute maxFrequency = 3.0 [SI::Hz];
            perform autonomousSwim.continueSwimming.actuateTail;
        }
        
        part leftPectoralFin : PectoralFinActuator {
            attribute side = "left";
            attribute maxAngle = 45.0 [SI::'°'];
            perform autonomousSwim.continueSwimming.actuateFins;
        }
        
        part rightPectoralFin : PectoralFinActuator {
            attribute side = "right";
            attribute maxAngle = 45.0 [SI::'°'];
            perform autonomousSwim.continueSwimming.actuateFins;
        }
        
        part proximitySensor : ProximitySensor {
            attribute detectionRange = 2.0 [SI::m];
            attribute updateRate = 10.0 [SI::Hz];
            perform autonomousSwim.sense;
        }
        
        part depthSensor : DepthSensor {
            attribute maxDepth = 100.0 [SI::m];
            attribute accuracy = 0.1 [SI::m];
            perform autonomousSwim.sense;
        }
        
        part imu : InertialMeasurementUnit {
            attribute orientationAccuracy = 0.5 [SI::'°'];
            perform autonomousSwim.sense;
        }
        
        part envSensor : EnvironmentalSensor {
            perform autonomousSwim.continueSwimming.collectData;
        }
        
        part battery : BatteryPack {
            attribute capacity = 50.0 [SI::'W*h'];
            attribute voltage = 12.0 [SI::V];
            perform autonomousSwim.monitorPower;
        }
        
        part commModule : CommunicationModule {
            attribute transmitPower = 5.0 [SI::W];
            attribute range = 500.0 [SI::m];
            perform autonomousSwim.continueSwimming.transmit;
        }
        
        connection sensorToController connect 
            proximitySensor.sensorOutput to navigationCtrl.sensorInput;
        connection depthToController connect 
            depthSensor.sensorOutput to navigationCtrl.sensorInput;
        connection imuToController connect 
            imu.sensorOutput to navigationCtrl.sensorInput;
        connection envSensorToController connect 
            envSensor.sensorOutput to navigationCtrl.sensorInput;
        connection controllerToTail connect 
            navigationCtrl.commandOutput to tailActuator.actuatorInput;
        connection controllerToLeftFin connect 
            navigationCtrl.commandOutput to leftPectoralFin.actuatorInput;
        connection controllerToRightFin connect 
            navigationCtrl.commandOutput to rightPectoralFin.actuatorInput;
        connection batteryToNavigation connect 
            battery.powerOutput to navigationCtrl.powerIn;
        connection batteryToTail connect 
            battery.powerOutput to tailActuator.powerIn;
        connection batteryToLeftFin connect 
            battery.powerOutput to leftPectoralFin.powerIn;
        connection batteryToRightFin connect 
            battery.powerOutput to rightPectoralFin.powerIn;
        connection batteryToProximity connect 
            battery.powerOutput to proximitySensor.powerIn;
        connection batteryToDepth connect 
            battery.powerOutput to depthSensor.powerIn;
        connection batteryToIMU connect 
            battery.powerOutput to imu.powerIn;
        connection batteryToEnvSensor connect 
            battery.powerOutput to envSensor.powerIn;
        connection batteryToComms connect 
            battery.powerOutput to commModule.powerIn;
        connection navigationToComms connect 
            navigationCtrl.commPort to commModule.commPort;
    }
    
    requirement def MissionRequirement {
        doc /*
            The robotic fish shall autonomously navigate underwater environments
            to collect environmental data and transmit telemetry.
        */
        subject fish : RoboticFish;
    }
    
    requirement def PropulsionRequirement {
        doc /*
            The robotic fish shall achieve biomimetic swimming through tail oscillation
            with frequency range suitable for efficient propulsion.
        */
        subject tailActuator : TailActuator;
        require constraint {
            tailActuator.currentFrequency >= 0.5 [SI::Hz] and 
            tailActuator.currentFrequency <= tailActuator.maxFrequency
        }
    }
    
    requirement def ManeuverabilityRequirement {
        doc /*
            The robotic fish shall maneuver using pectoral fins with minimum turning
            radius proportional to body length.
        */
        subject fish : RoboticFish;
        require constraint {
            fish.bodyLength * 2.0 >= 0.3 [SI::m]
        }
    }
    
    requirement def EnduranceRequirement {
        doc /*
            The robotic fish shall operate continuously for minimum mission duration
            on a single battery charge.
        */
        subject fish : RoboticFish;
        require constraint {
            fish.missionDuration >= 2.0 [SI::h]
        }
    }
    
    requirement def ObstacleAvoidanceRequirement {
        doc /*
            The robotic fish shall detect and avoid obstacles autonomously using
            proximity sensors with adequate detection range.
        */
        subject sensor : ProximitySensor;
        require constraint {
            sensor.detectionRange >= 1.0 [SI::m]
        }
    }
    
    requirement def DepthRatingRequirement {
        doc /*
            The robotic fish shall operate safely at specified maximum depth
            without structural failure.
        */
        subject fish : RoboticFish;
        require constraint {
            fish.operatingDepth <= 50.0 [SI::m]
        }
    }
    
    requirement def BatteryManagementRequirement {
        doc /*
            The robotic fish shall monitor battery level and initiate emergency
            return when charge drops below safety threshold.
        */
        subject battery : BatteryPack;
        require constraint {
            battery.currentCharge >= 15.0
        }
    }
    
    requirement <'RF-001'> autonomousNavigationMission : MissionRequirement {
        doc /*
            Primary mission requirement for autonomous underwater navigation
            and environmental data collection.
        */
        assume constraint environmentalConditions {
            doc /*
                Operating environment is freshwater or saltwater with visibility > 0.5m,
                temperature range 5-30°C, and current velocity < 0.5 m/s.
            */
        }
        require PropulsionRequirement;
        require ManeuverabilityRequirement;
        require EnduranceRequirement;
        require ObstacleAvoidanceRequirement;
        require DepthRatingRequirement;
        require BatteryManagementRequirement;
    }
}
