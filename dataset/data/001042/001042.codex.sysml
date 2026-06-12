package EnergyDispersiveXRaySpectroscopy;

import ScalarValues::*;
import SI::*;

attribute def ElectricPotential_V :> Real {
    unit = "V";
}

attribute def ElectricCurrent_uA :> Real {
    unit = "uA";
}

attribute def Energy_keV :> Real {
    unit = "keV";
}

attribute def CountRate_cps :> Real {
    unit = "count/s";
}

attribute def Time_s :> Real {
    unit = "s";
}

attribute def Temperature_K :> Real {
    unit = "K";
}

attribute def Pressure_Pa :> Real {
    unit = "Pa";
}

attribute def Resolution_eV :> Real {
    unit = "eV";
}

attribute def Length_mm :> Real {
    unit = "mm";
}

attribute def MassFraction_percent :> Real {
    unit = "%";
}

enum def AcquisitionMode {
    snapshot;
    pointAnalysis;
    lineScan;
    areaMap;
}

enum def SystemState {
    off;
    standby;
    vacuumReady;
    detectorCooling;
    calibrated;
    acquiring;
    processing;
    reporting;
    fault;
}

item def ElectronBeam {
    attribute acceleratingVoltage : ElectricPotential_V;
    attribute probeCurrent : ElectricCurrent_uA;
    attribute spotDiameter : Length_mm;
}

item def XRayPhoton {
    attribute energy : Energy_keV;
    attribute arrivalTime : Time_s;
}

item def XRaySpectrum {
    attribute channelCount : Integer;
    attribute minimumEnergy : Energy_keV;
    attribute maximumEnergy : Energy_keV;
    attribute liveTime : Time_s;
    attribute deadTimeFraction : Real;
    attribute totalCounts : Integer;
}

item def ElementIdentification {
    attribute atomicNumber : Integer;
    attribute symbol : String;
    attribute lineEnergy : Energy_keV;
    attribute netPeakCounts : Integer;
    attribute confidence : Real;
}

item def QuantifiedComposition {
    attribute elementSymbol : String;
    attribute massFraction : MassFraction_percent;
    attribute atomicFraction : MassFraction_percent;
    attribute uncertainty : MassFraction_percent;
}

item def AnalysisReport {
    attribute reportId : String;
    attribute acquisitionMode : AcquisitionMode;
    attribute analyzedAreaWidth : Length_mm;
    attribute analyzedAreaHeight : Length_mm;
    attribute acquisitionTime : Time_s;
    item spectrum : XRaySpectrum;
    item identifiedElements[1..*] : ElementIdentification;
    item composition[1..*] : QuantifiedComposition;
}

port def BeamPort {
    out beam : ElectronBeam;
}

port def XRayEmissionPort {
    out photons : XRayPhoton;
}

port def XRayDetectionPort {
    in photons : XRayPhoton;
}

port def SpectrumPort {
    out spectrum : XRaySpectrum;
}

port def ReportPort {
    out report : AnalysisReport;
}

port def VacuumPort {
    in chamberPressure : Pressure_Pa;
}

port def ThermalPort {
    in temperature : Temperature_K;
}

port def ControlPort {
    in command : String;
    out status : SystemState;
}

interface def BeamIrradiation {
    end source : BeamPort;
    end target : BeamPort;
}

interface def XRayCollection {
    end emitter : XRayEmissionPort;
    end receiver : XRayDetectionPort;
}

interface def SpectrumTransfer {
    end producer : SpectrumPort;
    end consumer : SpectrumPort;
}

part def ElectronColumn {
    attribute acceleratingVoltage : ElectricPotential_V = 20.0;
    attribute probeCurrent : ElectricCurrent_uA = 1.0;
    attribute workingDistance : Length_mm = 10.0;
    port beamOut : BeamPort;
}

part def SampleStage {
    attribute xPosition : Length_mm;
    attribute yPosition : Length_mm;
    attribute zPosition : Length_mm;
    attribute tiltAngle_deg : Real;
    port beamIn : BeamPort;
    port xrayOut : XRayEmissionPort;
}

