package MemsMagnetometerUnit {

    import ScalarValues::*;
    import ISQ::Time;

    // ---- Value types with units ----
    value type MagneticFluxDensity :> Real {
        unit T;
    }
    value type Voltage :> Real {
        unit V;
    }
    value type Current :> Real {
        unit A;
    }
    value type Temperature :> Real {
        unit degC;
    }
    value type DigitalCount :> Integer {
        unit count;
    }
    value type Frequency :> Real {
        unit Hz;
    }
    value type Power :> Real {
        unit W;
    }
    value type Gain :> Real {
        unit dimensionless;
    }

    // ---- Item definitions ----
    item def RawAnalogSignal {
        attribute voltageX : Voltage;
        attribute voltageY : Voltage;
        attribute voltageZ : Voltage;
        attribute noisy : Boolean;
    }

    item def ConditionedAnalogSignal {
        attribute voltageX : Voltage;
        attribute voltageY : Voltage;
        attribute voltageZ : Voltage;
        attribute bandwidth : Frequency;
    }

    item def RawDigitalSample {
        attribute countX : DigitalCount;
        attribute countY : DigitalCount;
        attribute countZ : DigitalCount;
        attribute timestamp : Time;
        attribute overRange : Boolean;
    }

    item def CalibrationParameters {
        attribute offsetX : DigitalCount;
        attribute offsetY : DigitalCount;
        attribute offsetZ : DigitalCount;
        attribute scaleX : Gain;
        attribute scaleY : Gain;
        attribute scaleZ : Gain;
        attribute tempCoeffX : Real;
        attribute tempCoeffY : Real;
        attribute tempCoeffZ : Real;
        attribute referenceTemp : Temperature;
    }

    item def MagneticFieldVector {
        attribute bx : MagneticFluxDensity;
        attribute by : MagneticFluxDensity;
        attribute bz : MagneticFluxDensity;
        attribute temperature : Temperature;
        attribute saturated : Boolean;
        attribute valid : Boolean;
        attribute timestamp : Time;
    }

    item def PowerInput {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute sourceName : String;
    }

    item def RegulatedPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute ripple : Voltage;
    }

    item def I2CCommand {
        attribute address : Integer;
        attribute registerId : Integer;
        attribute payload : String;
    }

    // ---- Port definitions ----
    port def RawAnalogOutPort {
        out item signal : RawAnalogSignal;
    }

    port def ConditionedAnalogOutPort {
        out item signal : ConditionedAnalogSignal;
    }

    port def DigitalSampleOutPort {
        out item sample : RawDigitalSample;
    }

    port def PowerInPort {
        in item power : PowerInput;
    }

    port def RegulatedPowerOutPort {
        out item power : RegulatedPower;
    }

    port def I2CInterfacePort {
        attribute deviceAddress : Integer;
        in item command : I2CCommand;
        out item measurement : MagneticFieldVector;
    }

    // ---- Action definitions ----
    action def SenseMagneticField {
        in ambientField : MagneticFluxDensity[3];
        out rawSignal : RawAnalogSignal;
    }

    action def ConditionSignal {
        in raw : RawAnalogSignal;
        out conditioned : ConditionedAnalogSignal;
    }

    action def ConvertAnalogToDigital {
        in conditioned : ConditionedAnalogSignal;
        out sample : RawDigitalSample;
    }

    action def ApplyCalibration {
        in sample : RawDigitalSample;
        in calibration : CalibrationParameters;
        in temperature : Temperature;
        out vector : MagneticFieldVector;
    }

    action def FilterNoise {
        in input : MagneticFieldVector;
        out filtered : MagneticFieldVector;
    }

    action def CompensateTemperature {
        in input : MagneticFieldVector;
        in calibration : CalibrationParameters;
        out compensated : MagneticFieldVector;
    }

    action def DetectSaturation {
        in vector : MagneticFieldVector;
        in saturationLimit : MagneticFluxDensity;
        out flagged : MagneticFieldVector;
    }

    action def TransmitMeasurement {
        in vector : MagneticFieldVector;
        out transmitted : MagneticFieldVector;
    }

    // ---- Part definitions ----
    part def MemsMagneticSensor {
        attribute sensitivity : MagneticFluxDensity = 0.0001 [T];
        attribute saturationLimit : MagneticFluxDensity = 0.05 [T];
        attribute noiseFloor : MagneticFluxDensity = 0.000002 [T];
        attribute axisCount : Integer = 3;

        port rawOut : RawAnalogOutPort;
        port powerIn : PowerInPort;

        action sense : SenseMagneticField {
            in ambientField : MagneticFluxDensity[3];
            out rawSignal : RawAnalogSignal = rawOut.signal;
        }
    }

    part def SignalConditioner {
        attribute gain : Gain = 100.0;
        attribute bandwidth : Frequency = 1000.0 [Hz];
        attribute offsetCorrection : Voltage = 0.0 [V];

        port signalIn : RawAnalogOutPort;
        port signalOut : ConditionedAnalogOutPort;
        port powerIn : PowerInPort;

        action condition : ConditionSignal {
            in raw : RawAnalogSignal = signalIn.signal;
            out conditioned : ConditionedAnalogSignal = signalOut.signal;
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer = 16;
        attribute sampleRate : Frequency = 2000.0 [Hz];
        attribute referenceVoltage : Voltage = 3.3 [V];
        attribute lsb : Voltage = referenceVoltage / (2 ^ resolutionBits);

        port analogIn : ConditionedAnalogOutPort;
        port digitalOut : DigitalSampleOutPort;
        port powerIn : PowerInPort;

        action convert : ConvertAnalogToDigital {
            in conditioned : ConditionedAnalogSignal = analogIn.signal;
            out sample : RawDigitalSample = digitalOut.sample;
        }
    }

    part def Microcontroller {
        attribute clockFrequency : Frequency = 48000000.0 [Hz];
        attribute firmwareVersion : String = "1.4.0";
        attribute calibration : CalibrationParameters;
        attribute saturationLimit : MagneticFluxDensity = 0.05 [T];
        attribute measurementInterval : Time = 0.005 [s];

        port sampleIn : DigitalSampleOutPort;
        port i2cPort : I2CInterfacePort;
        port powerIn : PowerInPort;

        attribute latestMeasurement : MagneticFieldVector;

        // Operational state machine
        state def OperationalState {
            entry; then idle;

            state idle {
                attribute powerMode : String = "low-power";
                entry action logIdle { /* enter low-power idle */ }
            }

            state initializing {
                entry action runSelfTest {
                    // perform power-on self-test and load calibration
                }
                do action loadCalibration {
                    out calibration = Microcontroller::calibration;
                }
                transition initializing -> ready {
                    when selfTestPassed;
                }
            }

            state ready {
                entry action clearBuffers { /* clear measurement buffers */ }
                transition ready -> active {
                    when i2cPort.command.registerId == 0x01;
                }
            }

            state active {
                do action processMeasurement {
                    in sample : RawDigitalSample = sampleIn.sample;
                    out vector : MagneticFieldVector = latestMeasurement;
                }
                transition active -> ready {
                    when i2cPort.command.registerId == 0x00;
                }
                transition active -> active {
                    when latestMeasurement.saturated;
                    effect action flagSaturation {
                        // set saturation flag in latestMeasurement
                    }
                }
            }

            transition idle -> initializing {
                when powerApplied;
            }
            transition ready -> idle {
                when idleTimeout;
            }
        }

        attribute state : OperationalState;

        action process : ApplyCalibration {
            in sample : RawDigitalSample = sampleIn.sample;
            in calibration : CalibrationParameters = Microcontroller::calibration;
            in temperature : Temperature;
            out vector : MagneticFieldVector;
        }

        action filter : FilterNoise {
            in input : MagneticFieldVector = process.vector;
            out filtered : MagneticFieldVector;
        }

        action compensate : CompensateTemperature {
            in input : MagneticFieldVector = filter.filtered;
            in calibration : CalibrationParameters = Microcontroller::calibration;
            out compensated : MagneticFieldVector;
        }

        action detectSaturation : DetectSaturation {
            in vector : MagneticFieldVector = compensate.compensated;
            in saturationLimit : MagneticFluxDensity = Microcontroller::saturationLimit;
            out flagged : MagneticFieldVector = latestMeasurement;
        }

        action transmit : TransmitMeasurement {
            in vector : MagneticFieldVector = latestMeasurement;
            out transmitted : MagneticFieldVector = i2cPort.measurement;
        }
    }

    part def VoltageRegulator {
        attribute inputVoltageMin : Voltage = 3.0 [V];
        attribute inputVoltageMax : Voltage = 5.5 [V];
        attribute outputVoltage : Voltage = 3.3 [V];
        attribute maxOutputCurrent : Current = 0.5 [A];
        attribute efficiency : Real = 0.92;
        attribute thermalShutdown : Temperature = 125.0 [degC];

        port powerIn : PowerInPort;
        port regulatedOut : RegulatedPowerOutPort;

        action regulate {
            in input : PowerInput = powerIn.power;
            out output : RegulatedPower = regulatedOut.power;
        }
    }

    part def I2CBusPort {
        attribute deviceAddress : Integer = 0x1E;
        attribute clockSpeed : Frequency = 400000.0 [Hz];
        attribute pullupResistance : Real = 4700.0;

        port interface : I2CInterfacePort;
    }

    // ---- Top-level integrated unit ----
    part def MemsMagnetometerModule {
        attribute moduleIdentifier : String = "MEMS-MAG-001";
        attribute manufacturer : String = "IntegratedSensors";
        attribute operatingTempMin : Temperature = -40.0 [degC];
        attribute operatingTempMax : Temperature = 85.0 [degC];

        port externalPower : PowerInPort;
        port hostInterface : I2CInterfacePort;

        part sensor : MemsMagneticSensor;
        part conditioner : SignalConditioner;
        part adc : AnalogToDigitalConverter;
        part controller : Microcontroller;
        part regulator : VoltageRegulator;
        part i2cPort : I2CBusPort;

        // Power distribution
        connection powerExternalToRegulator connect externalPower to regulator.powerIn;
        connection powerRegulatorToSensor connect regulator.regulatedOut to sensor.powerIn;
        connection powerRegulatorToConditioner connect regulator.regulatedOut to conditioner.powerIn;
        connection powerRegulatorToAdc connect regulator.regulatedOut to adc.powerIn;
        connection powerRegulatorToController connect regulator.regulatedOut to controller.powerIn;

        // Signal pipeline
        connection rawSignalFlow connect sensor.rawOut to conditioner.signalIn;
        connection conditionedSignalFlow connect conditioner.signalOut to adc.analogIn;
        connection digitalSampleFlow connect adc.digitalOut to controller.sampleIn;

        // Host communication
        connection hostI2cFlow connect controller.i2cPort to i2cPort.interface;
        connection hostInterfaceFlow connect i2cPort.interface to hostInterface;
    }

    // ---- Requirements ----
    requirement def MeasurementAccuracyRequirement {
        subject module : MemsMagnetometerModule;
        attribute maxError : MagneticFluxDensity = 0.0005 [T];
        require {
            module.controller.latestMeasurement.valid == true
            and abs(module.controller.latestMeasurement.bx) <= maxError
        }
    }

    requirement def TriAxisMeasurementRequirement {
        subject module : MemsMagnetometerModule;
        require {
            module.sensor.axisCount == 3
        }
    }

    requirement def SaturationDetectionRequirement {
        subject module : MemsMagnetometerModule;
        attribute saturationThreshold : MagneticFluxDensity = 0.05 [T];
        require {
            module.controller.latestMeasurement.saturated == true
            when abs(module.controller.latestMeasurement.bx) >= saturationThreshold
                or abs(module.controller.latestMeasurement.by) >= saturationThreshold
                or abs(module.controller.latestMeasurement.bz) >= saturationThreshold
        }
    }

    requirement def PowerRegulationRequirement {
        subject module : MemsMagnetometerModule;
        attribute regulatedVoltage : Voltage = 3.3 [V];
        attribute tolerance : Voltage = 0.03 [V];
        require {
            module.regulator.outputVoltage == regulatedVoltage
            and module.regulator.regulatedOut.power.ripple <= tolerance
        }
    }

    requirement def I2CCommunicationRequirement {
        subject module : MemsMagnetometerModule;
        attribute requiredAddress : Integer = 0x1E;
        require {
            module.i2cPort.deviceAddress == requiredAddress
            and module.hostInterface.measurement.valid == true
        }
    }

    requirement def OperationalStateMachineRequirement {
        subject module : MemsMagnetometerModule;
        require {
            module.controller.state in {OperationalState::idle,
                OperationalState::initializing,
                OperationalState::ready,
                OperationalState::active}
        }
    }

    requirement def TemperatureCompensationRequirement {
        subject module : MemsMagnetometerModule;
        attribute operatingRangeMin : Temperature = -40.0 [degC];
        attribute operatingRangeMax : Temperature = 85.0 [degC];
        require {
            module.controller.latestMeasurement.temperature >= operatingRangeMin
            and module.controller.latestMeasurement.temperature <= operatingRangeMax
        }
    }

    // ---- Requirement satisfaction ----
    satisfaction satisfyTriAxis : TriAxisMeasurementRequirement {
        subject : MemsMagnetometerModule = MemsMagnetometerModule;
    }
    satisfaction satisfyAccuracy : MeasurementAccuracyRequirement {
        subject : MemsMagnetometerModule = MemsMagnetometerModule;
    }
    satisfaction satisfySaturation : SaturationDetectionRequirement {
        subject : MemsMagnetometerModule = MemsMagnetometerModule;
    }
    satisfaction satisfyPower : PowerRegulationRequirement {
        subject : MemsMagnetometerModule = MemsMagnetometerModule;
    }
    satisfaction satisfyI2C : I2CCommunicationRequirement {
        subject : MemsMagnetometerModule = MemsMagnetometerModule;
    }
    satisfaction satisfyStateMachine : OperationalStateMachineRequirement {
        subject : MemsMagnetometerModule = MemsMagnetometerModule;
    }
    satisfaction satisfyTempComp : TemperatureCompensationRequirement {
        subject : MemsMagnetometerModule = MemsMagnetometerModule;
    }
}
