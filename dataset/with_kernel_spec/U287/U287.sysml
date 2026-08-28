package LungCounterSystem {
    private import ISQ::*;
    private import ScalarValues::*;

    attribute def CountValue :> Natural;
    attribute def EnergyChannelValue :> Integer;
    attribute def PulseAmplitudeValue :> Real;

    item def GammaPhoton {
        attribute energy : EnergyValue;
    }

    item def ElectricPulse {
        attribute amplitude : PulseAmplitudeValue;
    }

    item def EnergySpectrum {
        attribute channels : EnergyChannelValue[0..*] ordered;
        attribute counts : CountValue[0..*] ordered;
        attribute total : CountValue;
    }

    item def BackgroundSpectrum :> EnergySpectrum;
    item def NetSpectrum :> EnergySpectrum;

    item def CalibrationFactors {
        attribute nuclideNames : String[0..*] ordered;
        attribute energyLines : EnergyValue[0..*] ordered;
        attribute efficiencies : Real[0..*] ordered;
    }

    item def RadioactiveNuclide {
        attribute name : String;
        attribute peakEnergy : EnergyValue;
        attribute activity : ActivityValue;
    }

    item def AnalysisResult {
        attribute totalCounts : CountValue;
        attribute detectedNuclides : RadioactiveNuclide[0..*];
        attribute totalActivity : ActivityValue;
    }

    port def PhotonSourcePort {
        out photon : GammaPhoton;
    }

    port def PhotonSinkPort {
        in photon : GammaPhoton;
    }

    port def PulseSourcePort {
        out pulse : ElectricPulse;
    }

    port def PulseSinkPort {
        in pulse : ElectricPulse;
    }

    port def SpectrumSourcePort {
        out spectrum : EnergySpectrum;
    }

    port def SpectrumSinkPort {
        in spectrum : EnergySpectrum;
    }

    port def ResultSourcePort {
        out result : AnalysisResult;
    }

    port def ResultSinkPort {
        in result : AnalysisResult;
    }

    part def Subject {
        attribute identifier : String;
        port photonEmission : PhotonSourcePort;
    }

    part def LeadShielding {
        attribute wallThickness : LengthValue;
        attribute material : String = "Lead";
    }

    part def PositioningChair {
        attribute height : LengthValue;
        attribute locked : Boolean = false;
    }

    part def ScintillationDetector {
        port photonInput : PhotonSinkPort;
        port pulseOutput : PulseSourcePort;
        attribute detectorId : Integer;
    }

    part def DetectorArray {
        part detectors : ScintillationDetector[4];
        port photonInput : PhotonSinkPort;
        port pulseOutput : PulseSourcePort;
        flow from photonInput to detectors.photonInput;
        flow from detectors.pulseOutput to pulseOutput;
    }

    part def MultiChannelAnalyzer {
        port pulseInput : PulseSinkPort;
        port spectrumOutput : SpectrumSourcePort;
        attribute channelCount : Integer = 1024;
    }

    part def AnalysisComputer {
        port spectrumInput : SpectrumSinkPort;
        port resultOutput : ResultSourcePort;
        attribute calibration : CalibrationFactors;
        attribute storedBackground : BackgroundSpectrum;
    }

    part def DisplayConsole {
        port resultInput : ResultSinkPort;
    }

    action def PositionSubjectAction {
        in subjectId : String;
        out locked : Boolean;
    }

    action def AcquireBackgroundAction {
        in acquisitionTime : TimeValue;
        out background : BackgroundSpectrum;
    }

    action def AcquireSubjectAction {
        in subjectId : String;
        in acquisitionTime : TimeValue;
        out spectrum : EnergySpectrum;
    }

    action def SubtractBackground {
        in raw : EnergySpectrum;
        in bg : BackgroundSpectrum;
        out net : NetSpectrum;
    }

    action def IdentifyPeaks {
        in net : NetSpectrum;
        in cal : CalibrationFactors;
        out nuclides : RadioactiveNuclide[0..*];
    }

    action def CalculateActivity {
        in nuc : RadioactiveNuclide[0..*];
        in cal : CalibrationFactors;
        in acqTime : TimeValue;
        out result : AnalysisResult;
    }

    action def AnalyzeData {
        in spectrum : EnergySpectrum;
        in background : BackgroundSpectrum;
        in calibration : CalibrationFactors;
        in acquisitionTime : TimeValue;
        out result : AnalysisResult;

        action subtract : SubtractBackground {
            in raw = AnalyzeData::spectrum;
            in bg = AnalyzeData::background;
        }

        action identify : IdentifyPeaks {
            in cal = AnalyzeData::calibration;
        }

        flow from subtract.net to identify.net;

        action calculate : CalculateActivity {
            in cal = AnalyzeData::calibration;
            in acqTime = AnalyzeData::acquisitionTime;
            out result = AnalyzeData::result;
        }

        flow from identify.nuclides to calculate.nuc;
    }

    action def ReportResults {
        in result : AnalysisResult;
    }

    action def LungCounterOperation {
        in subjectId : String;
        in acquisitionTime : TimeValue;
        in calibration : CalibrationFactors;
        out result : AnalysisResult;

        action position : PositionSubjectAction {
            in subjectId = LungCounterOperation::subjectId;
        }

        action acquireBg : AcquireBackgroundAction {
            in acquisitionTime = LungCounterOperation::acquisitionTime;
        }

        action acquireSubj : AcquireSubjectAction {
            in subjectId = LungCounterOperation::subjectId;
            in acquisitionTime = LungCounterOperation::acquisitionTime;
        }

        action analyze : AnalyzeData {
            in calibration = LungCounterOperation::calibration;
            in acquisitionTime = LungCounterOperation::acquisitionTime;
            out result = LungCounterOperation::result;
        }

        flow from acquireBg.background to analyze.background;
        flow from acquireSubj.spectrum to analyze.spectrum;

        action report : ReportResults;

        flow from analyze.result to report.result;
    }

    state machine def LungCounterStateMachine {
        state idle;
        state positioning;
        state backgroundAcquisition;
        state subjectAcquisition;
        state analyzing;
        state reporting;

        transition from idle to positioning;
        transition from positioning to backgroundAcquisition;
        transition from backgroundAcquisition to subjectAcquisition;
        transition from subjectAcquisition to analyzing;
        transition from analyzing to reporting;
        transition from reporting to idle;
    }

    part def LungCounterSystem {
        part shielding : LeadShielding;
        part chair : PositioningChair;
        part subject : Subject;
        part detectorArray : DetectorArray;
        part mca : MultiChannelAnalyzer;
        part computer : AnalysisComputer;
        part console : DisplayConsole;

        attribute acquisitionTime : TimeValue;
        attribute calibration : CalibrationFactors;

        flow from subject.photonEmission to detectorArray.photonInput;
        flow from detectorArray.pulseOutput to mca.pulseInput;
        flow from mca.spectrumOutput to computer.spectrumInput;
        flow from computer.resultOutput to console.resultInput;

        state machine operation : LungCounterStateMachine;
    }

    requirement def GammaDetectionRequirement {
        subject system : LungCounterSystem;
        doc /* The system shall detect and measure gamma-ray-emitting radioactive material in a person's lungs. */;
    }

    requirement def ShieldingRequirement {
        subject shielding : LeadShielding;
        doc /* The system shall use lead shielding to form an enclosure that drastically reduces background radiation from the environment. */;
    }

    requirement def PositioningRequirement {
        subject chair : PositioningChair;
        doc /* The positioning chair shall be adjustable and ensure repeatable positioning of the subject relative to the detectors. */;
    }

    requirement def DetectorArrayRequirement {
        subject detectorArray : DetectorArray;
        doc /* The system shall use an array of four scintillation detectors positioned around the subject's thorax. */;
    }

    requirement def DetectorConversionRequirement {
        subject detector : ScintillationDetector;
        doc /* Each scintillation detector shall convert captured gamma photons into electrical pulses proportional to photon energy. */;
    }

    requirement def MCARequirement {
        subject mca : MultiChannelAnalyzer;
        doc /* The MCA shall sort electrical pulses by energy level and count them to create a detailed energy spectrum. */;
    }

    requirement def BackgroundSubtractionRequirement {
        subject computer : AnalysisComputer;
        doc /* The analysis computer shall subtract a previously measured background radiation spectrum from the subject spectrum. */;
    }

    requirement def PeakIdentificationRequirement {
        subject computer : AnalysisComputer;
        doc /* The analysis computer shall identify characteristic energy peaks in the net spectrum to determine which radioactive nuclides are present. */;
    }

    requirement def ActivityCalculationRequirement {
        subject computer : AnalysisComputer;
        doc /* The analysis computer shall use calibration factors to calculate the precise activity in Becquerels of the identified radioactive materials. */;
    }

    requirement def ReportingRequirement {
        subject console : DisplayConsole;
        doc /* The display console shall report total radiation counts, calculated activity, and a list of the specific radioactive materials detected. */;
    }

    requirement def StateSequenceRequirement {
        subject system : LungCounterSystem;
        doc /* The system shall operate through the states idle, positioning, background acquisition, subject acquisition, analyzing, and reporting before returning to idle. */;
    }
}
