package BlindSpotMonitorSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Probability;
    attribute def ConfidenceLevel :> Probability;
    attribute def LanePosition;
    attribute def VehicleSide;
    attribute def AlertPriority;
    attribute def ObjectClass;

    enum def SideKind {
        enum left;
        enum right;
    }

    enum def LanePositionKind {
        enum sameLane;
        enum adjacentLeft;
        enum adjacentRight;
        enum outsideRoadway;
        enum unknown;
    }

    enum def ObjectClassKind {
        enum passengerVehicle;
        enum motorcycle;
        enum truck;
        enum bicycle;
        enum unknownObject;
    }

    enum def AlertPriorityKind {
        enum none;
        enum advisory;
        enum warning;
        enum urgent;
    }

    item def RadarReflection {
        attribute range : DistanceValue;
        attribute rangeRate : SpeedValue;
        attribute azimuth : PlaneAngleValue;
        attribute signalToNoiseRatio : Real;
        attribute timestamp : TimeValue;
    }

    item def TrackedRoadObject {
        attribute objectId : Integer;
        attribute objectClass : ObjectClassKind;
        attribute side : SideKind;
        attribute lanePosition : LanePositionKind;
        attribute relativeLongitudinalPosition : DistanceValue;
        attribute relativeLateralPosition : DistanceValue;
        attribute relativeSpeed : SpeedValue;
        attribute confidence : ConfidenceLevel;
        attribute timeToCollision : TimeValue;
    }

    item def HostVehicleState {
        attribute speed : SpeedValue;
        attribute yawRate : AngularVelocityValue;
        attribute steeringAngle : PlaneAngleValue;
        attribute leftTurnSignalActive : Boolean;
        attribute rightTurnSignalActive : Boolean;
        attribute ignitionOn : Boolean;
        attribute reverseGearSelected : Boolean;
    }

    item def BlindSpotZoneDefinition {
        attribute side : SideKind;
        attribute rearStartOffset : DistanceValue;
        attribute rearEndOffset : DistanceValue;
        attribute lateralStartOffset : DistanceValue;
        attribute lateralEndOffset : DistanceValue;
        attribute minimumObjectSpeed : SpeedValue;
    }

    item def BlindSpotAlertCommand {
        attribute side : SideKind;
        attribute priority : AlertPriorityKind;
        attribute visualIndicatorOn : Boolean;
        attribute audibleWarningOn : Boolean;
        attribute hapticWarningOn : Boolean;
        attribute reason : String;
    }

    item def DiagnosticStatus {
        attribute sensorAvailable : Boolean;
        attribute processorAvailable : Boolean;
        attribute leftIndicatorAvailable : Boolean;
        attribute rightIndicatorAvailable : Boolean;
        attribute faultCode : String;
    }

    port def RadarPort {
        out item reflections : RadarReflection;
    }

    port def VehicleNetworkPort {
        in item vehicleState : HostVehicleState;
        out item diagnosticStatus : DiagnosticStatus;
    }

    port def ObjectTrackPort {
        out item trackedObject : TrackedRoadObject;
    }

    port def AlertCommandPort {
        out item alertCommand : BlindSpotAlertCommand;
    }

    port def IndicatorCommandPort {
        in item alertCommand : BlindSpotAlertCommand;
    }

    part def ShortRangeRadarSensor {
        attribute side : SideKind;
        attribute horizontalFieldOfView : PlaneAngleValue = 150 [deg];
        attribute maximumDetectionRange : DistanceValue = 25 [m];
        attribute minimumDetectionRange : DistanceValue = 0.2 [m];
        attribute updatePeriod : TimeValue = 0.05 [s];
        attribute operating : Boolean;

        port radarOutput : RadarPort;

        action perform SenseAdjacentRearQuarter {
            in item hostState : HostVehicleState;
            out item reflection : RadarReflection;
        }

        state def RadarSensorStateMachine {
            state off;
            state initializing;
            state active;
            state degraded;
            state failed;

            transition first off;
            transition off_to_initializing
                first off then initializing
                accept when operating;

            transition initializing_to_active
                first initializing then active
                accept after 1 [s];

            transition active_to_degraded
                first active then degraded
                accept when maximumDetectionRange < 15 [m];

            transition degraded_to_active
                first degraded then active
                accept when maximumDetectionRange >= 15 [m];

            transition active_to_failed
                first active then failed
                accept when not operating;

            transition degraded_to_failed
                first degraded then failed
                accept when not operating;
        }

        exhibit state radarState : RadarSensorStateMachine;
    }

    part def VehicleStateInterface {
        port network : VehicleNetworkPort;

        attribute hostSpeedValid : Boolean;
        attribute turnSignalValid : Boolean;
        attribute yawRateValid : Boolean;

        action perform ReadVehicleNetwork {
            out item state : HostVehicleState;
            out item diagnostics : DiagnosticStatus;
        }
    }

    part def ObjectTracker {
        port leftRadarInput : RadarPort;
        port rightRadarInput : RadarPort;
        port trackOutput : ObjectTrackPort;

        attribute trackRetentionTime : TimeValue = 0.6 [s];
        attribute minimumTrackConfidence : ConfidenceLevel = 0.65;

        action perform FuseRadarReflections {
            in item leftReflection : RadarReflection;
            in item rightReflection : RadarReflection;
            in item hostState : HostVehicleState;
            out item trackedObject : TrackedRoadObject;
        }

        action perform ClassifyObject {
            in item reflection : RadarReflection;
            out attribute objectClass : ObjectClassKind;
            out attribute confidence : ConfidenceLevel;
        }
    }

    part def BlindSpotDecisionLogic {
        port vehicleInput : VehicleNetworkPort;
        port objectInput : ObjectTrackPort;
        port alertOutput : AlertCommandPort;

        attribute leftZone : BlindSpotZoneDefinition {
            :>> side = SideKind::left;
            :>> rearStartOffset = -1 [m];
            :>> rearEndOffset = -7 [m];
            :>> lateralStartOffset = 2.2 [m];
            :>> lateralEndOffset = 4.8 [m];
            :>> minimumObjectSpeed = 1 [m/s];
        }

        attribute rightZone : BlindSpotZoneDefinition {
            :>> side = SideKind::right;
            :>> rearStartOffset = -1 [m];
            :>> rearEndOffset = -7 [m];
            :>> lateralStartOffset = -2.2 [m];
            :>> lateralEndOffset = -4.8 [m];
            :>> minimumObjectSpeed = 1 [m/s];
        }

        attribute minimumHostSpeedForAlert : SpeedValue = 10 [km/h];
        attribute warningTimeToCollisionThreshold : TimeValue = 3 [s];
        attribute alertSuppressionInReverse : Boolean = true;

        action perform EvaluateBlindSpotThreat {
            in item hostState : HostVehicleState;
            in item object : TrackedRoadObject;
            out item command : BlindSpotAlertCommand;
        }

        action def DetermineAlertPriority {
            in item hostState : HostVehicleState;
            in item object : TrackedRoadObject;
            out attribute priority : AlertPriorityKind;

            objective {
                doc
                /* Assign advisory priority when an object is inside the blind spot zone.
                   Escalate to warning when the driver signals toward the occupied side.
                   Escalate to urgent when time-to-collision is below the configured threshold. */
            }
        }

        state def MonitoringStateMachine {
            state disabled;
            state standby;
            state monitoring;
            state leftAdvisory;
            state rightAdvisory;
            state leftWarning;
            state rightWarning;
            state faulted;

            transition first disabled;

            transition disabled_to_standby
                first disabled then standby
                accept when vehicleInput.vehicleState.ignitionOn;

            transition standby_to_monitoring
                first standby then monitoring
                accept when vehicleInput.vehicleState.speed >= minimumHostSpeedForAlert
                    and not vehicleInput.vehicleState.reverseGearSelected;

            transition monitoring_to_standby
                first monitoring then standby
                accept when vehicleInput.vehicleState.speed < minimumHostSpeedForAlert
                    or vehicleInput.vehicleState.reverseGearSelected;

            transition monitoring_to_leftAdvisory
                first monitoring then leftAdvisory
                accept when objectInput.trackedObject.side == SideKind::left
                    and objectInput.trackedObject.lanePosition == LanePositionKind::adjacentLeft
                    and objectInput.trackedObject.confidence >= 0.65;

            transition monitoring_to_rightAdvisory
                first monitoring then rightAdvisory
                accept when objectInput.trackedObject.side == SideKind::right
                    and objectInput.trackedObject.lanePosition == LanePositionKind::adjacentRight
                    and objectInput.trackedObject.confidence >= 0.65;

            transition leftAdvisory_to_leftWarning
                first leftAdvisory then leftWarning
                accept when vehicleInput.vehicleState.leftTurnSignalActive;

            transition rightAdvisory_to_rightWarning
                first rightAdvisory then rightWarning
                accept when vehicleInput.vehicleState.rightTurnSignalActive;

            transition leftWarning_to_leftAdvisory
                first leftWarning then leftAdvisory
                accept when not vehicleInput.vehicleState.leftTurnSignalActive;

            transition rightWarning_to_rightAdvisory
                first rightWarning then rightAdvisory
                accept when not vehicleInput.vehicleState.rightTurnSignalActive;

            transition leftAdvisory_to_monitoring
                first leftAdvisory then monitoring
                accept when objectInput.trackedObject.confidence < 0.65;

            transition rightAdvisory_to_monitoring
                first rightAdvisory then monitoring
                accept when objectInput.trackedObject.confidence < 0.65;

            transition any_to_faulted
                first monitoring then faulted
                accept when not vehicleInput.diagnosticStatus.sensorAvailable
                    or not vehicleInput.diagnosticStatus.processorAvailable;
        }

        exhibit state monitorState : MonitoringStateMachine;
    }

    part def DriverAlertInterface {
        port leftIndicatorInput : IndicatorCommandPort;
        port rightIndicatorInput : IndicatorCommandPort;

        attribute leftMirrorIndicatorLuminance : LuminousIntensityValue = 12 [cd];
        attribute rightMirrorIndicatorLuminance : LuminousIntensityValue = 12 [cd];
        attribute audibleWarningSoundPressure : PressureValue = 70 [Pa];
        attribute hapticPulseFrequency : FrequencyValue = 8 [Hz];

        action perform DisplayVisualAlert {
            in item command : BlindSpotAlertCommand;
        }

        action perform IssueEscalatedWarning {
            in item command : BlindSpotAlertCommand;
        }
    }

    part def BlindSpotMonitor {
        doc
        /* Primary high-level function:
           The Blind Spot Monitor observes the rear-left and rear-right adjacent lanes,
           detects vehicles or motorcycles occupying the driver's blind spot zones,
           and alerts the driver when a lane-change maneuver toward an occupied zone
           may create a collision risk. */

        port vehicleNetwork : VehicleNetworkPort;

        part leftRadar : ShortRangeRadarSensor {
            :>> side = SideKind::left;
        }

        part rightRadar : ShortRangeRadarSensor {
            :>> side = SideKind::right;
        }

        part vehicleInterface : VehicleStateInterface;
        part tracker : ObjectTracker;
        part decisionLogic : BlindSpotDecisionLogic;
        part driverAlerts : DriverAlertInterface;

        connection leftRadarToTracker
            connect leftRadar.radarOutput to tracker.leftRadarInput;

        connection rightRadarToTracker
            connect rightRadar.radarOutput to tracker.rightRadarInput;

        connection vehicleNetworkToInterface
            connect vehicleNetwork to vehicleInterface.network;

        connection vehicleStateToDecisionLogic
            connect vehicleInterface.network to decisionLogic.vehicleInput;

        connection trackerToDecisionLogic
            connect tracker.trackOutput to decisionLogic.objectInput;

        connection decisionToLeftIndicator
            connect decisionLogic.alertOutput to driverAlerts.leftIndicatorInput;

        connection decisionToRightIndicator
            connect decisionLogic.alertOutput to driverAlerts.rightIndicatorInput;

        perform action MonitorBlindSpots {
            in item hostVehicleState : HostVehicleState;
            out item alert : BlindSpotAlertCommand;

            objective {
                doc
                /* Continuously acquire radar reflections, maintain object tracks,
                   determine whether tracked objects are inside the left or right
                   blind spot zones, and command visual, audible, or haptic alerts
                   according to driver intent and collision urgency. */
            }
        }
    }

    requirement def DetectAdjacentBlindSpotObjects {
        doc
        /* The system shall detect relevant road objects in the left and right adjacent
           blind spot zones while the host vehicle is moving forward above the minimum
           activation speed. */

        subject monitor : BlindSpotMonitor;

        require constraint {
            monitor.decisionLogic.minimumHostSpeedForAlert <= 10 [km/h]
        }
    }

    requirement def AlertDriverForOccupiedZone {
        doc
        /* The system shall provide a visual advisory alert when a tracked object is
           present in an adjacent blind spot zone with sufficient confidence. */

        subject command : BlindSpotAlertCommand;

        require constraint {
            command.visualIndicatorOn == true implies command.priority != AlertPriorityKind::none
        }
    }

    requirement def EscalateAlertOnTurnSignal {
        doc
        /* The system shall escalate the alert priority when the driver activates the
           turn signal toward an occupied blind spot side. */

        subject command : BlindSpotAlertCommand;
        subject host : HostVehicleState;

        require constraint {
            (host.leftTurnSignalActive or host.rightTurnSignalActive) implies
            (command.priority == AlertPriorityKind::warning or command.priority == AlertPriorityKind::urgent)
        }
    }

    requirement def SuppressAlertsWhenUnavailable {
        doc
        /* The system shall suppress blind spot alerts when the host vehicle is in
           reverse gear or when a critical diagnostic fault is present. */

        subject host : HostVehicleState;
        subject diagnostic : DiagnosticStatus;
        subject command : BlindSpotAlertCommand;

        require constraint {
            (host.reverseGearSelected or not diagnostic.sensorAvailable or not diagnostic.processorAvailable)
            implies command.priority == AlertPriorityKind::none
        }
    }

    requirement def DetectionRangeCoverage {
        doc
        /* Each rear side radar sensor shall cover at least the configured blind spot
           zone depth and lateral extent. */

        subject sensor : ShortRangeRadarSensor;

        require constraint {
            sensor.maximumDetectionRange >= 7 [m] and sensor.horizontalFieldOfView >= 120 [deg]
        }
    }

    requirement def TimelyUpdate {
        doc
        /* The blind spot monitor shall update object detection and alert decisions
           at least every 100 milliseconds. */

        subject sensor : ShortRangeRadarSensor;

        require constraint {
            sensor.updatePeriod <= 0.1 [s]
        }
    }

    satisfy DetectAdjacentBlindSpotObjects by BlindSpotMonitor;
    satisfy AlertDriverForOccupiedZone by BlindSpotMonitor::decisionLogic;
    satisfy EscalateAlertOnTurnSignal by BlindSpotMonitor::decisionLogic;
    satisfy SuppressAlertsWhenUnavailable by BlindSpotMonitor::decisionLogic;
    satisfy DetectionRangeCoverage by BlindSpotMonitor::leftRadar;
    satisfy DetectionRangeCoverage by BlindSpotMonitor::rightRadar;
    satisfy TimelyUpdate by BlindSpotMonitor::leftRadar;
    satisfy TimelyUpdate by BlindSpotMonitor::rightRadar;

}