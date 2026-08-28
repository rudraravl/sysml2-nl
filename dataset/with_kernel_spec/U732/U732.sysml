package 'IC Piezoelectric Sensing Unit' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def ChargeValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def PressureValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def CalFactor :> Real;
    attribute def DigitalCount :> Integer;

    item def ChargeSignal {
        attribute charge : ChargeValue;
    }
    item def AnalogVoltage {
        attribute voltage : VoltageValue;
    }
    item def FilteredVoltage {
        attribute voltage : VoltageValue;
    }
    item def DigitalSample {
        attribute rawValue : DigitalCount;
        attribute valid : Boolean;
    }
    item def CalibratedPressure {
        attribute pressure : PressureValue;
        attribute valid : Boolean;
    }
    item def PhysicalPressure {
        attribute pressure : PressureValue;
    }

    attribute def ControlCmd;
    attribute def MeasureCmd :> ControlCmd;
    attribute def StopMeasureCmd :> ControlCmd;
    attribute def CalibrateCmd :> ControlCmd;
    attribute def ResetCmd :> ControlCmd;
    attribute def SelfTestComplete;
    attribute def InitDone;
    attribute def ErrorDetected;

    item def StatusReport {
        attribute healthOk : Boolean;
        attribute temperature : TemperatureValue;
        attribute faultCode : DigitalCount;
    }

    port def ChargeOutPort {
        out charge : ChargeSignal;
    }
    port def ChargeInPort {
        in charge : ChargeSignal;
    }
    port def AnalogOutPort {
        out voltage : AnalogVoltage;
    }
    port def AnalogInPort {
        in voltage : AnalogVoltage;
    }
    port def FilteredOutPort {
        out voltage : FilteredVoltage;
    }
    port def FilteredInPort {
        in voltage : FilteredVoltage;
    }
    port def DigitalOutPort {
        out sample : DigitalSample;
    }
    port def DigitalInPort {
        in sample : DigitalSample;
    }
    port def PressureOutPort {
        out pressure : CalibratedPressure;
    }
    port def CommandInPort {
        in cmd : ControlCmd;
    }
    port def StatusOutPort {
        out status : StatusReport;
    }
    port def PhysicalPressureInPort {
        in pressure : PhysicalPressure;
    }

    action def 'Perform Self Test';
    action def 'Initialize Sensor';
    action def 'Report Fault';
    action def 'Sense Temperature' {
        out temp : TemperatureValue;
    }
    action def 'Generate Charge' {
        in physicalPressure : PhysicalPressure;
        out charge : ChargeSignal;
    }
    action def 'Amplify Charge' {
        in charge : ChargeSignal;
        out voltage : AnalogVoltage;
    }
    action def 'Filter Noise' {
        in voltage : AnalogVoltage;
        out filtered : FilteredVoltage;
    }
    action def 'Convert Analog to Digital' {
        in voltage : FilteredVoltage;
        out sample : DigitalSample;
    }
    action def 'Process Digital Sample' {
        in sample : DigitalSample;
        out calibrated : CalibratedPressure;
    }
    action def 'Apply Calibration Factors' {
        in raw : DigitalCount;
        in factor : CalFactor;
        in offsetValue : PressureValue;
        out calibrated : PressureValue;
    }
    action def 'Acquire Pressure' {
        in physicalPressure : PhysicalPressure;
        out result : CalibratedPressure;
    }

    calc def 'Compute Calibrated Pressure' {
        in raw : DigitalCount;
        in factor : CalFactor;
        in offsetValue : PressureValue;
        return : PressureValue;
        raw * factor + offsetValue
    }

    state def 'Sensor Operational States' {
        entry; then powerUp;
        state powerUp;
        accept SelfTestComplete then initialize;
        state initialize;
        accept InitDone then ready;
        state ready;
        accept MeasureCmd then active;
        accept CalibrateCmd then calibrating;
        accept ErrorDetected then fault;
        state active;
        accept StopMeasureCmd then ready;
        accept ErrorDetected then fault;
        state calibrating;
        accept InitDone then ready;
        state fault;
        accept ResetCmd then initialize;
    }

    part def PiezoCrystal {
        port pressureIn : PhysicalPressureInPort;
        port chargeOut : ChargeOutPort;
        attribute sensitivity : Real;
        perform action generateCharge : 'Generate Charge';
    }

    part def ChargeAmplifier {
        port chargeIn : ChargeInPort;
        port voltageOut : AnalogOutPort;
        attribute gain : Real;
        perform action amplifyCharge : 'Amplify Charge';
    }

    part def SignalFilter {
        port voltageIn : AnalogInPort;
        port voltageOut : FilteredOutPort;
        attribute cutoffFrequency : Real;
        perform action filterNoise : 'Filter Noise';
    }

    part def AnalogDigitalConverter {
        port voltageIn : FilteredInPort;
        port digitalOut : DigitalOutPort;
        attribute resolution : DigitalCount;
        attribute sampleRate : Real;
        perform action convert : 'Convert Analog to Digital';
    }

    part def SignalProcessor {
        port digitalIn : DigitalInPort;
        port pressureOut : PressureOutPort;
        port commandIn : CommandInPort;
        port statusOut : StatusOutPort;
        attribute calibrationFactor : CalFactor;
        attribute offset : PressureValue;
        attribute maxOperatingTemp : TemperatureValue;
        attribute healthOk : Boolean;
        perform action process : 'Process Digital Sample';
        perform action calibrate : 'Apply Calibration Factors';
    }

    part def SensorUnit {
        port pressureIn : PhysicalPressureInPort;
        port pressureOut : PressureOutPort;
        port commandIn : CommandInPort;
        port statusOut : StatusOutPort;
        attribute hermeticallySealed : Boolean;
        attribute integrated : Boolean;
        attribute measurementError : PressureValue;
        attribute ambientTemp : TemperatureValue;
        attribute currentTemp : TemperatureValue;
        attribute responseTime : Real;

        part crystal : PiezoCrystal;
        part amplifier : ChargeAmplifier;
        part sigFilter : SignalFilter;
        part adc : AnalogDigitalConverter;
        part processor : SignalProcessor;

        connect pressureIn to crystal.pressureIn;
        connect crystal.chargeOut to amplifier.chargeIn;
        connect amplifier.voltageOut to sigFilter.voltageIn;
        connect sigFilter.voltageOut to adc.voltageIn;
        connect adc.digitalOut to processor.digitalIn;
        connect processor.pressureOut to pressureOut;
        connect commandIn to processor.commandIn;
        connect processor.statusOut to statusOut;

        perform action acquirePressure : 'Acquire Pressure';
        exhibit state 'operational states' : 'Sensor Operational States';
    }

    requirement def 'Pressure Measurement Accuracy' {
        doc /* The sensing unit shall measure pressure within the specified accuracy. */
        subject sensor : SensorUnit;
        attribute maxError : PressureValue;
    }
    requirement def 'Wide Temperature Operation' {
        doc /* The unit shall operate across a wide temperature range. */
        subject sensor : SensorUnit;
        attribute minTemp : TemperatureValue;
        attribute maxTemp : TemperatureValue;
    }
    requirement def 'Hermetic Sealing' {
        doc /* The unit shall be hermetically sealed in a single package. */
        subject sensor : SensorUnit;
    }
    requirement def 'Fast Response Time' {
        doc /* The unit shall provide pressure readings with low latency. */
        subject sensor : SensorUnit;
        attribute maxLatency : Real;
    }
    requirement def 'Integrated Packaging' {
        doc /* All components shall be integrated into a single sealed package. */
        subject sensor : SensorUnit;
    }

    part icPiezoSensor : SensorUnit {
        attribute serialNumber : String;
        attribute :>> hermeticallySealed = true;
        attribute :>> integrated = true;
        attribute :>> measurementError = 0.5;
        attribute :>> responseTime = 0.0005;
        attribute :>> ambientTemp = 25;
        attribute :>> currentTemp = 25;
    }
}
