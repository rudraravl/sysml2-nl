package OdometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def PulseCount :> Integer;
    attribute def RotationRate :> Real;
    
    item def Vehicle;
    item def Wheel;
    
    part def WheelRotationSensor {
        doc /* Detects wheel rotations and generates pulses for each complete revolution. */
        
        attribute pulsesPerRevolution : PulseCount = 48;
        attribute currentRotationRate : RotationRate = 0.0;
        attribute totalPulseCount : PulseCount = 0;
        
        out port pulseOutput {
            out pulses : PulseCount;
            out rate : RotationRate;
        }
        
        perform action generatePulses {
            first start;
            then merge continueSensing;
            then action detectRotation {
                out rotationDetected : Boolean;
            }
            then decide;
                if detectRotation.rotationDetected then emitPulse;
            action emitPulse {
                out pulsesToOutput : PulseCount;
                out rateToOutput : RotationRate;
            }
            then continueSensing;
            then done;
        }
    }
    
    part def DistanceCalculationUnit {
        doc /* Converts wheel rotation pulses into distance measurements. */
        
        attribute wheelDiameter : LengthValue = 0.65[m];
        attribute wheelCircumference : LengthValue = wheelDiameter * 3.14159265;
        attribute accumulatedPulses : PulseCount = 0;
        attribute totalDistance : LengthValue = 0.0[m];
        attribute currentSpeed : SpeedValue = 0.0[m/s];
        
        in port pulseInput {
            in pulses : PulseCount;
            in rate : RotationRate;
        }
        
        out port distanceOutput {
            out distance : LengthValue;
            out speed : SpeedValue;
        }
        
        perform action calculateDistance {
            first start;
            then merge processingLoop;
            then action receivePulses {
                accept newPulses : PulseCount from pulseInput.pulses;
                accept rotationRate : RotationRate from pulseInput.rate;
                out pulseCount = newPulses;
                out rate = rotationRate;
            }
            then action computeDistance {
                in pulseCount = receivePulses.pulseCount;
                in rate = receivePulses.rate;
                out calculatedDistance : LengthValue;
                out calculatedSpeed : SpeedValue;
            }
            then processingLoop;
            then done;
        }
    }
    
    part def NonVolatileStorage {
        doc /* Stores odometer reading persistently to survive power loss. */
        
        attribute storedTotalDistance : LengthValue = 0.0[m];
        attribute storedTripDistance : LengthValue = 0.0[m];
        
        action saveDistance {
            in distanceToStore : LengthValue;
        }
        
        action loadDistance {
            out restoredDistance : LengthValue;
        }
    }
    
    part def TripMeter {
        doc /* Tracks resettable trip distance separate from total odometer reading. */
        
        attribute tripDistance : LengthValue = 0.0[m];
        attribute isReset : Boolean = false;
        
        in port distanceInput {
            in incrementalDistance : LengthValue;
        }
        
        out port tripOutput {
            out currentTrip : LengthValue;
        }
        
        action updateTrip {
            first start;
            then merge tripLoop;
            then action receiveIncrement {
                accept increment : LengthValue from distanceInput.incrementalDistance;
                out distanceIncrement = increment;
            }
            then decide;
                if isReset then resetTrip;
                else accumulateTrip;
            action resetTrip;
            then tripLoop;
            action accumulateTrip {
                in increment = receiveIncrement.distanceIncrement;
                out tripValue : LengthValue;
            }
            then tripLoop;
            then done;
        }
    }
    
    part def DisplayUnit {
        doc /* Presents total distance and trip distance to the user. */
        
        attribute displayedTotalDistance : LengthValue = 0.0[km];
        attribute displayedTripDistance : LengthValue = 0.0[km];
        attribute displayedSpeed : SpeedValue = 0.0[km/h];
        
        in port totalDistanceInput {
            in totalDist : LengthValue;
        }
        
        in port tripDistanceInput {
            in tripDist : LengthValue;
        }
        
        in port speedInput {
            in currentSpeed : SpeedValue;
        }
        
        perform action refreshDisplay {
            first start;
            then merge displayLoop;
            then action updateValues {
                accept total : LengthValue from totalDistanceInput.totalDist;
                accept trip : LengthValue from tripDistanceInput.tripDist;
                accept speed : SpeedValue from speedInput.currentSpeed;
            }
            then displayLoop;
            then done;
        }
    }
    
    part def Odometer {
        doc /* Measures and displays the cumulative distance traveled by a vehicle 
             * by monitoring wheel rotations, converting them to distance units, 
             * and maintaining persistent storage of the total distance.
             */
        
        attribute totalDistanceTraveled : LengthValue = 0.0[km];
        attribute wheelCircumference : LengthValue = 2.042[m];
        
        part sensor : WheelRotationSensor {
            attribute :>> pulsesPerRevolution = 48;
        }
        
        part calculator : DistanceCalculationUnit {
            attribute :>> wheelDiameter = 0.65[m];
            attribute :>> wheelCircumference = Odometer::wheelCircumference;
        }
        
        part storage : NonVolatileStorage;
        
        part tripMeter : TripMeter;
        
        part display : DisplayUnit;
        
        connection sensorToCalculator connect sensor.pulseOutput to calculator.pulseInput;
        connection calculatorToDisplay connect calculator.distanceOutput.distance to display.totalDistanceInput.totalDist;
        connection calculatorToTrip connect calculator.distanceOutput.distance to tripMeter.distanceInput.incrementalDistance;
        connection tripToDisplay connect tripMeter.tripOutput.currentTrip to display.tripDistanceInput.tripDist;
        connection speedToDisplay connect calculator.distanceOutput.speed to display.speedInput.currentSpeed;
        
        perform action operateOdometer {
            first start;
            then action initialize {
                perform storage.loadDistance;
            }
            then merge operationLoop;
            then action measureAndUpdate {
                perform sensor.generatePulses;
                perform calculator.calculateDistance;
                perform tripMeter.updateTrip;
                perform display.refreshDisplay;
            }
            then action persistData {
                perform storage.saveDistance;
            }
            then operationLoop;
            then done;
        }
    }
    
    state def OdometerOperationalStates {
        entry; then powerOff;
        
        state powerOff {
            doc /* Odometer is not powered; data retained in non-volatile storage. */
        }
        then powerOn;
        accept powerApplied;
        
        state powerOn;
        then initialization;
        
        state initialization {
            doc /* Load stored distance from non-volatile memory. */
            entry;
            do action loadStoredData;
        }
        then measuring;
        
        state measuring {
            doc /* Continuously measure distance and update display. */
            entry;
            do action continuousMeasurement;
        }
        then measuring;
        accept tripResetRequested;
        then tripReset;
        accept powerRemoved;
        then powerOff;
        
        state tripReset {
            doc /* Reset trip meter to zero while maintaining total distance. */
            entry;
            do action resetTripMeter;
        }
        then measuring;
    }
    
    part odometerInstance : Odometer {
        attribute :>> totalDistanceTraveled = 0.0[km];
        attribute :>> wheelCircumference = 2.042[m];
        
        exhibit state operationalBehavior : OdometerOperationalStates;
    }
    
    requirement <'REQ-ODO-001'> primaryFunction {
        doc /* The odometer shall measure and display the total cumulative distance 
             * traveled by the vehicle by monitoring wheel rotations and converting 
             * them to distance units.
             */
        subject odometer :> odometerInstance;
        
        require constraint {
            odometer.totalDistanceTraveled >= 0.0[km]
        }
    }
    
    requirement <'REQ-ODO-002'> measurementAccuracy {
        doc /* The odometer shall measure distance with an accuracy of ±2% 
             * over the operational range of 0 to 999,999 km.
             */
        subject calc :> odometerInstance.calculator;
        
        assert constraint {
            calc.wheelCircumference > 0.0[m] and
            calc.totalDistance >= 0.0[m] and
            calc.totalDistance <= 999999.0[km]
        }
    }
    
    requirement <'REQ-ODO-003'> dataPersistence {
        doc /* The odometer reading shall be stored in non-volatile memory 
             * and shall survive power loss without data corruption.
             */
        subject storage :> odometerInstance.storage;
        
        require constraint {
            storage.storedTotalDistance >= 0.0[m]
        }
    }
    
    requirement <'REQ-ODO-004'> tripMeterFunction {
        doc /* The odometer shall provide a resettable trip meter function 
             * to measure distance for individual journeys independently 
             * of the total odometer reading.
             */
        subject trip :> odometerInstance.tripMeter;
        
        require constraint {
            trip.tripDistance >= 0.0[m]
        }
    }
    
    requirement <'REQ-ODO-005'> displayResolution {
        doc /* The display shall show total distance in kilometers with 
             * a minimum resolution of 0.1 km and trip distance with 
             * a minimum resolution of 0.1 km.
             */
        subject disp :> odometerInstance.display;
        
        require constraint {
            disp.displayedTotalDistance >= 0.0[km] and
            disp.displayedTripDistance >= 0.0[km]
        }
    }
    
    requirement <'REQ-ODO-006'> continuousOperation {
        doc /* The odometer shall operate continuously whenever the vehicle 
             * is in motion without requiring manual intervention.
             */
        subject odometer :> odometerInstance;
    }
    
    constraint def MeasurementAccuracyConstraint {
        in measured : LengthValue;
        in actual : LengthValue;
        in maxError : Real;
        
        (measured - actual).abs / actual <= maxError
    }
    
    part def OdometerAssembly {
        doc /* Complete odometer assembly with accuracy verification. */
        
        attribute maxOperationalDistance : LengthValue = 999999.9[km];
        attribute accuracyTolerance : Real = 0.02;
        
        part odometer : Odometer;
        
        assert constraint accuracyCheck : MeasurementAccuracyConstraint {
            in measured : LengthValue;
            in actual : LengthValue;
            in maxError = accuracyTolerance;
        }
        
        satisfy primaryFunction by odometer;
        satisfy measurementAccuracy by odometer.calculator;
        satisfy dataPersistence by odometer.storage;
        satisfy tripMeterFunction by odometer.tripMeter;
        satisfy displayResolution by odometer.display;
        satisfy continuousOperation by odometer;
    }
}
