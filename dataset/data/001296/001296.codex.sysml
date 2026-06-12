package TriangulationSystemModel {
    doc /* A triangulation-based system estimates the two-dimensional position of a target by measuring bearing angles from two spatially separated reference stations, combining those measurements with the known baseline geometry, validating the resulting intersection, and publishing a position estimate with quality metadata. */

    package Units {
        attribute def Meter;
        attribute def Degree;
        attribute def Second;
        attribute def Hertz;
        attribute def Percent;
        attribute def Radian;
        attribute def Boolean;
    }

    item def BearingMeasurement {
        attribute stationId : String;
        attribute bearing : Units::Degree;
        attribute timestamp : Units::Second;
        attribute signalQuality : Units::Percent;
    }

    item def StationPose {
        attribute stationId : String;
        attribute x : Units::Meter;
        attribute y : Units::Meter;
        attribute heading : Units::Degree;
    }

    item def TargetSignal {
        attribute receivedPower : Units::Percent;
        attribute timeObserved : Units::Second;
    }

    item def PositionEstimate {
        attribute x : Units::Meter;
        attribute y : Units::Meter;
        attribute uncertaintyRadius : Units::Meter;
        attribute confidence : Units::Percent;
        attribute timestamp : Units::Second;
    }

    item def DiagnosticReport {
        attribute baselineValid : Units::Boolean;
        attribute angleDivergenceValid : Units::Boolean;
        attribute estimateAvailable : Units::Boolean;
        attribute faultCode : String;
    }

    port def SignalInputPort {
        in item signal : TargetSignal;
    }

    port def BearingOutputPort {
        out item bearing : BearingMeasurement;
    }

    port def PosePort {
        out item pose : StationPose;
    }

    port def EstimateOutputPort {
        out item estimate : PositionEstimate;
    }

    port def DiagnosticOutputPort {
        out item report : DiagnosticReport;
    }

    part def ReferenceStation {
        attribute stationId : String;
        attribute x : Units::Meter;
        attribute y : Units::Meter;
        attribute heading : Units::Degree;
        attribute angularResolution : Units::Degree;
        attribute minimumSignalQuality : Units::Percent;

        port signalIn : SignalInputPort;
        port bearingOut : BearingOutputPort;
        port poseOut : PosePort;

        action determineBearing {
            in item observedSignal : TargetSignal;
            out item bearingMeasurement : BearingMeasurement;
        }

        state stationOperatingState {
            state Off;
            state Calibrating;
            state Tracking;
            state Degraded;

            entry action Off;
            then Calibrating;

            transition first Calibrating to Tracking
                accept Calibrated;

            transition Tracking to Degraded
                accept LowSignalQuality;

            transition Degraded to Tracking
                accept SignalRecovered;
        }
    }

    part def BaselineGeometry {
        attribute stationA_x : Units::Meter;
        attribute stationA_y : Units::Meter;
        attribute stationB_x : Units::Meter;
        attribute stationB_y : Units::Meter;
        attribute baselineLength : Units::Meter;
        attribute baselineHeading : Units::Degree;
        attribute minimumBaselineLength : Units::Meter;

        action computeBaseline {
            in item poseA : StationPose;
            in item poseB : StationPose;
            out attribute length : Units::Meter;
            out attribute heading : Units::Degree;
        }
    }

    part def TriangulationProcessor {
        attribute minimumAngleSeparation : Units::Degree;
        attribute maximumAngleSeparation : Units::Degree;
        attribute maximumAllowedUncertainty : Units::Meter;
        attribute updateRate : Units::Hertz;

        port bearingAIn : BearingOutputPort;
        port bearingBIn : BearingOutputPort;
        port poseAIn : PosePort;
        port poseBIn : PosePort;
        port estimateOut : EstimateOutputPort;
        port diagnosticOut : DiagnosticOutputPort;

        part baseline : BaselineGeometry;

        action validateInputs {
            in item bearingA : BearingMeasurement;
            in item bearingB : BearingMeasurement;
            in item poseA : StationPose;
            in item poseB : StationPose;
            out item diagnostic : DiagnosticReport;
        }

        action intersectBearings {
            in item bearingA : BearingMeasurement;
            in item bearingB : BearingMeasurement;
            in item poseA : StationPose;
            in item poseB : StationPose;
            out item estimate : PositionEstimate;
        }

        action estimateUncertainty {
            in item estimate : PositionEstimate;
            in item bearingA : BearingMeasurement;
            in item bearingB : BearingMeasurement;
            out attribute uncertaintyRadius : Units::Meter;
            out attribute confidence : Units::Percent;
        }

        state processorState {
            state WaitingForMeasurements;
            state ValidatingGeometry;
            state ComputingIntersection;
            state PublishingEstimate;
            state Faulted;

            entry action WaitingForMeasurements;
            transition WaitingForMeasurements to ValidatingGeometry
                accept MeasurementPairReceived;

            transition ValidatingGeometry to ComputingIntersection
                accept GeometryValid;

            transition ValidatingGeometry to Faulted
                accept GeometryInvalid;

            transition ComputingIntersection to PublishingEstimate
                accept IntersectionComputed;

            transition ComputingIntersection to Faulted
                accept ParallelBearingsDetected;

            transition PublishingEstimate to WaitingForMeasurements
                accept EstimatePublished;

            transition Faulted to WaitingForMeasurements
                accept FaultCleared;
        }
    }

    part def PositionConsumer {
        port estimateIn : EstimateOutputPort;

        action usePositionEstimate {
            in item estimate : PositionEstimate;
        }
    }

    part def TriangulationBasedLocator {
        attribute primaryFunction : String = "Estimate target position by intersecting bearing measurements from two known reference stations.";
        attribute nominalUpdateRate : Units::Hertz = 10;
        attribute requiredConfidence : Units::Percent = 95;
        attribute maximumPositionError : Units::Meter = 5;

        port targetSignalInA : SignalInputPort;
        port targetSignalInB : SignalInputPort;
        port positionOut : EstimateOutputPort;
        port healthOut : DiagnosticOutputPort;

        part stationA : ReferenceStation {
            attribute stationId = "A";
            attribute x = 0;
            attribute y = 0;
            attribute heading = 0;
            attribute angularResolution = 0.25;
            attribute minimumSignalQuality = 40;
        }

        part stationB : ReferenceStation {
            attribute stationId = "B";
            attribute x = 100;
            attribute y = 0;
            attribute heading = 0;
            attribute angularResolution = 0.25;
            attribute minimumSignalQuality = 40;
        }

        part processor : TriangulationProcessor {
            attribute minimumAngleSeparation = 10;
            attribute maximumAngleSeparation = 170;
            attribute maximumAllowedUncertainty = 5;
            attribute updateRate = 10;
        }

        part consumer : PositionConsumer;

        connect targetSignalInA to stationA.signalIn;
        connect targetSignalInB to stationB.signalIn;

        connect stationA.bearingOut to processor.bearingAIn;
        connect stationB.bearingOut to processor.bearingBIn;
        connect stationA.poseOut to processor.poseAIn;
        connect stationB.poseOut to processor.poseBIn;

        connect processor.estimateOut to positionOut;
        connect processor.estimateOut to consumer.estimateIn;
        connect processor.diagnosticOut to healthOut;
    }

    requirement def PositionAccuracyRequirement {
        subject locator : TriangulationBasedLocator;
        attribute maximumError : Units::Meter = 5;

        require constraint {
            locator.maximumPositionError <= maximumError
        }
    }

    requirement def BearingSeparationRequirement {
        subject processor : TriangulationProcessor;
        attribute minimumSeparation : Units::Degree = 10;
        attribute maximumSeparation : Units::Degree = 170;

        require constraint {
            processor.minimumAngleSeparation >= minimumSeparation and
            processor.maximumAngleSeparation <= maximumSeparation
        }
    }

    requirement def ConfidenceRequirement {
        subject locator : TriangulationBasedLocator;
        attribute minimumConfidence : Units::Percent = 95;

        require constraint {
            locator.requiredConfidence >= minimumConfidence
        }
    }

    requirement def BaselineRequirement {
        subject locator : TriangulationBasedLocator;
        attribute minimumBaseline : Units::Meter = 25;

        require constraint {
            locator.processor.baseline.baselineLength >= minimumBaseline
        }
    }

    action def LocateTarget {
        in item signalAtStationA : TargetSignal;
        in item signalAtStationB : TargetSignal;
        out item estimatedPosition : PositionEstimate;

        first start;
        then collectBearings;
        then validateTriangulationGeometry;
        then computeTargetIntersection;
        then publishPositionEstimate;
        then done;

        action collectBearings;
        action validateTriangulationGeometry;
        action computeTargetIntersection;
        action publishPositionEstimate;
    }

    part triangulationLocator : TriangulationBasedLocator;

    satisfy PositionAccuracyRequirement by triangulationLocator;
    satisfy ConfidenceRequirement by triangulationLocator;
    satisfy BearingSeparationRequirement by triangulationLocator.processor;
    satisfy BaselineRequirement by triangulationLocator;
}