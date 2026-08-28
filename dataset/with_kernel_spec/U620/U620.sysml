package BrakeFluidPressureSensingUnit {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        attribute def PressureValue :> Real;
        attribute def TemperatureValue :> Real;
        attribute def VoltageValue :> Real;
        attribute def DigitalValue :> Integer;

        enum def SensorStatus {
            normal;
            degraded;
            fault;
        }

        attribute def CalibrationComplete;
        attribute def FaultDetected;
        attribute def RangeExceeded;
        attribute def RangeRestored;
        attribute def ResetCommand;

        port def BrakeFluidPort {
            out pressure : PressureValue;
            out temperature : TemperatureValue;
        }
        port def AnalogOutputPort {
            out voltage : VoltageValue;
        }
        port def PressurePort {
            out pressure : PressureValue;
        }
        port def TemperaturePort {
            out temperature : TemperatureValue;
        }
        port def DigitalPort {
            out digitalValue : DigitalValue;
        }
        port def StatusPort {
            out status : SensorStatus;
        }
        port def DiagnosticInputPort {
            in reset : ResetCommand;
        }

        action def InitializeSensor;
        action def CalibrateSensor;
        action def SenseRawPressure {
            out rawPressure : PressureValue;
        }
        action def SenseFluidTemperature {
            out fluidTemp : TemperatureValue;
        }
        action def CompensateForTemperature {
            in rawPressure : PressureValue;
            in fluidTemp : TemperatureValue;
            out compensatedPressure : PressureValue;
        }
        action def ConditionSignal {
            in compensatedPressure : PressureValue;
            out analogVoltage : VoltageValue;
        }
        action def ConvertAnalogToDigital {
            in analogVoltage : VoltageValue;
            out digitalValue : DigitalValue;
        }
        action def RunDiagnostics {
            in digitalValue : DigitalValue;
            out status : SensorStatus;
        }

        part def SensingElement {
            doc /* Primary sensing element in direct contact with brake fluid to obtain raw pressure measurement. */
            port fluidContactPort : ~BrakeFluidPort;
            port rawPressureOut : PressurePort;
            port rawTempOut : TemperaturePort;
            perform action senseRawPressure : SenseRawPressure;
            perform action senseFluidTemperature : SenseFluidTemperature;
        }

        part def TemperatureCompensationUnit {
            doc /* Adjusts raw pressure reading for accuracy across a wide range of operating temperatures. */
            port rawPressureIn : ~PressurePort;
            port rawTempIn : ~TemperaturePort;
            port compensatedPressureOut : PressurePort;
            perform action compensateForTemperature : CompensateForTemperature;
        }

        part def SignalConditioningCircuit {
            doc /* Amplifies and filters the compensated signal into a clean, stable analog voltage. */
            port compensatedPressureIn : ~PressurePort;
            port analogOut : AnalogOutputPort;
            perform action conditionSignal : ConditionSignal;
        }

        part def AnalogToDigitalConverter {
            doc /* Converts the analog voltage into a high-resolution digital value. */
            port analogIn : ~AnalogOutputPort;
            port digitalOut : DigitalPort;
            perform action convertAnalogToDigital : ConvertAnalogToDigital;
        }

        part def DiagnosticController {
            doc /* Continuously monitors sensor health and validity of readings, assigning diagnostic status. */
            port digitalIn : ~DigitalPort;
            port diagInput : DiagnosticInputPort;
            port statusOut : StatusPort;
            perform action runDiagnostics : RunDiagnostics;
        }

        part def VehicleController {
            doc /* External vehicle controller such as ABS or ESC that consumes sensor data. */
            port brakeSensorDigitalIn : ~DigitalPort;
            port brakeSensorAnalogIn : ~AnalogOutputPort;
            port brakeSensorStatusIn : ~StatusPort;
            port diagControlOut : DiagnosticInputPort;
        }

        part def BrakeFluidPressureSensor {
            doc /* Composite electronic sensor measuring hydraulic brake fluid pressure and providing analog and digital outputs. */
            attribute maxPressure : PressureValue = 200.0;
            attribute minPressure : PressureValue = 0.0;
            attribute maxOperatingTemp : TemperatureValue = 125.0;
            attribute supplyVoltage : VoltageValue = 5.0;
            attribute resolution : DigitalValue = 12;

            port fluidPort : ~BrakeFluidPort;
            port analogOutputPort : AnalogOutputPort;
            port digitalPressureOut : DigitalPort;
            port diagnosticStatusOut : StatusPort;
            port diagInputPort : DiagnosticInputPort;

            part sensingElement : SensingElement;
            part tempCompUnit : TemperatureCompensationUnit;
            part signalConditioning : SignalConditioningCircuit;
            part adc : AnalogToDigitalConverter;
            part diagController : DiagnosticController;

            perform action initializeSensor : InitializeSensor;
            perform action calibrateSensor : CalibrateSensor;
            perform action senseRawPressure : SenseRawPressure;
            perform action senseFluidTemperature : SenseFluidTemperature;
            perform action compensateForTemperature : CompensateForTemperature;
            perform action conditionSignal : ConditionSignal;
            perform action convertAnalogToDigital : ConvertAnalogToDigital;
            perform action runDiagnostics : RunDiagnostics;

            connect fluidPort to sensingElement.fluidContactPort;
            connect sensingElement.rawPressureOut to tempCompUnit.rawPressureIn;
            connect sensingElement.rawTempOut to tempCompUnit.rawTempIn;
            connect tempCompUnit.compensatedPressureOut to signalConditioning.compensatedPressureIn;
            connect signalConditioning.analogOut to analogOutputPort;
            connect signalConditioning.analogOut to adc.analogIn;
            connect adc.digitalOut to diagController.digitalIn;
            connect adc.digitalOut to digitalPressureOut;
            connect diagController.statusOut to diagnosticStatusOut;
            connect diagInputPort to diagController.diagInput;

            exhibit state operationalStates {
                entry; then initializing;

                state initializing {
                    entry initializeSensor;
                }
                transition init_to_calib
                    first initializing
                    then calibrating;

                state calibrating {
                    entry calibrateSensor;
                }
                transition calib_to_normal
                    first calibrating
                    accept CalibrationComplete
                    then normalOperation;

                state normalOperation {
                    do senseRawPressure;
                    do senseFluidTemperature;
                    do compensateForTemperature;
                    do conditionSignal;
                    do convertAnalogToDigital;
                    do runDiagnostics;
                }
                transition normal_to_faulted
                    first normalOperation
                    accept FaultDetected
                    then faulted;
                transition normal_to_degraded
                    first normalOperation
                    accept RangeExceeded
                    then degradedOperation;

                state degradedOperation {
                    do senseRawPressure;
                    do senseFluidTemperature;
                    do compensateForTemperature;
                    do conditionSignal;
                    do convertAnalogToDigital;
                    do runDiagnostics;
                }
                transition degraded_to_normal
                    first degradedOperation
                    accept RangeRestored
                    then normalOperation;
                transition degraded_to_faulted
                    first degradedOperation
                    accept FaultDetected
                    then faulted;
                transition degraded_to_init
                    first degradedOperation
                    accept ResetCommand
                    then initializing;

                state faulted;
                transition faulted_to_init
                    first faulted
                    accept ResetCommand
                    then initializing;
            }
        }

        requirement def ShallProvideAccuratePressure {
            subject sensor : BrakeFluidPressureSensor;
            doc /* The sensor shall measure brake fluid pressure with an accuracy of +/- 1% over the full operating range. */
        }
        requirement def ShallProvideAnalogAndDigitalOutput {
            subject sensor : BrakeFluidPressureSensor;
            doc /* The sensor shall provide both analog voltage and digital pressure outputs simultaneously. */
        }
        requirement def ShallMonitorHealth {
            subject sensor : BrakeFluidPressureSensor;
            doc /* The sensor shall continuously monitor its health and report normal, degraded, or fault status. */
        }
        requirement def ShallEnterFaultStateOnError {
            subject sensor : BrakeFluidPressureSensor;
            doc /* Upon detecting an internal error, the sensor shall enter a faulted state and cease providing pressure data. */
        }
        requirement def ShallSupportReset {
            subject sensor : BrakeFluidPressureSensor;
            doc /* The sensor shall support a reset command to clear faults and re-initialize. */
        }
        requirement def ShallProvideTemperatureCompensation {
            subject sensor : BrakeFluidPressureSensor;
            doc /* The sensor shall compensate raw pressure readings for temperature variations across the operating range. */
        }
    }

    package Usages {
        private import Definitions::*;

        part brakeFluidPressureSensor : BrakeFluidPressureSensor {
            ref vehicleController : VehicleController;

            connect digitalPressureOut to vehicleController.brakeSensorDigitalIn;
            connect analogOutputPort to vehicleController.brakeSensorAnalogIn;
            connect diagnosticStatusOut to vehicleController.brakeSensorStatusIn;
            connect vehicleController.diagControlOut to diagInputPort;

            satisfy ShallProvideAccuratePressure;
            satisfy ShallProvideAnalogAndDigitalOutput;
            satisfy ShallMonitorHealth;
            satisfy ShallEnterFaultStateOnError;
            satisfy ShallSupportReset;
            satisfy ShallProvideTemperatureCompensation;
        }
    }
}
