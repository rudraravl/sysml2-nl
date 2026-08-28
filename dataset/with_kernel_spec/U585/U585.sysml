package 'Three-Axis Digital Accelerometer' {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        attribute def AccelerationValue :> ISQ::acceleration;
        attribute def VoltageValue :> ISQ::electricPotential;
        attribute def TemperatureValue :> ISQ::thermodynamicTemperature;
        attribute def DisplacementValue :> ISQ::length;
        attribute def SamplingRateValue :> ISQ::frequency;
        attribute def SensitivityValue :> Real;

        attribute def AccelerationVector {
            attribute x : AccelerationValue;
            attribute y : AccelerationValue;
            attribute z : AccelerationValue;
        }

        attribute def OperationalStatus {
            attribute temperature : TemperatureValue;
            attribute calibrated : Boolean;
            attribute faultCode : Integer;
        }

        attribute def CalibrationMatrix {
            attribute m11 : Real; attribute m12 : Real; attribute m13 : Real;
            attribute m21 : Real; attribute m22 : Real; attribute m23 : Real;
            attribute m31 : Real; attribute m32 : Real; attribute m33 : Real;
        }

        attribute def OffsetVector {
            attribute x : Real;
            attribute y : Real;
            attribute z : Real;
        }

        attribute def ConfigCommand {
            attribute samplingRate : SamplingRateValue;
            attribute sensitivity : SensitivityValue;
        }

        attribute def StartCalibrationCmd;
        attribute def StartMeasuringCmd;
        attribute def StopCmd;
        attribute def ResetCmd;
        attribute def FaultDetected;

        item def RawAnalogSignal {
            attribute voltage : VoltageValue;
            attribute axisId : String;
        }

        item def ConditionedAnalogSignal {
            attribute voltage : VoltageValue;
            attribute axisId : String;
        }

        item def RawDigitalSample {
            attribute value : Integer;
            attribute axisId : String;
        }

        port def ConfigPort {
            in configCmd : ConfigCommand;
            in startCalibration : StartCalibrationCmd;
            in startMeasuring : StartMeasuringCmd;
            in stop : StopCmd;
            in reset : ResetCmd;
        }

        port def DataOutputPort {
            out acceleration : AccelerationVector;
            out status : OperationalStatus;
        }

        port def AnalogSignalPort {
            out signal : RawAnalogSignal;
        }

        port def ConditionedSignalPort {
            out signal : ConditionedAnalogSignal;
        }

        port def DigitalSamplePort {
            out sample : RawDigitalSample;
        }

        action def SenseAcceleration {
            in axisId : String;
            out displacement : DisplacementValue;
        }

        action def ConvertToAnalog {
            in displacement : DisplacementValue;
            in axisId : String;
            out signal : RawAnalogSignal;
        }

        action def ConditionSignal {
            in inputSignal : RawAnalogSignal;
            out outputSignal : ConditionedAnalogSignal;
        }

        action def ConvertToDigital {
            in inputSignal : ConditionedAnalogSignal;
            out sample : RawDigitalSample;
        }

        action def ProcessData {
            in xSample : RawDigitalSample;
            in ySample : RawDigitalSample;
            in zSample : RawDigitalSample;
            in calMatrix : CalibrationMatrix;
            in offset : OffsetVector;
            out acceleration : AccelerationVector;
        }

        action def SelfCalibration {
            out calMatrix : CalibrationMatrix;
            out offset : OffsetVector;
            out calibrated : Boolean;
        }

        action def ReadTemperature {
            out temp : TemperatureValue;
        }

        action def ReportStatus {
            in temp : TemperatureValue;
            in calibrated : Boolean;
            in faultCode : Integer;
            out status : OperationalStatus;
        }

        state def AccelerometerStates;

        part def SensingElement {
            attribute axisId : String;
            attribute proofMass :> ISQ::mass;
            attribute springConstant : Real;
            port analogOut : AnalogSignalPort;
            perform action sense : SenseAcceleration;
            perform action convert : ConvertToAnalog;
        }

        part def SignalConditioner {
            attribute gain : Real = 100.0;
            attribute filterCutoff : ISQ::frequency = 500[Hz];
            port analogIn : ~AnalogSignalPort;
            port conditionedOut : ConditionedSignalPort;
            perform action condition : ConditionSignal;
        }

        part def AnalogToDigitalConverter {
            attribute resolutionBits : Integer = 16;
            attribute samplingRate : SamplingRateValue = 1000[Hz];
            port conditionedIn : ~ConditionedSignalPort;
            port digitalOut : DigitalSamplePort;
            perform action convert : ConvertToDigital;
        }

        part def DataProcessor {
            attribute calibrationMatrix : CalibrationMatrix;
            attribute offsetVector : OffsetVector;
            attribute calibrated : Boolean = false;
            port digitalInX : ~DigitalSamplePort;
            port digitalInY : ~DigitalSamplePort;
            port digitalInZ : ~DigitalSamplePort;
            port dataOut : DataOutputPort;
            perform action process : ProcessData;
            perform action calibrate : SelfCalibration;
            perform action readTemp : ReadTemperature;
            perform action report : ReportStatus;
        }

        part def Accelerometer {
            attribute deviceName : String = "ADXL-3AXIS";
            attribute samplingRate : SamplingRateValue = 1000[Hz];
            attribute sensitivity : SensitivityValue = 2.0;
            attribute currentTemperature : TemperatureValue;
            attribute faultCode : Integer = 0;

            port configPort : ConfigPort;
            port dataPort : DataOutputPort;

            part xSensingElement : SensingElement { attribute axisId = "X"; }
            part ySensingElement : SensingElement { attribute axisId = "Y"; }
            part zSensingElement : SensingElement { attribute axisId = "Z"; }

            part xConditioner : SignalConditioner;
            part yConditioner : SignalConditioner;
            part zConditioner : SignalConditioner;

            part xADC : AnalogToDigitalConverter;
            part yADC : AnalogToDigitalConverter;
            part zADC : AnalogToDigitalConverter;

            part processor : DataProcessor;

            exhibit state accelerometerStates : AccelerometerStates parallel {
                state operationalStates {
                    entry; then idle;
                    state idle;
                    transition idle_To_calibrating
                        first idle
                        accept StartCalibrationCmd
                        then calibrating;
                    state calibrating {
                        do processor.calibrate;
                    }
                    transition calibrating_To_idle
                        first calibrating
                        accept StopCmd
                        then idle;
                    transition idle_To_measuring
                        first idle
                        accept StartMeasuringCmd
                        then measuring;
                    state measuring {
                        do processor.process;
                        do processor.readTemp;
                        do processor.report;
                    }
                    transition measuring_To_idle
                        first measuring
                        accept StopCmd
                        then idle;
                    transition measuring_To_fault
                        first measuring
                        accept FaultDetected
                        then fault;
                    state fault;
                    transition fault_To_idle
                        first fault
                        accept ResetCmd
                        then idle;
                }
                state configStates {
                    entry; then unconfigured;
                    state unconfigured;
                    transition unconfigured_To_configured
                        first unconfigured
                        accept ConfigCommand
                        then configured;
                    state configured;
                }
            }

            connect xSensingElement.analogOut to xConditioner.analogIn;
            connect ySensingElement.analogOut to yConditioner.analogIn;
            connect zSensingElement.analogOut to zConditioner.analogIn;

            connect xConditioner.conditionedOut to xADC.conditionedIn;
            connect yConditioner.conditionedOut to yADC.conditionedIn;
            connect zConditioner.conditionedOut to zADC.conditionedIn;

            connect xADC.digitalOut to processor.digitalInX;
            connect yADC.digitalOut to processor.digitalInY;
            connect zADC.digitalOut to processor.digitalInZ;

            connect processor.dataOut to dataPort;
        }

        requirement def AccelerometerPerformanceRequirement {
            attribute minSamplingRate : SamplingRateValue = 100[Hz];
            attribute maxSamplingRate : SamplingRateValue = 5000[Hz];
            attribute measurementRange : AccelerationValue = 157.0[m/s^2];
            subject accel : Accelerometer;
            require {
                accel.samplingRate >= minSamplingRate and
                accel.samplingRate <= maxSamplingRate
            }
        }

        requirement def AccuracyRequirement {
            attribute maxError : AccelerationValue = 0.098[m/s^2];
            subject accel : Accelerometer;
            require {
                accel.processor.calibrated == true
            }
        }

        requirement def PowerRequirement {
            attribute maxIdlePower : ISQ::power = 0.0005[W];
            attribute maxActivePower : ISQ::power = 0.005[W];
            subject accel : Accelerometer;
        }

        requirement def FaultToleranceRequirement {
            subject accel : Accelerometer;
            require {
                accel.faultCode >= 0
            }
        }
    }

    package Usages {
        private import Definitions::*;

        part accelerometerSystem : Accelerometer {
            attribute deviceName = "ADXL-3AXIS-001";
            attribute samplingRate = 1000[Hz];
            attribute sensitivity = 2.0;

            part xSensingElement {
                attribute axisId = "X";
                attribute proofMass = 0.000001[kg];
                attribute springConstant = 10.0;
            }
            part ySensingElement {
                attribute axisId = "Y";
                attribute proofMass = 0.000001[kg];
                attribute springConstant = 10.0;
            }
            part zSensingElement {
                attribute axisId = "Z";
                attribute proofMass = 0.000001[kg];
                attribute springConstant = 10.0;
            }

            part xConditioner {
                attribute gain = 100.0;
                attribute filterCutoff = 500[Hz];
            }
            part yConditioner {
                attribute gain = 100.0;
                attribute filterCutoff = 500[Hz];
            }
            part zConditioner {
                attribute gain = 100.0;
                attribute filterCutoff = 500[Hz];
            }

            part xADC {
                attribute resolutionBits = 16;
                attribute samplingRate = 1000[Hz];
            }
            part yADC {
                attribute resolutionBits = 16;
                attribute samplingRate = 1000[Hz];
            }
            part zADC {
                attribute resolutionBits = 16;
                attribute samplingRate = 1000[Hz];
            }

            part processor {
                attribute calibrationMatrix : CalibrationMatrix = CalibrationMatrix {
                    m11 = 1.0; m12 = 0.0; m13 = 0.0;
                    m21 = 0.0; m22 = 1.0; m23 = 0.0;
                    m31 = 0.0; m32 = 0.0; m33 = 1.0;
                };
                attribute offsetVector : OffsetVector = OffsetVector {
                    x = 0.0; y = 0.0; z = 0.0;
                };
                attribute calibrated = false;
            }
        }

        requirement accelPerfReq : AccelerometerPerformanceRequirement {
            subject accel = accelerometerSystem;
            attribute minSamplingRate = 100[Hz];
            attribute maxSamplingRate = 5000[Hz];
            attribute measurementRange = 157.0[m/s^2];
        }

        requirement accelAccuracyReq : AccuracyRequirement {
            subject accel = accelerometerSystem;
            attribute maxError = 0.098[m/s^2];
        }

        requirement accelPowerReq : PowerRequirement {
            subject accel = accelerometerSystem;
            attribute maxIdlePower = 0.0005[W];
            attribute maxActivePower = 0.005[W];
        }

        requirement accelFaultReq : FaultToleranceRequirement {
            subject accel = accelerometerSystem;
        }

        verification def VerifySamplingRate {
            subject accel : Accelerometer;
            objective {
                doc /* Verify the accelerometer supports the required sampling rate range. */
            }
            return pass : Boolean;
        }

        verification def VerifyAccuracy {
            subject accel : Accelerometer;
            objective {
                doc /* Verify the accelerometer meets accuracy requirements after calibration. */
            }
            return pass : Boolean;
        }

        verification verifySamplingRate : VerifySamplingRate {
            subject accel = accelerometerSystem;
        }

        verification verifyAccuracy : VerifyAccuracy {
            subject accel = accelerometerSystem;
        }
    }
}
