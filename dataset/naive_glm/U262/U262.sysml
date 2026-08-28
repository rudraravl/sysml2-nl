package DermatologySystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====
    value def LengthNm :> Real { unit "nm"; }
    value def DiameterMm :> Real { unit "mm"; }
    value def TemperatureC :> Real { unit "degC"; }
    value def PowerW :> Real { unit "W"; }
    value def EnergyJ :> Real { unit "J"; }
    value def DurationS :> Real { unit "s"; }
    value def Magnification :> Real { unit "x"; }
    value def ResolutionPx :> Integer { unit "px"; }
    value def ConfidencePct :> Real { unit "%"; }
    value def PressureBar :> Real { unit "bar"; }
    value def SpotSizeMm :> Real { unit "mm"; }

    // ===== Enumerations =====
    enum def RiskClass { benign; suspicious; malignant; }
    enum def OperatingMode { standby; examination; diagnosis; treatmentSelection; laserTherapy; cryotherapy; emergency; }
    enum def TreatmentType { none; laser; cryo; }
    enum def LaserWavelength { nm532; nm585; nm694; nm755; nm1064; }
    enum def IlluminationWavelength { white; polarizedWhite; uv365; nir850; }

    // ===== Items =====
    item def SkinImage {
        attribute resolution : ResolutionPx;
        attribute magnification : Magnification;
        attribute wavelength : IlluminationWavelength;
        attribute capturedAt : String;
    }

    item def DiagnosticReport {
        attribute asymmetryScore : Real;
        attribute borderIrregularity : Real;
        attribute colorVariation : Real;
        attribute diameter : DiameterMm;
        attribute riskClass : RiskClass;
        attribute confidence : ConfidencePct;
        attribute recommendation : String;
    }

    item def TreatmentProtocol {
        attribute treatmentType : TreatmentType;
        attribute laserWavelength : LaserWavelength;
        attribute laserPower : PowerW;
        attribute pulseDuration : DurationS;
        attribute totalEnergy : EnergyJ;
        attribute freezeTemperature : TemperatureC;
        attribute freezeDuration : DurationS;
        attribute thawDuration : DurationS;
    }

    item def SafetyStatus {
        attribute interlockOK : Boolean;
        attribute coolingOK : Boolean;
        attribute temperatureOK : Boolean;
        attribute contactOK : Boolean;
        attribute emergencyStop : Boolean;
        attribute overallSafe : Boolean;
    }

    item def SystemStatus {
        attribute currentMode : OperatingMode;
        attribute uptime : DurationS;
        attribute patientId : String;
    }

    // ===== Port Definitions =====
    port def ImageOutPort { out image : SkinImage; }
    port def ImageInPort { in image : SkinImage; }
    port def ReportOutPort { out report : DiagnosticReport; }
    port def ReportInPort { in report : DiagnosticReport; }
    port def ProtocolOutPort { out protocol : TreatmentProtocol; }
    port def ProtocolInPort { in protocol : TreatmentProtocol; }
    port def SafetyOutPort { out status : SafetyStatus; }
    port def SafetyInPort { in status : SafetyStatus; }
    port def StatusOutPort { out status : SystemStatus; }

    // ===== Dermatoscope Module =====
    part def DermatoscopeModule {
        attribute nominalMagnification : Magnification = 30;
        attribute nominalResolution : ResolutionPx = 4096;
        attribute supportedWavelengths : List(IlluminationWavelength) = (IlluminationWavelength::white, IlluminationWavelength::polarizedWhite, IlluminationWavelength::uv365, IlluminationWavelength::nir850);
        port imageOut : ImageOutPort;

        part opticalSystem {
            attribute aperture : Real = 0.25;
            attribute focusRangeMm : DiameterMm = 25;
            attribute currentFocus : DiameterMm = 10;
        }

        part polarizedFilter {
            attribute polarizationAngleDeg : Real = 0.0;
            attribute enabled : Boolean = true;
        }

        part illuminationUnit {
            attribute currentWavelength : IlluminationWavelength = IlluminationWavelength::polarizedWhite;
            attribute intensityPct : ConfidencePct = 80;
        }

        part imageSensor {
            attribute activeResolution : ResolutionPx = 4096;
            attribute gain : Real = 1.0;
        }

        action def CaptureImageAction {
            in wavelength : IlluminationWavelength;
            in magnification : Magnification;
            out image : SkinImage;
        }

        action capture : CaptureImageAction {
            in wavelength = illuminationUnit.currentWavelength;
            in magnification = nominalMagnification;
            out image : SkinImage;
            then deliverImage;
        }

        action deliverImage {
            out image : SkinImage via imageOut;
        }
    }

    // ===== Diagnostic Analysis Unit =====
    part def DiagnosticAnalysisUnit {
        attribute confidenceThreshold : ConfidencePct = 75;
        attribute modelVersion : String = "DermAI-v2.3";

        port imageIn : ImageInPort;
        port reportOut : ReportOutPort;

        part aiEngine {
            attribute modelVersion : String = "DermAI-v2.3";
            attribute trainedOnLesions : Integer = 250000;
        }

        part imageProcessor {
            attribute algorithm : String = "CNN-ResNet50";
            attribute preprocessing : String = "CLAUV+Normalization";
        }

        part featureExtractor {
            attribute asymmetryScore : Real;
            attribute borderIrregularity : Real;
            attribute colorVariation : Real;
            attribute diameter : DiameterMm;
        }

        action def AnalyzeImageAction {
            in image : SkinImage;
            out report : DiagnosticReport;
        }

        action analyze : AnalyzeImageAction {
            in image : SkinImage via imageIn;
            out report : DiagnosticReport;
        }

        action classifyRisk {
            in features : DiagnosticReport;
            out riskClass : RiskClass;
            out confidence : ConfidencePct;
        }

        flow analyze.report to reportOut.report;
    }

    // ===== Laser Therapy Unit =====
    part def LaserTherapyUnit {
        attribute availableWavelengths : List(LaserWavelength) = (LaserWavelength::nm532, LaserWavelength::nm585, LaserWavelength::nm694, LaserWavelength::nm755, LaserWavelength::nm1064);
        attribute maxPower : PowerW = 25;
        attribute maxPulseDuration : DurationS = 30;

        port protocolIn : ProtocolInPort;
        port safetyOut : SafetyOutPort;

        part beamDelivery {
            attribute spotSizeMm : SpotSizeMm = 1.0;
            attribute currentPower : PowerW = 0;
            attribute active : Boolean = false;
        }

        part coolingSystem {
            attribute targetTempC : TemperatureC = 5;
            attribute currentTempC : TemperatureC = 25;
            attribute active : Boolean = false;
        }

        part safetyInterlock {
            attribute engaged : Boolean = true;
            attribute emergencyStopPressed : Boolean = false;
        }

        part laserSource {
            attribute currentWavelength : LaserWavelength = LaserWavelength::nm755;
            attribute warmupComplete : Boolean = false;
        }

        state def LaserTherapyStateMachine;
        state machine LaserTherapyBehavior : LaserTherapyStateMachine {
            state idle;
            state warming;
            state armed;
            state firing;
            state cooldown;
            state fault;

            transition idle -> warming when protocolIn.protocol.treatmentType == TreatmentType::laser;
            transition warming -> armed when laserSource.warmupComplete && safetyInterlock.engaged;
            transition armed -> firing when coolingSystem.active && coolingSystem.currentTempC <= coolingSystem.targetTempC;
            transition firing -> cooldown when protocolIn.protocol.pulseDuration <= 0;
            transition cooldown -> idle when coolingSystem.currentTempC >= 20;
            transition armed -> fault when !safetyInterlock.engaged;
            transition firing -> fault when !coolingSystem.active;
            transition firing -> fault when safetyInterlock.emergencyStopPressed;
            transition fault -> idle when safetyInterlock.engaged && !safetyInterlock.emergencyStopPressed;
        }

        action def EmitLaserPulseAction {
            in wavelength : LaserWavelength;
            in power : PowerW;
            in duration : DurationS;
            out deliveredEnergy : EnergyJ;
        }

        action emitPulse : EmitLaserPulseAction {
            in wavelength = laserSource.currentWavelength;
            in power = beamDelivery.currentPower;
            in duration = protocolIn.protocol.pulseDuration;
            out deliveredEnergy : EnergyJ;
        }
    }

    // ===== Cryotherapy Unit =====
    part def CryotherapyUnit {
        attribute minTemp : TemperatureC = -196;
        attribute maxFreezeDuration : DurationS = 60;
        attribute refrigerantType : String = "N2O";

        port protocolIn : ProtocolInPort;
        port safetyOut : SafetyOutPort;

        part refrigerantSystem {
            attribute refrigerantType : String = "N2O";
            attribute pressureBar : PressureBar = 50;
            attribute valveOpen : Boolean = false;
        }

        part applicatorProbe {
            attribute tipDiameterMm : SpotSizeMm = 5.0;
            attribute contactDetected : Boolean = false;
        }

        part temperatureSensor {
            attribute measuredTemp : TemperatureC = 25;
            attribute samplingRateHz : Real = 10;
        }

        part freezeController {
            attribute targetTemp : TemperatureC = -40;
            attribute currentPhase : String = "idle";
        }

        state def CryotherapyStateMachine;
        state machine CryoBehavior : CryotherapyStateMachine {
            state idle;
            state cooling;
            state freezing;
            state thawing;
            state fault;

            transition idle -> cooling when protocolIn.protocol.treatmentType == TreatmentType::cryo;
            transition cooling -> freezing when temperatureSensor.measuredTemp <= -20 && applicatorProbe.contactDetected;
            transition freezing -> thawing when protocolIn.protocol.freezeDuration <= 0;
            transition thawing -> idle when temperatureSensor.measuredTemp >= 10;
            transition cooling -> fault when !applicatorProbe.contactDetected && refrigerantSystem.pressureBar < 10;
            transition freezing -> fault when temperatureSensor.measuredTemp > 0;
            transition fault -> idle when applicatorProbe.contactDetected;
        }

        action def FreezeCycleAction {
            in targetTemp : TemperatureC;
            in duration : DurationS;
            out achievedTemp : TemperatureC;
        }

        action freezeCycle : FreezeCycleAction {
            in targetTemp = freezeController.targetTemp;
            in duration = protocolIn.protocol.freezeDuration;
            out achievedTemp : TemperatureC;
        }
    }

    // ===== Control and Monitoring System =====
    part def ControlAndMonitoringSystem {
        attribute currentMode : OperatingMode = OperatingMode::standby;
        attribute currentProtocol : TreatmentProtocol;

        port reportIn : ReportInPort;
        port laserProtocolOut : ProtocolOutPort;
        port cryoProtocolOut : ProtocolOutPort;
        port laserSafetyIn : SafetyInPort;
        port cryoSafetyIn : SafetyInPort;
        port statusOut : StatusOutPort;

        part userInterface {
            attribute displayActive : Boolean = true;
            attribute selectedMode : OperatingMode = OperatingMode::standby;
            in currentMode : OperatingMode;
            in report : DiagnosticReport;
            in laserSafety : SafetyStatus;
            in cryoSafety : SafetyStatus;
        }

        part modeController {
            attribute selectedMode : OperatingMode = OperatingMode::standby;
            attribute operatorAuthenticated : Boolean = false;
        }

        part safetyMonitor {
            attribute overallSafety : SafetyStatus;
            attribute emergencyStopActive : Boolean = false;
        }

        part protocolGenerator {
            attribute lastProtocol : TreatmentProtocol;
        }

        action def DecideTreatmentAction {
            in report : DiagnosticReport;
            out protocol : TreatmentProtocol;
        }

        action decideTreatment : DecideTreatmentAction {
            in report : DiagnosticReport via reportIn;
            out protocol : TreatmentProtocol;
        }

        action configureLaser {
            in protocol : TreatmentProtocol;
            out laserProtocol : TreatmentProtocol via laserProtocolOut;
        }

        action configureCryo {
            in protocol : TreatmentProtocol;
            out cryoProtocol : TreatmentProtocol via cryoProtocolOut;
        }

        state def ControlStateMachine;
        state machine ControlBehavior : ControlStateMachine {
            state standby;
            state examination;
            state diagnosis;
            state treatmentSelection;
            state laserTreatment;
            state cryoTreatment;
            state emergency;

            transition standby -> examination when modeController.selectedMode == OperatingMode::examination;
            transition examination -> diagnosis when reportIn.report.confidence >= 0;
            transition diagnosis -> treatmentSelection when reportIn.report.riskClass == RiskClass::suspicious || reportIn.report.riskClass == RiskClass::malignant;
            transition diagnosis -> standby when reportIn.report.riskClass == RiskClass::benign;
            transition treatmentSelection -> laserTreatment when currentProtocol.treatmentType == TreatmentType::laser;
            transition treatmentSelection -> cryoTreatment when currentProtocol.treatmentType == TreatmentType::cryo;
            transition laserTreatment -> standby when laserSafetyIn.status.interlockOK == false;
            transition cryoTreatment -> standby when cryoSafetyIn.status.temperatureOK == false;
            transition laserTreatment -> emergency when laserSafetyIn.status.emergencyStop == true;
            transition cryoTreatment -> emergency when cryoSafetyIn.status.emergencyStop == true;
            transition emergency -> standby when safetyMonitor.emergencyStopActive == false;
        }
    }

    // ===== Integrated Dermatology System =====
    part def IntegratedDermatologySystem {
        attribute systemId : String = "DermSys-001";
        attribute firmwareVersion : String = "1.4.0";

        part dermatoscope : DermatoscopeModule;
        part diagnosticUnit : DiagnosticAnalysisUnit;
        part controlSystem : ControlAndMonitoringSystem;
        part laserUnit : LaserTherapyUnit;
        part cryoUnit : CryotherapyUnit;

        connection dermatoscope.imageOut to diagnosticUnit.imageIn;
        connection diagnosticUnit.reportOut to controlSystem.reportIn;
        connection controlSystem.laserProtocolOut to laserUnit.protocolIn;
        connection controlSystem.cryoProtocolOut to cryoUnit.protocolIn;
        connection laserUnit.safetyOut to controlSystem.laserSafetyIn;
        connection cryoUnit.safetyOut to controlSystem.cryoSafetyIn;

        flow dermatoscope.imageOut.image to diagnosticUnit.imageIn.image;
        flow diagnosticUnit.reportOut.report to controlSystem.reportIn.report;
        flow controlSystem.laserProtocolOut.protocol to laserUnit.protocolIn.protocol;
        flow controlSystem.cryoProtocolOut.protocol to cryoUnit.protocolIn.protocol;
        flow laserUnit.safetyOut.status to controlSystem.laserSafetyIn.status;
        flow cryoUnit.safetyOut.status to controlSystem.cryoSafetyIn.status;
    }

    // ===== Requirements =====
    requirement def DiagnosticAccuracyRequirement {
        subject diagnosticUnit : DiagnosticAnalysisUnit;
        attribute minConfidence : ConfidencePct = 75;
        objective {
            diagnosticUnit.confidenceThreshold >= minConfidence
        }
        doc /* The diagnostic analysis unit shall provide AI-driven diagnostic assessments with a confidence threshold of at least 75%. */
    }

    requirement def HighResolutionImagingRequirement {
        subject dermatoscope : DermatoscopeModule;
        attribute minResolution : ResolutionPx = 4096;
        attribute minMagnification : Magnification = 20;
        objective {
            dermatoscope.nominalResolution >= minResolution
            and dermatoscope.nominalMagnification >= minMagnification
        }
        doc /* The dermatoscope module shall capture high-resolution images at a minimum of 4096 px and 20x magnification. */
    }

    requirement def LaserSafetyRequirement {
        subject laserUnit : LaserTherapyUnit;
        objective {
            laserUnit.safetyInterlock.engaged == true
            and laserUnit.coolingSystem.active == true
        }
        doc /* The laser therapy unit shall include an emergency safety interlock and an active skin cooling system during operation. */
    }

    requirement def CryoTemperatureRequirement {
        subject cryoUnit : CryotherapyUnit;
        attribute maxFreezeTemp : TemperatureC = -20;
        objective {
            cryoUnit.temperatureSensor.measuredTemp <= maxFreezeTemp
        }
        doc /* The cryotherapy unit shall achieve a measured temperature of at most -20 degC during the freeze cycle. */
    }

    requirement def IntegratedWorkflowRequirement {
        subject system : IntegratedDermatologySystem;
        objective {
            system.dermatoscope.imageOut.isConnectedTo(system.diagnosticUnit.imageIn)
            and system.diagnosticUnit.reportOut.isConnectedTo(system.controlSystem.reportIn)
            and system.controlSystem.laserProtocolOut.isConnectedTo(system.laserUnit.protocolIn)
            and system.controlSystem.cryoProtocolOut.isConnectedTo(system.cryoUnit.protocolIn)
        }
        doc /* The system shall integrate imaging, AI-driven diagnosis, and both laser and cryotherapy treatment options into a single cohesive workflow. */
    }

    requirement def RealTimeMonitoringRequirement {
        subject controlSystem : ControlAndMonitoringSystem;
        objective {
            controlSystem.safetyMonitor.overallSafe.overallSafe == true
        }
        doc /* The control and monitoring system shall monitor patient safety in real time across all therapeutic modules. */
    }

    // ===== Requirement Satisfaction =====
    part def DermatologySystemInstance :> IntegratedDermatologySystem {
        satisfy DiagnosticAccuracyRequirement by diagnosticUnit;
        satisfy HighResolutionImagingRequirement by dermatoscope;
        satisfy LaserSafetyRequirement by laserUnit;
        satisfy CryoTemperatureRequirement by cryoUnit;
        satisfy IntegratedWorkflowRequirement by self;
        satisfy RealTimeMonitoringRequirement by controlSystem;
    }
}
