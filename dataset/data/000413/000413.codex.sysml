package ThymioBasedExplorerSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    value def Percent : Real {
        doc /* Dimensionless percent value from 0 to 100. */
    }

    value def Millimeter : Real {
        unit = SI::mm;
    }

    value def MillimeterPerSecond : Real {
        unit = SI::mm / SI::s;
    }

    value def DegreePerSecond : Real {
        unit = SI::deg / SI::s;
    }

    value def Volt : Real {
        unit = SI::V;
    }

    value def Ampere : Real {
        unit = SI::A;
    }

    value def Lux : Real {
        unit = SI::lx;
    }

    item def ProximityFrame {
        attribute frontLeftRange : Millimeter;
        attribute frontCenterLeftRange : Millimeter;
        attribute frontCenterRange : Millimeter;
        attribute frontCenterRightRange : Millimeter;
        attribute frontRightRange : Millimeter;
        attribute rearLeftRange : Millimeter;
        attribute rearRightRange : Millimeter;
        attribute sampleAge : SI::TimeValue;
    }

    item def GroundFrame {
        attribute leftReflectance : Percent;
        attribute rightReflectance : Percent;
        attribute leftDistanceEstimate : Millimeter;
        attribute rightDistanceEstimate : Millimeter;
        attribute sampleAge : SI::TimeValue;
    }

    item def MotionCommand {
        attribute leftWheelVelocity : MillimeterPerSecond;
        attribute rightWheelVelocity : MillimeterPerSecond;
        attribute commandTimeout : SI::TimeValue;
    }

    item def LightCommand {
        attribute redIntensity : Percent;
        attribute greenIntensity : Percent;
        attribute blueIntensity : Percent;
    }

    item def SoundCommand {
        attribute frequency : SI::FrequencyValue;
        attribute duration : SI::TimeValue;
        attribute loudness : Percent;
    }

    item def BatteryStatus {
        attribute voltage : Volt;
        attribute currentDraw : Ampere;
        attribute stateOfCharge : Percent;
        attribute lowBatteryLimit : Percent;
    }

    item def UserModeCommand {
        enum def ModeKind {
            enum idle;
            enum explore;
            enum followLine;
            enum returnToSafeStop;
        }
        attribute selectedMode : ModeKind;
    }

    port def ProximitySensorPort {
        out item proximity : ProximityFrame;
    }

    port def GroundSensorPort {
        out item ground : GroundFrame;
    }

    port def MotionCommandPort {
        in item command : MotionCommand;
    }

    port def LightCommandPort {
        in item command : LightCommand;
    }

    port def SoundCommandPort {
        in item command : SoundCommand;
    }

    port def BatteryStatusPort {
        out item status : BatteryStatus;
    }

    port def UserModePort {
        in item modeCommand : UserModeCommand;
    }

    part def ThymioExplorer {
        doc /* A mobile robot system based on a Thymio educational robot. Its primary high-level function is autonomous short-range exploration of an indoor tabletop or floor area while detecting nearby obstacles, avoiding collisions, indicating status with light and sound, and stopping safely when commanded or when battery energy is insufficient. */

        attribute nominalForwardSpeed : MillimeterPerSecond = 80 [SI::mm / SI::s];
        attribute reducedForwardSpeed : MillimeterPerSecond = 35 [SI::mm / SI::s];
        attribute turnRate : DegreePerSecond = 55 [SI::deg / SI::s];
        attribute obstacleStopDistance : Millimeter = 90 [SI::mm];
        attribute obstacleAvoidDistance : Millimeter = 160 [SI::mm];
        attribute edgeReflectanceLimit : Percent = 18.0;
        attribute lowBatteryLimit : Percent = 15.0;
        attribute controlPeriod : SI::TimeValue = 50 [SI::ms];

        port userMode : UserModePort;

        part chassis : MobileBase {
            attribute length : Millimeter = 112 [SI::mm];
            attribute width : Millimeter = 110 [SI::mm];
            attribute height : Millimeter = 53 [SI::mm];
        }

        part sensorSuite : SensorSuite;
        part controller : ExplorationController;
        part drive : DifferentialDrive;
        part indicators : UserIndicators;
        part power : PowerSubsystem;

        connect sensorSuite.proximityOut to controller.proximityIn;
        connect sensorSuite.groundOut to controller.groundIn;
        connect power.batteryOut to controller.batteryIn;
        connect userMode to controller.modeIn;
        connect controller.motionOut to drive.motionIn;
        connect controller.lightOut to indicators.lightIn;
        connect controller.soundOut to indicators.soundIn;
    }

    part def MobileBase {
        attribute length : Millimeter;
        attribute width : Millimeter;
        attribute height : Millimeter;
        attribute mass : SI::MassValue = 0.27 [SI::kg];
    }

    part def SensorSuite {
        port proximityOut : ProximitySensorPort;
        port groundOut : GroundSensorPort;

        part frontProximityArray : FrontProximityArray;
        part rearProximityArray : RearProximityArray;
        part groundSensors : GroundSensorPair;

        bind proximityOut.proximity.frontLeftRange = frontProximityArray.frontLeftRange;
        bind proximityOut.proximity.frontCenterLeftRange = frontProximityArray.frontCenterLeftRange;
        bind proximityOut.proximity.frontCenterRange = frontProximityArray.frontCenterRange;
        bind proximityOut.proximity.frontCenterRightRange = frontProximityArray.frontCenterRightRange;
        bind proximityOut.proximity.frontRightRange = frontProximityArray.frontRightRange;
        bind proximityOut.proximity.rearLeftRange = rearProximityArray.rearLeftRange;
        bind proximityOut.proximity.rearRightRange = rearProximityArray.rearRightRange;
        bind groundOut.ground.leftReflectance = groundSensors.leftReflectance;
        bind groundOut.ground.rightReflectance = groundSensors.rightReflectance;
    }

    part def FrontProximityArray {
        attribute frontLeftRange : Millimeter;
        attribute frontCenterLeftRange : Millimeter;
        attribute frontCenterRange : Millimeter;
        attribute frontCenterRightRange : Millimeter;
        attribute frontRightRange : Millimeter;
        attribute effectiveRange : Millimeter = 300 [SI::mm];
    }

    part def RearProximityArray {
        attribute rearLeftRange : Millimeter;
        attribute rearRightRange : Millimeter;
        attribute effectiveRange : Millimeter = 180 [SI::mm];
    }

    part def GroundSensorPair {
        attribute leftReflectance : Percent;
        attribute rightReflectance : Percent;
        attribute leftDistanceEstimate : Millimeter;
        attribute rightDistanceEstimate : Millimeter;
    }

    part def DifferentialDrive {
        port motionIn : MotionCommandPort;

        part leftMotor : WheelMotor {
            attribute side = "left";
        }

        part rightMotor : WheelMotor {
            attribute side = "right";
        }

        attribute wheelDiameter : Millimeter = 42 [SI::mm];
        attribute axleTrack : Millimeter = 95 [SI::mm];
        attribute maximumWheelVelocity : MillimeterPerSecond = 140 [SI::mm / SI::s];

        bind leftMotor.requestedVelocity = motionIn.command.leftWheelVelocity;
        bind rightMotor.requestedVelocity = motionIn.command.rightWheelVelocity;
    }

    part def WheelMotor {
        attribute side : String;
        attribute requestedVelocity : MillimeterPerSecond;
        attribute measuredVelocity : MillimeterPerSecond;
        attribute stallCurrent : Ampere = 0.35 [SI::A];
    }

    part def UserIndicators {
        port lightIn : LightCommandPort;
        port soundIn : SoundCommandPort;

        part topRgbLight : RgbLight;
        part speaker : PiezoSpeaker;

        bind topRgbLight.redIntensity = lightIn.command.redIntensity;
        bind topRgbLight.greenIntensity = lightIn.command.greenIntensity;
        bind topRgbLight.blueIntensity = lightIn.command.blueIntensity;
        bind speaker.frequency = soundIn.command.frequency;
        bind speaker.duration = soundIn.command.duration;
        bind speaker.loudness = soundIn.command.loudness;
    }

    part def RgbLight {
        attribute redIntensity : Percent;
        attribute greenIntensity : Percent;
        attribute blueIntensity : Percent;
    }

    part def PiezoSpeaker {
        attribute frequency : SI::FrequencyValue;
        attribute duration : SI::TimeValue;
        attribute loudness : Percent;
    }

    part def PowerSubsystem {
        port batteryOut : BatteryStatusPort;

        part battery : RechargeableBattery {
            attribute nominalVoltage : Volt = 3.7 [SI::V];
            attribute capacity : SI::ElectricChargeValue = 1500 [SI::mA * SI::h];
        }

        bind batteryOut.status.voltage = battery.voltage;
        bind batteryOut.status.currentDraw = battery.currentDraw;
        bind batteryOut.status.stateOfCharge = battery.stateOfCharge;
        bind batteryOut.status.lowBatteryLimit = battery.lowBatteryLimit;
    }

    part def RechargeableBattery {
        attribute nominalVoltage : Volt;
        attribute voltage : Volt;
        attribute currentDraw : Ampere;
        attribute capacity : SI::ElectricChargeValue;
        attribute stateOfCharge : Percent;
        attribute lowBatteryLimit : Percent = 15.0;
    }

    part def ExplorationController {
        port proximityIn : ProximitySensorPort;
        port groundIn : GroundSensorPort;
        port batteryIn : BatteryStatusPort;
        port modeIn : UserModePort;
        port motionOut : MotionCommandPort;
        port lightOut : LightCommandPort;
        port soundOut : SoundCommandPort;

        attribute nearestFrontObstacle : Millimeter;
        attribute nearestRearObstacle : Millimeter;
        attribute obstacleStopDistance : Millimeter = 90 [SI::mm];
        attribute obstacleAvoidDistance : Millimeter = 160 [SI::mm];
        attribute edgeReflectanceLimit : Percent = 18.0;
        attribute normalSpeed : MillimeterPerSecond = 80 [SI::mm / SI::s];
        attribute turnSpeed : MillimeterPerSecond = 55 [SI::mm / SI::s];

        action computeNearestObstacles {
            in item proximity : ProximityFrame;
            out attribute nearestFront : Millimeter;
            out attribute nearestRear : Millimeter;
        }

        action commandStop {
            out item motion : MotionCommand;
            out item light : LightCommand;
            out item sound : SoundCommand;
        }

        action commandForwardExplore {
            out item motion : MotionCommand;
            out item light : LightCommand;
        }

        action commandTurnLeft {
            out item motion : MotionCommand;
            out item light : LightCommand;
        }

        action commandTurnRight {
            out item motion : MotionCommand;
            out item light : LightCommand;
        }

        action commandReverse {
            out item motion : MotionCommand;
            out item light : LightCommand;
            out item sound : SoundCommand;
        }

        action commandLineFollow {
            in item ground : GroundFrame;
            out item motion : MotionCommand;
            out item light : LightCommand;
        }

        state def ControllerStateMachine {
            entry action commandStop;

            state idle;
            state exploring;
            state avoidingObstacle;
            state followingLine;
            state edgeDetected;
            state lowBatteryStop;
            state commandedStop;

            transition initial then idle;

            transition idleToExplore
                first idle
                accept UserModeCommand
                if modeIn.modeCommand.selectedMode == UserModeCommand::ModeKind::explore
                then exploring;

            transition idleToLineFollow
                first idle
                accept UserModeCommand
                if modeIn.modeCommand.selectedMode == UserModeCommand::ModeKind::followLine
                then followingLine;

            transition exploreToAvoid
                first exploring
                if nearestFrontObstacle <= obstacleAvoidDistance
                then avoidingObstacle;

            transition exploreToEdge
                first exploring
                if groundIn.ground.leftReflectance < edgeReflectanceLimit or groundIn.ground.rightReflectance < edgeReflectanceLimit
                then edgeDetected;

            transition avoidToExplore
                first avoidingObstacle
                if nearestFrontObstacle > obstacleAvoidDistance
                then exploring;

            transition lineToEdge
                first followingLine
                if groundIn.ground.leftReflectance < edgeReflectanceLimit and groundIn.ground.rightReflectance < edgeReflectanceLimit
                then edgeDetected;

            transition edgeToExplore
                first edgeDetected
                after 1 [SI::s]
                then exploring;

            transition anyToLowBattery
                first idle, exploring, avoidingObstacle, followingLine, edgeDetected
                if batteryIn.status.stateOfCharge <= batteryIn.status.lowBatteryLimit
                then lowBatteryStop;

            transition anyToCommandedStop
                first idle, exploring, avoidingObstacle, followingLine, edgeDetected
                accept UserModeCommand
                if modeIn.modeCommand.selectedMode == UserModeCommand::ModeKind::returnToSafeStop
                then commandedStop;

            transition commandedStopToIdle
                first commandedStop
                accept UserModeCommand
                if modeIn.modeCommand.selectedMode == UserModeCommand::ModeKind::idle
                then idle;

            transition lowBatteryStopToIdle
                first lowBatteryStop
                if batteryIn.status.stateOfCharge > 35.0
                then idle;

            state exploring {
                entry action commandForwardExplore;
                do action computeNearestObstacles;
            }

            state avoidingObstacle {
                entry action commandReverse;
                do action computeNearestObstacles;
            }

            state followingLine {
                do action commandLineFollow;
            }

            state edgeDetected {
                entry action commandReverse;
            }

            state lowBatteryStop {
                entry action commandStop;
            }

            state commandedStop {
                entry action commandStop;
            }
        }

        perform controllerBehavior : ControllerStateMachine;
    }

    requirement def PrimaryFunctionRequirement {
        subject robot : ThymioExplorer;
        doc /* The robot shall autonomously explore an indoor surface using the Thymio sensor suite and differential drive while maintaining collision avoidance and safe stop behavior. */
        require constraint {
            robot.nominalForwardSpeed > 0 [SI::mm / SI::s]
        }
    }

    requirement def ObstacleAvoidanceRequirement {
        subject robot : ThymioExplorer;
        doc /* When a front obstacle is detected within the avoidance threshold, the robot shall stop forward motion and command an avoidance maneuver before contact. */
        require constraint {
            robot.obstacleAvoidDistance > robot.obstacleStopDistance
        }
    }

    requirement def EdgeSafetyRequirement {
        subject robot : ThymioExplorer;
        doc /* When ground reflectance indicates a table edge or unsafe drop, the robot shall reverse or stop instead of continuing forward. */
        require constraint {
            robot.edgeReflectanceLimit > 0.0 and robot.edgeReflectanceLimit < 50.0
        }
    }

    requirement def BatterySafetyRequirement {
        subject robot : ThymioExplorer;
        doc /* When battery state of charge is at or below the low-battery limit, the robot shall enter a safe stopped state and indicate low energy. */
        require constraint {
            robot.lowBatteryLimit >= 10.0 and robot.lowBatteryLimit <= 25.0
        }
    }

    requirement def HumanReadableStatusRequirement {
        subject robot : ThymioExplorer;
        doc /* The robot shall expose its operating mode using visible RGB light patterns and audible tones for important state changes. */
    }

    satisfy PrimaryFunctionRequirement by ThymioExplorer;
    satisfy ObstacleAvoidanceRequirement by ThymioExplorer::controller;
    satisfy EdgeSafetyRequirement by ThymioExplorer::controller;
    satisfy BatterySafetyRequirement by ThymioExplorer::power;
    satisfy HumanReadableStatusRequirement by ThymioExplorer::indicators;

    part thymioExplorerRobot : ThymioExplorer {
        attribute nominalForwardSpeed = 80 [SI::mm / SI::s];
        attribute reducedForwardSpeed = 35 [SI::mm / SI::s];
        attribute obstacleStopDistance = 90 [SI::mm];
        attribute obstacleAvoidDistance = 160 [SI::mm];
        attribute lowBatteryLimit = 15.0;
    }
}