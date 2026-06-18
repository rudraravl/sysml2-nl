package EnergyDispersiveXRaySpectroscopySystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def PhotonEnergy :> ISQ::energy {
        :>> unit = SI::electronvolt;
    }

    attribute def XRayEnergy :> PhotonEnergy {
        :>> unit = SI::kiloelectronvolt;
    }

    attribute def BeamEnergy :> PhotonEnergy {
        :>> unit = SI::kiloelectronvolt;
    }

    attribute def ElectricPotential :> ISQ::electricPotential {
        :>> unit = SI::kilovolt;
    }

    attribute def ElectricCurrent :> ISQ::electricCurrent {
        :>> unit = SI::microampere;
    }

    attribute def CountRate {
        :>> unit = "count/s";
    }

    attribute def Counts {
        :>> unit = "count";
    }

    attribute def TimeDuration :> ISQ::time {
        :>> unit = SI::second;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        :>> unit = SI::kelvin;
    }

    attribute def MassFraction {
        :>> unit = "wt%";
    }

    attribute def AtomicNumber {
        :>> unit = "1";
    }

    attribute def ChannelIndex {
        :>> unit = "1";
    }

    attribute def EnergyResolution :> PhotonEnergy {
        :>> unit = SI::electronvolt;
    }

    attribute def VacuumPressure :> ISQ::pressure {
        :>> unit = SI::pascal;
    }

    attribute def SolidAngle {
        :>> unit = SI::steradian;
    }

    attribute def SignalVoltage :> ISQ::electricPotential {
        :>> unit = SI::volt;
    }

    attribute def DigitalWord {
        :>> unit = "1";
    }

    item def ElectronBeam {
        attribute acceleratingVoltage : ElectricPotential;
        attribute beamCurrent : ElectricCurrent;
        attribute beamEnergy : BeamEnergy;
        attribute spotDiameter {
            :>> unit = SI::nanometre;
        }
    }

    item def SampleMaterial {
        attribute name : String;
        attribute averageAtomicNumber : AtomicNumber;
        attribute electricalConductivity {
            :>> unit = "S/m";
        }
    }

    item def ExcitedSampleVolume {
        attribute material : SampleMaterial;
        attribute interactionDepth {
            :>> unit = SI::micrometre;
        }
        attribute interactionDiameter {
            :>> unit = SI::micrometre;
        }
    }

    item def CharacteristicXRayPhoton {
        attribute energy : XRayEnergy;
        attribute sourceElementSymbol : String;
        attribute lineFamily : String;
    }

    item def BremsstrahlungPhoton {
        attribute energy : XRayEnergy;
    }

    item def XRayPhotonStream {
        attribute totalCountRate : CountRate;
        attribute characteristicFraction {
            :>> unit = "1";
        }
        item photons : CharacteristicXRayPhoton[0..*];
        item continuum : BremsstrahlungPhoton[0..*];
    }

    item def ChargePulse {
        attribute amplitude : SignalVoltage;
        attribute riseTime : TimeDuration;
        attribute proportionalEnergy : XRayEnergy;
    }

    item def ShapedPulse {
        attribute peakAmplitude : SignalVoltage;
        attribute shapingTime : TimeDuration;
        attribute equivalentEnergy : XRayEnergy;
    }

    item def DigitalPulse {
        attribute channel : ChannelIndex;
        attribute energyEstimate : XRayEnergy;
        attribute digitizedAmplitude : DigitalWord;
        attribute timestamp : TimeDuration;
    }

    item def SpectrumChannel {
        attribute channel : ChannelIndex;
        attribute centerEnergy : XRayEnergy;
        attribute count : Counts;
    }

    item def EnergySpectrum {
        attribute acquisitionLiveTime : TimeDuration;
        attribute acquisitionRealTime : TimeDuration;
        attribute energyRangeMinimum : XRayEnergy;
        attribute energyRangeMaximum : XRayEnergy;
        attribute channelWidth : XRayEnergy;
        item channels : SpectrumChannel[2048];
    }

    item def ElementIdentification {
        attribute elementSymbol : String;
        attribute atomicNumber : AtomicNumber;
        attribute detectedLineFamily : String;
        attribute peakEnergy : XRayEnergy;
        attribute netPeakCounts : Counts;
        attribute confidence {
            :>> unit = "1";
        }
    }

    item def QuantifiedElement {
        attribute elementSymbol : String;
        attribute massFraction : MassFraction;
        attribute uncertainty : MassFraction;
    }

    item def CompositionReport {
        attribute sampleName : String;
        attribute generatedAt : String;
        attribute normalizedTotal : MassFraction;
        item detectedElements : ElementIdentification[0..*];
        item quantifiedComposition : QuantifiedElement[0..*];
    }

    item def CoolingCommand {
        attribute targetTemperature : Temperature;
    }

    item def DetectorHealth {
        attribute detectorTemperature : Temperature;
        attribute leakageCurrent : ElectricCurrent;
        attribute isReady : Boolean;
    }

    item def AcquisitionCommand {
        attribute sampleName : String;
        attribute requestedLiveTime : TimeDuration;
        attribute minimumBeamVoltage : ElectricPotential;
        attribute maximumBeamVoltage : ElectricPotential;
        attribute enableQuantification : Boolean;
    }

    item def OperatorRequest {
        attribute requestName : String;
        attribute sampleName : String;
    }

    item def StatusMessage {
        attribute operatingState : String;
        attribute message : String;
        attribute readyForAcquisition : Boolean;
    }

    port def ElectronBeamPort {
        out item beam : ElectronBeam;
    }

    port def SampleBeamPort {
        in item beam : ElectronBeam;
    }

    port def XRayEmissionPort {
        out item xrays : XRayPhotonStream;
    }

    port def XRayCollectionPort {
        in item xrays : XRayPhotonStream;
    }

    port def ChargePulsePort {
        out item pulse : ChargePulse;
    }

    port def ChargePulseInputPort {
        in item pulse : ChargePulse;
    }

    port def ShapedPulsePort {
        out item pulse : ShapedPulse;
    }

    port def ShapedPulseInputPort {
        in item pulse : ShapedPulse;
    }

    port def DigitalPulsePort {
        out item pulse : DigitalPulse;
    }

    port def DigitalPulseInputPort {
        in item pulse : DigitalPulse;
    }

    port def SpectrumPort {
        out item spectrum : EnergySpectrum;
    }

    port def SpectrumInputPort {
        in item spectrum : EnergySpectrum;
    }

    port def ReportPort {
        out item report : CompositionReport;
    }

    port def ReportInputPort {
        in item report : CompositionReport;
    }

    port def CoolingControlPort {
        in item command : CoolingCommand;
        out item health : DetectorHealth;
    }

    port def AcquisitionControlPort {
        in item command : AcquisitionCommand;
        out item status : StatusMessage;
    }

    port def OperatorInterfacePort {
        in item request : OperatorRequest;
        out item report : CompositionReport;
        out item status : StatusMessage;
    }

    part def ElectronColumn {
        attribute acceleratingVoltage : ElectricPotential = 20 [SI::kilovolt];
        attribute beamCurrent : ElectricCurrent = 1.0 [SI::microampere];
        attribute beamEnergy : BeamEnergy = 20 [SI::kiloelectronvolt];
        attribute spotDiameter {
            :>> unit = SI::nanometre;
        } = 50 [SI::nanometre];

        port beamOut : ElectronBeamPort;

        action def GeneratePrimaryElectronBeam {
            out item producedBeam : ElectronBeam;
        }

        perform action generateBeam : GeneratePrimaryElectronBeam {
            out producedBeam = beamOut.beam;
        }
    }

    part def SampleStage {
        attribute sampleName : String;
        attribute chamberPressure : VacuumPressure = 0.01 [SI::pascal];
        attribute tiltAngle {
            :>> unit = SI::degree;
        } = 0 [SI::degree];
        attribute workingDistance {
            :>> unit = SI::millimetre;
        } = 10 [SI::millimetre];

        part sampleMaterial : SampleMaterial;
        port beamIn : SampleBeamPort;
        port xrayOut : XRayEmissionPort;

        action def ExciteAtomsAndEmitXrays {
            in item incidentBeam : ElectronBeam;
            out item emittedXrays : XRayPhotonStream;
            out item excitedVolume : ExcitedSampleVolume;
        }

        perform action xrayGeneration : ExciteAtomsAndEmitXrays {
            in incidentBeam = beamIn.beam;
            out emittedXrays = xrayOut.xrays;
        }
    }

    part def XRayDetector {
        attribute detectorType : String = "silicon drift detector";
        attribute activeArea {
            :>> unit = SI::millimetre * SI::millimetre;
        } = 30 [SI::millimetre * SI::millimetre];
        attribute detectorTemperature : Temperature = 123 [SI::kelvin];
        attribute energyResolutionAtMnKa : EnergyResolution = 125 [SI::electronvolt];
        attribute collectionSolidAngle : SolidAngle = 0.12 [SI::steradian];
        attribute berylliumWindowThickness {
            :>> unit = SI::micrometre;
        } = 8 [SI::micrometre];
        attribute maximumInputCountRate : CountRate = 100000 [count/s];

        port xrayIn : XRayCollectionPort;
        port chargePulseOut : ChargePulsePort;
        port coolingControl : CoolingControlPort;

        action def ConvertPhotonEnergyToChargePulse {
            in item incidentXrays : XRayPhotonStream;
            out item detectorPulses : ChargePulse;
        }

        state def DetectorOperationalState {
            entry; then off;

            state off;
            state cooling;
            state stabilized;
            state detecting;
            state fault;

            transition off_to_cooling
                first off
                accept CoolingCommand
                then cooling;

            transition cooling_to_stabilized
                first cooling
                if detectorTemperature <= 130 [SI::kelvin]
                then stabilized;

            transition stabilized_to_detecting
                first stabilized
                accept XRayPhotonStream
                then detecting;

            transition detecting_to_stabilized
                first detecting
                if xrayIn.xrays.totalCountRate == 0 [count/s]
                then stabilized;

            transition any_to_fault
                first off, cooling, stabilized, detecting
                if detectorTemperature > 170 [SI::kelvin]
                then fault;
        }

        perform action detectPhotons : ConvertPhotonEnergyToChargePulse {
            in incidentXrays = xrayIn.xrays;
            out detectorPulses = chargePulseOut.pulse;
        }

        perform state detectorState : DetectorOperationalState;
    }

    part def Preamplifier {
        attribute gain {
            :>> unit = "V/C";
        } = 1.0e12 [V/C];
        attribute noiseRms : SignalVoltage = 0.001 [SI::volt];

        port pulseIn : ChargePulseInputPort;
        port pulseOut : ShapedPulsePort;

        action def AmplifyAndShapePulse {
            in item rawPulse : ChargePulse;
            out item shapedPulse : ShapedPulse;
        }

        perform action pulseShaping : AmplifyAndShapePulse {
            in rawPulse = pulseIn.pulse;
            out shapedPulse = pulseOut.pulse;
        }
    }

    part def DigitalPulseProcessor {
        attribute shapingTime : TimeDuration = 2.0e-6 [SI::second];
        attribute deadTimeFraction {
            :>> unit = "1";
        } = 0.25;
        attribute pileupRejectionEnabled : Boolean = true;
        attribute energyCalibrationOffset : XRayEnergy = 0 [SI::kiloelectronvolt];
        attribute energyCalibrationSlope : XRayEnergy = 0.010 [SI::kiloelectronvolt];

        port shapedPulseIn : ShapedPulseInputPort;
        port digitalPulseOut : DigitalPulsePort;

        action def DigitizePulseHeight {
            in item shapedPulse : ShapedPulse;
            out item digitalPulse : DigitalPulse;
        }

        action def RejectPileup {
            in item candidatePulse : DigitalPulse;
            out item acceptedPulse : DigitalPulse;
        }

        perform action digitize : DigitizePulseHeight {
            in shapedPulse = shapedPulseIn.pulse;
            out digitalPulse = digitalPulseOut.pulse;
        }
    }

    part def MultichannelAnalyzer {
        attribute numberOfChannels : Integer = 2048;
        attribute minimumEnergy : XRayEnergy = 0 [SI::kiloelectronvolt];
        attribute maximumEnergy : XRayEnergy = 20 [SI::kiloelectronvolt];
        attribute liveTime : TimeDuration = 60 [SI::second];
        attribute realTime : TimeDuration = 80 [SI::second];

        port digitalPulseIn : DigitalPulseInputPort;
        port spectrumOut : SpectrumPort;

        action def AccumulateEnergyHistogram {
            in item pulse : DigitalPulse;
            out item spectrum : EnergySpectrum;
        }

        action def ApplyDeadTimeCorrection {
            in item rawSpectrum : EnergySpectrum;
            out item correctedSpectrum : EnergySpectrum;
        }

        state def AcquisitionState {
            entry; then idle;

            state idle;
            state acquiring;
            state correcting;
            state complete;

            transition idle_to_acquiring
                first idle
                accept AcquisitionCommand
                then acquiring;

            transition acquiring_to_correcting
                first acquiring
                if liveTime >= 60 [SI::second]
                then correcting;

            transition correcting_to_complete
                first correcting
                then complete;

            transition complete_to_idle
                first complete
                accept AcquisitionCommand
                then acquiring;
        }

        perform action histogramming : AccumulateEnergyHistogram {
            in pulse = digitalPulseIn.pulse;
            out spectrum = spectrumOut.spectrum;
        }

        perform state acquisitionState : AcquisitionState;
    }

    part def SpectrumAnalyzer {
        attribute backgroundModel : String = "SNIP";
        attribute peakFitModel : String = "Gaussian with low-energy tail";
        attribute minimumPeakConfidence {
            :>> unit = "1";
        } = 0.95;
        attribute quantificationMethod : String = "standardless ZAF correction";

        port spectrumIn : SpectrumInputPort;
        port reportOut : ReportPort;

        action def CalibrateEnergyAxis {
            in item measuredSpectrum : EnergySpectrum;
            out item calibratedSpectrum : EnergySpectrum;
        }

        action def SubtractContinuumBackground {
            in item calibratedSpectrum : EnergySpectrum;
            out item backgroundCorrectedSpectrum : EnergySpectrum;
        }

        action def IdentifyElementalPeaks {
            in item backgroundCorrectedSpectrum : EnergySpectrum;
            out item identifications : ElementIdentification;
        }

        action def QuantifyComposition {
            in item identifications : ElementIdentification;
            in item calibratedSpectrum : EnergySpectrum;
            out item report : CompositionReport;
        }

        action def AnalyzeSpectrum {
            in item spectrum : EnergySpectrum;
            out item report : CompositionReport;

            first start;
            then calibrate;
            then subtractBackground;
            then identifyPeaks;
            then quantify;
            then done;

            action calibrate : CalibrateEnergyAxis;
            action subtractBackground : SubtractContinuumBackground;
            action identifyPeaks : IdentifyElementalPeaks;
            action quantify : QuantifyComposition;
        }

        perform action analyze : AnalyzeSpectrum {
            in spectrum = spectrumIn.spectrum;
            out report = reportOut.report;
        }
    }

    part def OperatorConsole {
        attribute displayResolution : String = "1920x1080";
        attribute supportsLiveSpectrumDisplay : Boolean = true;

        port operatorPort : OperatorInterfacePort;
        port commandOut : AcquisitionControlPort;
        port reportIn : ReportInputPort;

        action def RequestElementalAnalysis {
            out item command : AcquisitionCommand;
        }

        action def DisplaySpectrumAndComposition {
            in item report : CompositionReport;
            out item status : StatusMessage;
        }

        perform action requestAnalysis : RequestElementalAnalysis {
            out command = commandOut.command;
        }

        perform action displayResults : DisplaySpectrumAndComposition {
            in report = reportIn.report;
            out status = operatorPort.status;
        }
    }

    part def EDSController {
        attribute systemName : String = "Energy-dispersive X-ray spectroscopy system";
        attribute primaryFunction : String = "Measure the energies and counts of X-ray photons emitted from an electron-excited sample to identify and quantify its elemental composition.";
        attribute defaultLiveTime : TimeDuration = 60 [SI::second];
        attribute detectorReady : Boolean;
        attribute acquisitionEnabled : Boolean;

        port acquisitionControl : AcquisitionControlPort;
        port detectorCooling : CoolingControlPort;
        port reportOut : ReportPort;

        action def InitializeEDS {
            out item coolingCommand : CoolingCommand;
            out item status : StatusMessage;
        }

        action def ConfigureAcquisition {
            in item operatorCommand : AcquisitionCommand;
            out item status : StatusMessage;
        }

        action def CoordinateMeasurement {
            in item operatorCommand : AcquisitionCommand;
            out item status : StatusMessage;
        }

        state def SystemOperatingState {
            entry; then poweredOff;

            state poweredOff;
            state initializing;
            state ready;
            state acquiringSpectrum;
            state analyzingSpectrum;
            state reporting;
            state safeShutdown;
            state fault;

            transition powerOn
                first poweredOff
                accept OperatorRequest
                then initializing;

            transition initialized
                first initializing
                if detectorReady == true
                then ready;

            transition startAcquisition
                first ready
                accept AcquisitionCommand
                then acquiringSpectrum;

            transition acquisitionFinished
                first acquiringSpectrum
                then analyzingSpectrum;

            transition analysisFinished
                first analyzingSpectrum
                then reporting;

            transition reportDelivered
                first reporting
                then ready;

            transition shutdown
                first ready
                accept OperatorRequest
                then safeShutdown;

            transition faultDetected
                first initializing, ready, acquiringSpectrum, analyzingSpectrum, reporting
                if detectorReady == false
                then fault;
        }

        perform action initialize : InitializeEDS {
            out coolingCommand = detectorCooling.command;
            out status = acquisitionControl.status;
        }

        perform action coordinate : CoordinateMeasurement {
            in operatorCommand = acquisitionControl.command;
            out status = acquisitionControl.status;
        }

        perform state operatingState : SystemOperatingState;
    }

    part def EnergyDispersiveXRaySpectroscopyInstrument {
        attribute instrumentName : String = "EDS elemental microanalysis instrument";
        attribute highLevelPrimaryFunction : String = "Acquire an energy spectrum of characteristic X-rays emitted by a sample and transform that spectrum into elemental identification and composition information.";
        attribute supportedEnergyMinimum : XRayEnergy = 0.1 [SI::kiloelectronvolt];
        attribute supportedEnergyMaximum : XRayEnergy = 20 [SI::kiloelectronvolt];
        attribute nominalEnergyResolution : EnergyResolution = 125 [SI::electronvolt];
        attribute nominalLiveTime : TimeDuration = 60 [SI::second];

        part electronColumn : ElectronColumn;
        part sampleStage : SampleStage;
        part detector : XRayDetector;
        part preamplifier : Preamplifier;
        part pulseProcessor : DigitalPulseProcessor;
        part multichannelAnalyzer : MultichannelAnalyzer;
        part spectrumAnalyzer : SpectrumAnalyzer;
        part controller : EDSController;
        part operatorConsole : OperatorConsole;

        port operatorInterface : OperatorInterfacePort;

        connect electronColumn.beamOut to sampleStage.beamIn;
        connect sampleStage.xrayOut to detector.xrayIn;
        connect detector.chargePulseOut to preamplifier.pulseIn;
        connect preamplifier.pulseOut to pulseProcessor.shapedPulseIn;
        connect pulseProcessor.digitalPulseOut to multichannelAnalyzer.digitalPulseIn;
        connect multichannelAnalyzer.spectrumOut to spectrumAnalyzer.spectrumIn;
        connect spectrumAnalyzer.reportOut to operatorConsole.reportIn;
        connect spectrumAnalyzer.reportOut to controller.reportOut;
        connect operatorConsole.commandOut to controller.acquisitionControl;
        connect controller.detectorCooling to detector.coolingControl;
        connect operatorInterface to operatorConsole.operatorPort;

        action def PerformElementalMicroanalysis {
            in item request : OperatorRequest;
            out item report : CompositionReport;
            out item status : StatusMessage;

            first receiveRequest;
            then initializeDetector;
            then generateElectronBeam;
            then exciteSample;
            then detectXrays;
            then processPulses;
            then accumulateSpectrum;
            then analyzeSpectrum;
            then publishReport;
            then done;

            action receiveRequest;
            action initializeDetector : EDSController::InitializeEDS;
            action generateElectronBeam : ElectronColumn::GeneratePrimaryElectronBeam;
            action exciteSample : SampleStage::ExciteAtomsAndEmitXrays;
            action detectXrays : XRayDetector::ConvertPhotonEnergyToChargePulse;
            action processPulses : DigitalPulseProcessor::DigitizePulseHeight;
            action accumulateSpectrum : MultichannelAnalyzer::AccumulateEnergyHistogram;
            action analyzeSpectrum : SpectrumAnalyzer::AnalyzeSpectrum;
            action publishReport;
        }

        perform action primaryFunctionBehavior : PerformElementalMicroanalysis {
            in request = operatorInterface.request;
            out report = operatorInterface.report;
            out status = operatorInterface.status;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject eds : EnergyDispersiveXRaySpectroscopyInstrument;

        require constraint {
            eds.highLevelPrimaryFunction == "Acquire an energy spectrum of characteristic X-rays emitted by a sample and transform that spectrum into elemental identification and composition information."
        }
    }

    requirement def EnergyMeasurementRangeRequirement {
        subject eds : EnergyDispersiveXRaySpectroscopyInstrument;

        require constraint {
            eds.supportedEnergyMinimum <= 0.1 [SI::kiloelectronvolt] and
            eds.supportedEnergyMaximum >= 20 [SI::kiloelectronvolt]
        }
    }

    requirement def EnergyResolutionRequirement {
        subject eds : EnergyDispersiveXRaySpectroscopyInstrument;

        require constraint {
            eds.nominalEnergyResolution <= 130 [SI::electronvolt]
        }
    }

    requirement def DetectorCoolingRequirement {
        subject detector : XRayDetector;

        require constraint {
            detector.detectorTemperature <= 130 [SI::kelvin]
        }
    }

    requirement def SpectrumAcquisitionRequirement {
        subject analyzer : MultichannelAnalyzer;

        require constraint {
            analyzer.numberOfChannels >= 2048 and
            analyzer.liveTime >= 10 [SI::second]
        }
    }

    requirement def CountRateRequirement {
        subject detector : XRayDetector;

        require constraint {
            detector.maximumInputCountRate >= 100000 [count/s]
        }
    }

    requirement def ReportContentRequirement {
        subject report : CompositionReport;

        require constraint {
            report.normalizedTotal >= 99 [wt%] and
            report.normalizedTotal <= 101 [wt%]
        }
    }

    part edsSystem : EnergyDispersiveXRaySpectroscopyInstrument;

    requirement primaryFunctionSatisfied : PrimaryFunctionRequirement {
        subject eds = edsSystem;
    }

    requirement energyRangeSatisfied : EnergyMeasurementRangeRequirement {
        subject eds = edsSystem;
    }

    requirement energyResolutionSatisfied : EnergyResolutionRequirement {
        subject eds = edsSystem;
    }

    requirement detectorCoolingSatisfied : DetectorCoolingRequirement {
        subject detector = edsSystem.detector;
    }

    requirement spectrumAcquisitionSatisfied : SpectrumAcquisitionRequirement {
        subject analyzer = edsSystem.multichannelAnalyzer;
    }

    requirement countRateSatisfied : CountRateRequirement {
        subject detector = edsSystem.detector;
    }
}
