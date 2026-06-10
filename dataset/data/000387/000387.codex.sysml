package RoboticPrimaryTaskSystem {

    import ScalarValues::*;
    import SI::*;

    value type MassValue :> Real { unit = kg; }
    value type LengthValue :> Real { unit = m; }
    value type SpeedValue :> Real { unit = m/s; }
    value type TimeValue :> Real { unit = s; }
    value type EnergyValue :> Real { unit = J; }
    value type PowerValue :> Real { unit = W; }
    value type VoltageValue :> Real { unit = V; }
    value type PercentValue :> Real;
    value type TemperatureValue :> Real { unit = K; }

    item def NavigationCommand {
        attribute targetX : LengthValue;
        attribute targetY : LengthValue;
        attribute targetHeading : Real;
        attribute maxSpeed : SpeedValue;
    }

    item def MotionCommand {
        attribute linearVelocity : SpeedValue;
        attribute angularVelocity : Real;
    }

    item def PoseEstimate {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute heading : Real;
        attribute confidence : PercentValue;
    }

    item def ObstacleReport {
        attribute nearestObstacleDistance : LengthValue;
        attribute obstacleBearing : Real;
        attribute collisionRisk : PercentValue;
    }

    item def Payload {
        attribute payloadMass : MassValue;
        attribute payloadLength : LengthValue;
        attribute payloadWidth : LengthValue;
        attribute payloadHeight : LengthValue;
    }

    item def TaskRequest {
        attribute pickupX : LengthValue;
        attribute pickupY : LengthValue;
        attribute dropoffX : LengthValue;
        attribute dropoffY : LengthValue;
        attribute requiredCompletionTime : TimeValue;
    }

    item def TaskStatus {
        attribute taskAccepted : Boolean;
        attribute taskComplete : Boolean;
        attribute faultActive : Boolean;
        attribute progress : PercentValue;
    }

    item def BatteryStatus {
        attribute stateOfCharge : PercentValue;
        attribute busVoltage : VoltageValue;
        attribute availableEnergy : EnergyValue;
        attribute packTemperature : TemperatureValue;
    }

    port def CommandPort {
        in item taskRequest : TaskRequest;
        out item taskStatus : TaskStatus;
    }

    port def NavigationPort {
        in item navigationCommand : NavigationCommand;
        out item poseEstimate : PoseEstimate;
        out item obstacleReport : ObstacleReport;
    }

    port def MotionPort {
        in item motionCommand : MotionCommand;
        out item poseEstimate : PoseEstimate;
    }

    port def PayloadPort {
        inout item payload : Payload;
    }

    port def PowerPort {
        out item batteryStatus : BatteryStatus;
    }

    port def DiagnosticPort {
        out item taskStatus : TaskStatus;
        out item batteryStatus : BatteryStatus;
    }

    part def MissionController {
        port command : CommandPort;
        port navigation : NavigationPort;
        port diagnostics : DiagnosticPort;

        attribute acceptedTask : TaskRequest;
        attribute currentStatus : TaskStatus;

        action decideTask {
            in item request : TaskRequest;
            in item battery : BatteryStatus;
            out item accepted : TaskStatus;

            first start;
            then validatePayloadRoute;
            then checkEnergyMargin;
            then publishAcceptance;
            then done;

            action validatePayloadRoute;
            action checkEnergyMargin;
            action publishAcceptance;
        }

        action planDelivery {
            in item request : TaskRequest;
            out item pickupCommand : NavigationCommand;
            out item dropoffCommand : NavigationCommand;

            first start;
            then computePickupApproach;
            then computeDropoffApproach;
            then constrainSpeed;
            then done;

            action computePickupApproach;
            action computeDropoffApproach;
            action constrainSpeed;
        }
    }

    part def NavigationComputer {
        port navigation : NavigationPort;
        port motion : MotionPort;

        attribute localizationAccuracy : LengthValue = 0.05 [m];
        attribute obstacleStopDistance : LengthValue = 0.50 [m];

        action localize {
            out item pose : PoseEstimate;
        }

        action avoidObstacles {
            in item command : NavigationCommand;
            in item obstacle : ObstacleReport;
            out item safeMotion : MotionCommand;
        }
    }

    part def Robot {
        port command : CommandPort;
        port payloadInterface : PayloadPort;
        port diagnostics : DiagnosticPort;

        part controller : MissionController;
        part navigator : NavigationComputer;
        part driveBase : DriveBase;
        part manipulator : Manipulator;
        part sensorSuite : SensorSuite;
        part batterySystem : BatterySystem;

        attribute robotMass : MassValue = 48.0 [kg];
        attribute maximumPayloadMass : MassValue = 6.0 [kg];
        attribute maximumSpeed : SpeedValue = 1.2 [m/s];
        attribute nominalEndurance : TimeValue = 7200 [s];

        connect command to controller.command;
        connect controller.navigation to navigator.navigation;
        connect navigator.motion to driveBase.motion;
        connect sensorSuite.navigation to navigator.navigation;
        connect batterySystem.power to controller.diagnostics;
        connect batterySystem.power to diagnostics;
        connect controller.diagnostics to diagnostics;
        connect payloadInterface to manipulator.payloadInterface;

        action performPrimaryTask {
            in item request : TaskRequest;
            inout item payload : Payload;
            out item status : TaskStatus;

            first receiveTask;
            then evaluateTask;
            then navigateToPickup;
            then acquirePayload;
            then navigateToDropoff;
            then releasePayload;
            then reportCompletion;
            then done;

            action receiveTask {
                out item receivedRequest : TaskRequest;
            }

            action evaluateTask {
                in item receivedRequest : TaskRequest;
                out item acceptedStatus : TaskStatus;
            }

            action navigateToPickup {
                in item receivedRequest : TaskRequest;
                out item arrivedAtPickup : PoseEstimate;
            }

            action acquirePayload {
                inout item payload : Payload;
                out item payloadSecured : Boolean;
            }

            action navigateToDropoff {
                in item receivedRequest : TaskRequest;
                out item arrivedAtDropoff : PoseEstimate;
            }

            action releasePayload {
                inout item payload : Payload;
                out item payloadReleased : Boolean;
            }

            action reportCompletion {
                out item completedStatus : TaskStatus;
            }
        }

        state def RobotOperationalStates {
            entry action initializeRobot;

            state Idle;
            state AcceptingTask;
            state NavigatingToPickup;
            state LoadingPayload;
            state NavigatingToDropoff;
            state UnloadingPayload;
            state Completed;
            state Fault;
            state Charging;

            transition first Idle;
            transition Idle to AcceptingTask
                accept TaskRequest
                if batterySystem.stateOfCharge >= 30.0;

            transition AcceptingTask to NavigatingToPickup
                if controller.currentStatus.taskAccepted;

            transition NavigatingToPickup to LoadingPayload
                if driveBase.arrivedAtGoal;

            transition LoadingPayload to NavigatingToDropoff
                if manipulator.payloadSecured;

            transition NavigatingToDropoff to UnloadingPayload
                if driveBase.arrivedAtGoal;

            transition UnloadingPayload to Completed
                if not manipulator.payloadSecured;

            transition Completed to Idle;

            transition Idle to Charging
                if batterySystem.stateOfCharge < 30.0;

            transition Charging to Idle
                if batterySystem.stateOfCharge >= 90.0;

            transition Idle to Fault
                if controller.currentStatus.faultActive;

            transition AcceptingTask to Fault
                if controller.currentStatus.faultActive;

            transition NavigatingToPickup to Fault
                if sensorSuite.emergencyStopRequested;

            transition NavigatingToDropoff to Fault
                if sensorSuite.emergencyStopRequested;

            transition Fault to Idle
                accept ClearFaultCommand;
        }
    }

    part def DriveBase {
        port motion : MotionPort;

        attribute wheelBase : LengthValue = 0.42 [m];
        attribute maximumLinearSpeed : SpeedValue = 1.2 [m/s];
        attribute maximumSlopeClimb : Real = 8.0;
        attribute arrivedAtGoal : Boolean;

        part leftMotor : TractionMotor;
        part rightMotor : TractionMotor;

        action executeMotion {
            in item command : MotionCommand;
            out item pose : PoseEstimate;
        }
    }

    part def TractionMotor {
        attribute ratedPower : PowerValue = 180 [W];
        attribute ratedVoltage : VoltageValue = 24 [V];
        attribute peakTorque : Real = 8.5;
    }

    part def Manipulator {
        port payloadInterface : PayloadPort;

        attribute gripperOpening : LengthValue = 0.18 [m];
        attribute liftHeight : LengthValue = 0.35 [m];
        attribute payloadSecured : Boolean;

        action graspPayload {
            inout item payload : Payload;
            out item secured : Boolean;
        }

        action releasePayload {
            inout item payload : Payload;
            out item released : Boolean;
        }
    }

    part def SensorSuite {
        port navigation : NavigationPort;

        attribute lidarRange : LengthValue = 12.0 [m];
        attribute cameraRange : LengthValue = 8.0 [m];
        attribute emergencyStopRequested : Boolean;

        part lidar : LidarSensor;
        part depthCamera : DepthCamera;
        part inertialUnit : InertialMeasurementUnit;

        action detectObstacles {
            out item report : ObstacleReport;
        }

        action estimatePose {
            out item pose : PoseEstimate;
        }
    }

    part def LidarSensor {
        attribute range : LengthValue = 12.0 [m];
        attribute scanRate : Real = 10.0;
    }

    part def DepthCamera {
        attribute range : LengthValue = 8.0 [m];
        attribute horizontalFieldOfView : Real = 87.0;
    }

    part def InertialMeasurementUnit {
        attribute updateRate : Real = 200.0;
    }

    part def BatterySystem {
        port power : PowerPort;

        attribute stateOfCharge : PercentValue = 100.0;
        attribute nominalVoltage : VoltageValue = 24.0 [V];
        attribute capacityEnergy : EnergyValue = 900000 [J];
        attribute maximumContinuousPower : PowerValue = 600 [W];

        action supplyPower {
            out item status : BatteryStatus;
        }

        action recharge {
            in item requestedEnergy : EnergyValue;
            out item status : BatteryStatus;
        }
    }

    part def OperatorStation {
        port command : CommandPort;
        port diagnostics : DiagnosticPort;

        action submitTask {
            out item request : TaskRequest;
        }

        action monitorTask {
            in item status : TaskStatus;
            in item battery : BatteryStatus;
        }
    }

    part def PrimaryTaskEnvironment {
        attribute operatingAreaLength : LengthValue = 40.0 [m];
        attribute operatingAreaWidth : LengthValue = 25.0 [m];
        attribute maximumObstacleHeight : LengthValue = 1.2 [m];

        part pickupZone : TaskZone {
            attribute centerX = 4.0 [m];
            attribute centerY = 5.0 [m];
        }

        part dropoffZone : TaskZone {
            attribute centerX = 34.0 [m];
            attribute centerY = 18.0 [m];
        }
    }

    part def TaskZone {
        attribute centerX : LengthValue;
        attribute centerY : LengthValue;
        attribute radius : LengthValue = 1.0 [m];
    }

    part def RoboticDeliverySystem {
        part robot : Robot;
        part operatorStation : OperatorStation;
        part environment : PrimaryTaskEnvironment;

        port externalCommand : CommandPort;
        port externalDiagnostics : DiagnosticPort;

        connect externalCommand to operatorStation.command;
        connect operatorStation.command to robot.command;
        connect robot.diagnostics to operatorStation.diagnostics;
        connect operatorStation.diagnostics to externalDiagnostics;

        attribute systemAvailability : PercentValue;
        attribute completedTaskCount : Integer;

        action executeSystemPrimaryTask {
            in item request : TaskRequest;
            inout item payload : Payload;
            out item status : TaskStatus;

            first commandRobot;
            then robot.performPrimaryTask;
            then archiveResult;
            then done;

            action commandRobot;
            action archiveResult;
        }
    }

    requirement def PrimaryTaskRequirement {
        subject system : RoboticDeliverySystem;

        require constraint {
            system.robot.performPrimaryTask.status.taskComplete == true
        }

        doc /* The robotic system shall perform its primary delivery task using the Robot part. */
    }

    requirement def RobotUsageRequirement {
        subject system : RoboticDeliverySystem;

        require constraint {
            system.robot != null
        }

        doc /* The system shall include a Robot as the executing element for the primary task. */
    }

    requirement def PayloadCapacityRequirement {
        subject robot : Robot;

        require constraint {
            robot.maximumPayloadMass >= 5.0 [kg]
        }

        doc /* The Robot shall carry payloads up to at least five kilograms. */
    }

    requirement def NavigationAccuracyRequirement {
        subject robot : Robot;

        require constraint {
            robot.navigator.localizationAccuracy <= 0.10 [m]
        }

        doc /* The Robot shall localize itself within ten centimeters during task execution. */
    }

    requirement def ObstacleAvoidanceRequirement {
        subject robot : Robot;

        require constraint {
            robot.navigator.obstacleStopDistance >= 0.50 [m]
        }

        doc /* The Robot shall maintain at least half a meter stopping distance from detected obstacles. */
    }

    requirement def EnduranceRequirement {
        subject robot : Robot;

        require constraint {
            robot.nominalEndurance >= 3600 [s]
        }

        doc /* The Robot shall support at least one hour of autonomous operation. */
    }

    requirement def CompletionReportingRequirement {
        subject system : RoboticDeliverySystem;

        require constraint {
            system.externalDiagnostics.taskStatus.taskComplete == true
        }

        doc /* The robotic system shall report successful completion after the Robot finishes the primary task. */
    }

    part deliverySystem : RoboticDeliverySystem;

    requirement primaryTaskSatisfied : PrimaryTaskRequirement {
        subject system = deliverySystem;
    }

    requirement robotUsageSatisfied : RobotUsageRequirement {
        subject system = deliverySystem;
    }

    requirement payloadCapacitySatisfied : PayloadCapacityRequirement {
        subject robot = deliverySystem.robot;
    }

    requirement navigationAccuracySatisfied : NavigationAccuracyRequirement {
        subject robot = deliverySystem.robot;
    }

    requirement obstacleAvoidanceSatisfied : ObstacleAvoidanceRequirement {
        subject robot = deliverySystem.robot;
    }

    requirement enduranceSatisfied : EnduranceRequirement {
        subject robot = deliverySystem.robot;
    }

    requirement completionReportingSatisfied : CompletionReportingRequirement {
        subject system = deliverySystem;
    }
}