package InclinometerSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---------- Value Types ----------
    def AngleDeg :> Real { unit 'deg'; }
    def CapacitanceValue :> Real { unit 'pF'; }
    def VoltageAC :> Real { unit 'V'; }
    def VoltageDC :> Real { unit 'V'; }
    def FrequencyValue :> Real { unit 'Hz'; }
    def TemperatureValue :> Real { unit '°C'; }
    def DigitalValue :> Integer;
    def PowerValue :> Real { unit 'mW'; }
    def CurrentValue :> Real { unit 'mA'; }

    // ---------- Item Types ----------
    item def DielectricFluid;
    item def ExcitationSignal;
    item def CapacitanceDifference;
    item def AnalogVoltageSignal;
    item def FilteredSignal;
    item def DigitalSample;
    item def TemperatureReading;
    item def AngleData;
    item def RS485Frame;
    item def CalibrationCommand;

    // ---------- Attributes ----------
    attribute def OperatingRange {
        attribute minTemp : TemperatureValue = -20 [°C];
        attribute maxTemp : TemperatureValue = 85 [°C];
    }

    attribute def AccuracySpec {
        attribute resolution : AngleDeg = 0.001 [deg];
        attribute linearity : AngleDeg = 0.01 [deg];
    }

    // ---------- Port Definitions ----------
    port def ExcitationPort {
        out excitation : ExcitationSignal;
    }

    port def CapacitanceBridgePort {
        in upperCap : CapacitanceValue;
        in lowerCap : CapacitanceValue;
        out diffSignal : AnalogVoltageSignal;
    }

    port def AnalogSignalPort {
        out signal : AnalogVoltageSignal;
    }

    port def FilteredSignalPort {
        out signal : FilteredSignal;
    }

    port def DigitalPort {
        out sample : DigitalSample;
    }

    port def TemperaturePort {
        out reading : TemperatureReading;
    }

    port def DataBusPort {
        in command : CalibrationCommand;
        out frame : RS485Frame;
    }

    port def PowerPort {
        in supplyVoltage : VoltageDC;
    }

    // ---------- Requirements ----------
    requirement def HighPrecisionMeasurement {
        subject sensor : Inclinometer;
        objective {
            doc "The inclinometer shall measure tilt angle with high accuracy and stability."
        }
        require sensor.measuredAngle.resolution <= 0.001 [deg];
        require sensor.measuredAngle.linearity <= 0.01 [deg];
        require sensor.measuredAngle.range >= 90 [deg];
    }

    requirement def TemperatureCompensation {
        subject sensor : Inclinometer;
        objective {
            doc "The inclinometer shall maintain accuracy across -20°C to +85°C."
        }
        require sensor.operatingTemp.minTemp <= -20 [°C];
        require sensor.operatingTemp.maxTemp >= 85 [°C];
    }

    requirement def LowPowerOperation {
        subject sensor : Inclinometer;
        objective {
            doc "The inclinometer shall operate with low power consumption."
        }
        require sensor.powerConsumption <= 50 [mW];
    }

    requirement def RS485Communication {
        subject sensor : Inclinometer;
        objective {
            doc "The inclinometer shall transmit angle data via RS485."
        }
        require sensor.commInterface.protocol == "RS485";
    }

    requirement def OperationalStates {
        subject sensor : Inclinometer;
        objective {
            doc "The inclinometer shall support initialization, measurement, calibration, and fault states."
        }
        require sensor.stateMachine.states == {"Initializing", "Measuring", "Calibrating", "Fault"};
    }

    // ---------- Part Definitions ----------
    part def SealedChamber {
        attribute material : String = "Anodized Aluminum";
        attribute fluidType : DielectricFluid;
        attribute fillLevel : Real = 0.5;
        port upperPlateCap : CapacitanceValue;
        port lowerPlateCap : CapacitanceValue;
    }

    part def CapacitivePlates {
        attribute material : String = "Gold-plated Copper";
        attribute plateArea : Real = 100 [mm²];
        attribute separation : Real = 2 [mm];
        port upperCapOut : CapacitanceValue;
        port lowerCapOut : CapacitanceValue;
    }

    part def ExcitationCircuit {
        attribute frequency : FrequencyValue = 100000 [Hz];
        attribute amplitude : VoltageAC = 5 [V];
        port excitationOut : ExcitationPort;
        action def GenerateExcitation {
            out signal : ExcitationSignal;
        }
        perform GenerateExcitation;
    }

    part def CapacitanceBridge {
        port bridgeIn : CapacitanceBridgePort;
        action def MeasureDifference {
            in upper : CapacitanceValue;
            in lower : CapacitanceValue;
            out diff : AnalogVoltageSignal;
        }
        perform MeasureDifference;
    }

    part def SignalConditioner {
        attribute gain : Real = 100;
        attribute filterCutoff : FrequencyValue = 1000 [Hz];
        port conditionerIn : AnalogSignalPort;
        port conditionerOut : FilteredSignalPort;
        action def AmplifyAndFilter {
            in raw : AnalogVoltageSignal;
            out filtered : FilteredSignal;
        }
        perform AmplifyAndFilter;
    }

    part def ADC {
        attribute resolution : Integer = 16;
        attribute sampleRate : FrequencyValue = 1000 [Hz];
        port adcIn : FilteredSignalPort;
        port adcOut : DigitalPort;
        action def Sample {
            in analog : FilteredSignal;
            out digital : DigitalSample;
        }
        perform Sample;
    }

    part def TemperatureSensor {
        port tempOut : TemperaturePort;
        action def ReadTemperature {
            out temp : TemperatureReading;
        }
        perform ReadTemperature;
    }

    part def CPU {
        port cpuDataIn : DigitalPort;
        port cpuTempIn : TemperaturePort;
        port cpuDataOut : DataBusPort;
        action def ProcessMeasurement {
            in digital : DigitalSample;
            in temp : TemperatureReading;
            out angle : AngleData;
        }
        action def ApplyCalibration {
            in raw : DigitalSample;
            in temp : TemperatureReading;
            out compensated : AngleData;
        }
        perform ProcessMeasurement;
    }

    part def CommunicationInterface {
        attribute protocol : String = "RS485";
        attribute baudRate : Integer = 115200;
        port commIn : DataBusPort;
        action def TransmitFrame {
            in data : AngleData;
            out frame : RS485Frame;
        }
        perform TransmitFrame;
    }

    // ---------- State Machine ----------
    state def InclinometerStates {
        entry; then Initializing;
        state Initializing {
            entry {
                doc "Perform self-tests and initialize subsystems.";
            }
            do {
                self.runSelfTest();
            }
            transition to Measuring
                when self.selfTestPassed == true;
            transition to Fault
                when self.selfTestPassed == false;
        }
        state Measuring {
            entry {
                doc "Continuous measurement loop.";
            }
            do {
                self.excitationCircuit.GenerateExcitation();
                self.capacitanceBridge.MeasureDifference();
                self.signalConditioner.AmplifyAndFilter();
                self.adc.Sample();
                self.temperatureSensor.ReadTemperature();
                self.cpu.ProcessMeasurement();
                self.commInterface.TransmitFrame();
            }
            transition to Calibrating
                when self.calibrationRequested == true;
            transition to Fault
                when self.errorDetected == true;
        }
        state Calibrating {
            entry {
                doc "Dedicated calibration mode.";
            }
            do {
                self.cpu.ApplyCalibration();
            }
            transition to Measuring
                when self.calibrationComplete == true;
            transition to Fault
                when self.errorDetected == true;
        }
        state Fault {
            entry {
                doc "Error handling state.";
            }
            do {
                self.reportError();
            }
            transition to Initializing
                when self.resetRequested == true;
        }
    }

    // ---------- Top-level Inclinometer ----------
    part def Inclinometer {
        attribute measuredAngle : AngleDeg;
        attribute operatingTemp : OperatingRange;
        attribute powerConsumption : PowerValue = 45 [mW];
        attribute supplyCurrent : CurrentValue = 10 [mA];
        attribute selfTestPassed : Boolean = false;
        attribute calibrationRequested : Boolean = false;
        attribute calibrationComplete : Boolean = false;
        attribute errorDetected : Boolean = false;
        attribute resetRequested : Boolean = false;

        port powerIn : PowerPort;
        port externalComm : DataBusPort;

        part chamber : SealedChamber {
            part plates : CapacitivePlates {
                port upperCapOut : CapacitanceValue;
                port lowerCapOut : CapacitanceValue;
            }
        }
        part excitationCircuit : ExcitationCircuit;
        part capacitanceBridge : CapacitanceBridge;
        part signalConditioner : SignalConditioner;
        part adc : ADC;
        part temperatureSensor : TemperatureSensor;
        part cpu : CPU;
        part commInterface : CommunicationInterface;

        state stateMachine : InclinometerStates;

        action def runSelfTest {
            doc "Execute power-on self-test sequence.";
            out result : Boolean;
        }
        action def reportError {
            doc "Report fault condition via communication interface.";
        }

        satisfy HighPrecisionMeasurement;
        satisfy TemperatureCompensation;
        satisfy LowPowerOperation;
        satisfy RS485Communication;
        satisfy OperationalStates;
    }

    // ---------- Connections ----------
    part inclinometerInstance : Inclinometer {
        connection excitationToPlates connect
            inclinometerInstance.excitationCircuit.excitationOut.excitation
            to inclinometerInstance.chamber.plates.upperCapOut;

        connection platesToBridge connect
            inclinometerInstance.chamber.plates.upperCapOut
            to inclinometerInstance.capacitanceBridge.bridgeIn.upperCap;

        connection platesToBridgeLower connect
            inclinometerInstance.chamber.plates.lowerCapOut
            to inclinometerInstance.capacitanceBridge.bridgeIn.lowerCap;

        connection bridgeToConditioner connect
            inclinometerInstance.capacitanceBridge.bridgeIn.diffSignal
            to inclinometerInstance.signalConditioner.conditionerIn.signal;

        connection conditionerToADC connect
            inclinometerInstance.signalConditioner.conditionerOut.signal
            to inclinometerInstance.adc.adcIn.signal;

        connection adcToCPU connect
            inclinometerInstance.adc.adcOut.sample
            to inclinometerInstance.cpu.cpuDataIn.sample;

        connection tempToCPU connect
            inclinometerInstance.temperatureSensor.tempOut.reading
            to inclinometerInstance.cpu.cpuTempIn.reading;

        connection cpuToComm connect
            inclinometerInstance.cpu.cpuDataOut.frame
            to inclinometerInstance.commInterface.commIn.frame;

        connection commToExternal connect
            inclinometerInstance.commInterface.commIn.frame
            to inclinometerInstance.externalComm.frame;

        connection externalCommandToCPU connect
            inclinometerInstance.externalComm.command
            to inclinometerInstance.cpu.cpuDataOut.command;

        connection powerToAll connect
            inclinometerInstance.powerIn.supplyVoltage
            to inclinometerInstance.excitationCircuit;
    }

}
