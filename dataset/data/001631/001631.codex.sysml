package WorkplaceRoboticsSafetySystem {

    import ScalarValues::*;
    import SI::*;

    attribute def SafetyIntegrityLevel {
        attribute level : Integer;
        attribute description : String;
    }

    enum def OperationalMode {
        enum idle;
        enum collaborativeOperation;
        enum reducedSpeed;
        enum protectiveStop;
        enum emergencyStop;
        enum maintenance;
        enum fault;
    }

    enum def HazardClass {
        enum humanIntrusion;
        enum excessiveRobotSpeed;
        enum unsafeSeparationDistance;
        enum guardDoorOpen;
        enum emergencyButtonPressed;
        enum sensorFault;
        enum actuatorFault;
        enum communicationFault;
    }

    enum def AlertSeverity {
        enum information;
        enum warning;
        enum critical;
        enum emergency;
    }

    item def PersonPresence {
        attribute detected : Boolean;
        attribute distanceToRobot : Real [m];
        attribute zoneId : String;
        attribute confidence : Real;
        attribute timestamp : Real [s];
    }

    item def RobotMotionStatus {
        attribute jointSpeed : Real [rad/s];
        attribute cartesianSpeed : Real [m/s];
        attribute stoppingDistance : Real [m];
        attribute payloadMass : Real [kg];
        attribute timestamp : Real [s];
    }

    item def SafetyCommand {
        attribute targetMode : OperationalMode;
        attribute requestedStopCategory : Integer;
        attribute speedLimit : Real [m/s];
        attribute reason : HazardClass;
        attribute timestamp : Real [s];
    }

    item def SafetyAlert {
        attribute severity : AlertSeverity;
        attribute hazard : HazardClass;
        attribute message : String;
        attribute zoneId : String;
        attribute timestamp : Real [s];
    }

    item def DiagnosticsReport {
        attribute healthy : Boolean;
        attribute failedChannel : String;
        attribute diagnosticCoverage : Real;
        attribute timestamp : Real [s];
    }

    port def PresenceSensorPort {
        out item presence : PersonPresence;
        out item diagnostics : DiagnosticsReport;
    }

    port def RobotStatusPort {
        in item status : RobotMotionStatus;
    }

    port def RobotControlPort {
        out item command : SafetyCommand;
    }

    port def AlertPort {
        out item alert : SafetyAlert;
    }

    port def EmergencyInputPort {
        out item command : SafetyCommand;
    }

    part def SafetyRatedPresenceSensor {
        attribute fieldOfViewAngle : Real [rad] = 3.14;
        attribute maximumRange : Real [m] = 8.0;
        attribute minimumDetectableObjectWidth : Real [m] = 0.15;
        attribute responseTime : Real [ms] = 40.0;
        attribute diagnosticInterval : Real [s] = 0.1;
        attribute sil : SafetyIntegrityLevel = (level = 2, description = "Dual-channel safety-rated human presence detection");

        port sensing : PresenceSensorPort;

        action senseWorkcell {
            out item detectedPresence : PersonPresence;
        }

        action runSelfDiagnostic {
            out item report : DiagnosticsReport;
        }
    }

    part def SafetyController {
        attribute controllerCycleTime : Real [ms] = 10.0;
        attribute minimumProtectiveSeparationDistance : Real [m] = 1.2;
        attribute reducedSpeedLimit : Real [m/s] = 0.25;
        attribute maximumCollaborativeSpeed : Real [m/s] = 1.0;
        attribute protectiveStopResponseTime : Real [ms] = 120.0;
        attribute emergencyStopResponseTime : Real [ms] = 80.0;
        attribute diagnosticCoverage : Real = 0.99;
        attribute sil : SafetyIntegrityLevel = (level = 3, description = "Safety PLC with redundant processors and monitored outputs");

        port presenceInput : PresenceSensorPort;
        port robotInput : RobotStatusPort;
        port emergencyInput : EmergencyInputPort;
        port robotOutput : RobotControlPort;
        port alertOutput : AlertPort;

        action evaluateSeparation {
            in item presence : PersonPresence;
            in item motion : RobotMotionStatus;
            out attribute safeDistance : Boolean;
            out attribute requiredDistance : Real [m];
        }

        action computeSafetyCommand {
            in item presence : PersonPresence;
            in item motion : RobotMotionStatus;
            in item diagnostic : DiagnosticsReport;
            out item command : SafetyCommand;
            out item alert : SafetyAlert;
        }

        state def SafetyControlStateMachine {
            state idle;
            state collaborativeOperation;
            state reducedSpeed;
            state protectiveStop;
            state emergencyStop;
            state maintenance;
            state fault;

            transition first idle;

            transition idle_to_collaborative
                first idle
                then collaborativeOperation
                accept SafetyCommand
                if targetMode == OperationalMode::collaborativeOperation;

            transition collaborative_to_reduced
                first collaborativeOperation
                then reducedSpeed
                accept PersonPresence
                if detected == true and distanceToRobot <= 2.0 and distanceToRobot > 1.2;

            transition reduced_to_protective_stop
                first reducedSpeed
                then protectiveStop
                accept PersonPresence
                if detected == true and distanceToRobot <= 1.2;

            transition collaborative_to_protective_stop
                first collaborativeOperation
                then protectiveStop
                accept PersonPresence
                if detected == true and distanceToRobot <= 1.2;

            transition any_to_emergency_stop
                first idle
                then emergencyStop
                accept SafetyCommand
                if targetMode == OperationalMode::emergencyStop;

            transition collaborative_to_emergency_stop
                first collaborativeOperation
                then emergencyStop
                accept SafetyCommand
                if targetMode == OperationalMode::emergencyStop;

            transition reduced_to_emergency_stop
                first reducedSpeed
                then emergencyStop
                accept SafetyCommand
                if targetMode == OperationalMode::emergencyStop;

            transition protective_to_emergency_stop
                first protectiveStop
                then emergencyStop
                accept SafetyCommand
                if targetMode == OperationalMode::emergencyStop;

            transition protective_to_reduced
                first protectiveStop
                then reducedSpeed
                accept PersonPresence
                if detected == true and distanceToRobot > 1.2 and distanceToRobot <= 2.0;

            transition reduced_to_collaborative
                first reducedSpeed
                then collaborativeOperation
                accept PersonPresence
                if detected == false or distanceToRobot > 2.0;

            transition emergency_to_idle
                first emergencyStop
                then idle
                accept SafetyCommand
                if targetMode == OperationalMode::idle;

            transition any_to_fault
                first collaborativeOperation
                then fault
                accept DiagnosticsReport
                if healthy == false;

            transition reduced_to_fault
                first reducedSpeed
                then fault
                accept DiagnosticsReport
                if healthy == false;

            transition protective_to_fault
                first protectiveStop
                then fault
                accept DiagnosticsReport
                if healthy == false;

            transition fault_to_maintenance
                first fault
                then maintenance
                accept SafetyCommand
                if targetMode == OperationalMode::maintenance;

            transition maintenance_to_idle
                first maintenance
                then idle
                accept DiagnosticsReport
                if healthy == true;
        }

        behavior safetySupervision : SafetyControlStateMachine;
    }

    part def CollaborativeRobot {
        attribute maximumReach : Real [m] = 1.7;
        attribute maximumPayload : Real [kg] = 12.0;
        attribute normalSpeed : Real [m/s] = 0.8;
        attribute reducedSpeed : Real [m/s] = 0.25;
        attribute brakeEngagementTime : Real [ms] = 60.0;
        attribute controlledStopTime : Real [ms] = 150.0;

        port statusOutput : RobotStatusPort;
        port safetyInput : RobotControlPort;

        action executeMotion {
            in item command : SafetyCommand;
            out item status : RobotMotionStatus;
        }

        action stopMotion {
            in attribute stopCategory : Integer;
            out item status : RobotMotionStatus;
        }
    }

    part def EmergencyStopStation {
        attribute buttonCount : Integer = 4;
        attribute resetRequired : Boolean = true;
        attribute responseTime : Real [ms] = 20.0;
        attribute sil : SafetyIntegrityLevel = (level = 3, description = "Hardwired emergency stop circuit with manual reset");

        port emergencyOutput : EmergencyInputPort;

        action pressEmergencyStop {
            out item command : SafetyCommand {
                attribute targetMode = OperationalMode::emergencyStop;
                attribute requestedStopCategory = 0;
                attribute speedLimit = 0.0;
                attribute reason = HazardClass::emergencyButtonPressed;
            }
        }

        action resetEmergencyStop {
            out item command : SafetyCommand {
                attribute targetMode = OperationalMode::idle;
                attribute requestedStopCategory = 1;
                attribute speedLimit = 0.0;
                attribute reason = HazardClass::emergencyButtonPressed;
            }
        }
    }

    part def GuardedWorkcell {
        attribute workcellLength : Real [m] = 6.0;
        attribute workcellWidth : Real [m] = 4.5;
        attribute guardedOpeningWidth : Real [m] = 1.2;
        attribute operatorZoneDistance : Real [m] = 2.0;
        attribute restrictedZoneDistance : Real [m] = 1.2;

        port presenceOutput : PresenceSensorPort;
    }

    part def HumanMachineInterface {
        attribute displayRefreshPeriod : Real [ms] = 250.0;
        attribute audibleAlarmLevel : Real [dB] = 85.0;
        attribute visualBeaconVisibleDistance : Real [m] = 15.0;

        port alertInput : AlertPort;

        action displayAlert {
            in item alert : SafetyAlert;
        }

        action requestReset {
            out item command : SafetyCommand;
        }
    }

    part def SafetyDataRecorder {
        attribute retentionPeriod : Real [day] = 365.0;
        attribute samplePeriod : Real [ms] = 100.0;
        attribute storageCapacity : Real [GB] = 64.0;

        port alertInput : AlertPort;
        port commandInput : RobotControlPort;
        port statusInput : RobotStatusPort;

        action recordSafetyEvent {
            in item alert : SafetyAlert;
            in item command : SafetyCommand;
            in item status : RobotMotionStatus;
        }
    }

    part def WorkplaceRoboticsSafetySystem {
        attribute primaryFunction : String =
            "Continuously supervise a collaborative robot workcell, detect worker presence and unsafe motion, maintain protective separation, command reduced speed or stops, alert operators, and record safety events.";
        attribute targetAvailability : Real = 0.995;
        attribute maximumAllowedResidualRisk : Real = 0.000001;
        attribute operatingTemperatureMin : Real [degC] = 0.0;
        attribute operatingTemperatureMax : Real [degC] = 45.0;

        part robot : CollaborativeRobot;
        part safetyController : SafetyController;
        part leftScanner : SafetyRatedPresenceSensor {
            attribute maximumRange = 8.0;
        }
        part rightScanner : SafetyRatedPresenceSensor {
            attribute maximumRange = 8.0;
        }
        part workcell : GuardedWorkcell;
        part emergencyStations : EmergencyStopStation;
        part operatorInterface : HumanMachineInterface;
        part recorder : SafetyDataRecorder;

        connect leftScanner.sensing to safetyController.presenceInput;
        connect rightScanner.sensing to safetyController.presenceInput;
        connect emergencyStations.emergencyOutput to safetyController.emergencyInput;
        connect robot.statusOutput to safetyController.robotInput;
        connect safetyController.robotOutput to robot.safetyInput;
        connect safetyController.alertOutput to operatorInterface.alertInput;
        connect safetyController.alertOutput to recorder.alertInput;
        connect safetyController.robotOutput to recorder.commandInput;
        connect robot.statusOutput to recorder.statusInput;
        connect workcell.presenceOutput to safetyController.presenceInput;

        action superviseWorkplaceRobotSafety {
            in item presence : PersonPresence;
            in item robotStatus : RobotMotionStatus;
            out item command : SafetyCommand;
            out item alert : SafetyAlert;

            first start;
            then monitorPresence;
            then monitorRobotMotion;
            then evaluateHazard;
            then commandSafeState;
            then notifyAndRecord;
            then done;

            action monitorPresence {
                out item currentPresence : PersonPresence;
            }

            action monitorRobotMotion {
                out item currentMotion : RobotMotionStatus;
            }

            action evaluateHazard {
                in item currentPresence : PersonPresence;
                in item currentMotion : RobotMotionStatus;
                out attribute hazardDetected : Boolean;
                out attribute hazardClass : HazardClass;
            }

            action commandSafeState {
                in attribute hazardDetected : Boolean;
                in attribute hazardClass : HazardClass;
                out item command : SafetyCommand;
            }

            action notifyAndRecord {
                in item command : SafetyCommand;
                out item alert : SafetyAlert;
            }
        }
    }

    requirement def DetectWorkerPresenceRequirement {
        subject system : WorkplaceRoboticsSafetySystem;
        attribute maximumDetectionTime : Real [ms] = 60.0;
        doc /* The system shall detect a worker entering the monitored workcell zones within the maximum detection time. */
    }

    requirement def MaintainProtectiveSeparationRequirement {
        subject system : WorkplaceRoboticsSafetySystem;
        attribute minimumDistance : Real [m] = 1.2;
        doc /* The system shall command a protective stop before any worker can enter the restricted zone while robot motion is hazardous. */
    }

    requirement def ReducedSpeedRequirement {
        subject system : WorkplaceRoboticsSafetySystem;
        attribute speedLimit : Real [m/s] = 0.25;
        doc /* The system shall limit robot cartesian speed to the reduced speed limit when a worker is detected in the collaborative approach zone. */
    }

    requirement def EmergencyStopRequirement {
        subject system : WorkplaceRoboticsSafetySystem;
        attribute maximumStopCommandTime : Real [ms] = 80.0;
        doc /* The system shall issue an emergency stop command when any emergency stop station is actuated. */
    }

    requirement def DiagnosticCoverageRequirement {
        subject system : WorkplaceRoboticsSafetySystem;
        attribute minimumCoverage : Real = 0.99;
        doc /* The system shall detect safety sensor, controller, actuator, and communication faults with at least the minimum diagnostic coverage. */
    }

    requirement def OperatorAlertRequirement {
        subject system : WorkplaceRoboticsSafetySystem;
        attribute maximumAlertLatency : Real [ms] = 250.0;
        doc /* The system shall provide visual and audible operator alerts for protective stops, emergency stops, and detected safety faults. */
    }

    requirement def EventRecordingRequirement {
        subject system : WorkplaceRoboticsSafetySystem;
        attribute retentionPeriod : Real [day] = 365.0;
        doc /* The system shall record safety events, commands, diagnostics, and robot motion status for traceability over the retention period. */
    }

    requirement def SafetyRatedControlRequirement {
        subject system : WorkplaceRoboticsSafetySystem;
        attribute requiredSIL : Integer = 3;
        doc /* The safety control function shall be implemented using redundant safety-rated components meeting the required integrity level. */
    }

    satisfy DetectWorkerPresenceRequirement by WorkplaceRoboticsSafetySystem::leftScanner;
    satisfy DetectWorkerPresenceRequirement by WorkplaceRoboticsSafetySystem::rightScanner;
    satisfy MaintainProtectiveSeparationRequirement by WorkplaceRoboticsSafetySystem::safetyController;
    satisfy ReducedSpeedRequirement by WorkplaceRoboticsSafetySystem::safetyController;
    satisfy EmergencyStopRequirement by WorkplaceRoboticsSafetySystem::emergencyStations;
    satisfy EmergencyStopRequirement by WorkplaceRoboticsSafetySystem::safetyController;
    satisfy DiagnosticCoverageRequirement by WorkplaceRoboticsSafetySystem::safetyController;
    satisfy OperatorAlertRequirement by WorkplaceRoboticsSafetySystem::operatorInterface;
    satisfy EventRecordingRequirement by WorkplaceRoboticsSafetySystem::recorder;
    satisfy SafetyRatedControlRequirement by WorkplaceRoboticsSafetySystem::safetyController;

    constraint def ProtectiveSeparationDistanceConstraint {
        in robotSpeed : Real [m/s];
        in controllerResponseTime : Real [s];
        in robotStoppingTime : Real [s];
        in intrusionDistance : Real [m];
        in minimumDistance : Real [m];
        constraint minimumDistance >= robotSpeed * (controllerResponseTime + robotStoppingTime) + intrusionDistance;
    }

    constraint def ReducedSpeedConstraint {
        in actualSpeed : Real [m/s];
        in allowedSpeed : Real [m/s];
        constraint actualSpeed <= allowedSpeed;
    }

    constraint def EmergencyStopLatencyConstraint {
        in buttonResponse : Real [ms];
        in controllerResponse : Real [ms];
        in brakeResponse : Real [ms];
        in maximumLatency : Real [ms];
        constraint buttonResponse + controllerResponse + brakeResponse <= maximumLatency;
    }

    analysis def SafetyDistanceAnalysis {
        subject system : WorkplaceRoboticsSafetySystem;
        objective "Verify that protective separation distance remains sufficient for maximum collaborative motion speed.";
        constraint distanceConstraint : ProtectiveSeparationDistanceConstraint {
            in robotSpeed = 1.0;
            in controllerResponseTime = 0.12;
            in robotStoppingTime = 0.15;
            in intrusionDistance = 0.9;
            in minimumDistance = 1.2;
        }
    }

    analysis def EmergencyStopTimingAnalysis {
        subject system : WorkplaceRoboticsSafetySystem;
        objective "Verify that the emergency stop path commands and arrests hazardous motion within required timing.";
        constraint timingConstraint : EmergencyStopLatencyConstraint {
            in buttonResponse = 20.0;
            in controllerResponse = 40.0;
            in brakeResponse = 60.0;
            in maximumLatency = 150.0;
        }
    }

    verification def VerifyReducedSpeed {
        subject system : WorkplaceRoboticsSafetySystem;
        objective "Confirm robot speed remains at or below 0.25 m/s while a worker is in the collaborative approach zone.";
        constraint reducedSpeedCheck : ReducedSpeedConstraint {
            in actualSpeed = 0.25;
            in allowedSpeed = 0.25;
        }
    }

    verification def VerifyProtectiveStop {
        subject system : WorkplaceRoboticsSafetySystem;
        objective "Confirm protective stop is commanded when worker distance is less than or equal to 1.2 m.";
    }

    verification def VerifyEmergencyStop {
        subject system : WorkplaceRoboticsSafetySystem;
        objective "Confirm emergency stop is commanded from any emergency stop station and requires manual reset.";
    }
}