package StadiometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    attribute def HeightValue :> LengthValue;
    attribute def PositionValue :> LengthValue;
    attribute def ForceValue :> ForceValue;
    
    enum def SystemState {
        idle;
        ready;
        positioning;
        measuring;
        displaying;
        error;
    }
    
    enum def CalibrationState {
        calibrated;
        requiresCalibration;
        outOfSpec;
    }

    item def Person {
        attribute actualHeight : HeightValue;
        attribute weight : MassValue;
    }

    item def HeightReading {
        attribute value : HeightValue;
        attribute timestamp : Real;
        attribute valid : Boolean;
    }

    port def MeasurementDataPort {
        out reading : HeightReading;
    }

    port def DisplayInputPort {
        in measurement : HeightReading;
    }

    port def SensorOutputPort {
        out position : PositionValue;
    }

    part def VerticalRail {
        attribute length : HeightValue = 2500.0 [mm];
        attribute scaleMin : HeightValue = 200.0 [mm];
        attribute scaleMax : HeightValue = 2200.0 [mm];
        attribute calibrationState : CalibrationState;
        attribute zeroOffset : HeightValue = 0.0 [mm];
    }

    part def SlidingHeadpiece {
        attribute currentPosition : PositionValue;
        attribute locked : Boolean = false;
        attribute contactForce : ForceValue;
        attribute maxTravel : HeightValue = 2000.0 [mm];
    }

    part def PositionSensor {
        attribute resolution : HeightValue = 0.1 [mm];
        attribute accuracy : HeightValue = 0.5 [mm];
        attribute measurementRange : HeightValue = 2500.0 [mm];
        out port sensorOut : SensorOutputPort;
    }

    part def DigitalDisplay {
        attribute screenSize : LengthValue = 100.0 [mm];
        attribute brightness : Real = 0.8;
        attribute currentReading : HeightValue;
        attribute displayState : SystemState;
        in port dataIn : DisplayInputPort;
    }

    part def BasePlatform {
        attribute footprint : AreaValue;
        attribute levelTolerance : Real = 0.001;
        attribute isLevel : Boolean = true;
        attribute mass : MassValue = 5.0 [kg];
    }

    part def ControlUnit {
        attribute systemState : SystemState = SystemState::idle;
        attribute measurementCount : Integer = 0;
        attribute lastCalibrationDate : Real;
    }

    action def InitializeSystem {
        out initComplete : Boolean;
        out systemReady : Boolean;
        first start;
        then action checkCalibration {
            out calibrationValid : Boolean;
        }
        then action levelCheck {
            out levelOk : Boolean;
        }
        then decide;
            if checkCalibration.calibrationValid and levelCheck.levelOk then setReady;
            if !(checkCalibration.calibrationValid and levelCheck.levelOk) then setError;
        action setReady {
            out ready : Boolean;
        }
        action setError {
            out errorFlag : Boolean;
        }
        then done;
    }

    action def PositionHeadpiece {
        in targetHeight : HeightValue;
        out finalPosition : PositionValue;
        out positioningSuccess : Boolean;
        first start;
        then action unlockHeadpiece {
            out unlocked : Boolean;
        }
        then action moveToPosition {
            in target : HeightValue;
            out reached : Boolean;
        }
        then action verifyPosition {
            out verified : Boolean;
        }
        then done;
    }

    action def DetectHeadContact {
        out contactDetected : Boolean;
        out contactStable : Boolean;
        out appliedForce : ForceValue;
    }

    action def AcquireHeightMeasurement {
        out rawPosition : PositionValue;
        out calibratedHeight : HeightValue;
        out measurementValid : Boolean;
        first start;
        then action readSensor {
            out sensorValue : PositionValue;
        }
        then action applyCalibration {
            in rawValue : PositionValue;
            in offset : HeightValue;
            out correctedValue : HeightValue;
        }
        then action validateReading {
            in value : HeightValue;
            out valid : Boolean;
        }
        then done;
    }

    action def DisplayHeight {
        in heightValue : HeightValue;
        in status : SystemState;
    }

    action def PerformMeasurement {
        out finalHeight : HeightValue;
        out measurementSuccess : Boolean;
        first start;
        then merge awaitSubject;
        then action detectSubject {
            out subjectPresent : Boolean;
        }
        then decide;
            if detectSubject.subjectPresent then lowerHeadpiece;
            if !detectSubject.subjectPresent then awaitSubject;
        action lowerHeadpiece : PositionHeadpiece {
            in targetHeight : HeightValue;
        }
        then action waitForContact : DetectHeadContact {
            out contactDetected : Boolean;
        }
        then decide;
            if !waitForContact.contactDetected then lowerHeadpiece;
            if waitForContact.contactDetected then lockAndMeasure;
        action lockAndMeasure {
            first action lockHeadpiece {
                out locked : Boolean;
            }
            then action stabilize {
                out stable : Boolean;
            }
            then action measure : AcquireHeightMeasurement {
                out calibratedHeight : HeightValue;
            }
            then done;
        }
        then action displayResult : DisplayHeight {
            in heightValue = lockAndMeasure.measure.calibratedHeight;
            in status = SystemState::displaying;
        }
        then action raiseHeadpiece : PositionHeadpiece {
            in targetHeight = 2000.0 [mm];
        }
        then action recordMeasurement {
            in height = lockAndMeasure.measure.calibratedHeight;
            out recorded : Boolean;
        }
        then awaitSubject;
    }

    state def StadiometerOperationalBehavior {
        entry; then idle;
        
        state idle {
            entry action setIdleState {
                out state : SystemState = SystemState::idle;
            }
        }
        
        transition idle_to_ready
            first idle
            accept SystemInitialized
            then ready;
        
        state ready {
            entry action prepareSystem {
                out prepared : Boolean;
            }
        }
        
        transition ready_to_positioning
            first ready
            accept SubjectDetected
            then positioning;
        
        state positioning {
            do action positioningAction : PositionHeadpiece {
                in targetHeight : HeightValue;
            }
        }
        
        transition positioning_to_measuring
            first positioning
            accept ContactDetected
            then measuring;
        
        state measuring {
            entry action lockAndRead;
            do action measurementAction : AcquireHeightMeasurement;
        }
        
        transition measuring_to_displaying
            first measuring
            accept MeasurementComplete
            then displaying;
        
        state displaying {
            entry action showMeasurement;
            do action displayAction : DisplayHeight {
                in heightValue : HeightValue;
                in status : SystemState;
            }
        }
        
        transition displaying_to_ready
            first displaying
            after 5.0 [s]
            then ready;
        
        transition any_to_error
            accept SystemError
            then error;
        
        state error {
            entry action handleError {
                out errorCode : Integer;
            }
        }
        
        transition error_to_idle
            first error
            accept ErrorCleared
            then idle;
    }

    part def Stadiometer {
        doc /* A precision height measurement device consisting of a vertical rail 
             * with calibrated scale, a sliding headpiece that contacts the subject's head,
             * position sensors, and a digital display for presenting measurements.
            */
        
        attribute currentState : SystemState = SystemState::idle;
        attribute lastMeasuredHeight : HeightValue;
        attribute totalMeasurements : Integer = 0;
        attribute calibrationDue : Boolean = false;
        
        out port measurementOutput : MeasurementDataPort;
        
        part rail : VerticalRail {
            attribute :>> length = 2500.0 [mm];
            attribute :>> scaleMin = 200.0 [mm];
            attribute :>> scaleMax = 2200.0 [mm];
            attribute :>> calibrationState = CalibrationState::calibrated;
        }
        
        part headpiece : SlidingHeadpiece {
            attribute :>> currentPosition = 2000.0 [mm];
            attribute :>> locked = false;
            attribute :>> maxTravel = 2000.0 [mm];
        }
        
        part sensor : PositionSensor {
            attribute :>> resolution = 0.1 [mm];
            attribute :>> accuracy = 0.5 [mm];
            attribute :>> measurementRange = 2500.0 [mm];
        }
        
        part display : DigitalDisplay {
            attribute :>> screenSize = 100.0 [mm];
            attribute :>> brightness = 0.8;
            attribute :>> displayState = SystemState::idle;
        }
        
        part base : BasePlatform {
            attribute :>> levelTolerance = 0.001;
            attribute :>> isLevel = true;
            attribute :>> mass = 5.0 [kg];
        }
        
        part controller : ControlUnit {
            attribute :>> systemState = SystemState::idle;
            attribute :>> measurementCount = 0;
        }
        
        connect sensor.sensorOut to measurementOutput;
        connect measurementOutput to display.dataIn;
        
        perform action initialization : InitializeSystem;
        perform action measurementCycle : PerformMeasurement[*];
        
        exhibit state behavior : StadiometerOperationalBehavior;
    }

    constraint def MeasurementAccuracyConstraint {
        in measured : HeightValue;
        in actual : HeightValue;
        in tolerance : HeightValue;
        abs(measured - actual) <= tolerance
    }

    constraint def MeasurementRangeConstraint {
        in height : HeightValue;
        in minHeight : HeightValue;
        in maxHeight : HeightValue;
        height >= minHeight and height <= maxHeight
    }

    constraint def CalibrationValidityConstraint {
        in calibrationState : CalibrationState;
        calibrationState == CalibrationState::calibrated
    }

    requirement <'REQ-STA-001'> primaryMeasurementFunction {
        doc /* The stadiometer system shall measure the standing height of a person
             * by positioning a horizontal headpiece to make gentle contact with the
             * top of the subject's head and determining the vertical distance from
             * the base platform to the headpiece position using a calibrated scale.
            */
        subject stadiometer : Stadiometer;
    }

    requirement <'REQ-STA-002'> measurementAccuracy {
        doc /* The stadiometer shall measure height with an accuracy of ±1.0 mm
             * across its entire measurement range.
            */
        subject stadiometer : Stadiometer;
        assert constraint accuracyCheck : MeasurementAccuracyConstraint {
            in measured = stadiometer.lastMeasuredHeight;
            in actual : HeightValue;
            in tolerance = 1.0 [mm];
        }
    }

    requirement <'REQ-STA-003'> operationalRange {
        doc /* The stadiometer shall be capable of measuring heights from 200 mm
             * to 2200 mm.
            */
        subject stadiometer : Stadiometer;
        assert constraint rangeCheck : MeasurementRangeConstraint {
            in height = stadiometer.lastMeasuredHeight;
            in minHeight = 200.0 [mm];
            in maxHeight = 2200.0 [mm];
        }
    }

    requirement <'REQ-STA-004'> calibrationRequirement {
        doc /* The stadiometer shall maintain valid calibration and indicate when
             * recalibration is required.
            */
        subject rail :>> stadiometer.rail;
        assert constraint calibrationCheck : CalibrationValidityConstraint {
            in calibrationState = rail.calibrationState;
        }
    }

    requirement <'REQ-STA-005'> displayRequirement {
        doc /* The digital display shall clearly present the measured height value
             * in millimeters with resolution of 0.1 mm and indicate system status.
            */
        subject display :>> stadiometer.display;
    }

    requirement <'REQ-STA-006'> stabilityRequirement {
        doc /* The base platform shall maintain level orientation within 0.1% tolerance
             * to ensure measurement accuracy.
            */
        subject base :>> stadiometer.base;
        assert constraint {
            base.isLevel and base.levelTolerance <= 0.001
        }
    }

    part stadiometerSystem : Stadiometer {
        attribute :>> currentState = SystemState::idle;
        attribute :>> totalMeasurements = 0;
        
        part :>> rail {
            attribute :>> calibrationState = CalibrationState::calibrated;
            attribute :>> zeroOffset = 0.0 [mm];
        }
        
        part :>> headpiece {
            attribute :>> currentPosition = 2000.0 [mm];
        }
        
        part :>> sensor {
            attribute :>> accuracy = 0.5 [mm];
        }
        
        part :>> display {
            attribute :>> brightness = 1.0;
        }
    }

    satisfy primaryMeasurementFunction by stadiometerSystem;
    satisfy measurementAccuracy by stadiometerSystem;
    satisfy operationalRange by stadiometerSystem;
    satisfy calibrationRequirement by stadiometerSystem.rail;
    satisfy displayRequirement by stadiometerSystem.display;
    satisfy stabilityRequirement by stadiometerSystem.base;
}
