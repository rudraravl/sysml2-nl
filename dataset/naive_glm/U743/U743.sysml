package LaserRangefinderModel {
    import ScalarValues::*;

    // ===== Units =====
    unit m;
    unit nm;
    unit ns;
    unit Hz;
    unit degC;
    unit J;
    unit V;
    unit A;
    unit mPerSec;

    // ===== Value Types =====
    value type Length :> Real { unit m; }
    value type Wavelength :> Real { unit nm; }
    value type Duration :> Real { unit ns; }
    value type Frequency :> Real { unit Hz; }
    value type Temperature :> Real { unit degC; }
    value type Energy :> Real { unit J; }
    value type ElectricPotential :> Real { unit V; }
    value type ElectricCurrent :> Real { unit A; }
    value type Velocity :> Real { unit mPerSec; }

    // ===== Item Types =====
    item def LaserPulse {
        attribute wavelength : Wavelength = 905 [nm];
        attribute pulseEnergy : Energy;
        attribute emissionTime : Duration;
    }

    item def ReflectedSignal {
        attribute intensity : Real;
        attribute returnTime : Duration;
    }

    item def TimingMeasurement {
        attribute timeOfFlight : Duration;
        attribute valid : Boolean;
    }

    item def DistanceResult {
        attribute distance : Length;
        attribute valid : Boolean;
        attribute measurementId : Integer;
    }

    item def PowerStatus {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
        attribute active : Boolean;
    }

    // ===== Port Definitions =====
    port def TriggerPort {
        out trigger : Boolean;
    }

    port def OpticalPort {
        out pulse : LaserPulse;
        in reflection : ReflectedSignal;
    }

    port def DetectionPort {
        out detection : Boolean;
    }

    port def TimingDataPort {
        out timing : TimingMeasurement;
    }

    port def DistanceDataPort {
        out result : DistanceResult;
    }

    port def PowerPort {
        out power : PowerStatus;
    }

    // ===== Requirement Definitions =====
    requirement def MeasurementAccuracyRequirement {
        doc "The rangefinder shall measure distance with accuracy within 1 cm.";
        attribute maxError : Length = 0.01 [m];
    }

    requirement def MeasurementRateRequirement {
        doc "The rangefinder shall perform up to 100 readings per second.";
        attribute maxRate : Frequency = 100 [Hz];
    }

    requirement def OperationalRangeRequirement {
        doc "Effective operational range from 0.2 m to 250 m.";
        attribute minRange : Length = 0.2 [m];
        attribute maxRange : Length = 250 [m];
    }

    requirement def EyeSafetyRequirement {
        doc "Comply with Class 1 laser product eye safety standards.";
        attribute laserClass : String = "Class 1";
        attribute maxAccessibleEmission : Energy = 1.5e-9 [J];
    }

    requirement def EnvironmentalRequirement {
        doc "Function across wide environmental temperatures.";
        attribute minTemp : Temperature = -20 [degC];
        attribute maxTemp : Temperature = 60 [degC];
    }

    requirement def WavelengthRequirement {
        doc "Laser emission at 905 nm infrared wavelength.";
        attribute wavelength : Wavelength = 905 [nm];
    }

    requirement def TimingResolutionRequirement {
        doc "Timing circuit shall have nanosecond-level resolution.";
        attribute resolution : Duration = 1 [ns];
    }

    // ===== Component Definitions =====
    part def LaserEmitter {
        port triggerIn : TriggerPort;
        port opticalOut : OpticalPort;
        port powerIn : PowerPort;

        attribute wavelength : Wavelength = 905 [nm];
        attribute pulseEnergy : Energy = 1.5e-9 [J];
        attribute pulseDuration : Duration = 5 [ns];
        attribute pulseCount : Integer = 0;

        action emitPulse {
            in trigger : Boolean;
            out pulse : LaserPulse;
            if trigger {
                pulse.wavelength := wavelength;
                pulse.pulseEnergy := pulseEnergy;
                pulse.emissionTime := 0 [ns];
                pulseCount := pulseCount + 1;
            }
        }
    }

    part def OpticalReceiver {
        port opticalIn : OpticalPort;
        port detectionOut : DetectionPort;
        port powerIn : PowerPort;

        attribute sensitivity : Real = 1e-6;
        attribute detectionThreshold : Real = 1e-7;
        attribute detectionCount : Integer = 0;

        action detectReflection {
            in reflection : ReflectedSignal;
            out detection : Boolean;
            if reflection.intensity > detectionThreshold {
                detection := true;
                detectionCount := detectionCount + 1;
            } else {
                detection := false;
            }
        }
    }

    part def TimingCircuit {
        port triggerIn : TriggerPort;
        port detectionIn : DetectionPort;
        port timingOut : TimingDataPort;
        port powerIn : PowerPort;

        attribute resolution : Duration = 1 [ns];
        attribute startTime : Duration;
        attribute stopTime : Duration;
        attribute measurementCount : Integer = 0;

        action recordStartTime {
            in trigger : Boolean;
            if trigger {
                startTime := 0 [ns];
            }
        }

        action recordStopTime {
            in detection : Boolean;
            if detection {
                stopTime := 1500 [ns];
            }
        }

        action measureTimeOfFlight {
            in start : Boolean;
            in stop : Boolean;
            out timing : TimingMeasurement;
            if start { startTime := 0 [ns]; }
            if stop {
                stopTime := startTime + 1500 [ns];
                timing.timeOfFlight := stopTime - startTime;
                timing.valid := true;
                measurementCount := measurementCount + 1;
            }
        }
    }

    part def ProcessingUnit {
        port timingIn : TimingDataPort;
        port distanceOut : DistanceDataPort;
        port powerIn : PowerPort;

        attribute speedOfLight : Velocity = 299792458 [mPerSec];
        attribute minRange : Length = 0.2 [m];
        attribute maxRange : Length = 250 [m];
        attribute calculationCount : Integer = 0;
        attribute lastDistance : Length;

        action calculateDistance {
            in timing : TimingMeasurement;
            out result : DistanceResult;
            if timing.valid {
                result.distance := (speedOfLight * timing.timeOfFlight) / 2.0;
                result.valid := (result.distance >= minRange) and (result.distance <= maxRange);
                result.measurementId := calculationCount + 1;
                lastDistance := result.distance;
                calculationCount := calculationCount + 1;
            } else {
                result.distance := 0 [m];
                result.valid := false;
                result.measurementId := calculationCount + 1;
            }
        }

        action validateRange {
            in distance : Length;
            out valid : Boolean;
            valid := (distance >= minRange) and (distance <= maxRange);
        }
    }

    part def DisplayModule {
        port distanceIn : DistanceDataPort;
        port powerIn : PowerPort;

        attribute displayResolution : Length = 0.01 [m];
        attribute displayedDistance : Length;
        attribute displayCount : Integer = 0;

        action displayResult {
            in result : DistanceResult;
            if result.valid {
                displayedDistance := result.distance;
                displayCount := displayCount + 1;
            }
        }

        action clearDisplay {
            displayedDistance := 0 [m];
        }
    }

    part def PowerSupply {
        port powerOut : PowerPort;

        attribute outputVoltage : ElectricPotential = 3.3 [V];
        attribute outputCurrent : ElectricCurrent = 2.0 [A];
        attribute batteryCapacity : Real = 2000;
        attribute batteryLevel : Real = 100;
        attribute active : Boolean = true;

        action providePower {
            out power : PowerStatus;
            power.voltage := outputVoltage;
            power.current := outputCurrent;
            power.active := active;
        }

        action checkBatteryLevel {
            if batteryLevel < 10 {
                active := false;
            }
        }
    }

    // ===== System Definition =====
    part def LaserRangefinder {
        port triggerInput : TriggerPort;
        port displayOutput : DistanceDataPort;

        // Requirement usages
        requirement accuracyReq : MeasurementAccuracyRequirement;
        requirement rateReq : MeasurementRateRequirement;
        requirement rangeReq : OperationalRangeRequirement;
        requirement eyeSafetyReq : EyeSafetyRequirement;
        requirement envReq : EnvironmentalRequirement;
        requirement wavelengthReq : WavelengthRequirement;
        requirement timingResReq : TimingResolutionRequirement;

        // Parts
        part emitter : LaserEmitter;
        part receiver : OpticalReceiver;
        part timing : TimingCircuit;
        part processor : ProcessingUnit;
        part display : DisplayModule;
        part power : PowerSupply;

        // Requirement satisfaction
        satisfy accuracyReq by processor;
        satisfy rateReq by timing;
        satisfy rangeReq by processor;
        satisfy eyeSafetyReq by emitter;
        satisfy wavelengthReq by emitter;
        satisfy timingResReq by timing;

        // Power distribution connections
        connection powerToEmitter : PowerPort from power.powerOut to emitter.powerIn;
        connection powerToReceiver : PowerPort from power.powerOut to receiver.powerIn;
        connection powerToTiming : PowerPort from power.powerOut to timing.powerIn;
        connection powerToProcessor : PowerPort from power.powerOut to processor.powerIn;
        connection powerToDisplay : PowerPort from power.powerOut to display.powerIn;

        // Trigger distribution connections
        connection triggerToEmitter : TriggerPort from triggerInput to emitter.triggerIn;
        connection triggerToTiming : TriggerPort from triggerInput to timing.triggerIn;

        // Optical path connection
        connection opticalPath : OpticalPort from emitter.opticalOut to receiver.opticalIn;

        // Detection signal connection
        connection detectionToTiming : DetectionPort from receiver.detectionOut to timing.detectionIn;

        // Timing data connection
        connection timingToProcessor : TimingDataPort from timing.timingOut to processor.timingIn;

        // Distance result connections
        connection processorToDisplay : DistanceDataPort from processor.distanceOut to display.distanceIn;
        connection processorToOutput : DistanceDataPort from processor.distanceOut to displayOutput;

        // State machine attributes
        attribute triggerReceived : Boolean = false;
        attribute pulseEmitted : Boolean = false;
        attribute reflectionDetected : Boolean = false;
        attribute timingComplete : Boolean = false;
        attribute calculationComplete : Boolean = false;
        attribute displayComplete : Boolean = false;
        attribute timeoutOccurred : Boolean = false;
        attribute outOfRangeFlag : Boolean = false;
        attribute resetFlag : Boolean = false;
        attribute measurementCycleCount : Integer = 0;

        // State machine
        state machine RangefinderOperation {
            initial state Idle;
            state Emitting {
                entry action {
                    triggerReceived := false;
                    pulseEmitted := false;
                }
            }
            state Waiting {
                entry action {
                    reflectionDetected := false;
                }
            }
            state Measuring;
            state Calculating {
                entry action {
                    calculationComplete := false;
                }
            }
            state Displaying {
                entry action {
                    displayComplete := false;
                    measurementCycleCount := measurementCycleCount + 1;
                }
            }
            state Error {
                entry action {
                    outOfRangeFlag := false;
                    timeoutOccurred := false;
                }
            }

            transition first Idle then Emitting when triggerReceived;
            transition first Emitting then Waiting when pulseEmitted;
            transition first Waiting then Measuring when reflectionDetected;
            transition first Measuring then Calculating when timingComplete;
            transition first Calculating then Displaying when calculationComplete;
            transition first Displaying then Idle when displayComplete;
            transition first Waiting then Error when timeoutOccurred;
            transition first Calculating then Error when outOfRangeFlag;
            transition first Error then Idle when resetFlag;
        }
    }

    // ===== Package-level requirement satisfaction for system-level requirements =====
    requirement envReqInstance : EnvironmentalRequirement;
    satisfy envReqInstance by LaserRangefinder;
}
