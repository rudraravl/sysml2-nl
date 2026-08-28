package FrequencyDomainSensingUnit {
    private import ScalarValues::*;

    attribute def Frequency :> Real;
    attribute def Power :> Real;
    attribute def Temperature :> Real;
    attribute def Voltage :> Real;
    attribute def Current :> Real;

    attribute def StartCommand;
    attribute def ResetCommand;
    attribute def ErrorSignal;
    attribute def DataReady;
    attribute def AnalysisComplete;
    attribute def TransmitComplete;

    item def AnalogSignal {
        attribute amplitude : Real;
        attribute sampleRate : Frequency;
    }
    item def DigitalBlock {
        attribute samples : Real[*];
    }
    item def FrequencySpectrum {
        attribute frequencies : Frequency[*];
        attribute magnitudes : Real[*];
        attribute phases : Real[*];
    }
    item def AnalysisResult {
        attribute dominantFrequency : Frequency;
        attribute totalPower : Power;
        attribute qualityMetric : Real;
    }

    port def AnalogInputPort {
        in signal : AnalogSignal;
    }
    port def DigitalOutputPort {
        out data : DigitalBlock;
    }
    port def DigitalInputPort {
        in data : DigitalBlock;
    }
    port def ResultOutputPort {
        out result : AnalysisResult;
    }
    port def ResultInputPort {
        in result : AnalysisResult;
    }
    port def PowerInputPort {
        in voltage : Voltage;
        in current : Current;
    }
    port def PowerOutputPort {
        out voltage : Voltage;
        out current : Current;
    }
    port def CommandOutputPort {
        out startCmd : StartCommand;
        out resetCmd : ResetCommand;
    }
    port def CommandInputPort {
        in startCmd : StartCommand;
        in resetCmd : ResetCommand;
        in errorSig : ErrorSignal;
        in dataReady : DataReady;
        in analysisDone : AnalysisComplete;
        in transmitDone : TransmitComplete;
    }
    port def ExternalCommandPort {
        in startCmd : StartCommand;
        in resetCmd : ResetCommand;
        in errorSig : ErrorSignal;
    }

    action def ConditionAndConvert {
        in analog : AnalogSignal;
        out digital : DigitalBlock;
    }
    action def AcquireBlock {
        in input : DigitalBlock;
        out block : DigitalBlock;
    }
    action def ApplyWindow {
        in block : DigitalBlock;
        out windowed : DigitalBlock;
    }
    action def ComputeFFT {
        in windowed : DigitalBlock;
        out spectrum : FrequencySpectrum;
    }
    action def ExtractFeatures {
        in spectrum : FrequencySpectrum;
        out result : AnalysisResult;
    }
    action def RegulatePower {
        in inputVoltage : Voltage;
        out outputVoltage : Voltage;
    }
    action def DSPAnalysisSequence {
        in inputData : DigitalBlock;
        out analysisResult : AnalysisResult;
        first start;
        then action acquire : AcquireBlock {
            in input = inputData;
        }
        then action window : ApplyWindow {
            in block = acquire.block;
        }
        then action fft : ComputeFFT {
            in windowed = window.windowed;
        }
        then action extract : ExtractFeatures {
            in spectrum = fft.spectrum;
        }
        then done;
        bind analysisResult = extract.result;
    }

    state def ControllerStates {
        entry; then idle;
        state idle;
        transition first idle accept StartCommand then ready;
        state ready;
        transition first ready accept StartCommand then acquiring;
        state acquiring;
        transition first acquiring accept DataReady then processing;
        state processing;
        transition first processing accept AnalysisComplete then outputting;
        state outputting;
        transition first outputting accept TransmitComplete then ready;
        state error;
        transition first idle accept ErrorSignal then error;
        transition first ready accept ErrorSignal then error;
        transition first acquiring accept ErrorSignal then error;
        transition first processing accept ErrorSignal then error;
        transition first outputting accept ErrorSignal then error;
        transition first error accept ResetCommand then idle;
    }

    state def DSPStates {
        entry; then idle;
        state idle;
        transition first idle accept StartCommand then acquiring;
        state acquiring;
        transition first acquiring accept DataReady then processing;
        state processing;
        transition first processing accept AnalysisComplete then idle;
        state error;
        transition first idle accept ErrorSignal then error;
        transition first acquiring accept ErrorSignal then error;
        transition first processing accept ErrorSignal then error;
        transition first error accept ResetCommand then idle;
    }

    state def CommStates {
        entry; then idle;
        state idle;
        transition first idle accept StartCommand then transmitting;
        state transmitting;
        transition first transmitting accept TransmitComplete then idle;
        state error;
        transition first idle accept ErrorSignal then error;
        transition first transmitting accept ErrorSignal then error;
        transition first error accept ResetCommand then idle;
    }

    part def AnalogFrontEnd {
        port analogIn : AnalogInputPort;
        port digitalOut : DigitalOutputPort;
        port powerIn : PowerInputPort;
        perform action conditionAndConvert : ConditionAndConvert;
    }

    part def DSP {
        port dataIn : DigitalInputPort;
        port resultsOut : ResultOutputPort;
        port powerIn : PowerInputPort;
        port cmdIn : CommandInputPort;
        perform action dspAnalysis : DSPAnalysisSequence;
        exhibit state dspStates : DSPStates;
    }

    part def CommunicationInterface {
        port resultsIn : ResultInputPort;
        port extOut : ResultOutputPort;
        port powerIn : PowerInputPort;
        port cmdIn : CommandInputPort;
        exhibit state commStates : CommStates;
    }

    part def PowerManagement {
        port extPowerIn : PowerInputPort;
        port regPowerOut : PowerOutputPort;
        perform action regulatePower : RegulatePower;
    }

    part def Controller {
        port extCmd : ExternalCommandPort;
        port cmdOut : CommandOutputPort;
        port powerIn : PowerInputPort;
        exhibit state controllerStates : ControllerStates;
    }

    requirement def AccuracyRequirement {
        doc /* The dominant frequency measurement shall be accurate within plus or minus 0.1 Hz. */
        attribute maxError : Frequency := 0.1;
    }

    requirement def TemperatureRangeRequirement {
        doc /* The unit shall operate over a temperature range of -40 to 85 degrees Celsius. */
        attribute minTemp : Temperature := -40.0;
        attribute maxTemp : Temperature := 85.0;
    }

    requirement def PowerConsumptionRequirement {
        doc /* The unit shall consume less than 500 mW of power. */
        attribute maxPower : Power := 0.5;
    }

    part def FrequencyDomainSensingSystem {
        part afe : AnalogFrontEnd;
        part dsp : DSP;
        part comm : CommunicationInterface;
        part pwr : PowerManagement;
        part ctrl : Controller;

        port extAnalogIn : AnalogInputPort;
        port extResults : ResultOutputPort;
        port extPowerIn : PowerInputPort;
        port extCmd : ExternalCommandPort;

        connect afe.analogIn to this.extAnalogIn;
        connect afe.digitalOut to dsp.dataIn;
        connect dsp.resultsOut to comm.resultsIn;
        connect comm.extOut to this.extResults;
        connect pwr.extPowerIn to this.extPowerIn;
        connect pwr.regPowerOut to afe.powerIn;
        connect pwr.regPowerOut to dsp.powerIn;
        connect pwr.regPowerOut to comm.powerIn;
        connect pwr.regPowerOut to ctrl.powerIn;
        connect ctrl.cmdOut to dsp.cmdIn;
        connect ctrl.cmdOut to comm.cmdIn;
        connect ctrl.extCmd to this.extCmd;

        satisfy AccuracyRequirement by this;
        satisfy TemperatureRangeRequirement by this;
        satisfy PowerConsumptionRequirement by this;
    }

    part sensingUnit : FrequencyDomainSensingSystem;
}
