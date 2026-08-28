package GasDetectionSystem {

    import ScalarValues::*;

    // ===== Units =====
    unit ohm;
    unit volt;
    unit ppm;
    unit decibel;
    unit second;

    // ===== Value Types =====
    value type Resistance :> Real { unit ohm; }
    value type Voltage :> Real { unit volt; }
    value type Concentration :> Real { unit ppm; }
    value type SoundLevel :> Real { unit decibel; }
    value type TimeSeconds :> Real { unit second; }
    value type DigitalValue :> Integer;

    // ===== Item Definitions =====
    item def AirSample {
        attribute gasConcentration : Concentration;
        attribute temperature : Real;
        attribute humidity : Real;
    }

    item def AnalogSignal {
        attribute voltage : Voltage;
        attribute noiseLevel : Voltage;
    }

    item def DigitalSample {
        attribute value : DigitalValue;
        attribute timestamp : String;
    }

    item def AlarmCommand {
        attribute activate : Boolean;
    }

    item def MeasurementRecord {
        attribute concentration : Concentration;
        attribute timestamp : String;
        attribute alarmTriggered : Boolean;
    }

    item def PowerSupply {
        attribute voltage : Voltage;
    }

    // ===== Port Definitions =====
    port def AirInputPort {
        in item : AirSample;
    }

    port def AnalogOutputPort {
        out item : AnalogSignal;
    }

    port def AnalogInputPort {
        in item : AnalogSignal;
    }

    port def DigitalOutputPort {
        out item : DigitalSample;
    }

    port def DigitalInputPort {
        in item : DigitalSample;
    }

    port def AlarmCommandPort {
        out item : AlarmCommand;
    }

    port def AlarmReceivePort {
        in item : AlarmCommand;
    }

    port def PowerOutputPort {
        out item : PowerSupply;
    }

    port def PowerInputPort {
        in item : PowerSupply;
    }

    port def RecordOutputPort {
        out item : MeasurementRecord;
    }

    // ===== Action Definitions =====
    action def SenseGas {
        in airSample : AirSample;
        in baselineResistance : Resistance;
        in sensitivityFactor : Real;
        out signal : AnalogSignal;
    }

    action def ProcessSignal {
        in rawSignal : AnalogSignal;
        in gain : Real;
        in filterFactor : Real;
        out processedSignal : AnalogSignal;
    }

    action def ConvertAD {
        in analogSignal : AnalogSignal;
        in referenceVoltage : Voltage;
        in resolutionBits : Integer;
        out digitalSample : DigitalSample;
    }

    action def CalculateConcentration {
        in digitalValue : DigitalValue;
        in calibrationSlope : Real;
        in calibrationOffset : Real;
        out concentration : Concentration;
    }

    action def EvaluateThreshold {
        in concentration : Concentration;
        in threshold : Concentration;
        out alarmTriggered : Boolean;
    }

    action def FormatRecord {
        in concentration : Concentration;
        in timestamp : String;
        in alarmTriggered : Boolean;
        out record : MeasurementRecord;
    }

    // ===== Part Definitions =====

    part def ChemiresistiveSensor {
        attribute baselineResistance : Resistance = 10000 [ohm];
        attribute sensitivityFactor : Real = 0.001;
        attribute responseTime : TimeSeconds = 5.0 [second];

        port airPort : AirInputPort;
        port rawSignalPort : AnalogOutputPort;
        port powerPort : PowerInputPort;

        perform sense : SenseGas;

        exhibit {
            entry; then idle;
            state idle;
            state sensing;

            transition idle -> sensing
                when airPort.item.gasConcentration > 0 [ppm];

            transition sensing -> idle
                when airPort.item.gasConcentration == 0 [ppm];

            transition sensing -> sensing
                do {
                    rawSignalPort.item.voltage := baselineResistance * sensitivityFactor * airPort.item.gasConcentration;
                    rawSignalPort.item.noiseLevel := 0.0005 [volt];
                }
        }
    }

    part def SignalProcessor {
        attribute gain : Real = 100.0;
        attribute filterFactor : Real = 0.1;
        attribute bandwidth : Real = 1000.0;

        port analogIn : AnalogInputPort;
        port analogOut : AnalogOutputPort;
        port powerPort : PowerInputPort;

        perform process : ProcessSignal;

        exhibit {
            entry; then ready;
            state ready;
            state processing;

            transition ready -> processing
                when analogIn.item.voltage > 0 [volt];

            transition processing -> ready
                when analogIn.item.voltage == 0 [volt];

            transition processing -> processing
                do {
                    analogOut.item.voltage := analogIn.item.voltage * gain;
                    analogOut.item.noiseLevel := analogIn.item.noiseLevel * filterFactor;
                }
        }
    }

    part def ADC {
        attribute resolutionBits : Integer = 12;
        attribute referenceVoltage : Voltage = 3.3 [volt];
        attribute samplingRate : Real = 1000.0;

        port analogIn : AnalogInputPort;
        port digitalOut : DigitalOutputPort;
        port powerPort : PowerInputPort;

        perform convert : ConvertAD;

        exhibit {
            entry; then waiting;
            state waiting;
            state converting;

            transition waiting -> converting
                when analogIn.item.voltage > 0 [volt];

            transition converting -> waiting
                when analogIn.item.voltage == 0 [volt];

            transition converting -> converting
                do {
                    digitalOut.item.value := (analogIn.item.voltage / referenceVoltage) * 4095;
                    digitalOut.item.timestamp := "system_clock";
                }
        }
    }

    part def Microcontroller {
        attribute safetyThreshold : Concentration = 50 [ppm];
        attribute calibrationSlope : Real = 0.05;
        attribute calibrationOffset : Real = 0.0;
        attribute currentConcentration : Concentration = 0 [ppm];
        attribute currentTimestamp : String = "00:00:00";

        port dataIn : DigitalInputPort;
        port alarmPort : AlarmCommandPort;
        port recordPort : RecordOutputPort;
        port powerPort : PowerInputPort;

        perform calcConc : CalculateConcentration;
        perform evalThresh : EvaluateThreshold;
        perform formatRec : FormatRecord;

        exhibit {
            entry; then idle;
            state idle;
            state analyzing;
            state alarmActive;

            transition idle -> analyzing
                when dataIn.item.value > 0
                do {
                    currentConcentration := calibrationSlope * dataIn.item.value + calibrationOffset;
                    currentTimestamp := dataIn.item.timestamp;
                }

            transition analyzing -> alarmActive
                when currentConcentration > safetyThreshold
                do {
                    alarmPort.item.activate := true;
                    recordPort.item.concentration := currentConcentration;
                    recordPort.item.timestamp := currentTimestamp;
                    recordPort.item.alarmTriggered := true;
                }

            transition analyzing -> idle
                when currentConcentration <= safetyThreshold
                do {
                    alarmPort.item.activate := false;
                    recordPort.item.concentration := currentConcentration;
                    recordPort.item.timestamp := currentTimestamp;
                    recordPort.item.alarmTriggered := false;
                }

            transition alarmActive -> idle
                when currentConcentration <= safetyThreshold
                do {
                    alarmPort.item.activate := false;
                    recordPort.item.concentration := currentConcentration;
                    recordPort.item.timestamp := currentTimestamp;
                    recordPort.item.alarmTriggered := false;
                }
        }
    }

    part def AlarmIndicator {
        attribute ledColor : String = "red";
        attribute sirenLevel : SoundLevel = 85.0 [decibel];
        attribute flashRate : Real = 2.0;

        port alarmIn : AlarmReceivePort;
        port powerPort : PowerInputPort;

        exhibit {
            entry; then silent;
            state silent;
            state active;

            transition silent -> active
                when alarmIn.item.activate == true;

            transition active -> silent
                when alarmIn.item.activate == false;
        }
    }

    part def PowerManagement {
        attribute inputVoltage : Voltage = 12.0 [volt];
        attribute regulatedVoltage3V3 : Voltage = 3.3 [volt];
        attribute regulatedVoltage5V : Voltage = 5.0 [volt];
        attribute efficiency : Real = 0.9;

        port extPowerIn : PowerInputPort;
        port powerOut3V3 : PowerOutputPort;
        port powerOut5V : PowerOutputPort;

        exhibit {
            entry; then off;
            state off;
            state powered;

            transition off -> powered
                when extPowerIn.item.voltage > 0 [volt]
                do {
                    powerOut3V3.item.voltage := regulatedVoltage3V3;
                    powerOut5V.item.voltage := regulatedVoltage5V;
                }

            transition powered -> off
                when extPowerIn.item.voltage == 0 [volt];
        }
    }

    // ===== Top-Level System =====
    part def GasDetector {
        part sensor : ChemiresistiveSensor;
        part processor : SignalProcessor;
        part adc : ADC;
        part controller : Microcontroller;
        part alarm : AlarmIndicator;
        part power : PowerManagement;

        port externalAirPort : AirInputPort;
        port externalPowerPort : PowerInputPort;
        port externalRecordPort : RecordOutputPort;

        connection airToSensor
            connect externalAirPort to sensor.airPort;

        connection sensorToProcessor
            connect sensor.rawSignalPort to processor.analogIn;

        connection processorToADC
            connect processor.analogOut to adc.analogIn;

        connection adcToController
            connect adc.digitalOut to controller.dataIn;

        connection controllerToAlarm
            connect controller.alarmPort to alarm.alarmIn;

        connection controllerToExternalRecord
            connect controller.recordPort to externalRecordPort;

        connection powerToSensor
            connect power.powerOut3V3 to sensor.powerPort;

        connection powerToProcessor
            connect power.powerOut3V3 to processor.powerPort;

        connection powerToADC
            connect power.powerOut3V3 to adc.powerPort;

        connection powerToController
            connect power.powerOut3V3 to controller.powerPort;

        connection powerToAlarm
            connect power.powerOut5V to alarm.powerPort;

        connection externalPowerToPM
            connect externalPowerPort to power.extPowerIn;
    }

    part gasDetectorSystem : GasDetector;

    // ===== Requirements =====
    requirement def DetectHazardousGas {
        subject detector : GasDetector;
        doc "The system shall continuously monitor air for hazardous gases such as Carbon Monoxide and provide early warnings to ensure personnel safety.";
    }

    requirement def SenseResistanceChange {
        subject sensor : ChemiresistiveSensor;
        doc "The chemiresistive sensor shall detect changes in electrical resistance of the chemically sensitive material proportional to target gas concentration.";
    }

    requirement def FilterAndAmplify {
        subject processor : SignalProcessor;
        doc "The signal processor shall filter electronic noise and amplify the raw sensor signal to produce a clean, reliable analog signal.";
    }

    requirement def AnalogToDigitalConversion {
        subject adc : ADC;
        doc "The ADC shall convert the amplified analog signal into a stream of digital values understandable by the microcontroller.";
    }

    requirement def CalculateAndCompare {
        subject controller : Microcontroller;
        doc "The microcontroller shall calculate gas concentration in ppm using a built-in calibration profile and compare against a pre-set safety threshold.";
    }

    requirement def ActivateAlarm {
        subject alarm : AlarmIndicator;
        doc "The alarm indicator shall produce a visual flashing light and audible siren alert when gas concentration exceeds the safety threshold.";
    }

    requirement def RegulatePower {
        subject power : PowerManagement;
        doc "The power management unit shall provide stable, regulated voltage from an external power source to all electronic components.";
    }

    requirement def LogMeasurementData {
        subject controller : Microcontroller;
        doc "The microcontroller shall format measurement data including concentration level and timestamp for logging or display.";
    }

    // ===== Satisfactions =====
    satisfaction satisfyDetectGas : DetectHazardousGas {
        subject :>> detector = gasDetectorSystem;
    }

    satisfaction satisfySenseResistance : SenseResistanceChange {
        subject :>> sensor = gasDetectorSystem.sensor;
    }

    satisfaction satisfyFilterAmplify : FilterAndAmplify {
        subject :>> processor = gasDetectorSystem.processor;
    }

    satisfaction satisfyADC : AnalogToDigitalConversion {
        subject :>> adc = gasDetectorSystem.adc;
    }

    satisfaction satisfyCalculateCompare : CalculateAndCompare {
        subject :>> controller = gasDetectorSystem.controller;
    }

    satisfaction satisfyActivateAlarm : ActivateAlarm {
        subject :>> alarm = gasDetectorSystem.alarm;
    }

    satisfaction satisfyRegulatePower : RegulatePower {
        subject :>> power = gasDetectorSystem.power;
    }

    satisfaction satisfyLogData : LogMeasurementData {
        subject :>> controller = gasDetectorSystem.controller;
    }
}
