package DigitalLightSensingUnit {

    import ScalarValues::*;
    import ISQ::*;
    import ISQ::ElectricCurrent;
    import ISQ::ElectricPotential;
    import ISQ::ThermodynamicTemperature;

    // ---- Value types with units ----

    value def Illuminance :> Real {
        unit lux;
    }

    value def Photocurrent :> ElectricCurrent {
        unit nA;
    }

    value def SignalVoltage :> ElectricPotential {
        unit mV;
    }

    value def RawDigital :> Integer {
        doc /* 16-bit unsigned raw ADC code */
    }

    value def Temperature :> ThermodynamicTemperature {
        unit 'degC';
    }

    value def SensorId :> String;

    value def Timestamp :> Integer {
        unit ms;
    }

    item def CalibrationData {
        value offset : Real;
        value gain : Real;
        value referenceIlluminance : Illuminance;
        value calibratedAt : Timestamp;
    }

    item def LightReading {
        value illuminance : Illuminance;
        value timestamp : Timestamp;
        value sensorId : SensorId;
        value valid : Boolean;
    }

    item def ControlCommand {
        value command : CommandKind;
        value payload : CalibrationData optional;
    }

    enum def CommandKind { enable; reset; uploadCalibration; requestStatus; }

    enum def OperationalStatus { initializing; idle; active; calibrating; fault; }

    item def StatusReport {
        value status : OperationalStatus;
        value internalTemperature : Temperature;
        value lastReading : LightReading optional;
    }

    // ---- Interfaces ----

    interface def LightInput {
        in item light : Illuminance;
    }

    interface def CurrentLink {
        in item current : Photocurrent;
    }

    interface def VoltageLink {
        in item voltage : SignalVoltage;
    }

    interface def DigitalLink {
        in item code : RawDigital;
    }

    interface def ControlInterface {
        in item command : ControlCommand;
        out item status : StatusReport;
        out item reading : LightReading;
    }

    // ---- Component part definitions ----

    part def Photodiode {
        in item ambientLight : Illuminance via lightPort;
        out item photocurrent : Photocurrent via currentPort;

        port lightPort : LightInput;
        port currentPort : CurrentLink;

        attribute responsivity : Real = 0.5; // A/lux nominal
    }

    part def TransimpedanceAmplifier {
        in item inputCurrent : Photocurrent via inPort;
        out item outputVoltage : SignalVoltage via outPort;

        port inPort : CurrentLink;
        port outPort : VoltageLink;

        attribute feedbackResistance : Real = 1000.0; // kOhm
    }

    part def LowPassFilter {
        in item inputVoltage : SignalVoltage via inPort;
        out item filteredVoltage : SignalVoltage via outPort;

        port inPort : VoltageLink;
        port outPort : VoltageLink;

        attribute cutoffFrequency : Real = 1000.0; // Hz
    }

    part def AnalogDigitalConverter {
        in item inputVoltage : SignalVoltage via inPort;
        out item digitalCode : RawDigital via outPort;

        port inPort : VoltageLink;
        port outPort : DigitalLink;

        attribute resolutionBits : Integer = 16;
        attribute referenceVoltage : SignalVoltage = SignalVoltage(3300);
        attribute sampleRate : Real = 100.0; // Hz
    }

    part def MicrocontrollerMemory {
        item storedCalibration : CalibrationData[1] = (
            CalibrationData(offset = 0.0, gain = 1.0,
                referenceIlluminance = Illuminance(100.0),
                calibratedAt = Timestamp(0)));
    }

    part def Microcontroller {
        in item rawCode : RawDigital via adcPort;
        in item command : ControlCommand via cmdPort;
        out item reading : LightReading via readingPort;
        out item status : StatusReport via statusPort;

        port adcPort : DigitalLink;
        port cmdPort : ControlInterface;
        port readingPort : ControlInterface;
        port statusPort : ControlInterface;

        part memory : MicrocontrollerMemory;

        attribute sensorId : SensorId = "DLSU-0001";
        attribute minValidIlluminance : Illuminance = Illuminance(0.0);
        attribute maxValidIlluminance : Illuminance = Illuminance(100000.0);
        attribute internalTemperature : Temperature = Temperature(25.0);

        // Calibration computation action
        action def CalibrateReading {
            in raw : RawDigital;
            in cal : CalibrationData;
            out result : Illuminance;
        }

        action def ValidateReading {
            in value : Illuminance;
            out valid : Boolean;
        }

        action def PackageReading {
            in illuminance : Illuminance;
            in timestamp : Timestamp;
            in id : SensorId;
            in valid : Boolean;
            out reading : LightReading;
        }

        // State machine
        state machine Behavior {
            state initializing {
                entry { /* load calibration from memory */ }
            }
            state idle {
                /* awaiting commands */
            }
            state active {
                /* continuously sample and compute */
            }
            state calibrating {
                /* accept new calibration data */
            }
            state fault {
                /* report internal faults */
            }

            transition initializing -> idle;
            transition idle -> active
                when command.command == CommandKind::enable;
            transition active -> idle
                when command.command == CommandKind::reset;
            transition idle -> calibrating
                when command.command == CommandKind::uploadCalibration;
            transition calibrating -> idle
                when command.command == CommandKind::requestStatus;
            transition any -> fault
                when internalTemperature > Temperature(85.0);
            transition fault -> initializing
                when command.command == CommandKind::reset;
        }
    }

    // ---- Top-level assembly ----

    part def DigitalLightSensorUnit {
        port lightIn : LightInput;
        port control : ControlInterface;

        part photodiode : Photodiode;
        part amplifier : TransimpedanceAmplifier;
        part filter : LowPassFilter;
        part adc : AnalogDigitalConverter;
        part mcu : Microcontroller;

        // Light input flows to photodiode
        flow lightIn.light to photodiode.lightPort.light;

        // Photodiode current to amplifier
        flow photodiode.currentPort.current to amplifier.inPort.current;

        // Amplifier voltage to filter
        flow amplifier.outPort.voltage to filter.inPort.voltage;

        // Filtered voltage to ADC
        flow filter.outPort.voltage to adc.inPort.voltage;

        // ADC digital code to MCU
        flow adc.outPort.code to mcu.adcPort.code;

        // Control interface to MCU
        flow control.command to mcu.cmdPort.command;
        flow mcu.statusPort.status to control.status;
        flow mcu.readingPort.reading to control.reading;
    }

    // ---- Requirements ----

    requirement def MeasureAmbientLight {
        subject sensor : DigitalLightSensorUnit;
        doc /* The sensor shall measure ambient illuminance and provide a calibrated digital output. */
        require sensor.lightIn.light : Illuminance;
    }

    requirement def PhotodiodeConversion {
        subject pd : Photodiode;
        doc /* The photodiode shall convert incoming light into a small electrical current proportional to illuminance. */
        require pd.responsivity > 0;
    }

    requirement def AmplificationAndConversion {
        subject amp : TransimpedanceAmplifier;
        doc /* The transimpedance amplifier shall convert photocurrent into a usable voltage. */
        require amp.feedbackResistance > 0;
    }

    requirement def NoiseFiltering {
        subject lp : LowPassFilter;
        doc /* The low-pass filter shall remove unwanted electronic noise from the analog voltage. */
        require lp.cutoffFrequency > 0;
    }

    requirement def AnalogToDigital {
        subject converter : AnalogDigitalConverter;
        doc /* The ADC shall sample the filtered voltage and produce a raw digital value. */
        require converter.resolutionBits >= 12;
    }

    requirement def CalibrationProcessing {
        subject controller : Microcontroller;
        doc /* The microcontroller shall apply offset and gain correction using stored calibration data. */
        require controller.memory.storedCalibration.gain > 0;
    }

    requirement def RangeValidation {
        subject controller : Microcontroller;
        doc /* The processor shall validate the final reading is within expected range. */
        require controller.minValidIlluminance >= Illuminance(0.0);
        require controller.maxValidIlluminance <= Illuminance(200000.0);
    }

    requirement def DataStructurePackaging {
        subject controller : Microcontroller;
        doc /* The processor shall package illuminance, timestamp, and sensor ID into a final data structure. */
        require controller.readingPort.reading.sensorId == controller.sensorId;
    }

    requirement def ControlInterfaceRequirement {
        subject sensor : DigitalLightSensorUnit;
        doc /* The sensor shall provide an interface to enable, reset, upload calibration, and check status. */
        require sensor.control.command.command in {CommandKind::enable, CommandKind::reset, CommandKind::uploadCalibration, CommandKind::requestStatus};
    }

    requirement def StateMachineRequirement {
        subject controller : Microcontroller;
        doc /* The unit shall operate through initialization, idle, active, calibration, and error states. */
        require controller.Behavior.initializing.oclIsKindOf(State);
    }

    requirement def TemperatureMonitoring {
        subject controller : Microcontroller;
        doc /* The status report shall include internal temperature. */
        require controller.statusPort.status.internalTemperature : Temperature;
    }

    // ---- Satisfaction ----

    satisfaction photodiodeConversionSatisfies : PhotodiodeConversion {
        subject photodiode satisfies PhotodiodeConversion;
    }

    satisfaction amplificationSatisfies : AmplificationAndConversion {
        subject amplifier satisfies AmplificationAndConversion;
    }

    satisfaction filteringSatisfies : NoiseFiltering {
        subject filter satisfies NoiseFiltering;
    }

    satisfaction adcSatisfies : AnalogToDigital {
        subject adc satisfies AnalogToDigital;
    }

    satisfaction calibrationSatisfies : CalibrationProcessing {
        subject mcu satisfies CalibrationProcessing;
    }

    satisfaction rangeSatisfies : RangeValidation {
        subject mcu satisfies RangeValidation;
    }

    satisfaction packagingSatisfies : DataStructurePackaging {
        subject mcu satisfies DataStructurePackaging;
    }

    satisfaction controlSatisfies : ControlInterfaceRequirement {
        subject DigitalLightSensorUnit satisfies ControlInterfaceRequirement;
    }

    satisfaction tempSatisfies : TemperatureMonitoring {
        subject mcu satisfies TemperatureMonitoring;
    }

}
