package FluxgateCompassSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NonSI::*;

    package Definitions {
        item def MagneticFieldStrength :> ISQ::MagneticFluxDensityValue;
        item def ExcitationCurrent :> ISQ::ElectricCurrentValue;
        item def PickupVoltage :> ISQ::ElectricPotentialValue;
        item def DigitalFieldData {
            attribute xField : MagneticFieldStrength;
            attribute yField : MagneticFieldStrength;
            attribute zField : MagneticFieldStrength;
        }
        item def CalibrationData {
            attribute hardIronOffsetX : MagneticFieldStrength;
            attribute hardIronOffsetY : MagneticFieldStrength;
            attribute hardIronOffsetZ : MagneticFieldStrength;
            attribute softIronScaleXX : Real;
            attribute softIronScaleYY : Real;
            attribute softIronScaleZZ : Real;
            attribute tempCoeffX : Real;
            attribute tempCoeffY : Real;
            attribute tempCoeffZ : Real;
        }
        item def HeadingAngle :> ISQ::AngleValue;
        item def TemperatureReading :> ISQ::TemperatureValue;

        port def ExcitationPort {
            out excitationSignal : ExcitationCurrent;
        }
        port def PickupPort {
            in pickupVoltage : PickupVoltage;
        }
        port def RawSignalPort {
            out rawVoltage : PickupVoltage;
        }
        port def DigitalDataPort {
            out fieldData : DigitalFieldData;
        }
        port def ProcessedDataPort {
            in fieldData : DigitalFieldData;
        }
        port def CalibrationPort {
            out calibrationData : CalibrationData;
            out temperature : TemperatureReading;
        }
        port def TemperatureOutputPort {
            out temperature : TemperatureReading;
        }
        port def HeadingOutputPort {
            out heading : HeadingAngle;
        }
        port def CommandPort {
            in command : CompassCommand;
        }

        attribute def CompassCommand;
        attribute def PowerOn;
        attribute def SelfTestComplete;
        attribute def CalibrationLoaded;
        attribute def PauseCommand;
        attribute def ResumeCommand;
        attribute def SelfTestFailed;

        part def FerromagneticCore {
            attribute saturationThreshold : MagneticFieldStrength;
        }
        part def DriveCoil {
            attribute inductance : ISQ::ElectricInductanceValue;
        }
        part def PickupCoil {
            attribute numberOfTurns : Integer;
        }
        part def FluxgateSensor {
            part coreX : FerromagneticCore;
            part coreY : FerromagneticCore;
            part coreZ : FerromagneticCore;
            part driveCoilX : DriveCoil;
            part driveCoilY : DriveCoil;
            part driveCoilZ : DriveCoil;
            part pickupCoilX : PickupCoil;
            part pickupCoilY : PickupCoil;
            part pickupCoilZ : PickupCoil;
            port excitationInput : ExcitationPort;
            port pickupOutputX : RawSignalPort;
            port pickupOutputY : RawSignalPort;
            port pickupOutputZ : RawSignalPort;
            perform action senseMagneticField;
        }
        part def ExcitationCircuit {
            attribute excitationFrequency : ISQ::FrequencyValue;
            attribute driveAmplitude : ExcitationCurrent;
            port excitationOutput : ExcitationPort;
            perform action generateExcitation;
        }
        part def SignalProcessor {
            attribute gain : Real;
            attribute filterCutoff : ISQ::FrequencyValue;
            port rawInputX : PickupPort;
            port rawInputY : PickupPort;
            port rawInputZ : PickupPort;
            port digitalOutput : DigitalDataPort;
            perform action processSignals;
        }
        part def TemperatureSensor {
            attribute maxOperatingTemp : ISQ::TemperatureValue;
            port tempOutput : TemperatureOutputPort;
            perform action measureTemperature;
        }
        part def CalibrationModule {
            part tempSensor : TemperatureSensor;
            port calibrationOutput : CalibrationPort;
            perform action loadCalibration;
        }
        part def HeadingCalculator {
            port dataInput : ProcessedDataPort;
            port calibrationInput : CalibrationPort;
            port headingOutput : HeadingOutputPort;
            perform action computeHeading;
        }
        part def FluxgateCompass {
            part fluxgateSensor : FluxgateSensor;
            part excitationCircuit : ExcitationCircuit;
            part signalProcessor : SignalProcessor;
            part calibrationModule : CalibrationModule;
            part headingCalculator : HeadingCalculator;
            port commandInput : CommandPort;
            port navigationOutput : HeadingOutputPort;
            exhibit state compassStates : CompassStates;
        }

        action def GenerateExcitation {
            out excitationSignal : ExcitationCurrent;
        }
        action def SenseMagneticField {
            in excitationSignal : ExcitationCurrent;
            out rawVoltageX : PickupVoltage;
            out rawVoltageY : PickupVoltage;
            out rawVoltageZ : PickupVoltage;
        }
        action def ProcessSignals {
            in rawVoltageX : PickupVoltage;
            in rawVoltageY : PickupVoltage;
            in rawVoltageZ : PickupVoltage;
            out fieldData : DigitalFieldData;
        }
        action def MeasureTemperature {
            out temperature : TemperatureReading;
        }
        action def LoadCalibration {
            out calibrationData : CalibrationData;
        }
        action def ComputeHeading {
            in fieldData : DigitalFieldData;
            in calibrationData : CalibrationData;
            in temperature : TemperatureReading;
            out heading : HeadingAngle;
        }
        action def PerformSelfTest;
        action def Initialize;

        state def CompassStates;

        requirement def HeadingAccuracyRequirement {
            doc /* The system shall provide heading information with an accuracy of <= 1.0 degrees. */
            attribute maxError : ISQ::AngleValue = 1.0 [deg];
        }
        requirement def ExcitationFrequencyRequirement {
            doc /* The excitation circuit shall generate a signal between 5000.0 and 20000.0 Hz. */
            attribute minFrequency : ISQ::FrequencyValue = 5000.0 [Hz];
            attribute maxFrequency : ISQ::FrequencyValue = 20000.0 [Hz];
        }
        requirement def OperatingTemperatureRequirement {
            doc /* The system shall operate correctly within a temperature range of -40.0 to +85.0 degrees Celsius. */
            attribute minTemp : ISQ::TemperatureValue = -40.0 [degC];
            attribute maxTemp : ISQ::TemperatureValue = 85.0 [degC];
        }
    }

    package Usages {
        private import Definitions::*;

        action 'initialize' : Initialize;
        action 'perform self test' : PerformSelfTest;
        action 'load calibration' : LoadCalibration;
        action 'generate excitation' : GenerateExcitation;
        action 'sense magnetic field' : SenseMagneticField;
        action 'process signals' : ProcessSignals;
        action 'measure temperature' : MeasureTemperature;
        action 'compute heading' : ComputeHeading;

        part fluxgateCompass : FluxgateCompass {
            part fluxgateSensor : FluxgateSensor {
                part coreX : FerromagneticCore {
                    attribute redefines saturationThreshold = 0.8 [T];
                }
                part coreY : FerromagneticCore {
                    attribute redefines saturationThreshold = 0.8 [T];
                }
                part coreZ : FerromagneticCore {
                    attribute redefines saturationThreshold = 0.8 [T];
                }
                part driveCoilX : DriveCoil {
                    attribute redefines inductance = 2.0 [mH];
                }
                part driveCoilY : DriveCoil {
                    attribute redefines inductance = 2.0 [mH];
                }
                part driveCoilZ : DriveCoil {
                    attribute redefines inductance = 2.0 [mH];
                }
                part pickupCoilX : PickupCoil {
                    attribute redefines numberOfTurns = 500;
                }
                part pickupCoilY : PickupCoil {
                    attribute redefines numberOfTurns = 500;
                }
                part pickupCoilZ : PickupCoil {
                    attribute redefines numberOfTurns = 500;
                }
            }
            part excitationCircuit : ExcitationCircuit {
                attribute redefines excitationFrequency = 10000.0 [Hz];
                attribute redefines driveAmplitude = 0.05 [A];
            }
            part signalProcessor : SignalProcessor {
                attribute redefines gain = 1000.0;
                attribute redefines filterCutoff = 50.0 [Hz];
            }
            part calibrationModule : CalibrationModule {
                part tempSensor : TemperatureSensor {
                    attribute redefines maxOperatingTemp = 85.0 [degC];
                }
            }
            part headingCalculator : HeadingCalculator;

            connect excitationCircuit.excitationOutput to fluxgateSensor.excitationInput;
            connect fluxgateSensor.pickupOutputX to signalProcessor.rawInputX;
            connect fluxgateSensor.pickupOutputY to signalProcessor.rawInputY;
            connect fluxgateSensor.pickupOutputZ to signalProcessor.rawInputZ;
            connect signalProcessor.digitalOutput to headingCalculator.dataInput;
            connect calibrationModule.calibrationOutput to headingCalculator.calibrationInput;
            connect headingCalculator.headingOutput to navigationOutput;
        }

        state compassStates : CompassStates {
            entry; then initializing;
            state initializing;
            accept SelfTestComplete
                then loadingCalibration;
            accept SelfTestFailed
                then faulted;
            state loadingCalibration;
            accept CalibrationLoaded
                then measuring;
            state measuring {
                do 'generate excitation';
                do 'sense magnetic field';
                do 'process signals';
                do 'measure temperature';
                do 'compute heading';
                accept PauseCommand
                    then standby;
            }
            state standby;
            accept ResumeCommand
                then measuring;
            state faulted;
            accept PowerOn
                then initializing;
        }

        requirement headingAccuracy : HeadingAccuracyRequirement;
        requirement excitationFrequency : ExcitationFrequencyRequirement;
        requirement operatingTemp : OperatingTemperatureRequirement;
    }
}
