package AutonomousEntertainmentRobot {
    import ScalarValues::*;
    import ISQ::*;
    import ISQBase::*;

    // ===== Value Types =====
    value def SpeedValue :> Real {
        doc "Movement speed in meters per second.";
    }
    value def VolumeValue :> Real {
        doc "Sound volume in decibels.";
    }
    value def ChargePercent :> Real {
        doc "Battery charge level as a percentage (0 to 100).";
    }
    value def PowerValue :> Real {
        doc "Electrical power in watts.";
    }
    value def DistanceValue :> Real {
        doc "Distance in meters.";
    }
    value def EngagementLevel :> Real {
        doc "Audience engagement level from 0.0 to 1.0.";
    }

    // ===== Item / Signal Types =====
    item def AudiencePresence {
        attribute present : Boolean;
        attribute engagement : EngagementLevel;
    }

    item def PowerStatus {
        attribute chargeLevel : ChargePercent;
        attribute lowBattery : Boolean;
    }

    item def NavigationGoal {
        attribute targetX : Real;
        attribute targetY : Real;
        attribute reached : Boolean;
    }

    item def PerformanceCommand {
        attribute performanceType : String;
        attribute content : String;
    }

    item def DockingStatus {
        attribute docked : Boolean;
        attribute powerAvailable : Boolean;
    }

    // Event signals for state machine
    item def AudiencePresent;
    item def InteractionRequest;
    item def ResumePerformance;
    item def LowBattery;
    item def ChargeComplete;
    item def FaultDetected;
    item def FaultCleared;

    // ===== Port Definitions =====
    port def MotionPort {
        out speed : SpeedValue;
        out moving : Boolean;
    }

    port def AudioPort {
        out volume : VolumeValue;
        out playing : Boolean;
    }

    port def SensorPort {
        out audience : AudiencePresence;
    }

    port def PowerPort {
        out status : PowerStatus;
        in charging : Boolean;
    }

    port def NavigationPort {
        out goal : NavigationGoal;
        in destination : NavigationGoal;
    }

    port def ChargingInterfacePort {
        out docking : DockingStatus;
        in requestCharge : Boolean;
    }

    port def StationPort {
        out powerAvailable : Boolean;
        in docked : Boolean;
    }

    // ===== Requirements =====
    requirement def MaxSpeedConstraint {
        doc "The robot must not exceed a maximum movement speed for safety.";
        constraint maxSpeedConstraint { maxSpeed <= 1.5 }
        attribute maxSpeed : SpeedValue;
    }

    requirement def MaxVolumeConstraint {
        doc "The robot must not exceed a maximum sound volume for safety.";
        constraint maxVolumeConstraint { maxVolume <= 85.0 }
        attribute maxVolume : VolumeValue;
    }

    requirement def AutonomousChargingRequirement {
        doc "The robot must autonomously navigate to the charging station when battery is low.";
        constraint chargeThresholdConstraint { chargeThreshold <= 20.0 }
        attribute chargeThreshold : ChargePercent;
    }

    requirement def AudienceDetectionRequirement {
        doc "The robot must detect audience presence before beginning a performance.";
    }

    requirement def SafetyDiagnosticsRequirement {
        doc "The robot must enter an error state and run self-diagnostics when a fault is detected.";
    }

    // ===== Subsystem Parts =====
    part def MotionSystem {
        port motionOut : MotionPort;
        attribute currentSpeed : SpeedValue = 0.0;
        attribute maxAllowedSpeed : SpeedValue = 1.5;
        attribute isMoving : Boolean = false;

        action performDance {
            in choreography : String;
        }

        action moveToLocation {
            in destination : NavigationGoal;
        }

        action stopMotion;
    }

    part def AudioSystem {
        port audioOut : AudioPort;
        attribute currentVolume : VolumeValue = 0.0;
        attribute maxAllowedVolume : VolumeValue = 85.0;
        attribute isPlaying : Boolean = false;

        action playMusic {
            in track : String;
        }

        action tellStory {
            in story : String;
        }

        action performComedy {
            in routine : String;
        }

        action stopAudio;
    }

    part def SensorSystem {
        port sensorOut : SensorPort;
        attribute detectionRange : DistanceValue = 5.0;
        attribute lastAudience : AudiencePresence;

        action detectAudience {
            out audience : AudiencePresence;
        }

        action gaugeEngagement {
            in audience : AudiencePresence;
            out engagement : EngagementLevel;
        }
    }

    part def BatterySystem {
        port powerOut : PowerPort;
        attribute chargeLevel : ChargePercent = 100.0;
        attribute lowThreshold : ChargePercent = 20.0;
        attribute capacity : PowerValue = 100.0;
        attribute isCharging : Boolean = false;

        action monitorCharge {
            out status : PowerStatus;
        }

        action recharge {
            in power : PowerValue;
        }

        action discharge {
            out rate : PowerValue;
        }
    }

    part def NavigationSystem {
        port navOut : NavigationPort;
        port navIn : NavigationPort;
        attribute positionX : Real = 0.0;
        attribute positionY : Real = 0.0;
        attribute stationLocationX : Real = 0.0;
        attribute stationLocationY : Real = 0.0;

        action locateChargingStation {
            out goal : NavigationGoal;
        }

        action planPath {
            in destination : NavigationGoal;
        }

        action navigate {
            in destination : NavigationGoal;
        }
    }

    part def ControlSystem {
        port motionCmd : MotionPort;
        port audioCmd : AudioPort;
        port sensorIn : SensorPort;
        port powerIn : PowerPort;
        port navCmd : NavigationPort;

        action decidePerformance {
            in audience : AudiencePresence;
            out command : PerformanceCommand;
        }

        action managePower {
            in status : PowerStatus;
            out seekCharger : Boolean;
        }

        action handleFault {
            in faultCode : String;
        }
    }

    // ===== Robot Part =====
    part def EntertainmentRobot {
        port chargingInterface : ChargingInterfacePort;

        part motion : MotionSystem;
        part audio : AudioSystem;
        part sensors : SensorSystem;
        part battery : BatterySystem;
        part navigation : NavigationSystem;
        part controller : ControlSystem;

        satisfy MaxSpeedConstraint by motion.maxAllowedSpeed;
        satisfy MaxVolumeConstraint by audio.maxAllowedVolume;
        satisfy AutonomousChargingRequirement by battery.lowThreshold;
        satisfy AudienceDetectionRequirement by sensors;
        satisfy SafetyDiagnosticsRequirement by controller;

        connection motionConnection connect controller.motionCmd to motion.motionOut;
        connection audioConnection connect controller.audioCmd to audio.audioOut;
        connection sensorConnection connect sensors.sensorOut to controller.sensorIn;
        connection powerConnection connect battery.powerOut to controller.powerIn;
        connection navCommandConnection connect controller.navCmd to navigation.navIn;
        connection navFeedbackConnection connect navigation.navOut to controller.navCmd;

        state def RobotStateMachine {
            initial start;

            state idle {
                doc "Waiting for an audience to arrive.";
                entry action {
                    motion.stopMotion();
                    audio.stopAudio();
                }
            }

            state performing {
                doc "Actively entertaining the audience with music, stories, or comedy.";
                entry action {
                    controller.decidePerformance(sensors.sensorOut.audience);
                }
            }

            state interacting {
                doc "Directly interacting with audience members.";
            }

            state charging {
                doc "Managing power by recharging at the docking station.";
                entry action {
                    battery.recharge(50.0);
                }
            }

            state error {
                doc "Self-diagnostics mode when a fault is detected.";
                entry action {
                    motion.stopMotion();
                    audio.stopAudio();
                    controller.handleFault("general");
                }
            }

            transition idle_to_performing
                first idle
                accept AudiencePresent
                    when sensors.sensorOut.audience.present == true
                then performing;

            transition performing_to_interacting
                first performing
                accept InteractionRequest
                then interacting;

            transition interacting_to_performing
                first interacting
                accept ResumePerformance
                then performing;

            transition performing_to_idle
                first performing
                accept AudiencePresent
                    when sensors.sensorOut.audience.present == false
                then idle;

            transition interacting_to_idle
                first interacting
                accept AudiencePresent
                    when sensors.sensorOut.audience.present == false
                then idle;

            transition performing_to_charging
                first performing
                accept LowBattery
                    when battery.powerOut.status.chargeLevel <= battery.lowThreshold
                then charging;

            transition interacting_to_charging
                first interacting
                accept LowBattery
                    when battery.powerOut.status.chargeLevel <= battery.lowThreshold
                then charging;

            transition idle_to_charging
                first idle
                accept LowBattery
                    when battery.powerOut.status.chargeLevel <= battery.lowThreshold
                then charging;

            transition charging_to_idle
                first charging
                accept ChargeComplete
                    when battery.powerOut.status.chargeLevel >= 100.0
                then idle;

            transition idle_to_error
                first idle
                accept FaultDetected
                then error;

            transition performing_to_error
                first performing
                accept FaultDetected
                then error;

            transition interacting_to_error
                first interacting
                accept FaultDetected
                then error;

            transition charging_to_error
                first charging
                accept FaultDetected
                then error;

            transition error_to_idle
                first error
                accept FaultCleared
                then idle;
        }

        action performForAudience {
            in audience : AudiencePresence;
            // Decide performance type based on engagement level
            if audience.engagement > 0.5 {
                audio.playMusic("upbeat_track");
                motion.performDance("energetic_choreography");
            } else {
                audio.tellStory("engaging_story");
            }
        }

        action seekCharger {
            // Stop current activity, locate and navigate to charging station
            motion.stopMotion();
            audio.stopAudio();
            navigation.locateChargingStation();
            navigation.navigate(NavigationGoal { targetX = navigation.stationLocationX; targetY = navigation.stationLocationY; reached = false; });
        }
    }

    // ===== Charging Station Part =====
    part def ChargingStation {
        port stationPort : StationPort;
        attribute outputPower : PowerValue = 50.0;
        attribute locationX : Real = 0.0;
        attribute locationY : Real = 0.0;
        attribute isOccupied : Boolean = false;

        action providePower {
            out power : PowerValue;
        }

        action detectDocking {
            in docked : Boolean;
        }

        action indicateStatus {
            out available : Boolean;
        }
    }

    // ===== Top-Level System =====
    part def EntertainmentRobotSystem {
        doc "Autonomous entertainment robot system consisting of a mobile robot and a dedicated charging station.";

        part robot : EntertainmentRobot;
        part station : ChargingStation;

        connection dockingConnection connect robot.chargingInterface to station.stationPort;

        requirement constraint SafetyConstraints {
            doc "The entire system operates within defined safety constraints on maximum movement speed and sound volume.";
            constraint speedLimit { robot.motion.maxAllowedSpeed <= 1.5 }
            constraint volumeLimit { robot.audio.maxAllowedVolume <= 85.0 }
        }
    }
}
