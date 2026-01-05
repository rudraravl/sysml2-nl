package AnybotTelepresenceSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def BatteryChargeLevel :> Real {
        doc /* Battery state of charge as percentage 0-100 */
    }
    
    attribute def NetworkLatencyValue :> ISQ::TimeValue {
        doc /* Round-trip network communication delay */
    }
    
    attribute def VideoResolution :> String {
        doc /* Video resolution: 480p, 720p, 1080p */
    }
    
    attribute def AudioQualityLevel :> Real {
        doc /* Audio quality metric 0-100 */
    }
    
    item def NavigationCommand {
        attribute forwardSpeed : ISQ::SpeedValue;
        attribute turnRate : ISQ::AngularSpeedValue;
    }
    
    item def CameraControl {
        attribute panAngle : ISQ::AngleValue;
        attribute tiltAngle : ISQ::AngleValue;
        attribute zoom : Real;
    }
    
    item def RobotPose {
        attribute xPosition : ISQ::LengthValue;
        attribute yPosition : ISQ::LengthValue;
        attribute orientation : ISQ::AngleValue;
    }
    
    item def SensorReading {
        attribute obstacleDistance : ISQ::LengthValue;
        attribute obstacleDetected : Boolean;
    }
    
    item def VideoStream {
        attribute resolution : VideoResolution;
        attribute frameRate : ISQ::FrequencyValue;
    }
    
    item def AudioStream {
        attribute sampleRate : ISQ::FrequencyValue;
        attribute quality : AudioQualityLevel;
    }
    
    port def VideoPort {
        out stream : VideoStream;
    }
    
    port def AudioBidirectionalPort {
        in remoteAudio : AudioStream;
        out localAudio : AudioStream;
    }
    
    port def ControlCommandPort {
        in navCommand : NavigationCommand;
        in cameraCommand : CameraControl;
    }
    
    port def TelemetryPort {
        out robotPose : RobotPose;
        out batteryLevel : BatteryChargeLevel;
        out sensorData : SensorReading;
    }
    
    port def PowerPort {
        in powerSupply : ISQ::PowerValue;
    }
    
    part def CameraModule {
        attribute currentPan : ISQ::AngleValue;
        attribute currentTilt : ISQ::AngleValue;
        attribute currentZoom : Real;
        attribute videoResolution : VideoResolution;
        
        port videoOutput : VideoPort;
        port powerInput : PowerPort;
        
        action adjustCamera {
            in command : CameraControl;
            out newPan : ISQ::AngleValue;
            out newTilt : ISQ::AngleValue;
        }
        
        action captureVideo {
            out videoData : VideoStream;
        }
    }
    
    part def AudioModule {
        attribute speakerVolume : Real;
        attribute microphoneSensitivity : Real;
        
        port audioInterface : AudioBidirectionalPort;
        port powerInput : PowerPort;
        
        action processAudio {
            in remoteAudio : AudioStream;
            out localAudio : AudioStream;
        }
    }
    
    part def MobilityBase {
        attribute currentPose : RobotPose;
        attribute maxSpeed : ISQ::SpeedValue;
        attribute wheelDiameter : ISQ::LengthValue;
        
        port powerInput : PowerPort;
        
        action executeNavigation {
            in command : NavigationCommand;
            in obstaclePresent : Boolean;
            out newPose : RobotPose;
        }
    }
    
    part def ProximitySensor {
        attribute detectionRange : ISQ::LengthValue;
        attribute minimumDistance : ISQ::LengthValue;
        
        port powerInput : PowerPort;
        
        action detectObstacle {
            out reading : SensorReading;
        }
    }
    
    part def BatterySystem {
        attribute capacity : ISQ::EnergyValue;
        attribute currentCharge : BatteryChargeLevel;
        attribute voltage : ISQ::VoltageValue;
        attribute dischargePower : ISQ::PowerValue;
        
        port powerOutput : PowerPort;
        
        action monitorCharge {
            out chargeLevel : BatteryChargeLevel;
        }
        
        action supplyPower {
            in demand : ISQ::PowerValue;
            out available : ISQ::PowerValue;
        }
    }
    
    part def NetworkController {
        attribute bandwidth : ISQ::DataRateValue;
        attribute latency : NetworkLatencyValue;
        attribute connectionActive : Boolean;
        
        action transmitTelemetry {
            in videoData : VideoStream;
            in audioData : AudioStream;
            in poseData : RobotPose;
            in batteryData : BatteryChargeLevel;
            out transmitLatency : NetworkLatencyValue;
        }
        
        action receiveCommands {
            out navCmd : NavigationCommand;
            out camCmd : CameraControl;
            out receiveLatency : NetworkLatencyValue;
        }
    }
    
    part def ControlProcessor {
        attribute processingLoad : Real;
        
        port powerInput : PowerPort;
        
        action coordinateSubsystems {
            in navCmd : NavigationCommand;
            in camCmd : CameraControl;
            in sensorInput : SensorReading;
            out mobilityCmd : NavigationCommand;
            out cameraCmd : CameraControl;
        }
    }
    
    part def AnybotRobot {
        doc /* Mobile telepresence robot enabling remote presence through real-time video, audio, and navigation */
        
        part camera : CameraModule {
            attribute videoResolution = "1080p";
            attribute currentPan = 0.0 [SI::rad];
            attribute currentTilt = 0.0 [SI::rad];
            attribute currentZoom = 1.0;
        }
        
        part audio : AudioModule {
            attribute speakerVolume = 80.0;
            attribute microphoneSensitivity = 75.0;
        }
        
        part mobility : MobilityBase {
            attribute maxSpeed = 1.2 [SI::m/SI::s];
            attribute wheelDiameter = 0.15 [SI::m];
        }
        
        part frontSensor : ProximitySensor {
            attribute detectionRange = 2.5 [SI::m];
            attribute minimumDistance = 0.3 [SI::m];
        }
        
        part leftSensor : ProximitySensor {
            attribute detectionRange = 1.5 [SI::m];
            attribute minimumDistance = 0.3 [SI::m];
        }
        
        part rightSensor : ProximitySensor {
            attribute detectionRange = 1.5 [SI::m];
            attribute minimumDistance = 0.3 [SI::m];
        }
        
        part battery : BatterySystem {
            attribute capacity = 120.0 [SI::W*SI::h];
            attribute currentCharge = 95.0;
            attribute voltage = 24.0 [SI::V];
        }
        
        part network : NetworkController {
            attribute bandwidth = 15.0 [SI::Mbit/SI::s];
            attribute connectionActive = true;
        }
        
        part controller : ControlProcessor {
            attribute processingLoad = 45.0;
        }
        
        port commandInterface : ControlCommandPort;
        port telemetryInterface : TelemetryPort;
        
        connect battery.powerOutput to camera.powerInput;
        connect battery.powerOutput to audio.powerInput;
        connect battery.powerOutput to mobility.powerInput;
        connect battery.powerOutput to frontSensor.powerInput;
        connect battery.powerOutput to leftSensor.powerInput;
        connect battery.powerOutput to rightSensor.powerInput;
        connect battery.powerOutput to controller.powerInput;
        
        perform action enableTelepresence;
    }
    
    part def OperatorStation {
        doc /* Remote control interface for operating the Anybot telepresence robot */
        
        attribute operatorIdentifier : String;
        attribute displayResolution : VideoResolution;
        
        port videoReceive : VideoPort;
        port audioInterface : AudioBidirectionalPort;
        port commandTransmit : ControlCommandPort;
        port telemetryReceive : TelemetryPort;
        
        action generateNavigationCommand {
            in userInput : String;
            out command : NavigationCommand;
        }
        
        action generateCameraCommand {
            in userInput : String;
            out command : CameraControl;
        }
        
        action displayStatus {
            in pose : RobotPose;
            in battery : BatteryChargeLevel;
            in sensors : SensorReading;
        }
    }
    
    action def EnableTelepresence {
        doc /* Primary function: Provide remote human presence through mobile robotic platform with real-time audiovisual communication */
        
        in navigationInput : NavigationCommand;
        in cameraInput : CameraControl;
        out videoOutput : VideoStream;
        out audioOutput : AudioStream;
        out poseOutput : RobotPose;
        
        first start;
        then merge mainLoop;
        
        action initializeSystem {
            action bootController;
            then action establishNetworkConnection;
            then action calibrateSensors;
            then action activateCamera;
            then action activateAudio;
        }
        
        then mainLoop;
        
        action mainLoop {
            action receiveOperatorInput {
                out navCmd : NavigationCommand;
                out camCmd : CameraControl;
            }
            
            then action processNavigation {
                in cmd : NavigationCommand;
                
                action scanEnvironment {
                    action checkFrontSensor {
                        out frontObstacle : Boolean;
                        out frontDistance : ISQ::LengthValue;
                    }
                    action checkLeftSensor {
                        out leftObstacle : Boolean;
                    }
                    action checkRightSensor {
                        out rightObstacle : Boolean;
                    }
                    out anyObstacle : Boolean;
                }
                
                then decide;
                if scanEnvironment.anyObstacle then stopMovement;
                if !scanEnvironment.anyObstacle then executeMovement;
                
                action stopMovement {
                    action haltMotors;
                    then action notifyOperator;
                }
                
                action executeMovement {
                    action controlMotors;
                    then action updateOdometry;
                }
            }
            
            then action processCamera {
                in cmd : CameraControl;
                
                action adjustPanTilt {
                    in panAngle : ISQ::AngleValue;
                    in tiltAngle : ISQ::AngleValue;
                }
                then action adjustZoom;
                then action captureVideoFrame;
            }
            
            then action processAudioCommunication {
                action captureLocalAudio;
                action receiveRemoteAudio;
                action playRemoteAudio;
            }
            
            then action transmitData {
                action compressVideo;
                action compressAudio;
                action packageTelemetry;
                then action sendOverNetwork;
            }
            
            then action checkBatteryStatus {
                out batteryLevel : BatteryChargeLevel;
            }
            
            then decide;
            if checkBatteryStatus.batteryLevel > 25.0 then mainLoop;
            if checkBatteryStatus.batteryLevel <= 25.0 then lowPowerMode;
            
            action lowPowerMode {
                action reduceVideoQuality;
                then action notifyLowBattery;
                then decide;
                if checkBatteryStatus.batteryLevel > 15.0 then mainLoop;
                if checkBatteryStatus.batteryLevel <= 15.0 then criticalBatteryMode;
            }
            
            action criticalBatteryMode {
                action disableNonEssentialSystems;
                then action alertOperator;
                then action navigateToChargingStation;
                then shutdown;
            }
        }
        
        action shutdown {
            action saveSystemState;
            then action closeNetworkConnection;
            then action powerDownSubsystems;
        }
        
        then done;
    }
    
    part telepresenceDeployment {
        doc /* Complete Anybot telepresence deployment enabling remote human interaction and presence */
        
        part robot : AnybotRobot;
        part operator : OperatorStation {
            attribute operatorIdentifier = "Operator_001";
            attribute displayResolution = "1080p";
        }
        
        connect operator.videoReceive to robot.camera.videoOutput;
        connect operator.audioInterface to robot.audio.audioInterface;
        connect operator.commandTransmit to robot.commandInterface;
        connect operator.telemetryReceive to robot.telemetryInterface;
        
        perform action enableTelepresence : EnableTelepresence;
    }
    
    requirement def TelepresenceSystemRequirements {
        doc /* Requirements for effective remote presence and interaction */
        
        requirement videoPerformanceReq {
            doc /* Video stream shall maintain minimum 720p resolution at 24fps under normal network conditions */
            require constraint {
                telepresenceDeployment.robot.camera.videoResolution == "720p" or
                telepresenceDeployment.robot.camera.videoResolution == "1080p"
            }
        }
        
        requirement networkLatencyReq {
            doc /* End-to-end network latency shall not exceed 250ms for responsive telepresence */
            require constraint {
                telepresenceDeployment.robot.network.latency < 250.0 [SI::ms]
            }
        }
        
        requirement operationalDurationReq {
            doc /* Robot shall operate continuously for minimum 3 hours on single battery charge */
            require constraint {
                telepresenceDeployment.robot.battery.capacity >= 100.0 [SI::W*SI::h]
            }
        }
        
        requirement safetyDistanceReq {
            doc /* Robot shall maintain minimum 0.3m clearance from obstacles during navigation */
            require constraint {
                telepresenceDeployment.robot.frontSensor.minimumDistance <= 0.3 [SI::m]
            }
        }
        
        requirement mobilitySpeedReq {
            doc /* Robot shall achieve maximum speed of at least 1.0 m/s for efficient navigation */
            require constraint {
                telepresenceDeployment.robot.mobility.maxSpeed >= 1.0 [SI::m/SI::s]
            }
        }
        
        requirement audioQualityReq {
            doc /* Bidirectional audio shall maintain quality level above 70 for clear communication */
            require constraint {
                telepresenceDeployment.robot.audio.speakerVolume >= 70.0 and
                telepresenceDeployment.robot.audio.microphoneSensitivity >= 70.0
            }
        }
    }
    
    requirement missionRequirement : TelepresenceSystemRequirements {
        doc /* The Anybot telepresence system shall enable remote human presence by providing 
               real-time bidirectional audiovisual communication combined with autonomous mobile 
               navigation, allowing operators to interact naturally with people and environments 
               as if physically present, while maintaining safe obstacle avoidance and reliable 
               network connectivity throughout extended operational sessions */
        
        require videoPerformanceReq;
        require networkLatencyReq;
        require operationalDurationReq;
        require safetyDistanceReq;
        require mobilitySpeedReq;
        require audioQualityReq;
    }
}
