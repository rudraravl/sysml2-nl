package BiosensorDevice {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    item def BiologicalSample {
        attribute sampleType : String;
        attribute volume :> ISQ::volume;
        attribute targetSubstance : String;
    }
    item def PreparedSample :> BiologicalSample {
        attribute preparationComplete : Boolean;
    }
    item def BoundSample :> PreparedSample {
        attribute bindingConcentration :> ISQ::massDensity;
    }
    item def RawElectricalSignal {
        attribute voltage :> ISQ::electricPotential;
    }
    item def AmplifiedSignal :> RawElectricalSignal;
    item def DigitalSignal {
        attribute rawValue : Integer;
    }
    item def MeasurementResult {
        attribute concentration :> ISQ::massDensity;
        attribute confidenceScore : Real;
        attribute unit : String;
    }
    item def Power {
        attribute voltage :> ISQ::electricPotential;
        attribute current :> ISQ::electricCurrent;
    }

    attribute def StartCommand;
    attribute def SampleInserted;
    attribute def MeasurementComplete;
    attribute def ErrorEvent {
        attribute errorCode : Integer;
        attribute description : String;
    }
    attribute def ResetCommand;
    attribute def ContinuousModeCommand {
        attribute interval :> ISQ::duration;
    }

    port def SamplePort {
        in item sample : BiologicalSample;
    }
    port def PreparedSamplePort {
        in item preparedSample : PreparedSample;
    }
    port def BoundSamplePort {
        in item boundSample : BoundSample;
    }
    port def RawSignalPort {
        out item rawSignal : RawElectricalSignal;
    }
    port def AmplifiedSignalPort {
        out item amplifiedSignal : AmplifiedSignal;
    }
    port def DigitalSignalPort {
        out item digitalSignal : DigitalSignal;
    }
    port def ResultPort {
        out item result : MeasurementResult;
    }
    port def DisplayPort {
        in item result : MeasurementResult;
    }
    port def PowerPort {
        in item power : Power;
    }
    port def CommandPort {
        in attribute startCmd : StartCommand;
        in attribute resetCmd : ResetCommand;
        in attribute continuousCmd : ContinuousModeCommand;
    }

    action def PrepareSample {
        in item rawSample : BiologicalSample;
        out item preparedSample : PreparedSample;
    }
    action def BiorecognitionBinding {
        in item preparedSample : PreparedSample;
        out item boundSample : BoundSample;
    }
    action def Transduce {
        in item boundSample : BoundSample;
        out item rawSignal : RawElectricalSignal;
    }
    action def Amplify {
        in item rawSignal : RawElectricalSignal;
        out item amplifiedSignal : AmplifiedSignal;
    }
    action def ConvertAnalogToDigital {
        in item amplifiedSignal : AmplifiedSignal;
        out item digitalSignal : DigitalSignal;
    }
    action def ProcessData {
        in item digitalSignal : DigitalSignal;
        out item result : MeasurementResult;
    }
    action def DisplayResult {
        in item result : MeasurementResult;
    }
    action def RunSelfTest;
    action def Calibrate;
    action def ManagePower;
    action def MeasurementSequence;

    state def BiosensorStates {
        entry; then initialization;
        state initialization {
            do runSelfTest : RunSelfTest;
            do calibrate : Calibrate;
        }
        transition first initialization accept MeasurementComplete then ready;
        state ready;
        transition first ready accept SampleInserted then measuring;
        transition first ready accept StartCommand then initialization;
        transition first ready accept cmd : ContinuousModeCommand then continuousMonitoring;
        state measuring {
            do measure : MeasurementSequence;
        }
        transition first measuring accept MeasurementComplete then ready;
        transition first measuring accept err : ErrorEvent then errorState;
        state continuousMonitoring;
        transition first continuousMonitoring accept after 60 [s] do measure : MeasurementSequence then continuousMonitoring;
        transition first continuousMonitoring accept ResetCommand then ready;
        state errorState;
        transition first errorState accept ResetCommand then initialization;
    }

    part def Battery {
        attribute capacity :> ISQ::energy;
        attribute currentCharge :> ISQ::energy;
        attribute nominalVoltage :> ISQ::electricPotential;
        attribute batteryLife :> ISQ::duration;
        port powerOut : ~PowerPort;
    }
    part def PowerManagementUnit {
        attribute efficiency : Real;
        port powerIn : PowerPort;
        port powerOut1 : ~PowerPort;
        port powerOut2 : ~PowerPort;
        port powerOut3 : ~PowerPort;
        port powerOut4 : ~PowerPort;
        port powerOut5 : ~PowerPort;
        port powerOut6 : ~PowerPort;
        port powerOut7 : ~PowerPort;
        perform managePower : ManagePower;
    }
    part def SamplePreparationUnit {
        port sampleIn : SamplePort;
        port preparedSampleOut : ~PreparedSamplePort;
        port powerIn : PowerPort;
        perform prepareSample : PrepareSample;
    }
    part def BiorecognitionLayer {
        attribute targetMolecule : String;
        attribute bindingAffinity :> ISQ::energy;
        port preparedSampleIn : PreparedSamplePort;
        port boundSampleOut : ~BoundSamplePort;
        port powerIn : PowerPort;
        perform bioBinding : BiorecognitionBinding;
    }
    part def Transducer {
        attribute sensitivity :> ISQ::electricPotential;
        port boundSampleIn : BoundSamplePort;
        port rawSignalOut : RawSignalPort;
        port powerIn : PowerPort;
        perform transduce : Transduce;
    }
    part def SignalAmplifier {
        attribute gain : Real;
        port rawSignalIn : ~RawSignalPort;
        port amplifiedSignalOut : AmplifiedSignalPort;
        port powerIn : PowerPort;
        perform amplify : Amplify;
    }
    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer;
        attribute samplingRate :> ISQ::frequency;
        port amplifiedSignalIn : ~AmplifiedSignalPort;
        port digitalSignalOut : DigitalSignalPort;
        port powerIn : PowerPort;
        perform convert : ConvertAnalogToDigital;
    }
    part def DataProcessor {
        attribute calibrationCurve : String;
        port digitalSignalIn : ~DigitalSignalPort;
        port resultOut : ResultPort;
        port commandInput : CommandPort;
        port powerIn : PowerPort;
        perform processData : ProcessData;
        perform runSelfTest : RunSelfTest;
        perform calibrate : Calibrate;
    }
    part def DisplayInterface {
        attribute displayType : String;
        port resultIn : DisplayPort;
        port powerIn : PowerPort;
        perform displayResult : DisplayResult;
    }
    part def Biosensor {
        attribute deviceSerialNumber : String;
        attribute firmwareVersion : String;
        attribute measurementDuration :> ISQ::duration;
        attribute measurementError : Real;
        attribute accuracyTarget : Real;
        attribute batteryLifeTarget :> ISQ::duration;
        port externalSamplePort : SamplePort;
        port externalCommandPort : CommandPort;
        part battery : Battery;
        part pmu : PowerManagementUnit;
        part samplePrep : SamplePreparationUnit;
        part biorecognition : BiorecognitionLayer;
        part transducer : Transducer;
        part amplifier : SignalAmplifier;
        part adc : AnalogToDigitalConverter;
        part processor : DataProcessor;
        part display : DisplayInterface;
        connect battery.powerOut to pmu.powerIn;
        connect pmu.powerOut1 to samplePrep.powerIn;
        connect pmu.powerOut2 to biorecognition.powerIn;
        connect pmu.powerOut3 to transducer.powerIn;
        connect pmu.powerOut4 to amplifier.powerIn;
        connect pmu.powerOut5 to adc.powerIn;
        connect pmu.powerOut6 to processor.powerIn;
        connect pmu.powerOut7 to display.powerIn;
        connect externalSamplePort to samplePrep.sampleIn;
        connect samplePrep.preparedSampleOut to biorecognition.preparedSampleIn;
        connect biorecognition.boundSampleOut to transducer.boundSampleIn;
        connect transducer.rawSignalOut to amplifier.rawSignalIn;
        connect amplifier.amplifiedSignalOut to adc.amplifiedSignalIn;
        connect adc.digitalSignalOut to processor.digitalSignalIn;
        connect processor.resultOut to display.resultIn;
        connect externalCommandPort to processor.commandInput;
        exhibit state biosensorStates : BiosensorStates;
    }

    requirement def AccuracyRequirement {
        doc /* The biosensor shall provide concentration measurements with error less than the specified maximum. */
        attribute maxErrorPercent : Real;
        subject biosensor : Biosensor;
    }
    requirement def ResponseTimeRequirement {
        doc /* A single measurement shall complete within the specified maximum response time. */
        attribute maxResponseTime :> ISQ::duration;
        subject biosensor : Biosensor;
    }
    requirement def BatteryLifeRequirement {
        doc /* The battery shall support at least the specified minimum duration of continuous operation. */
        attribute minBatteryLife :> ISQ::duration;
        subject battery : Battery;
    }

    part biosensorDevice : Biosensor {
        attribute deviceSerialNumber = "BIO-2024-001";
        attribute firmwareVersion = "v2.1.0";
        attribute measurementDuration = 25 [s];
        attribute measurementError = 2.0;
        attribute accuracyTarget = 2.0;
        attribute batteryLifeTarget = 8 [h];

        part battery : Battery {
            attribute capacity = 115200 [J];
            attribute currentCharge = 115200 [J];
            attribute nominalVoltage = 3.7 [V];
            attribute batteryLife = 10 [h];
        }
        part pmu : PowerManagementUnit {
            attribute efficiency = 0.92;
        }
        part samplePrep : SamplePreparationUnit;
        part biorecognition : BiorecognitionLayer {
            attribute targetMolecule = "Glucose";
        }
        part transducer : Transducer {
            attribute sensitivity = 0.001 [V];
        }
        part amplifier : SignalAmplifier {
            attribute gain = 1000.0;
        }
        part adc : AnalogToDigitalConverter {
            attribute resolutionBits = 16;
            attribute samplingRate = 1000 [Hz];
        }
        part processor : DataProcessor {
            attribute calibrationCurve = "linear_2point";
        }
        part display : DisplayInterface {
            attribute displayType = "LCD";
        }
    }

    requirement accuracyReq : AccuracyRequirement {
        maxErrorPercent = 5.0;
        subject biosensor = biosensorDevice;
    }
    requirement responseTimeReq : ResponseTimeRequirement {
        maxResponseTime = 30 [s];
        subject biosensor = biosensorDevice;
    }
    requirement batteryLifeReq : BatteryLifeRequirement {
        minBatteryLife = 8 [h];
        subject battery = biosensorDevice.battery;
    }
}