part def VacuumChamber {
    attribute chamberPressure : Pressure_Pa;
    attribute maximumOperatingPressure : Pressure_Pa = 0.1;
    port vacuumStatus : VacuumPort;
}

part def SiliconDriftDetector {
    attribute activeArea : Length_mm = 30.0;
    attribute energyResolutionAtMnKa : Resolution_eV = 129.0;
    attribute detectorTemperature : Temperature_K = 240.0;
    attribute maximumInputCountRate : CountRate_cps = 1000000.0;
    port xrayIn : XRayDetectionPort;
    port spectrumOut : SpectrumPort;
    port thermalIn : ThermalPort;
}

part def PulseProcessor {
    attribute shapingTime : Time_s = 0.000001;
    attribute lowerEnergyThreshold : Energy_keV = 0.1;
    attribute upperEnergyThreshold : Energy_keV = 40.0;
    port spectrumIn : SpectrumPort;
    port spectrumOut : SpectrumPort;
}

part def CalibrationReference {
    attribute manganeseKaEnergy : Energy_keV = 5.89875;
    attribute copperKaEnergy : Energy_keV = 8.04778;
    attribute zeroOffset : Energy_keV = 0.0;
}

part def SpectrumAnalyzer {
    attribute backgroundFitOrder : Integer = 5;
    attribute minimumPeakConfidence : Real = 0.95;
    port spectrumIn : SpectrumPort;
    port reportOut : ReportPort;
}

part def OperatorConsole {
    port control : ControlPort;
    port reportIn : ReportPort;
}

action def EvacuateChamber {
    in targetPressure : Pressure_Pa;
    out achievedPressure : Pressure_Pa;
}

action def CoolDetector {
    in targetTemperature : Temperature_K;
    out stabilizedTemperature : Temperature_K;
}

action def CalibrateEnergyScale {
    in reference : CalibrationReference;
    in measuredSpectrum : XRaySpectrum;
    out calibrationAccepted : Boolean;
}

action def AcquireSpectrum {
    in beam : ElectronBeam;
    in mode : AcquisitionMode;
    in liveTime : Time_s;
    out spectrum : XRaySpectrum;
}

action def IdentifyCharacteristicPeaks {
    in spectrum : XRaySpectrum;
    out elements[1..*] : ElementIdentification;
}

action def QuantifyComposition {
    in spectrum : XRaySpectrum;
    in elements[1..*] : ElementIdentification;
    out composition[1..*] : QuantifiedComposition;
}

action def GenerateAnalysisReport {
    in spectrum : XRaySpectrum;
    in elements[1..*] : ElementIdentification;
    in composition[1..*] : QuantifiedComposition;
    out report : AnalysisReport;
}

state def EDSAcquisitionStateMachine {
    state off;
    state standby;
    state vacuumReady;
    state detectorCooling;
    state calibrated;
    state acquiring;
    state processing;
    state reporting;
    state fault;

    transition initial then off;
    transition off then standby accept powerOn;
    transition standby then vacuumReady accept chamberEvacuated;
    transition vacuumReady then detectorCooling accept detectorCoolCommand;
    transition detectorCooling then calibrated accept detectorStable;
    transition calibrated then acquiring accept startAcquisition;
    transition acquiring then processing accept liveTimeComplete;
    transition processing then reporting accept analysisComplete;
    transition reporting then calibrated accept reportDelivered;
    transition calibrated then standby accept shutdownBeam;
    transition standby then off accept powerOff;

    transition standby then fault accept vacuumFailure;
    transition detectorCooling then fault accept temperatureFault;
    transition acquiring then fault accept overloadCountRate;
    transition processing then fault accept processingFailure;
    transition fault then standby accept reset;
}

