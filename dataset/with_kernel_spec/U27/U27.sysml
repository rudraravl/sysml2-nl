package ThymioRobotModel {
    public import ISQ::*;
    public import ScalarValues::*;

    attribute def StartSignal;
    attribute def StopSignal;
    attribute def ObstacleDetectedSignal;
    attribute def ClearPathSignal;
    attribute def EdgeDetectedSignal;
    attribute def ButtonPressedSignal;
    attribute def AvoidanceCompleteSignal;

    item def ProximityReading {
        attribute distance :> ISQ::length;
        attribute detected : Boolean;
    }
    item def MotorCommand {
        attribute leftSpeed :> ISQ::speed;
        attribute rightSpeed :> ISQ::speed;
    }
    item def LEDCommand {
        attribute red : Real;
        attribute green : Real;
        attribute blue : Real;
    }
    item def AudioCommand {
        attribute frequency :> ISQ::frequency;
        attribute duration :> ISQ::time;
    }
    item def BatteryStatus {
        attribute voltage :> ISQ::electricPotential;
        attribute chargeLevel : Real;
    }

    port def MotorCommandPort {
        in command : MotorCommand;
    }
    port def ProximitySensorPort {
        out reading : ProximityReading;
    }
    port def ButtonEventPort {
        out pressed : Boolean;
    }
    port def LEDCommandPort {
        in command : LEDCommand;
    }
    port def AudioCommandPort {
        in command : AudioCommand;
    }
    port def BatteryPowerPort {
        out voltage :> ISQ::electricPotential;
    }
    port def StatusPort {
        out status : String;
    }

    action def ScanProximitySensors {
        in frontReadings[5] : ProximityReading;
        in rearReadings[2] : ProximityReading;
        in bottomReadings[2] : ProximityReading;
        out obstacleDetected : Boolean;
        out edgeDetected : Boolean;
    }
    action def ComputeAvoidanceManeuver {
        in obstacleDetected : Boolean;
        in edgeDetected : Boolean;
        out motorCommand : MotorCommand;
    }
    action def ControlMotors {
        in motorCommand : MotorCommand;
    }
    action def UpdateLEDs {
        in command : LEDCommand;
    }
    action def PlaySound {
        in command : AudioCommand;
    }
    action def StopMotors;
    action def MoveForward {
        out motorCommand : MotorCommand;
    }

    part def Wheel {
        attribute radius :> ISQ::length;
        port motorCmdPort : ~MotorCommandPort;
    }

    part def DCMotor {
        port commandPort : MotorCommandPort;
        port powerPort : ~BatteryPowerPort;
        attribute currentSpeed :> ISQ::speed;
    }

    part def ProximitySensor {
        port sensorDataPort : ProximitySensorPort;
        port powerPort : ~BatteryPowerPort;
        attribute maxRange :> ISQ::length;
    }

    part def CapacitiveTouchButton {
        port touchPort : ButtonEventPort;
        attribute isPressed : Boolean;
    }

    part def RGBLED {
        port ledCmdPort : LEDCommandPort;
        port powerPort : ~BatteryPowerPort;
        attribute color : String;
    }

    part def PiezoSpeaker {
        port speakerCmdPort : AudioCommandPort;
        port powerPort : ~BatteryPowerPort;
        attribute tone :> ISQ::frequency;
    }

    part def Battery {
        port powerPort : BatteryPowerPort;
        attribute capacity :> ISQ::energy;
        attribute currentCharge :> ISQ::energy;
        attribute voltage :> ISQ::electricPotential;
    }

    part def Microcontroller {
        port leftMotorCmdPort : MotorCommandPort;
        port rightMotorCmdPort : MotorCommandPort;
        port frontSensorPorts[5] : ~ProximitySensorPort;
        port rearSensorPorts[2] : ~ProximitySensorPort;
        port bottomSensorPorts[2] : ~ProximitySensorPort;
        port touchPorts[5] : ~ButtonEventPort;
        port topLedCmdPort : LEDCommandPort;
        port bottomLedCmdPort : LEDCommandPort;
        port speakerCmdPort : AudioCommandPort;
        port powerPort : ~BatteryPowerPort;
        port statusPort : StatusPort;
        attribute processingState : String;
    }

    part def ThymioRobot {
        attribute mass :> ISQ::mass;
        attribute length :> ISQ::length;
        attribute width :> ISQ::length;
        attribute height :> ISQ::length;
        attribute maxSpeed :> ISQ::speed;
        attribute obstacleDetected : Boolean;
        attribute edgeDetected : Boolean;
        attribute frontReadings[5] : ProximityReading;
        attribute rearReadings[2] : ProximityReading;
        attribute bottomReadings[2] : ProximityReading;
        attribute cruiseCommand : MotorCommand;
        attribute avoidanceCommand : MotorCommand;
        attribute avoidanceLEDCommand : LEDCommand;
        attribute avoidanceAudioCommand : AudioCommand;

        part leftMotor : DCMotor;
        part rightMotor : DCMotor;
        part leftWheel : Wheel;
        part rightWheel : Wheel;
        part frontSensors[5] : ProximitySensor;
        part rearSensors[2] : ProximitySensor;
        part bottomSensors[2] : ProximitySensor;
        part touchButtons[5] : CapacitiveTouchButton;
        part topLedRing : RGBLED;
        part bottomLeds : RGBLED;
        part speaker : PiezoSpeaker;
        part controller : Microcontroller;
        part battery : Battery;

        connect battery.powerPort to controller.powerPort;
        connect battery.powerPort to leftMotor.powerPort;
        connect battery.powerPort to rightMotor.powerPort;
        connect battery.powerPort to frontSensors.powerPort;
        connect battery.powerPort to rearSensors.powerPort;
        connect battery.powerPort to bottomSensors.powerPort;
        connect battery.powerPort to topLedRing.powerPort;
        connect battery.powerPort to bottomLeds.powerPort;
        connect battery.powerPort to speaker.powerPort;

        connect controller.leftMotorCmdPort to leftMotor.commandPort;
        connect controller.rightMotorCmdPort to rightMotor.commandPort;
        connect leftMotor.commandPort to leftWheel.motorCmdPort;
        connect rightMotor.commandPort to rightWheel.motorCmdPort;

        connect frontSensors.sensorDataPort to controller.frontSensorPorts;
        connect rearSensors.sensorDataPort to controller.rearSensorPorts;
        connect bottomSensors.sensorDataPort to controller.bottomSensorPorts;

        connect touchButtons.touchPort to controller.touchPorts;

        connect controller.topLedCmdPort to topLedRing.ledCmdPort;
        connect controller.bottomLedCmdPort to bottomLeds.ledCmdPort;
        connect controller.speakerCmdPort to speaker.speakerCmdPort;

        exhibit state thymioStates {
            ref robotController : Microcontroller = controller;

            entry; then off;

            state off {
                entry action StopMotors;
            }

            state idle {
                do action StopMotors;
            }

            state scanning {
                do action ScanProximitySensors {
                    in frontReadings = frontReadings;
                    in rearReadings = rearReadings;
                    in bottomReadings = bottomReadings;
                    out obstacleDetected = obstacleDetected;
                    out edgeDetected = edgeDetected;
                }
            }

            state cruising {
                entry action MoveForward {
                    out motorCommand = cruiseCommand;
                }
                do action ControlMotors {
                    in motorCommand = cruiseCommand;
                }
            }

            state avoidingObstacle {
                entry action ComputeAvoidanceManeuver {
                    in obstacleDetected = true;
                    in edgeDetected = false;
                    out motorCommand = avoidanceCommand;
                }
                do action ControlMotors {
                    in motorCommand = avoidanceCommand;
                }
                do action UpdateLEDs {
                    in command = avoidanceLEDCommand;
                }
                do action PlaySound {
                    in command = avoidanceAudioCommand;
                }
            }

            state avoidingEdge {
                entry action ComputeAvoidanceManeuver {
                    in obstacleDetected = false;
                    in edgeDetected = true;
                    out motorCommand = avoidanceCommand;
                }
                do action ControlMotors {
                    in motorCommand = avoidanceCommand;
                }
                do action UpdateLEDs {
                    in command = avoidanceLEDCommand;
                }
                do action PlaySound {
                    in command = avoidanceAudioCommand;
                }
            }

            transition off_to_idle
                first off
                accept StartSignal
                then idle;

            transition idle_to_scanning
                first idle
                accept ButtonPressedSignal
                then scanning;

            transition scanning_to_cruising
                first scanning
                accept ClearPathSignal
                if obstacleDetected == false and edgeDetected == false
                then cruising;

            transition scanning_to_avoidingObstacle
                first scanning
                accept ObstacleDetectedSignal
                if obstacleDetected == true
                then avoidingObstacle;

            transition scanning_to_avoidingEdge
                first scanning
                accept EdgeDetectedSignal
                if edgeDetected == true
                then avoidingEdge;

            transition cruising_to_avoidingObstacle
                first cruising
                accept ObstacleDetectedSignal
                then avoidingObstacle;

            transition cruising_to_avoidingEdge
                first cruising
                accept EdgeDetectedSignal
                then avoidingEdge;

            transition avoidingObstacle_to_scanning
                first avoidingObstacle
                accept AvoidanceCompleteSignal
                then scanning;

            transition avoidingEdge_to_scanning
                first avoidingEdge
                accept AvoidanceCompleteSignal
                then scanning;

            transition to_off
                first idle accept StopSignal then off;
            transition scanning_to_off
                first scanning accept StopSignal then off;
            transition cruising_to_off
                first cruising accept StopSignal then off;
            transition avoidingObstacle_to_off
                first avoidingObstacle accept StopSignal then off;
            transition avoidingEdge_to_off
                first avoidingEdge accept StopSignal then off;
        }
    }

    requirement def AutonomousNavigationRequirement {
        subject robot : ThymioRobot;
        doc /* The robot shall continuously scan its surroundings using its proximity sensors and cruise forward when the path is clear. */;
    }

    requirement def ObstacleAvoidanceRequirement {
        subject robot : ThymioRobot;
        doc /* Upon detecting an obstacle, the robot shall automatically calculate and execute an avoidance maneuver to navigate around the obstacle. */;
    }

    requirement def EdgeDetectionRequirement {
        subject robot : ThymioRobot;
        doc /* The robot shall detect surface edges using its downward-facing sensors to prevent falling off elevated surfaces. */;
    }

    requirement def VisualFeedbackRequirement {
        subject robot : ThymioRobot;
        doc /* The robot shall provide visual feedback through its RGB LEDs, changing color to indicate different operational modes and events. */;
    }

    requirement def AudibleFeedbackRequirement {
        subject robot : ThymioRobot;
        doc /* The robot shall produce audible feedback through its piezo speaker during avoidance maneuvers and other events. */;
    }

    requirement def UserInteractionRequirement {
        subject robot : ThymioRobot;
        doc /* The robot shall accept user commands through capacitive touch buttons on its top shell for starting programs and giving commands. */;
    }
}
