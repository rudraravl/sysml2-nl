package FluxgateCompassSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def ElectricPotential :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def ElectricCurrent :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def Frequency :> ISQ::frequency {
        unit = SI::hertz;
    }

    attribute def MagneticFluxDensity :> ISQ::magneticFluxDensity {
        unit = SI::tesla;
    }

    attribute def PlaneAngle :> ISQ::planeAngle {
        unit = SI::degree;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::degreeCelsius;
    }

    attribute def Duration :> ISQ::time {
        unit = SI::second;
    }

    attribute def Power :> ISQ::power {
        unit = SI::watt;
    }

    item def ElectricalPower {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
    }

    item def MagneticFieldVector {
        attribute xField : MagneticFluxDensity;
        attribute yField : MagneticFluxDensity;
        attribute zField : MagneticFluxDensity;
    }

    item def RawFluxgateSignal {
        attribute xSenseVoltage : ElectricPotential;
        attribute ySenseVoltage : ElectricPotential;
        attribute zSenseVoltage : ElectricPotential;
        attribute excitationFrequency : Frequency;
    }

    item def HeadingEstimate {
        attribute magneticHeading : PlaneAngle;
        attribute trueHeading : PlaneAngle;
        attribute confidence : Real;
        attribute timestamp : Duration;
    }

    item def CalibrationData {
        attribute hardIronOffsetX : MagneticFluxDensity;
        attribute hardIronOffsetY : MagneticFluxDensity;
        attribute hardIronOffsetZ : MagneticFluxDensity;
        attribute softIronScaleX : Real;
        attribute softIronScaleY : Real;
        attribute softIronScaleZ : Real;
        attribute magneticDeclination : PlaneAngle;
    }

    item def HealthStatus {
        attribute sensorHealthy : Boolean;
        attribute excitationHealthy : Boolean;
        attribute processingHealthy : Boolean;
        attribute temperatureWithinLimit : Boolean;
        attribute faultCode : String;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def FieldSensePort {
        in item localMagneticField : MagneticFieldVector;
    }

    port def RawSignalPort {
        out item rawSignal : RawFluxgateSignal;
    }

    port def CalibrationPort {
        in item calibration : CalibrationData;
    }

    port def HeadingOutputPort {
        out item heading : HeadingEstimate;
    }

    port def HealthOutputPort {
        out item health : HealthStatus;
    }

    part def ExcitationDriver {
        port powerIn : PowerInputPort;
        port driveOut : RawSignalPort;

        attribute supplyVoltage : ElectricPotential = 5.0 [SI::volt];
        attribute driveCurrent : ElectricCurrent = 0.035 [SI::ampere];
        attribute excitationFrequency : Frequency = 10000 [SI::hertz];
        attribute maximumPower : Power = 0.25 [SI::watt];

        action generateAlternatingDrive {
            in item electricalPower : ElectricalPower;
            out item excitationSignal : RawFluxgateSignal;
        }
    }

    part def FluxgateSensorCore {
        port fieldIn : FieldSensePort;
        port excitationIn : RawSignalPort;
        port rawOut : RawSignalPort;

        attribute xAxisRange : MagneticFluxDensity = 0.0001 [SI::tesla];
        attribute yAxisRange : MagneticFluxDensity = 0.0001 [SI::tesla];
        attribute zAxisRange : MagneticFluxDensity = 0.0001 [SI::tesla];
        attribute noiseDensity : MagneticFluxDensity = 0.000000002 [SI::tesla];

        action senseMagneticField {
            in item magneticField : MagneticFieldVector;
            in item excitation : RawFluxgateSignal;
            out item rawSignal : RawFluxgateSignal;
        }
    }

    part def SignalConditioner {
        port rawIn : RawSignalPort;
        port conditionedOut : RawSignalPort;

        attribute amplifierGain : Real = 120.0;
        attribute lowPassCutoff : Frequency = 50 [SI::hertz];
        attribute demodulationReference : Frequency = 20000 [SI::hertz];

        action filterAndDemodulate {
            in item rawSignal : RawFluxgateSignal;
            out item conditionedSignal : RawFluxgateSignal;
        }
    }

    part def CalibrationProcessor {
        port conditionedIn : RawSignalPort;
        port calibrationIn : CalibrationPort;
        port headingOut : HeadingOutputPort;

        attribute updatePeriod : Duration = 0.02 [SI::second];
        attribute headingResolution : PlaneAngle = 0.1 [SI::degree];
        attribute maximumHeadingError : PlaneAngle = 2.0 [SI::degree];

        action compensateMagneticDistortion {
            in item conditionedSignal : RawFluxgateSignal;
            in item calibration : CalibrationData;
            out item compensatedField : MagneticFieldVector;
        }

        action computeHeading {
            in item compensatedField : MagneticFieldVector;
            in item calibration : CalibrationData;
            out item heading : HeadingEstimate;
        }
    }

    part def HealthMonitor {
        port powerIn : PowerInputPort;
        port rawSignalIn : RawSignalPort;
        port healthOut : HealthOutputPort;

        attribute minimumSupplyVoltage : ElectricPotential = 4.5 [SI::volt];
        attribute maximumSupplyVoltage : ElectricPotential = 5.5 [SI::volt];
        attribute minimumOperatingTemperature : Temperature = -40 [SI::degreeCelsius];
        attribute maximumOperatingTemperature : Temperature = 85 [SI::degreeCelsius];
        attribute faultDetectionPeriod : Duration = 0.1 [SI::second];

        action evaluateHealth {
            in item power : ElectricalPower;
            in item rawSignal : RawFluxgateSignal;
            out item health : HealthStatus;
        }
    }

    part def FluxgateCompass {
        port powerInput : PowerInputPort;
        port magneticFieldInput : FieldSensePort;
        port calibrationInput : CalibrationPort;
        port headingOutput : HeadingOutputPort;
        port healthOutput : HealthOutputPort;

        attribute nominalSupplyVoltage : ElectricPotential = 5.0 [SI::volt];
        attribute nominalCurrent : ElectricCurrent = 0.08 [SI::ampere];
        attribute headingUpdateRate : Frequency = 50 [SI::hertz];
        attribute operatingTemperatureMin : Temperature = -40 [SI::degreeCelsius];
        attribute operatingTemperatureMax : Temperature = 85 [SI::degreeCelsius];

        part excitationDriver : ExcitationDriver;
        part sensorCore : FluxgateSensorCore;
        part signalConditioner : SignalConditioner;
        part calibrationProcessor : CalibrationProcessor;
        part healthMonitor : HealthMonitor;

        connect powerInput to excitationDriver.powerIn;
        connect powerInput to healthMonitor.powerIn;
        connect magneticFieldInput to sensorCore.fieldIn;
        connect calibrationInput to calibrationProcessor.calibrationIn;
        connect excitationDriver.driveOut to sensorCore.excitationIn;
        connect sensorCore.rawOut to signalConditioner.rawIn;
        connect sensorCore.rawOut to healthMonitor.rawSignalIn;
        connect signalConditioner.conditionedOut to calibrationProcessor.conditionedIn;
        connect calibrationProcessor.headingOut to headingOutput;
        connect healthMonitor.healthOut to healthOutput;

        action provideHeading {
            in item localField : MagneticFieldVector;
            in item calibration : CalibrationData;
            out item heading : HeadingEstimate;

            first start;
            then exciteCore;
            then senseField;
            then conditionSignal;
            then compensateDistortion;
            then calculateHeading;
            then publishHeading;
        }

        state operatingState {
            entry action initializeCompass;

            state Off;
            state Initializing;
            state Calibrating;
            state Measuring;
            state Faulted;

            transition first Off;
            transition Off_to_Initializing
                first Off
                then Initializing
                accept PowerApplied;

            transition Initializing_to_Calibrating
                first Initializing
                then Calibrating
                accept SelfTestPassed;

            transition Calibrating_to_Measuring
                first Calibrating
                then Measuring
                accept CalibrationLoaded;

            transition Measuring_to_Faulted
                first Measuring
                then Faulted
                accept FaultDetected;

            transition Faulted_to_Initializing
                first Faulted
                then Initializing
                accept ResetCommand;

            transition Measuring_to_Off
                first Measuring
                then Off
                accept PowerRemoved;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The fluxgate compass shall determine vehicle or platform heading by sensing the local terrestrial magnetic field, compensating for installation and magnetic distortion, and publishing a calibrated heading estimate. */
        subject compass : FluxgateCompass;
        require constraint {
            compass.headingUpdateRate >= 10 [SI::hertz]
        }
    }

    requirement def HeadingAccuracyRequirement {
        doc /* The fluxgate compass shall provide magnetic heading with an error not exceeding two degrees under calibrated operating conditions. */
        subject processor : CalibrationProcessor;
        require constraint {
            processor.maximumHeadingError <= 2.0 [SI::degree]
        }
    }

    requirement def PowerRequirement {
        doc /* The fluxgate compass shall operate from a regulated five volt direct-current supply. */
        subject compass : FluxgateCompass;
        require constraint {
            compass.nominalSupplyVoltage == 5.0 [SI::volt]
        }
    }

    requirement def EnvironmentalRequirement {
        doc /* The fluxgate compass shall remain operational across the specified industrial temperature range. */
        subject compass : FluxgateCompass;
        require constraint {
            compass.operatingTemperatureMin <= -40 [SI::degreeCelsius] and
            compass.operatingTemperatureMax >= 85 [SI::degreeCelsius]
        }
    }

    requirement def HealthMonitoringRequirement {
        doc /* The fluxgate compass shall report health status for power, excitation, sensor signal, processing, and temperature conditions. */
        subject monitor : HealthMonitor;
        require constraint {
            monitor.faultDetectionPeriod <= 0.1 [SI::second]
        }
    }

    satisfy PrimaryFunctionRequirement by FluxgateCompass;
    satisfy HeadingAccuracyRequirement by FluxgateCompass::calibrationProcessor;
    satisfy PowerRequirement by FluxgateCompass;
    satisfy EnvironmentalRequirement by FluxgateCompass;
    satisfy HealthMonitoringRequirement by FluxgateCompass::healthMonitor;
}