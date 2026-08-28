package CapacitiveDisplacementSensingUnit {
    import ScalarValues::*;
    import SI::*;
    import Quantities::*;

    // ---- Units ----
    unit def picofarad { shortName = "pF"; }
    unit def millimeter { shortName = "mm"; }
    unit def celsius { shortName = "degC"; }
    unit def kilohertz { shortName = "kHz"; }
    unit def millivolt { shortName = "mV"; }

    // ---- Value types ----
    value def Capacitance :> Real { unit picofarad; }
    value def GapDistance :> Real { unit millimeter; }
    value def Displacement :> Real { unit millimeter; }
    value def AnalogVoltage :> Real { unit Volt; }
    value def Temperature :> Real { unit celsius; }
    value def SampleRate :> Real { unit kilohertz; }
    value def NoiseLevel :> Real { unit millivolt; }
    value def DigitalCount :> Integer;
    value def QualityFactor :> Real; // 0.0 .. 1.0
    value def SupplyVoltage :> Real { unit Volt; }
    value def Current :> Real { unit Ampere; }
    value def ResponseTime :> Real { unit Second; }

    // ---- Item definitions ----
    item def RawCapacitanceSignal {
        attribute value : Capacitance;
        attribute timestamp : Time;
    }

    item def ConditionedVoltageSignal {
        attribute value : AnalogVoltage;
        attribute timestamp : Time;
    }

    item def DigitalSample {
        attribute count : DigitalCount;
        attribute timestamp : Time;
    }

    item def CalibrationEntry {
        attribute capacitance : Capacitance;
        attribute displacement : Displacement;
    }

    item def CalibrationTable {
        attribute entries : CalibrationEntry[0..*] ordered;
    }

    item def DisplacementMeasurement {
        attribute value : Displacement;
        attribute temperature : Temperature;
        attribute valid : Boolean;
        attribute quality : QualityFactor;
        attribute timestamp : Time;
    }

    item def FaultRecord {
        attribute code : Integer;
        attribute description : String;
        attribute timestamp : Time;
    }

    // ---- Port definitions ----
    port def PowerPort {
        attribute voltage : SupplyVoltage;
        attribute current : Current;
    }

    port def CapacitanceSignalOutPort {
        out item signal : RawCapacitanceSignal;
    }

    port def VoltageSignalInPort {
        in item signal : RawCapacitanceSignal;
    }

    port def VoltageSignalOutPort {
        out item signal : ConditionedVoltageSignal;
    }

    port def DigitalDataOutPort {
        out item sample : DigitalSample;
    }

    port def MeasurementOutputPort {
        out item measurement : DisplacementMeasurement;
    }

    port def CommandPort {
        in attribute command : String;
        in attribute parameter : Real := 0.0;
    }

    port def FaultLogPort {
        out item fault : FaultRecord;
    }

    // ---- Actions ----
    action def GenerateRawCapacitance {
        in gap : GapDistance;
        in temperature : Temperature;
        out signal : RawCapacitanceSignal;
    }

    action def AmplifySignal {
        in raw : RawCapacitanceSignal;
        out amplified : AnalogVoltage;
    }

    action def FilterSignal {
        in noisy : AnalogVoltage;
        out clean : AnalogVoltage;
    }

    action def SampleAndConvert {
        in analog : AnalogVoltage;
        out digital : DigitalSample;
    }

    action def ApplyCalibration {
        in sample : DigitalSample;
        in table : CalibrationTable;
        out displacement : Displacement;
    }

    action def CompensateTemperature {
        in raw : Displacement;
        in temperature : Temperature;
        out compensated : Displacement;
    }

    action def ValidateMeasurement {
        in value : Displacement;
        in rangeMin : Displacement;
        in rangeMax : Displacement;
        out valid : Boolean;
        out quality : QualityFactor;
    }

    action def SelfTest {
        out passed : Boolean;
    }

    action def RecoverFromFault {
        in fault : FaultRecord;
        out recovered : Boolean;
    }

    // ---- Functional parts ----
    part def CapacitiveSensorProbe {
        port powerIn : PowerPort;
        port signalOut : CapacitanceSignalOutPort;
        port faultOut : FaultLogPort;

        attribute plateArea : Real := 1.0e-4; // m^2
        attribute permittivity : Real := 8.854e-12; // F/m
        attribute nominalGap : GapDistance := 0.5 mm;
        attribute minGap : GapDistance := 0.05 mm;
        attribute maxGap : GapDistance := 5.0 mm;
        attribute operatingTemperature : Temperature := 25 degC;

        perform GenerateRawCapacitance {
            in gap : GapDistance = nominalGap;
            in temperature : Temperature = operatingTemperature;
            out signal : RawCapacitanceSignal = signalOut.signal;
        }
    }

    part def SignalConditioningCircuit {
        port powerIn : PowerPort;
        port signalIn : VoltageSignalInPort;
        port signalOut : VoltageSignalOutPort;
        port faultOut : FaultLogPort;

        attribute gain : Real := 1000.0;
        attribute bandwidth : SampleRate := 10 kHz;
        attribute noiseFloor : NoiseLevel := 1.0 mV;
        attribute offsetVoltage : AnalogVoltage := 0.0 V;

        perform AmplifySignal {
            in raw : RawCapacitanceSignal = signalIn.signal;
            out amplified : AnalogVoltage;
        }

        perform FilterSignal {
            in noisy : AnalogVoltage;
            out clean : AnalogVoltage = signalOut.signal.value;
        }
    }

    part def AnalogToDigitalConverter {
        port powerIn : PowerPort;
        port signalIn : VoltageSignalOutPort;
        port dataOut : DigitalDataOutPort;
        port faultOut : FaultLogPort;

        attribute resolutionBits : Integer := 16;
        attribute sampleRate : SampleRate := 1 kHz;
        attribute referenceVoltage : AnalogVoltage := 5.0 V;
        attribute lsbVoltage : AnalogVoltage := referenceVoltage / (2 ^ resolutionBits);

        perform SampleAndConvert {
            in analog : AnalogVoltage = signalIn.signal.value;
            out digital : DigitalSample = dataOut.sample;
        }
    }

    part def DigitalSignalProcessor {
        port powerIn : PowerPort;
        port dataIn : DigitalDataOutPort;
        port commandIn : CommandPort;
        port measurementOut : MeasurementOutputPort;
        port faultOut : FaultLogPort;

        attribute calibrationTable : CalibrationTable;
        attribute temperatureReading : Temperature := 25 degC;
        attribute rangeMin : Displacement := 0.0 mm;
        attribute rangeMax : Displacement := 10.0 mm;
        attribute temperatureCoefficient : Real := 0.001; // mm/degC

        perform ApplyCalibration {
            in sample : DigitalSample = dataIn.sample;
            in table : CalibrationTable = calibrationTable;
            out displacement : Displacement;
        }

        perform CompensateTemperature {
            in raw : Displacement;
            in temperature : Temperature = temperatureReading;
            out compensated : Displacement;
        }

        perform ValidateMeasurement {
            in value : Displacement;
            in rangeMin : Displacement = rangeMin;
            in rangeMax : Displacement = rangeMax;
            out valid : Boolean;
            out quality : QualityFactor;
        }
    }

    // ---- Connections between ports ----
    connection def CapacitanceLink {
        end source : CapacitanceSignalOutPort;
        end target : VoltageSignalInPort;
    }

    connection def VoltageLink {
        end source : VoltageSignalOutPort;
        end target : VoltageSignalOutPort;
    }

    connection def DigitalLink {
        end source : DigitalDataOutPort;
        end target : DigitalDataOutPort;
    }

    connection def PowerLink {
        end source : PowerPort;
        end target : PowerPort;
    }

    connection def MeasurementLink {
        end source : MeasurementOutputPort;
        end target : MeasurementOutputPort;
    }

    connection def CommandLink {
        end source : CommandPort;
        end target : CommandPort;
    }

    // ---- State machine ----
    state def SensingUnitStates {
        state Off {
            entry action { /* power removed */ }
        }

        state Initializing {
            entry action { /* begin self-test and calibration */ }
            do perform SelfTest { out passed; }
            transition success -> Ready when passed == true;
            transition failure -> Fault when passed == false;
        }

        state Ready {
            entry action { /* await command */ }
            transition startContinuous -> Active.continuous when commandIn.command == "start";
            transition startTriggered -> Active.triggered when commandIn.command == "trigger";
        }

        state Active {
            state continuous {
                do perform GenerateRawCapacitance;
                do perform AmplifySignal;
                do perform FilterSignal;
                do perform SampleAndConvert;
                do perform ApplyCalibration;
                do perform CompensateTemperature;
                do perform ValidateMeasurement;
            }
            state triggered {
                entry action { /* acquire single sample on trigger */ }
                do perform SampleAndConvert;
                do perform ApplyCalibration;
                do perform CompensateTemperature;
                do perform ValidateMeasurement;
            }
            transition switchToTriggered -> triggered when commandIn.command == "trigger";
            transition switchToContinuous -> continuous when commandIn.command == "start";
            transition stop -> Ready when commandIn.command == "stop";
            transition faultDetected -> Fault;
        }

        state Fault {
            entry action { /* log fault record */ }
            do perform RecoverFromFault;
            transition recovered -> Ready when recovered == true;
            transition shutdown -> Off when recovered == false;
        }

        transition powerApplied -> Initializing when powerIn.voltage > 0 V;
        transition powerRemoved -> Off when powerIn.voltage == 0 V;
    }

    // ---- Top-level system ----
    part def CapacitiveDisplacementSensingUnit {
        port powerIn : PowerPort;
        port commandIn : CommandPort;
        port measurementOut : MeasurementOutputPort;
        port faultOut : FaultLogPort;

        attribute manufacturer : String := "Precision Metrology Inc.";
        attribute model : String := "CDS-100";
        attribute serialNumber : String;
        attribute responseTime : ResponseTime := 0.005 s;

        part probe : CapacitiveSensorProbe {
            attribute nominalGap : GapDistance := 1.0 mm;
        }
        part conditioning : SignalConditioningCircuit {
            attribute gain : Real := 2000.0;
        }
        part adc : AnalogToDigitalConverter {
            attribute resolutionBits : Integer := 18;
        }
        part dsp : DigitalSignalProcessor {
            attribute rangeMin : Displacement := 0.0 mm;
            attribute rangeMax : Displacement := 5.0 mm;
        }

        // Power distribution
        connection powerToProbe : PowerLink connect powerIn to probe.powerIn;
        connection powerToConditioning : PowerLink connect powerIn to conditioning.powerIn;
        connection powerToADC : PowerLink connect powerIn to adc.powerIn;
        connection powerToDSP : PowerLink connect powerIn to dsp.powerIn;

        // Signal chain
        connection probeToConditioning : CapacitanceLink connect probe.signalOut to conditioning.signalIn;
        connection conditioningToADC : VoltageLink connect conditioning.signalOut to adc.signalIn;
        connection adcToDSP : DigitalLink connect adc.dataOut to dsp.dataIn;
        connection dspOutput : MeasurementLink connect dsp.measurementOut to measurementOut;
        connection commandToDSP : CommandLink connect commandIn to dsp.commandIn;

        // Fault aggregation
        connection probeFault : FaultLogPort connect probe.faultOut to faultOut;
        connection conditioningFault : FaultLogPort connect conditioning.faultOut to faultOut;
        connection adcFault : FaultLogPort connect adc.faultOut to faultOut;
        connection dspFault : FaultLogPort connect dsp.faultOut to faultOut;

        exhibit state : SensingUnitStates;
    }

    // ---- Requirements ----
    requirement def MeasurementAccuracyRequirement {
        doc "The sensing unit shall measure displacement with an accuracy of at least 1 micrometer.";
        subject sensor : CapacitiveDisplacementSensingUnit;
        attribute maxError : Displacement := 0.001 mm;
        attribute trueValue : Displacement;
        require { |sensor.measurementOut.measurement.value - trueValue| <= maxError }
    }

    requirement def OperatingRangeRequirement {
        doc "The sensing unit shall measure linear displacement over a 0 to 5 mm range.";
        subject sensor : CapacitiveDisplacementSensingUnit;
        attribute minRange : Displacement := 0.0 mm;
        attribute maxRange : Displacement := 5.0 mm;
        require { sensor.measurementOut.measurement.value >= minRange and
                  sensor.measurementOut.measurement.value <= maxRange }
    }

    requirement def ResponseTimeRequirement {
        doc "The sensing unit shall produce a valid measurement within 10 milliseconds of a trigger.";
        subject sensor : CapacitiveDisplacementSensingUnit;
        attribute maxResponse : ResponseTime := 0.01 s;
        require { sensor.responseTime <= maxResponse }
    }

    requirement def NonContactRequirement {
        doc "The sensing unit shall perform measurements without physical contact with the target surface.";
        subject sensor : CapacitiveDisplacementSensingUnit;
        require { sensor.probe.nominalGap > 0 mm }
    }

    requirement def TemperatureCompensationRequirement {
        doc "The DSP shall compensate displacement readings for temperature effects between 0 and 70 degrees Celsius.";
        subject dsp : DigitalSignalProcessor;
        attribute minTemp : Temperature := 0 degC;
        attribute maxTemp : Temperature := 70 degC;
        require { dsp.temperatureReading >= minTemp and dsp.temperatureReading <= maxTemp }
    }

    requirement def PowerSupplyRequirement {
        doc "The sensing unit shall operate from an external 12 V DC supply.";
        subject sensor : CapacitiveDisplacementSensingUnit;
        attribute nominalVoltage : SupplyVoltage := 12.0 V;
        attribute tolerance : Real := 0.5; // V
        require { |sensor.powerIn.voltage - nominalVoltage| <= tolerance }
    }

    requirement def SelfTestRequirement {
        doc "The sensing unit shall perform a self-test on startup and report faults before entering Ready.";
        subject sensor : CapacitiveDisplacementSensingUnit;
        require { sensor.SensingUnitStates.Initializing.passed == true implies
                  sensor.SensingUnitStates.Ready.active }
    }

    requirement def ContinuousAndTriggeredRequirement {
        doc "The sensing unit shall support both continuous and triggered measurement modes.";
        subject sensor : CapacitiveDisplacementSensingUnit;
        require { sensor.SensingUnitStates.Active.continuous.active or
                  sensor.SensingUnitStates.Active.triggered.active }
    }

    // ---- Requirement satisfaction ----
    satisfaction satisfy MeasurementAccuracyRequirement by CapacitiveDisplacementSensingUnit;
    satisfaction satisfy OperatingRangeRequirement by CapacitiveDisplacementSensingUnit;
    satisfaction satisfy ResponseTimeRequirement by CapacitiveDisplacementSensingUnit;
    satisfaction satisfy NonContactRequirement by CapacitiveDisplacementSensingUnit;
    satisfaction satisfy TemperatureCompensationRequirement by CapacitiveDisplacementSensingUnit.dsp;
    satisfaction satisfy PowerSupplyRequirement by CapacitiveDisplacementSensingUnit;
    satisfaction satisfy SelfTestRequirement by CapacitiveDisplacementSensingUnit;
    satisfaction satisfy ContinuousAndTriggeredRequirement by CapacitiveDisplacementSensingUnit;
}
