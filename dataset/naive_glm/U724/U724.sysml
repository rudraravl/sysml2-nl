package InclinometerSystem {
    import ScalarValues::*;

    // ===== Value Types =====
    attribute def Acceleration :> Real { unit 'm/s^2'; }
    attribute def Angle :> Real { unit 'deg'; }
    attribute def Voltage :> Real { unit 'V'; }
    attribute def Current :> Real { unit 'A'; }
    attribute def Frequency :> Real { unit 'Hz'; }
    attribute def Confidence :> Real { unit '%'; }
    attribute def TimeValue :> Real { unit 's'; }
    attribute def Dimensionless :> Real {}
    attribute def PowerValue :> Real { unit 'W'; }

    // ===== Items =====
    item def ElectricPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute nominal : Boolean;
    }

    item def RawAccelerationData {
        attribute ax : Acceleration;
        attribute ay : Acceleration;
        attribute az : Acceleration;
        attribute timestamp : TimeValue;
        attribute valid : Boolean;
    }

    item def TiltMeasurement {
        attribute pitch : Angle;
        attribute roll : Angle;
        attribute valid : Boolean;
        attribute confidence : Confidence;
        attribute timestamp : TimeValue;
    }

    item def CalibrationParameters {
        attribute offsetPitch : Angle = 0.0;
        attribute offsetRoll : Angle = 0.0;
        attribute sensitivityX : Dimensionless = 1.0;
        attribute sensitivityY : Dimensionless = 1.0;
        attribute sensitivityZ : Dimensionless = 1.0;
        attribute calibrated : Boolean = false;
    }

    item def DisplayCommand {
        attribute brightness : Dimensionless;
        attribute backlightOn : Boolean;
    }

    item def UserCommand {
        attribute kind : UserCommandKind;
    }
    enum def UserCommandKind {
        powerOn;
        powerOff;
        startCalibration;
        confirmCalibration;
        reset;
    }

    item def FaultReport {
        attribute code : Integer;
        attribute description : String;
        attribute timestamp : TimeValue;
    }

    // ===== Ports =====
    port def PowerInPort { in item power : ElectricPower; }
    port def PowerOutPort { out item power : ElectricPower; }
    port def AccelDataOutPort { out item data : RawAccelerationData; }
    port def AccelDataInPort { in item data : RawAccelerationData; }
    port def TiltOutPort { out item measurement : TiltMeasurement; }
    port def TiltInPort { in item measurement : TiltMeasurement; }
    port def CalibrationOutPort { out item params : CalibrationParameters; }
    port def CalibrationInPort { in item params : CalibrationParameters; }
    port def CommandInPort { in item command : UserCommand; }
    port def FaultOutPort { out item fault : FaultReport; }
    port def DisplayOutPort { out item measurement : TiltMeasurement; }

    // ===== Requirements =====
    requirement def AngleAccuracyRequirement {
        doc /The inclinometer shall measure pitch and roll angles with an accuracy of +/- 0.1 deg over the range +/- 90 deg./
        attribute maxError : Angle = 0.1;
        attribute rangeMin : Angle = -90.0;
        attribute rangeMax : Angle = 90.0;
    }

    requirement def UpdateRateRequirement {
        doc /The inclinometer shall update the displayed tilt angles at a rate of at least 50 Hz./
        attribute minRate : Frequency = 50.0;
    }

    requirement def CalibrationRequirement {
        doc /The inclinometer shall support field calibration to correct mounting offsets for pitch and roll./
        attribute maxOffsetCorrection : Angle = 5.0;
    }

    requirement def PowerRegulationRequirement {
        doc /The power regulator shall provide a stable regulated voltage to all subsystems within +/- 2 percent of nominal./
        attribute nominalVoltage : Voltage = 3.3;
        attribute tolerance : Dimensionless = 0.02;
    }

    requirement def FaultHandlingRequirement {
        doc /The inclinometer shall enter an error state upon sensor failure or power fault and report the fault code./
    }

    requirement def ConfidenceReportingRequirement {
        doc /Each tilt measurement shall include a validity flag and a confidence score between 0 and 100 percent./
        attribute minConfidence : Confidence = 0.0;
        attribute maxConfidence : Confidence = 100.0;
    }

    // ===== Parts =====
    part def MEMSAccelerometer {
        doc /Three-axis MEMS accelerometer acting as the primary sensor measuring components of Earth's gravity vector./
        port powerIn : PowerInPort;
        port dataOut : AccelDataOutPort;
        port faultOut : FaultOutPort;

        attribute sampleRate : Frequency = 100.0;
        attribute measurementRange : Acceleration = 19.62;
        attribute noiseDensity : Acceleration = 0.001;
        attribute selfTestEnabled : Boolean = true;

        action def SampleAcceleration {
            out ax : Acceleration;
            out ay : Acceleration;
            out az : Acceleration;
            out valid : Boolean;
        }

        perform SampleAcceleration continuously {
            // Samples the three gravity components at the configured sample rate.
        }

        action def RunSelfTest {
            out passed : Boolean;
        }
    }

    part def SignalProcessor {
        doc /Signal processor that filters noise, applies calibration corrections, and computes pitch and roll angles./
        port powerIn : PowerInPort;
        port dataIn : AccelDataInPort;
        port tiltOut : TiltOutPort;
        port calibrationIn : CalibrationInPort;
        port faultOut : FaultOutPort;

        attribute filterCoefficient : Dimensionless = 0.1;
        attribute calibrationParams : CalibrationParameters;
        attribute computationRate : Frequency = 100.0;
        attribute lastTilt : TiltMeasurement;

        action def FilterRawData {
            in raw : RawAccelerationData;
            out filteredAx : Acceleration;
            out filteredAy : Acceleration;
            out filteredAz : Acceleration;
        }

        action def ApplyCalibration {
            in ax : Acceleration;
            in ay : Acceleration;
            in az : Acceleration;
            in params : CalibrationParameters;
            out correctedAx : Acceleration;
            out correctedAy : Acceleration;
            out correctedAz : Acceleration;
        }

        action def ComputeTilt {
            in ax : Acceleration;
            in ay : Acceleration;
            in az : Acceleration;
            out pitch : Angle;
            out roll : Angle;
            out confidence : Confidence;
            out valid : Boolean;
        }

        action def ProcessMeasurement {
            in raw : RawAccelerationData;
            in params : CalibrationParameters;
            out tilt : TiltMeasurement;

            perform FilterRawData(raw = raw);
            perform ApplyCalibration;
            perform ComputeTilt;
        }

        perform ProcessMeasurement continuously {
            // Continuously filters, calibrates, and computes tilt from incoming acceleration data.
        }
    }

    part def DisplayController {
        doc /Display controller managing the visual output of tilt measurements for the user./
        port powerIn : PowerInPort;
        port tiltIn : TiltInPort;
        port displayOut : DisplayOutPort;

        attribute refreshRate : Frequency = 60.0;
        attribute brightness : Dimensionless = 0.8;
        attribute backlightOn : Boolean = true;
        attribute resolution : Integer = 128;

        action def RenderMeasurement {
            in measurement : TiltMeasurement;
        }

        perform RenderMeasurement continuously {
            // Renders the current tilt measurement on the display at the configured refresh rate.
        }
    }

    part def PowerRegulator {
        doc /Central power regulator that takes external power and provides stable regulated voltage to all subsystems./
        port powerIn : PowerInPort;
        port accelPowerOut : PowerOutPort;
        port processorPowerOut : PowerOutPort;
        port displayPowerOut : PowerOutPort;

        attribute inputVoltageRangeMin : Voltage = 4.5;
        attribute inputVoltageRangeMax : Voltage = 12.0;
        attribute outputVoltage : Voltage = 3.3;
        attribute maxOutputCurrent : Current = 1.0;
        attribute efficiency : Dimensionless = 0.9;
        attribute thermalShutdownThreshold : Temperature = 85.0; // conceptual

        action def RegulatePower {
            in input : ElectricPower;
            out accelPower : ElectricPower;
            out processorPower : ElectricPower;
            out displayPower : ElectricPower;
        }

        perform RegulatePower continuously {
            // Regulates incoming power and distributes stable voltage to all subsystems.
        }
    }

    // ===== State Machine =====
    state def InclinometerStateMachine {
        doc /Operational state machine of the digital inclinometer./

        state PoweredOff {
            doc /Device is powered off and consumes no active power./
            entry action { /* disable all subsystems */ }
        }

        state Initializing {
            doc /Startup initialization sequence including sensor self-test and calibration load./
            entry action { /* run accelerometer self-test, load calibration parameters */ }
            do action { /* verify subsystem communications */ }
        }

        state CalibrationMode {
            doc /Field calibration mode allowing the user to correct mounting offsets./
            entry action { /* prompt user to place device in reference orientation */ }
            do action { /* collect reference samples and compute offsets */ }
            exit action { /* store calibration parameters persistently */ }
        }

        state Operational {
            doc /Primary operational mode for continuous tilt measurement and display update./
            entry action { /* begin continuous measurement loop */ }
            do action { /* continuously measure, process, and display tilt */ }
        }

        state ErrorState {
            doc /Error state handling sensor failures, power faults, or other detected faults./
            entry action { /* log fault report, halt measurement, indicate error on display */ }
            do action { /* await reset or power-down command */ }
        }

        transition PoweredOff to Initializing
            when { command.kind == UserCommandKind::powerOn }
            accept UserCommand;

        transition Initializing to Operational
            when { selfTestPassed == true }
            accept UserCommand;

        transition Initializing to ErrorState
            when { selfTestPassed == false };

        transition Operational to CalibrationMode
            when { command.kind == UserCommandKind::startCalibration }
            accept UserCommand;

        transition CalibrationMode to Operational
            when { command.kind == UserCommandKind::confirmCalibration }
            accept UserCommand;

        transition Operational to ErrorState
            when { sensorFaultDetected == true };

        transition CalibrationMode to ErrorState
            when { sensorFaultDetected == true };

        transition ErrorState to Initializing
            when { command.kind == UserCommandKind::reset }
            accept UserCommand;

        transition any to PoweredOff
            when { command.kind == UserCommandKind::powerOff }
            accept UserCommand;

        attribute selfTestPassed : Boolean;
        attribute sensorFaultDetected : Boolean;
        attribute command : UserCommand;
    }

    // ===== Top-Level System =====
    part def DigitalInclinometer {
        doc /Digital inclinometer system for precise measurement of tilt, pitch, and roll angles relative to Earth's gravitational field./

        port externalPowerIn : PowerInPort;
        port userCommandIn : CommandInPort;
        port dataOutput : TiltOutPort;
        port faultOutput : FaultOutPort;

        satisfy AngleAccuracyRequirement;
        satisfy UpdateRateRequirement;
        satisfy CalibrationRequirement;
        satisfy PowerRegulationRequirement;
        satisfy FaultHandlingRequirement;
        satisfy ConfidenceReportingRequirement;

        part accelerometer : MEMSAccelerometer {
            port powerIn : PowerInPort;
            port dataOut : AccelDataOutPort;
            port faultOut : FaultOutPort;
        }

        part processor : SignalProcessor {
            port powerIn : PowerInPort;
            port dataIn : AccelDataInPort;
            port tiltOut : TiltOutPort;
            port calibrationIn : CalibrationInPort;
            port faultOut : FaultOutPort;
        }

        part display : DisplayController {
            port powerIn : PowerInPort;
            port tiltIn : TiltInPort;
            port displayOut : DisplayOutPort;
        }

        part regulator : PowerRegulator {
            port powerIn : PowerInPort;
            port accelPowerOut : PowerOutPort;
            port processorPowerOut : PowerOutPort;
            port displayPowerOut : PowerOutPort;
        }

        attribute storedCalibration : CalibrationParameters;
        attribute currentTilt : TiltMeasurement;
        attribute currentState : String;

        exhibit state machine : InclinometerStateMachine;

        connection powerExternalToRegulator connect externalPowerIn to regulator.powerIn;
        connection powerRegulatorToAccel connect regulator.accelPowerOut to accelerometer.powerIn;
        connection powerRegulatorToProcessor connect regulator.processorPowerOut to processor.powerIn;
        connection powerRegulatorToDisplay connect regulator.displayPowerOut to display.powerIn;

        connection accelDataToProcessor connect accelerometer.dataOut to processor.dataIn;
        connection processorTiltToDisplay connect processor.tiltOut to display.tiltIn;
        connection processorTiltToOutput connect processor.tiltOut to dataOutput;

        connection accelFaultToProcessor connect accelerometer.faultOut to processor.faultOut;
        connection processorFaultToOutput connect processor.faultOut to faultOutput;

        action def SystemMeasurementLoop {
            in command : UserCommand;
            out tilt : TiltMeasurement;
            out fault : FaultReport;

            perform accelerometer.SampleAcceleration;
            perform processor.ProcessMeasurement;
            perform display.RenderMeasurement;
        }

        perform SystemMeasurementLoop continuously {
            // Continuously measures acceleration, processes it, and updates the displayed and output tilt angles.
        }
    }
}
