package CurrentSensingUnit {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    value def ResistanceValue :> Real { unit 'ohm'; }
    value def VoltageValue :> Real { unit 'V'; }
    value def CurrentValue :> Real { unit 'A'; }
    value def FrequencyValue :> Real { unit 'Hz'; }
    value def TimeValue :> Real { unit 's'; }
    value def DigitalCode :> Integer;
    value def GainFactor :> Real;

    // ---- Item definitions ----
    item def AnalogVoltage {
        ref value magnitude : VoltageValue;
    }
    item def MeasuredCurrent {
        ref value magnitude : CurrentValue;
        ref value timestamp : TimeValue;
        attribute valid : Boolean;
    }
    item def DigitalSample {
        ref value code : DigitalCode;
        ref value timestamp : TimeValue;
    }
    item def CurrentReport {
        ref value measurement : MeasuredCurrent;
        attribute sequenceId : Integer;
    }

    // ---- Port definitions ----
    port def ElectricalPort {
        in item current : CurrentValue;
        out item voltage : VoltageValue;
    }
    port def AnalogSignalPort {
        in item voltageIn : AnalogVoltage;
        out item voltageOut : AnalogVoltage;
    }
    port def DigitalDataPort {
        in item sampleIn : DigitalSample;
        out item sampleOut : DigitalSample;
    }
    port def MeasurementReportPort {
        in item reportIn : CurrentReport;
        out item reportOut : CurrentReport;
    }
    port def SPIDataPort {
        out item report : CurrentReport;
    }
    port def PowerPort {
        in item supplyVoltage : VoltageValue;
    }

    // ---- Shunt Resistor ----
    part def ShuntResistor {
        attribute resistance : ResistanceValue = 0.001 [ohm];
        attribute tolerance : Real = 0.01;
        in port mainCurrent : ElectricalPort;
        out port senseVoltage : AnalogSignalPort;

        action def SenseVoltage {
            in current : CurrentValue;
            out voltage : AnalogVoltage;
        }
        perform SenseVoltage {
            in current = mainCurrent.current;
            out voltage = senseVoltage.voltageOut;
        }
    }

    // ---- Amplifier ----
    part def Amplifier {
        attribute gain : GainFactor = 100.0;
        attribute bandwidth : FrequencyValue = 50000 [Hz];
        in port signalIn : AnalogSignalPort;
        out port signalOut : AnalogSignalPort;

        action def Amplify {
            in input : AnalogVoltage;
            out output : AnalogVoltage;
        }
        perform Amplify {
            in input = signalIn.voltageIn;
            out output = signalOut.voltageOut;
        }
    }

    // ---- Analog-to-Digital Converter ----
    part def AnalogToDigitalConverter {
        attribute samplingRate : FrequencyValue = 10000 [Hz];
        attribute resolution : Integer = 16;
        attribute referenceVoltage : VoltageValue = 3.3 [V];
        in port analogIn : AnalogSignalPort;
        out port digitalOut : DigitalDataPort;

        action def Convert {
            in input : AnalogVoltage;
            out output : DigitalSample;
        }
        perform Convert {
            in input = analogIn.voltageIn;
            out output = digitalOut.sampleOut;
        }
    }

    // ---- Microcontroller ----
    part def Microcontroller {
        attribute shuntResistance : ResistanceValue = 0.001 [ohm];
        attribute amplifierGain : GainFactor = 100.0;
        attribute adcReference : VoltageValue = 3.3 [V];
        attribute adcResolution : Integer = 16;
        attribute clockFrequency : FrequencyValue = 48000000 [Hz];
        in port dataIn : DigitalDataPort;
        out port dataOut : MeasurementReportPort;
        in port power : PowerPort;

        action def ProcessSample {
            in sample : DigitalSample;
            out measurement : MeasuredCurrent;
        }
        perform ProcessSample {
            in sample = dataIn.sampleIn;
            out measurement;
        }

        action def ValidateReading {
            in measurement : MeasuredCurrent;
            out validated : MeasuredCurrent;
        }
        perform ValidateReading {
            in measurement;
            out validated = dataOut.reportIn.measurement;
        }
    }

    // ---- Data Interface ----
    part def DataInterface {
        attribute protocol : String = "SPI";
        attribute maxBaudRate : FrequencyValue = 1000000 [Hz];
        in port reportIn : MeasurementReportPort;
        out port spiOut : SPIDataPort;

        action def Transmit {
            in report : CurrentReport;
        }
        perform Transmit {
            in report = reportIn.reportIn;
        }
    }

    // ---- Power Supply ----
    part def PowerSupply {
        attribute outputVoltage : VoltageValue = 3.3 [V];
        attribute maxCurrent : CurrentValue = 0.5 [A];
        attribute efficiency : Real = 0.85;
        out port powerOut : PowerPort;
    }

    // ---- Current Sensor (composite) ----
    part def CurrentSensor {
        attribute deviceName : String = "CSU-1";
        attribute firmwareVersion : String = "1.0.0";
        in port measuredCircuit : ElectricalPort;
        out port spiInterface : SPIDataPort;

        part shunt : ShuntResistor {
            attribute resistance : ResistanceValue = 0.001 [ohm];
        }
        part amp : Amplifier {
            attribute gain : GainFactor = 100.0;
        }
        part adc : AnalogToDigitalConverter {
            attribute samplingRate : FrequencyValue = 10000 [Hz];
            attribute resolution : Integer = 16;
        }
        part mcu : Microcontroller;
        part iface : DataInterface;
        part psu : PowerSupply;

        // Internal connections
        connect measuredCircuit to shunt.mainCurrent;
        connect shunt.senseVoltage to amp.signalIn;
        connect amp.signalOut to adc.analogIn;
        connect adc.digitalOut to mcu.dataIn;
        connect mcu.dataOut to iface.reportIn;
        connect iface.spiOut to spiInterface;
        connect psu.powerOut to mcu.power;

        // Lifecycle state machine
        state def Lifecycle {
            entry; then offline;

            state offline {
                entry action powerOff();
            }
            transition off_to_init
                first offline
                then initializing
                when powered;

            state initializing {
                entry action runSelfChecks();
                do action selfCheck;
                exit action reportReady();
            }
            transition init_to_ready
                first initializing
                then ready
                when selfChecksPassed;
            transition init_to_error
                first initializing
                then error
                when selfChecksFailed;

            state ready {
                entry action enterIdle();
                do action waitForTrigger;
            }
            transition ready_to_measuring
                first ready
                then measuring
                when triggerReceived;
            transition ready_to_error
                first ready
                then error
                when faultDetected;

            state measuring {
                entry action startMeasurement();
                do action performMeasurementCycle;
                exit action finalizeMeasurement();
            }
            transition measuring_to_ready
                first measuring
                then ready
                when measurementComplete;
            transition measuring_to_error
                first measuring
                then error
                when faultDetected;

            state error {
                entry action logFault();
                do action runDiagnostics;
                exit action clearFault();
            }
            transition error_to_offline
                first error
                then offline
                when powerCycle;
            transition error_to_ready
                first error
                then ready
                when faultCleared;
        }

        perform Lifecycle;
    }

    // ---- Requirements ----
    requirement def MeasurementAccuracyRequirement {
        subject sensor : CurrentSensor;
        attribute maxRelativeError : Real = 0.01;
        require {
            sensor.measuredCircuit.current > 0 [A] implies
            sensor.spiInterface.report.measurement.valid == true
        }
    }

    requirement def SamplingRateRequirement {
        subject adc : AnalogToDigitalConverter;
        attribute minRate : FrequencyValue = 1000 [Hz];
        require { adc.samplingRate >= minRate }
    }

    requirement def ResolutionRequirement {
        subject adc : AnalogToDigitalConverter;
        attribute minBits : Integer = 12;
        require { adc.resolution >= minBits }
    }

    requirement def ShuntResistanceRequirement {
        subject shunt : ShuntResistor;
        attribute maxResistance : ResistanceValue = 0.01 [ohm];
        require { shunt.resistance <= maxResistance }
    }

    requirement def AmplifierGainRequirement {
        subject amp : Amplifier;
        attribute minGain : GainFactor = 50.0;
        attribute maxGain : GainFactor = 200.0;
        require { amp.gain >= minGain and amp.gain <= maxGain }
    }

    requirement def PowerSupplyRequirement {
        subject psu : PowerSupply;
        attribute nominalVoltage : VoltageValue = 3.3 [V];
        attribute tolerance : Real = 0.05;
        require {
            psu.outputVoltage >= nominalVoltage * (1 - tolerance) and
            psu.outputVoltage <= nominalVoltage * (1 + tolerance)
        }
    }

    requirement def LifecycleRequirement {
        subject sensor : CurrentSensor;
        require {
            sensor.Lifecycle includes offline and
            sensor.Lifecycle includes initializing and
            sensor.Lifecycle includes ready and
            sensor.Lifecycle includes measuring and
            sensor.Lifecycle includes error
        }
    }

    requirement def DataInterfaceRequirement {
        subject iface : DataInterface;
        require { iface.protocol == "SPI" }
    }

    // ---- Requirement satisfaction ----
    satisfaction shuntResistanceSatisfaction : ShuntResistanceRequirement {
        subject shunt : CurrentSensor::shunt;
    }
    satisfaction amplifierGainSatisfaction : AmplifierGainRequirement {
        subject amp : CurrentSensor::amp;
    }
    satisfaction samplingRateSatisfaction : SamplingRateRequirement {
        subject adc : CurrentSensor::adc;
    }
    satisfaction resolutionSatisfaction : ResolutionRequirement {
        subject adc : CurrentSensor::adc;
    }
    satisfaction powerSupplySatisfaction : PowerSupplyRequirement {
        subject psu : CurrentSensor::psu;
    }
    satisfaction dataInterfaceSatisfaction : DataInterfaceRequirement {
        subject iface : CurrentSensor::iface;
    }
    satisfaction lifecycleSatisfaction : LifecycleRequirement {
        subject sensor : CurrentSensor;
    }
}