part def EnergyDispersiveXRaySpectrometer {
    attribute primaryFunction : String =
        "Measure characteristic X-ray photon energies emitted from an electron-excited sample and convert the spectrum into elemental identification and quantified composition.";

    attribute supportedMinimumEnergy : Energy_keV = 0.1;
    attribute supportedMaximumEnergy : Energy_keV = 40.0;
    attribute nominalResolutionAtMnKa : Resolution_eV = 129.0;
    attribute maximumLiveTime : Time_s = 3600.0;
    attribute nominalWorkingDistance : Length_mm = 10.0;
    attribute state : SystemState = SystemState::off;

    part electronColumn : ElectronColumn;
    part sampleStage : SampleStage;
    part chamber : VacuumChamber;
    part detector : SiliconDriftDetector;
    part pulseProcessor : PulseProcessor;
    part calibrationReference : CalibrationReference;
    part analyzer : SpectrumAnalyzer;
    part console : OperatorConsole;

    port control : ControlPort;
    port reportOut : ReportPort;

    connect electronColumn.beamOut to sampleStage.beamIn;
    connect sampleStage.xrayOut to detector.xrayIn;
    connect detector.spectrumOut to pulseProcessor.spectrumIn;
    connect pulseProcessor.spectrumOut to analyzer.spectrumIn;
    connect analyzer.reportOut to console.reportIn;
    connect analyzer.reportOut to reportOut;
    connect console.control to control;

    perform action EvacuateChamber {
        in targetPressure = chamber.maximumOperatingPressure;
        out achievedPressure = chamber.chamberPressure;
    }

    perform action CoolDetector {
        in targetTemperature = detector.detectorTemperature;
        out stabilizedTemperature = detector.detectorTemperature;
    }

    perform action CalibrateEnergyScale {
        in reference = calibrationReference;
        out calibrationAccepted;
    }

    perform action AcquireSpectrum {
        in mode = AcquisitionMode::pointAnalysis;
        in liveTime = 60.0;
        out spectrum;
    }

    perform action IdentifyCharacteristicPeaks;
    perform action QuantifyComposition;
    perform action GenerateAnalysisReport;

    exhibit stateMachine : EDSAcquisitionStateMachine;
}

requirement def PrimaryFunctionRequirement {
    subject eds : EnergyDispersiveXRaySpectrometer;

    require constraint {
        eds.supportedMinimumEnergy <= 0.1 and
        eds.supportedMaximumEnergy >= 20.0
    }
}

requirement def EnergyResolutionRequirement {
    subject detector : SiliconDriftDetector;

    require constraint {
        detector.energyResolutionAtMnKa <= 135.0
    }
}

requirement def VacuumReadinessRequirement {
    subject chamber : VacuumChamber;

    require constraint {
        chamber.chamberPressure <= chamber.maximumOperatingPressure
    }
}

requirement def DetectorThermalStabilityRequirement {
    subject detector : SiliconDriftDetector;

    require constraint {
        detector.detectorTemperature >= 220.0 and
        detector.detectorTemperature <= 260.0
    }
}

requirement def SpectrumAcquisitionRequirement {
    subject eds : EnergyDispersiveXRaySpectrometer;

    require constraint {
        eds.maximumLiveTime >= 1.0 and
        eds.maximumLiveTime <= 3600.0
    }
}

requirement def ElementalAnalysisRequirement {
    subject analyzer : SpectrumAnalyzer;

    require constraint {
        analyzer.minimumPeakConfidence >= 0.90
    }
}

part edsSystem : EnergyDispersiveXRaySpectrometer;

satisfy PrimaryFunctionRequirement by edsSystem;
satisfy EnergyResolutionRequirement by edsSystem.detector;
satisfy VacuumReadinessRequirement by edsSystem.chamber;
satisfy DetectorThermalStabilityRequirement by edsSystem.detector;
satisfy SpectrumAcquisitionRequirement by edsSystem;
satisfy ElementalAnalysisRequirement by edsSystem.analyzer;

end package EnergyDispersiveXRaySpectroscopy;