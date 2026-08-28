package LaserTriangulationSensor {
    import ScalarValues::*;
    import ISQ::*;
    import ISQBase::*;
    import ISQSpace::*;
    import ISQTime::*;
    import ISQElectricity::*;

    // ---------- Value Types with Units ----------
    value type Distance :> Real {
        private attribute unit: String = "m";
    }
    value type DistanceCm :> Real {
        private attribute unit: String = "cm";
    }
    value type Angle :> Real {
        private attribute unit: String = "rad";
    }
    value type Voltage :> Real {
        private attribute unit: String = "V";
    }
    value type Current :> Real {
        private attribute unit: String = "A";
    }
    value type Frequency :> Real {
        private attribute unit: String = "Hz";
    }
    value type Length :> Real {
        private attribute unit: String = "m";
    }

    // ---------- Enumerations ----------
    enum def MeasurementStatus {
        enum idle;
        enum triggered;
        enum acquiring;
        enum calculating;
        enum validating;
        enum complete;
        enum error;
    }

    enum def ValidityFlag {
        enum valid;
        enum invalid;
        enum outOfRange;
        enum lowSignal;
    }

    // ---------- Item Definitions ----------
    item def LaserBeam {
        attribute wavelength: Length = 650e-9 [m];
        attribute power: Real = 5e-3 [mW];
    }

    item def ReflectedLight {
        attribute intensity: Real;
        attribute wavelength: Length = 650e-9 [m];
    }

    item def DetectorReading {
        attribute detectorId: Integer;
        attribute intensity: Real;
        attribute pixelPosition: Real;
        attribute timestamp: TimeValue;
    }

    item def AngleReading {
        attribute detectorId: Integer;
        attribute angle: Angle;
        attribute confidence: Real;
    }

    item def DistanceResult {
        attribute distance: Distance;
        attribute valid: ValidityFlag;
        attribute timestamp: TimeValue;
        attribute sequenceNumber: Natural;
    }

    item def TriggerSignal {
        attribute triggerId: Natural;
        attribute timestamp: TimeValue;
    }

    // ---------- Port Definitions ----------
    port def PowerPort {
        in attribute supplyVoltage: Voltage = 5.0 [V];
        in attribute supplyCurrent: Current;
    }

    port def TriggerPort {
        in trigger: TriggerSignal;
    }

    port def DataOutputPort {
        out result: DistanceResult;
    }

    port def LaserEmissionPort {
        out beam: LaserBeam;
    }

    port def LightReceiverPort {
        in reflected: ReflectedLight;
    }

    // ---------- Requirements ----------
    requirement def MeasurementRangeRequirement {
        doc /* The sensor shall measure distances from 10 cm to 10 m. */
        attribute minRange: DistanceCm = 10 [cm];
        attribute maxRange: Distance = 10 [m];
        subject sensor :> DistanceMeasurementSensor;
        require {
            sensor.measurementRange.min >= minRange;
            sensor.measurementRange.max <= maxRange;
        }
    }

    requirement def AccuracyRequirement {
        doc /* The sensor shall achieve an accuracy of 1 mm. */
        attribute accuracy: Length = 1e-3 [m];
        subject sensor :> DistanceMeasurementSensor;
        require { sensor.accuracy <= accuracy; }
    }

    requirement def UpdateRateRequirement {
        doc /* The sensor shall provide new measurements at 50 Hz. */
        attribute rate: Frequency = 50 [Hz];
        subject sensor :> DistanceMeasurementSensor;
        require { sensor.updateRate >= rate; }
    }

    requirement def PowerRequirement {
        doc /* The sensor shall operate on a 5 V supply. */
        attribute nominalVoltage: Voltage = 5.0 [V];
        subject sensor :> DistanceMeasurementSensor;
        require { sensor.supplyVoltage == nominalVoltage; }
    }

    requirement def BaselineRequirement {
        doc /* The two photodetectors shall be mounted 12 cm apart. */
        attribute baseline: DistanceCm = 12 [cm];
        subject sensor :> DistanceMeasurementSensor;
        require { sensor.detectorBaseline == baseline; }
    }

    requirement def ValidationRequirement {
        doc /* Each measurement shall include a validity flag. */
        subject sensor :> DistanceMeasurementSensor;
        require { sensor.providesValidityFlag == true; }
    }

    // ---------- Part Definitions ----------
    part def DistanceMeasurementSensor {
        attribute supplyVoltage: Voltage = 5.0 [V];
        attribute accuracy: Length = 1e-3 [m];
        attribute updateRate: Frequency = 50 [Hz];
        attribute detectorBaseline: DistanceCm = 12 [cm];
        attribute providesValidityFlag: Boolean = true;
        attribute measurementRange :>> 
            attribute min : DistanceCm = 10 [cm];
            attribute max : Distance = 10 [m];
        ;

        port powerIn : PowerPort;
        port triggerIn : TriggerPort;
        port dataOut : DataOutputPort;

        requirement measurementRangeReq : MeasurementRangeRequirement { subject = self; }
        requirement accuracyReq : AccuracyRequirement { subject = self; }
        requirement updateRateReq : UpdateRateRequirement { subject = self; }
        requirement powerReq : PowerRequirement { subject = self; }
        requirement baselineReq : BaselineRequirement { subject = self; }
        requirement validationReq : ValidationRequirement { subject = self; }

        part laserSource : LaserSource;
        part detectorA : Photodetector {
            attribute id : Integer = 1;
        }
        part detectorB : Photodetector {
            attribute id : Integer = 2;
        }
        part angleCalcA : AngleCalculator {
            attribute detectorId : Integer = 1;
        }
        part angleCalcB : AngleCalculator {
            attribute detectorId : Integer = 2;
        }
        part cpu : CentralProcessingUnit;
        part optics : ProjectionOptics;
        part housing : SensorHousing;

        // baseline constraint between detectors
        constraint baselineConstraint {
            (detectorB.mountPosition - detectorA.mountPosition) == 0.12 [m]
        }

        // Connections
        connection laserBeamPath connect laserSource.emissionPort.beam to optics.inputPort.beam;
        connection projectedBeam connect optics.outputPort.beam to laserSource.targetPort.beam;
        connection reflectedToDetA connect detectorA.receiverPort.reflected to angleCalcA.inputPort.reading;
        connection reflectedToDetB connect detectorB.receiverPort.reflected to angleCalcB.inputPort.reading;
        connection angleAtoCPU connect angleCalcA.outputPort.angleReading to cpu.angleInputA;
        connection angleBtoCPU connect angleCalcB.outputPort.angleReading to cpu.angleInputB;
        connection triggerToCPU connect triggerIn.trigger to cpu.triggerInput;
        connection cpuToDataOut connect cpu.resultOutput.result to dataOut.result;
        connection powerToLaser connect powerIn.supplyVoltage to laserSource.powerPort.supplyVoltage;
        connection powerToDetA connect powerIn.supplyVoltage to detectorA.powerPort.supplyVoltage;
        connection powerToDetB connect powerIn.supplyVoltage to detectorB.powerPort.supplyVoltage;
        connection powerToCPU connect powerIn.supplyVoltage to cpu.powerPort.supplyVoltage;

        // State machine for overall sensor operation
        state def SensorStates {
            entry; then Idle;

            state Idle {
                entry { /* wait for trigger */ }
                accept trigger via triggerIn;
                then Triggered;
            }

            state Triggered {
                entry { /* activate laser and detectors */ }
                then Acquiring;
            }

            state Acquiring {
                entry { /* capture reflected light at both detectors */ }
                do { /* read pixel positions from both detectors */ }
                then Calculating;
            }

            state Calculating {
                entry { /* compute angles and distance using triangulation */ }
                do { /* d = baseline / (tan(a1) + tan(a2)) */ }
                then Validating;
            }

            state Validating {
                entry { /* check signal strength, range, consistency */ }
                then Complete;
            }

            state Complete {
                entry { /* emit DistanceResult on dataOut */ }
                then Idle;
            }

            state Error {
                entry { /* report invalid measurement */ }
                then Idle;
            }
        }

        state machine : SensorStates;
    }

    part def LaserSource {
        attribute wavelength: Length = 650e-9 [m];
        attribute outputPower: Real = 5e-3 [W];
        attribute active: Boolean = false;

        port powerPort : PowerPort;
        port emissionPort : LaserEmissionPort;
        port targetPort : LaserEmissionPort;

        action def EmitBeam {
            in beam : LaserBeam;
            out emitted : LaserBeam;
        }

        action emit : EmitBeam;

        state def LaserStates {
            entry; then Off;
            state Off {
                entry { active = false; }
                accept activate;
                then On;
            }
            state On {
                entry { active = true; }
                do { emit; }
                accept deactivate;
                then Off;
            }
        }
        state machine : LaserStates;
    }

    part def Photodetector {
        attribute id : Integer;
        attribute sensitivity: Real = 0.5 [A/W];
        attribute mountPosition: Length;
        attribute pixelPosition: Real;
        attribute signalStrength: Real;

        port powerPort : PowerPort;
        port receiverPort : LightReceiverPort;

        action def CaptureLight {
            in reflected : ReflectedLight;
            out reading : DetectorReading;
        }

        action capture : CaptureLight;

        state def DetectorStates {
            entry; then Ready;
            state Ready {
                entry { /* clear previous reading */ }
                accept light via receiverPort;
                then Capturing;
            }
            state Capturing {
                entry { /* integrate charge, determine pixel position */ }
                do { capture; }
                then Ready;
            }
        }
        state machine : DetectorStates;
    }

    part def AngleCalculator {
        attribute detectorId : Integer;
        attribute focalLength: Length = 0.02 [m];
        attribute lensCenterOffset: Length;

        port inputPort {
            in reading : DetectorReading;
        }
        port outputPort {
            out angleReading : AngleReading;
        }

        action def ComputeAngle {
            in reading : DetectorReading;
            out angleReading : AngleReading;
            // angle = atan(pixelPosition / focalLength)
        }

        action compute : ComputeAngle;

        state def AngleCalcStates {
            entry; then Waiting;
            state Waiting {
                accept reading via inputPort;
                then Computing;
            }
            state Computing {
                entry { compute; }
                then Waiting;
            }
        }
        state machine : AngleCalcStates;
    }

    part def CentralProcessingUnit {
        attribute clockFrequency: Frequency = 48e6 [Hz];
        attribute baseline: DistanceCm = 12 [cm];
        attribute minRange: DistanceCm = 10 [cm];
        attribute maxRange: Distance = 10 [m];
        attribute sequenceCounter: Natural = 0;

        port powerPort : PowerPort;
        port angleInputA {
            in angleReading : AngleReading;
        }
        port angleInputB {
            in angleReading : AngleReading;
        }
        port triggerInput {
            in trigger : TriggerSignal;
        }
        port resultOutput {
            out result : DistanceResult;
        }

        action def CalculateDistance {
            in angleA : AngleReading;
            in angleB : AngleReading;
            in baseline : DistanceCm;
            out distance : Distance;
            // distance = baseline / (tan(angleA) + tan(angleB))
        }

        action def ValidateReading {
            in distance : Distance;
            in angleA : AngleReading;
            in angleB : AngleReading;
            out valid : ValidityFlag;
            // check range, signal confidence, angle consistency
        }

        action def EmitResult {
            in distance : Distance;
            in valid : ValidityFlag;
            out result : DistanceResult;
        }

        action calcDistance : CalculateDistance;
        action validate : ValidateReading;
        action emitResult : EmitResult;

        // Action flow
        flow calcDistance.distance to validate.distance;
        flow validate.valid to emitResult.valid;
        flow calcDistance.distance to emitResult.distance;

        state def CPUStates {
            entry; then Idle;
            state Idle {
                entry { /* wait for trigger and angle readings */ }
                accept trigger via triggerInput;
                then Processing;
            }
            state Processing {
                entry { calcDistance; }
                then Checking;
            }
            state Checking {
                entry { validate; }
                then Emitting;
            }
            state Emitting {
                entry { emitResult; sequenceCounter = sequenceCounter + 1; }
                then Idle;
            }
        }
        state machine : CPUStates;
    }

    part def ProjectionOptics {
        attribute focalLength: Length = 0.05 [m];
        attribute aperture: Length = 0.008 [m];

        port inputPort {
            in beam : LaserBeam;
        }
        port outputPort {
            out beam : LaserBeam;
        }

        action def FocusBeam {
            in beam : LaserBeam;
            out focused : LaserBeam;
        }

        action focus : FocusBeam;
    }

    part def SensorHousing {
        attribute material: String = "aluminum";
        attribute dimensions: String = "80x60x30 mm";
        attribute ipRating: String = "IP54";
    }

    // ---------- Top-level instantiation ----------
    part sensor : DistanceMeasurementSensor {
        // Satisfy requirements
        satisfy measurementRangeReq;
        satisfy accuracyReq;
        satisfy updateRateReq;
        satisfy powerReq;
        satisfy baselineReq;
        satisfy validationReq;
    }

    // ---------- Constraint blocks ----------
    constraint def TriangulationEquation {
        in angleA : Angle;
        in angleB : Angle;
        in baseline : DistanceCm;
        out distance : Distance;
        constraint { distance == (baseline / 100.0) / (tan(angleA) + tan(angleB)) }
    }

    constraint def RangeCheck {
        in distance : Distance;
        in minRange : DistanceCm;
        in maxRange : Distance;
        out inRange : Boolean;
        constraint { inRange == (distance >= (minRange / 100.0) && distance <= maxRange) }
    }

    constraint def AccuracyCheck {
        in measured : Distance;
        in actual : Distance;
        in tolerance : Length;
        out meetsSpec : Boolean;
        constraint { meetsSpec == (abs(measured - actual) <= tolerance) }
    }

    // ---------- Package-level assertions ----------
    assertion triangulationValid : TriangulationEquation {
        in angleA = 0.5 [rad];
        in angleB = 0.5 [rad];
        in baseline = 12 [cm];
        out distance;
    }
}
