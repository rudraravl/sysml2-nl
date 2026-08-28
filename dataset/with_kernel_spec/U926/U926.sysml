package TriangulationPositioningSystem {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    private import ScalarValues::String;
    private import ScalarValues::Integer;
    private import ISQ::LengthValue;
    private import ISQ::PlaneAngleValue;
    private import SI::m;
    private import SI::rad;
    private import SI::s;

    attribute def Distance :> LengthValue;
    attribute def Angle :> PlaneAngleValue;
    attribute def Confidence :> Real;

    attribute def Coordinate3D {
        attribute x : Distance;
        attribute y : Distance;
        attribute z : Distance;
    }

    item def BeaconSignal {
        attribute beaconId : String;
        attribute location : Coordinate3D;
    }

    item def RangeMeasurement {
        attribute beaconId : String;
        attribute beaconLocation : Coordinate3D;
        attribute distance : Distance;
        attribute azimuth : Angle;
        attribute elevation : Angle;
    }

    item def ValidatedMeasurement :> RangeMeasurement {
        attribute isValid : Boolean;
        attribute errorMargin : Distance;
    }

    item def ValidatedMeasurementSet {
        attribute measurements : ValidatedMeasurement[3];
    }

    item def PositionEstimate {
        attribute coordinates : Coordinate3D;
        attribute accuracy : Distance;
        attribute confidence : Confidence;
    }

    port def SignalOutPort { out signal : BeaconSignal; }
    port def SignalInPort { in signal : BeaconSignal; }
    port def MeasurementOutPort { out measurement : RangeMeasurement; }
    port def MeasurementInPort { in measurement : RangeMeasurement; }
    port def ValidatedOutPort { out validated : ValidatedMeasurementSet; }
    port def ValidatedInPort { in validated : ValidatedMeasurementSet; }
    port def PositionOutPort { out position : PositionEstimate; }
    port def PositionInPort { in position : PositionEstimate; }

    part def Beacon {
        attribute beaconId : String;
        attribute location : Coordinate3D;
        port signalPort : SignalOutPort;
    }

    part def RangeFinder {
        port signalPort : SignalInPort;
        port measurementPort : MeasurementOutPort;
    }

    part def DataValidator {
        port measurementPort1 : MeasurementInPort;
        port measurementPort2 : MeasurementInPort;
        port measurementPort3 : MeasurementInPort;
        port validatedPort : ValidatedOutPort;
        attribute maxErrorMargin : Distance = 0.5 [m];
    }

    part def TriangulationProcessor {
        port validatedPort : ValidatedInPort;
        port positionPort : PositionOutPort;
    }

    part def PositionDisplay {
        port positionPort : PositionInPort;
    }

    calc def ValidateMeasurements {
        in m1 : RangeMeasurement;
        in m2 : RangeMeasurement;
        in m3 : RangeMeasurement;
        return validated : ValidatedMeasurementSet;
    }

    calc def Triangulate {
        in validated : ValidatedMeasurementSet;
        return position : PositionEstimate;
    }

    part def PositioningSystem {
        attribute measurementsReady : Boolean;
        attribute measurementsValid : Boolean;
        attribute positionReady : Boolean;

        part beacon1 : Beacon;
        part beacon2 : Beacon;
        part beacon3 : Beacon;
        part rangeFinder1 : RangeFinder;
        part rangeFinder2 : RangeFinder;
        part rangeFinder3 : RangeFinder;
        part validator : DataValidator;
        part processor : TriangulationProcessor;
        part display : PositionDisplay;

        interface conn1 connect beacon1.signalPort to rangeFinder1.signalPort {
            flow signalFlow1 of BeaconSignal from beacon1.signalPort.signal to rangeFinder1.signalPort.signal;
        }
        interface conn2 connect beacon2.signalPort to rangeFinder2.signalPort {
            flow signalFlow2 of BeaconSignal from beacon2.signalPort.signal to rangeFinder2.signalPort.signal;
        }
        interface conn3 connect beacon3.signalPort to rangeFinder3.signalPort {
            flow signalFlow3 of BeaconSignal from beacon3.signalPort.signal to rangeFinder3.signalPort.signal;
        }
        interface conn4 connect rangeFinder1.measurementPort to validator.measurementPort1 {
            flow measurementFlow1 of RangeMeasurement from rangeFinder1.measurementPort.measurement to validator.measurementPort1.measurement;
        }
        interface conn5 connect rangeFinder2.measurementPort to validator.measurementPort2 {
            flow measurementFlow2 of RangeMeasurement from rangeFinder2.measurementPort.measurement to validator.measurementPort2.measurement;
        }
        interface conn6 connect rangeFinder3.measurementPort to validator.measurementPort3 {
            flow measurementFlow3 of RangeMeasurement from rangeFinder3.measurementPort.measurement to validator.measurementPort3.measurement;
        }
        interface conn7 connect validator.validatedPort to processor.validatedPort {
            flow validatedFlow of ValidatedMeasurementSet from validator.validatedPort.validated to processor.validatedPort.validated;
        }
        interface conn8 connect processor.positionPort to display.positionPort {
            flow positionFlow of PositionEstimate from processor.positionPort.position to display.positionPort.position;
        }

        state def PositioningCycle {
            state AcquiringSignals;
            state ProcessingData;
            state Error;

            transition from AcquiringSignals to ProcessingData when measurementsReady;
            transition from ProcessingData to AcquiringSignals when positionReady;
            transition from AcquiringSignals to Error when !measurementsValid;
            transition from Error to AcquiringSignals when true;
        }

        part positioningCycle : PositioningCycle;
    }

    requirement PositioningAccuracy {
        doc /* The system shall determine position with accuracy of at least 1 meter. */
        attribute requiredAccuracy : Distance = 1.0 [m];
    }

    requirement MeasurementValidation {
        doc /* The system shall validate range measurements within acceptable error limits. */
        attribute maxAcceptableError : Distance = 0.5 [m];
    }

    requirement ContinuousOperation {
        doc /* The system shall operate in a continuous cycle. */
    }

    requirement ErrorRecovery {
        doc /* The system shall enter Error state and attempt recovery. */
    }

    requirement MinimumBeacons {
        doc /* The system shall use at least three fixed Beacons. */
        attribute minBeaconCount : Integer = 3;
    }

    part positioningSystem : PositioningSystem {
        satisfy PositioningAccuracy by processor;
        satisfy MeasurementValidation by validator;
        satisfy ContinuousOperation by positioningCycle;
        satisfy ErrorRecovery by positioningCycle;
        satisfy MinimumBeacons by beacon1;
    }
}
