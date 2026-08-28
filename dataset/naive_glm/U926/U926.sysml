package TriangulationPositioningSystem {
    import ScalarValues::*;

    // ===== Units =====
    unit m;
    unit rad;
    unit s;
    unit dBm;
    unit percent;

    // ===== Value Types =====
    value def Distance :> Real { unit = m; }
    value def Angle :> Real { unit = rad; }
    value def Coordinate :> Real { unit = m; }
    value def Accuracy :> Real { unit = m; }
    value def Confidence :> Real { unit = percent; }
    value def SignalStrength :> Real { unit = dBm; }
    value def TimeStamp :> Real { unit = s; }

    value def Position3D {
        attribute x : Coordinate;
        attribute y : Coordinate;
        attribute z : Coordinate;
    }

    // ===== Item Types =====
    item def BeaconSignal {
        attribute beaconId : String;
        attribute beaconLocation : Position3D;
        attribute timestamp : TimeStamp;
        attribute signalStrength : SignalStrength;
    }

    item def RangeMeasurement {
        attribute beaconId : String;
        attribute distance : Distance;
        attribute azimuth : Angle;
        attribute elevation : Angle;
        attribute timestamp : TimeStamp;
    }

    item def ValidatedMeasurement {
        attribute beaconId : String;
        attribute distance : Distance;
        attribute azimuth : Angle;
        attribute elevation : Angle;
        attribute isValid : Boolean;
        attribute validationError : String;
    }

    item def PositionEstimate {
        attribute position : Position3D;
        attribute accuracy : Accuracy;
        attribute confidence : Confidence;
        attribute timestamp : TimeStamp;
    }

    // ===== Port Definitions =====
    port def SignalOutPort {
        out signal : BeaconSignal;
    }

    port def SignalInPort {
        in signal : BeaconSignal;
    }

    port def MeasurementOutPort {
        out measurement : RangeMeasurement;
    }

    port def MeasurementInPort {
        in measurement : RangeMeasurement;
    }

    port def ValidatedOutPort {
        out validated : ValidatedMeasurement;
    }

    port def ValidatedInPort {
        in validated : ValidatedMeasurement;
    }

    port def PositionOutPort {
        out estimate : PositionEstimate;
    }

    port def PositionInPort {
        in estimate : PositionEstimate;
    }

    // ===== Beacon =====
    part def Beacon {
        attribute beaconId : String;
        attribute location : Position3D;
        attribute transmitInterval : TimeStamp = 0.1;
        port signalOut : SignalOutPort;

        action def TransmitSignal {
            in id : String;
            in loc : Position3D;
            out signal : BeaconSignal;
        }

        action transmit : TransmitSignal {
            in id = beaconId;
            in loc = location;
            out signal to signalOut.signal;
        }
    }

    // ===== Range Finder =====
    part def RangeFinder {
        attribute assignedBeaconId : String;
        port signalIn : SignalInPort;
        port measurementOut : MeasurementOutPort;

        action def CalculateRange {
            in signal : BeaconSignal;
            out measurement : RangeMeasurement;
        }

        action calculate : CalculateRange {
            in signal from signalIn.signal;
            out measurement to measurementOut.measurement;
        }
    }

    // ===== Data Validator =====
    part def DataValidator {
        port measurementsIn : MeasurementInPort[3];
        port validatedOut : ValidatedOutPort[3];

        attribute maxDistance : Distance = 1000.0;
        attribute minDistance : Distance = 0.5;
        attribute maxAzimuth : Angle = 6.283;
        attribute maxElevation : Angle = 1.571;
        attribute maxRetries : Integer = 3;
        attribute retryCount : Integer = 0;

        action def ValidateMeasurements {
            in measurements : RangeMeasurement[3];
            out validated : ValidatedMeasurement[3];
        }

        action validate : ValidateMeasurements {
            in measurements from measurementsIn.measurement;
            out validated to validatedOut.validated;
        }
    }

    // ===== Triangulation Processor =====
    part def TriangulationProcessor {
        port validatedIn : ValidatedInPort[3];
        port positionOut : PositionOutPort;

        attribute computationTimeout : TimeStamp = 2.0;

        action def ComputePosition {
            in validated : ValidatedMeasurement[3];
            out estimate : PositionEstimate;
        }

        action compute : ComputePosition {
            in validated from validatedIn.validated;
            out estimate to positionOut.estimate;
        }
    }

    // ===== Position Display =====
    part def PositionDisplay {
        port positionIn : PositionInPort;

        attribute displayRefreshRate : TimeStamp = 0.5;

        action def DisplayPosition {
            in estimate : PositionEstimate;
        }

        action display : DisplayPosition {
            in estimate from positionIn.estimate;
        }
    }

    // ===== System =====
    part def TriangulationSystem {
        attribute systemActive : Boolean = true;
        attribute dataValid : Boolean = true;
        attribute cycleCount : Integer = 0;

        part beacon1 : Beacon {
            attribute beaconId = "B001";
            attribute location : Position3D = Position3D { x = 0.0; y = 0.0; z = 0.0; };
        }
        part beacon2 : Beacon {
            attribute beaconId = "B002";
            attribute location : Position3D = Position3D { x = 100.0; y = 0.0; z = 0.0; };
        }
        part beacon3 : Beacon {
            attribute beaconId = "B003";
            attribute location : Position3D = Position3D { x = 0.0; y = 100.0; z = 10.0; };
        }

        part rangeFinder1 : RangeFinder { attribute assignedBeaconId = "B001"; }
        part rangeFinder2 : RangeFinder { attribute assignedBeaconId = "B002"; }
        part rangeFinder3 : RangeFinder { attribute assignedBeaconId = "B003"; }

        part validator : DataValidator;
        part processor : TriangulationProcessor;
        part display : PositionDisplay;

        connection from beacon1.signalOut to rangeFinder1.signalIn;
        connection from beacon2.signalOut to rangeFinder2.signalIn;
        connection from beacon3.signalOut to rangeFinder3.signalIn;

        connection from rangeFinder1.measurementOut to validator.measurementsIn[1];
        connection from rangeFinder2.measurementOut to validator.measurementsIn[2];
        connection from rangeFinder3.measurementOut to validator.measurementsIn[3];

        connection from validator.validatedOut[1] to processor.validatedIn[1];
        connection from validator.validatedOut[2] to processor.validatedIn[2];
        connection from validator.validatedOut[3] to processor.validatedIn[3];

        connection from processor.positionOut to display.positionIn;

        stateMachine systemStates {
            state AcquiringSignals {
                entry {
                    /* Trigger beacon transmissions and range finder calculations */
                }
            }
            state ProcessingData {
                entry {
                    /* Validate measurements and compute triangulated position */
                }
            }
            state Error {
                entry {
                    /* Log error condition and prepare retry */
                }
            }
            transition from AcquiringSignals to ProcessingData if dataValid;
            transition from ProcessingData to AcquiringSignals after 1.0 [s];
            transition from AcquiringSignals to Error if not dataValid;
            transition from Error to AcquiringSignals after 2.0 [s];
        }
    }

    // ===== Requirements =====
    requirement def PositioningSystemRequirement {
        doc "The system shall determine the precise 3D location of an object using triangulation from at least three fixed beacons.";
        subject system : TriangulationSystem;
    }

    requirement def MinBeaconRequirement {
        doc "The system shall include at least three fixed beacons at known coordinates.";
        subject system : TriangulationSystem;
    }

    requirement def AccuracyRequirement {
        doc "The system shall compute position with accuracy better than 1 meter.";
        attribute maxError : Accuracy = 1.0;
        subject system : TriangulationSystem;
    }

    requirement def ContinuousUpdateRequirement {
        doc "The system shall continuously update position estimates in a cyclic manner.";
        subject system : TriangulationSystem;
    }

    requirement def ErrorRecoveryRequirement {
        doc "The system shall enter an Error state upon detecting invalid data and shall attempt recovery by retrying.";
        subject system : TriangulationSystem;
    }

    requirement def ConfidenceReportingRequirement {
        doc "Each position estimate shall include an accuracy and confidence level.";
        subject system : TriangulationSystem;
    }

    requirement def SignalTransmissionRequirement {
        doc "Each beacon shall continuously transmit a unique signal including its ID and location.";
        subject beacon : Beacon;
    }

    requirement def RangeCalculationRequirement {
        doc "Each range finder shall calculate distance and angle to its assigned beacon upon signal reception.";
        subject rangeFinder : RangeFinder;
    }

    requirement def ValidationRequirement {
        doc "The data validator shall reject measurements that exceed acceptable error limits.";
        subject validator : DataValidator;
    }

    // ===== Satisfaction =====
    part systemInstance : TriangulationSystem;

    satisfy PositioningSystemRequirement by systemInstance;
    satisfy MinBeaconRequirement by systemInstance;
    satisfy AccuracyRequirement by systemInstance;
    satisfy ContinuousUpdateRequirement by systemInstance;
    satisfy ErrorRecoveryRequirement by systemInstance;
    satisfy ConfidenceReportingRequirement by systemInstance;
    satisfy SignalTransmissionRequirement by systemInstance.beacon1;
    satisfy RangeCalculationRequirement by systemInstance.rangeFinder1;
    satisfy ValidationRequirement by systemInstance.validator;
}
