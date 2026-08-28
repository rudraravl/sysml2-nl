package NuclearDensityGaugeModel {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def Density :> ScalarValues::Real;
    attribute def MoistureContent :> ScalarValues::Real;
    attribute def CountRate :> ScalarValues::Real;
    attribute def CalibrationParameter :> ScalarValues::Real;
    attribute def MeasurementDepth :> ScalarValues::Real;
    attribute def AuthorizationCode :> ScalarValues::String;
    attribute def SourceActivity :> ScalarValues::Real;
    attribute def ShieldingFactor :> ScalarValues::Real;
    attribute def ExposureTimeSeconds :> ScalarValues::Real;

    enum def MeasurementMode {
        enum directTransmission;
        enum backscatter;
    }
    enum def MaterialType {
        enum soil;
        enum asphalt;
        enum baseLayer;
    }
    enum def IsotopeKind {
        enum Cs137;
    }
    enum def ShieldingMaterial {
        enum lead;
        enum tungsten;
    }

    attribute def PowerOnSignal;
    attribute def PowerOffSignal;
    attribute def ArmSignal;
    attribute def StartMeasurementSignal;
    attribute def MeasurementCompleteSignal;
    attribute def OpenShutterCommand;
    attribute def CloseShutterCommand;
    attribute def EmergencyCloseSignal;

    item def GammaRay {
        attribute energy : ScalarValues::Real;
    }
    item def RadiationFlux {
        attribute countRate : CountRate;
    }
    item def ProcessedSignal {
        attribute amplifiedCountRate : CountRate;
    }
    item def MeasurementResult {
        attribute density : Density;
        attribute moisture : MoistureContent;
        attribute mode : MeasurementMode;
        attribute depth : MeasurementDepth;
    }

    port def RadiationOutPort {
        out gammaRay : GammaRay;
    }
    port def RadiationInPort {
        in gammaRay : GammaRay;
    }
    port def RawSignalOutPort {
        out signal : RadiationFlux;
    }
    port def RawSignalInPort {
        in signal : RadiationFlux;
    }
    port def ProcessedSignalOutPort {
        out signal : ProcessedSignal;
    }
    port def ProcessedSignalInPort {
        in signal : ProcessedSignal;
    }
    port def DataOutPort {
        out result : MeasurementResult;
    }
    port def DataInPort {
        in result : MeasurementResult;
    }
    port def ControlOutPort {
        out command : ScalarValues::String;
    }
    port def ControlInPort {
        in command : ScalarValues::String;
    }

    interface def RadiationBeamInterface {
        end sourcePort : RadiationOutPort;
        end detectorPort : RadiationInPort;
    }
    interface def RawSignalInterface {
        end producerPort : RawSignalOutPort;
        end consumerPort : RawSignalInPort;
    }
    interface def ProcessedSignalInterface {
        end producerPort : ProcessedSignalOutPort;
        end consumerPort : ProcessedSignalInPort;
    }
    interface def DataInterface {
        end senderPort : DataOutPort;
        end receiverPort : DataInPort;
    }
    interface def ControlInterface {
        end senderPort : ControlOutPort;
        end receiverPort : ControlInPort;
    }

    action def EmitGammaRaysAction;
    action def OpenShutterAction;
    action def CloseShutterAction;
    action def LowerSourceRodAction;
    action def RaiseSourceRodAction;
    action def ArmDeviceAction {
        in code : AuthorizationCode;
    }
    action def CollectRadiationCountsAction {
        in mode : MeasurementMode;
        in depth : MeasurementDepth;
        out flux : RadiationFlux;
    }
    action def AmplifySignalAction {
        in rawSignal : RadiationFlux;
        out processedSignal : ProcessedSignal;
    }
    action def CalculateDensityAction {
        in countRate : CountRate;
        in calibration : CalibrationParameter;
        out density : Density;
    }
    action def CalculateMoistureAction {
        in countRate : CountRate;
        in calibration : CalibrationParameter;
        out moisture : MoistureContent;
    }
    action def PerformMeasurementAction {
        in mode : MeasurementMode;
        in material : MaterialType;
        in depth : MeasurementDepth;
        in densityCalibration : CalibrationParameter;
        in moistureCalibration : CalibrationParameter;
        out result : MeasurementResult;
    }
    action def DisplayResultsAction {
        in result : MeasurementResult;
    }

    part def SafetyInterlockSystem {
        attribute armed : ScalarValues::Boolean;
        attribute authorized : ScalarValues::Boolean;
        attribute requiredCode : AuthorizationCode;
        perform action arm :>> ArmDeviceAction;
    }

    part def RadioactiveSource {
        attribute isotope : IsotopeKind;
        attribute activity : SourceActivity;
        port radiationOutPort : RadiationOutPort;
        item emittedGammaRays : GammaRay;
        perform action emitGammaRays :>> EmitGammaRaysAction;
    }

    part def RadiationShield {
        attribute material : ShieldingMaterial;
        attribute shieldingFactor : ShieldingFactor;
    }

    part def Shutter {
        attribute isOpen : ScalarValues::Boolean;
        port radiationInPort : RadiationInPort;
        port radiationOutPort : RadiationOutPort;
        ref interlock : SafetyInterlockSystem;
        perform action open :>> OpenShutterAction;
        perform action close :>> CloseShutterAction;
        exhibit state shutterStates {
            entry; then closed;
            state closed;
            accept OpenShutterCommand
                if interlock.armed
                then open;
            state open;
            accept CloseShutterCommand then closed;
            accept MeasurementCompleteSignal then closed;
            accept EmergencyCloseSignal then closed;
        }
    }

    part def SourceRod {
        attribute extended : ScalarValues::Boolean;
        attribute maxDepth : MeasurementDepth;
        port beamOut : RadiationOutPort;
        perform action lower :>> LowerSourceRodAction;
        perform action raise :>> RaiseSourceRodAction;
    }

    part def ScintillationDetector {
        attribute sensitivity : ScalarValues::Real;
        port radiationInPort : RadiationInPort;
        port signalOutPort : RawSignalOutPort;
        item detectedRadiation : RadiationFlux;
        perform action collect :>> CollectRadiationCountsAction;
    }

    part def SignalProcessor {
        port signalInPort : RawSignalInPort;
        port signalOutPort : ProcessedSignalOutPort;
        perform action amplify :>> AmplifySignalAction;
    }

    part def ComputationUnit {
        attribute densityCalibration : CalibrationParameter;
        attribute moistureCalibration : CalibrationParameter;
        port signalInPort : ProcessedSignalInPort;
        port dataOutPort : DataOutPort;
        perform action calcDensity :>> CalculateDensityAction;
        perform action calcMoisture :>> CalculateMoistureAction;
    }

    part def Display {
        attribute brightness : ScalarValues::Real;
    }

    part def ControlPanel {
        attribute keypadActive : ScalarValues::Boolean;
    }

    part def UserInterface {
        attribute displayActive : ScalarValues::Boolean;
        part display : Display;
        part controlPanel : ControlPanel;
        port dataInPort : DataInPort;
        port controlOutPort : ControlOutPort;
        perform action displayResults :>> DisplayResultsAction;
    }

    part def Material {
        attribute type : MaterialType;
        attribute density : Density;
        attribute moisture : MoistureContent;
        attribute depth : MeasurementDepth;
    }

    part def MaterialUnderTest {
        attribute mass : ScalarValues::Real;
        attribute volume : ScalarValues::Real;
        attribute density : Density;
        attribute moistureContent : MoistureContent;
        port gammaIn : RadiationInPort;
        port gammaOut : RadiationOutPort;
        assert constraint { density == mass / volume }
    }

    part def NuclearDensityGauge {
        attribute selectedMode : MeasurementMode;
        attribute selectedMaterial : MaterialType;
        attribute selectedDepth : MeasurementDepth;
        attribute currentResult : MeasurementResult;
        port controlPort : ControlInPort;
        port dataOutPort : DataOutPort;
        part radioactiveSource : RadioactiveSource;
        part radiationShield : RadiationShield;
        part shutter : Shutter;
        part sourceRod : SourceRod;
        part scintillationDetector : ScintillationDetector;
        part signalProcessor : SignalProcessor;
        part computationUnit : ComputationUnit;
        part userInterface : UserInterface;
        part safetyInterlock : SafetyInterlockSystem;
        perform action performMeasurement :>> PerformMeasurementAction;
        exhibit state gaugeStates {
            entry; then poweredOff;
            state poweredOff;
            accept PowerOnSignal then standby;
            state standby;
            accept ArmSignal
                if safetyInterlock.authorized
                then armed;
            state armed;
            accept StartMeasurementSignal then measuring;
            state measuring {
                entry action openShutter;
                do action collectRadiationCounts;
                exit action closeShutter;
            }
            accept MeasurementCompleteSignal then standby;
            accept PowerOffSignal then poweredOff;
        }
    }

    part def DensityGaugeTestSystem {
        part gauge : NuclearDensityGauge;
        part material : MaterialUnderTest;
        connect gauge.radioactiveSource.radiationOutPort to material.gammaIn;
        connect material.gammaOut to gauge.scintillationDetector.radiationInPort;
    }

    requirement def SafetyInterlockRequirement {
        subject gauge : NuclearDensityGauge;
        doc /* The shutter shall remain locked in the closed position unless an authorized user enters a valid code to arm the device. */
        require {
            gauge.shutter.isOpen implies gauge.safetyInterlock.authorized
        }
    }

    requirement def ShutterAutoCloseRequirement {
        subject gauge : NuclearDensityGauge;
        doc /* The shutter shall only open for the brief duration of an active measurement and automatically close upon completion. */
        require {
            gauge.shutter.isOpen implies gauge.safetyInterlock.armed
        }
    }

    requirement def MinimumExposureRequirement {
        subject gauge : NuclearDensityGauge;
        attribute maxExposureTime : ExposureTimeSeconds = 60;
        doc /* Radiation exposure time shall not exceed the maximum allowable limit. */
    }

    requirement def MeasurementAccuracyRequirement {
        subject gauge : NuclearDensityGauge;
        attribute densityToleranceFraction : ScalarValues::Real = 0.05;
        doc /* The computation unit shall convert radiation count rate into density and moisture content using pre-set calibration parameters. */
    }

    requirement def SourceShieldingRequirement {
        subject gauge : NuclearDensityGauge;
        doc /* The radiation shield shall provide adequate shielding with a shielding factor of at least 0.95. */
        require {
            gauge.radiationShield.shieldingFactor >= 0.95
        }
    }

    requirement def AuthorizationRequirement {
        subject gauge : NuclearDensityGauge;
        doc /* The safety interlock system shall only arm when an authorized code is entered. */
        require {
            gauge.safetyInterlock.armed implies gauge.safetyInterlock.authorized
        }
    }

    part nuclearDensityGauge : NuclearDensityGauge {
        :>> selectedMode = MeasurementMode::directTransmission;
        :>> selectedMaterial = MaterialType::soil;
        :>> selectedDepth = 0.15;

        part radioactiveSource : RadioactiveSource {
            :>> isotope = IsotopeKind::Cs137;
            :>> activity = 370e6;
        }
        part radiationShield : RadiationShield {
            :>> material = ShieldingMaterial::tungsten;
            :>> shieldingFactor = 0.99;
        }
        part safetyInterlock : SafetyInterlockSystem {
            :>> requiredCode = "AUTH_2024";
            :>> armed = false;
            :>> authorized = false;
        }
        part sourceRod : SourceRod {
            :>> maxDepth = 0.30;
            :>> extended = false;
        }
        part computationUnit : ComputationUnit {
            :>> densityCalibration = 1.85;
            :>> moistureCalibration = 0.42;
        }
        part scintillationDetector : ScintillationDetector {
            :>> sensitivity = 0.95;
        }
        part shutter : Shutter {
            :>> isOpen = false;
        }
        part signalProcessor : SignalProcessor;
        part userInterface : UserInterface {
            :>> displayActive = true;
            part display : Display {
                :>> brightness = 0.8;
            }
            part controlPanel : ControlPanel {
                :>> keypadActive = true;
            }
        }

        bind shutter.interlock = safetyInterlock;

        interface : RadiationBeamInterface connect
            sourcePort ::> radioactiveSource.radiationOutPort to
            detectorPort ::> shutter.radiationInPort;
        interface : RadiationBeamInterface connect
            sourcePort ::> shutter.radiationOutPort to
            detectorPort ::> scintillationDetector.radiationInPort;
        interface : RawSignalInterface connect
            producerPort ::> scintillationDetector.signalOutPort to
            consumerPort ::> signalProcessor.signalInPort;
        interface : ProcessedSignalInterface connect
            producerPort ::> signalProcessor.signalOutPort to
            consumerPort ::> computationUnit.signalInPort;
        interface : DataInterface connect
            senderPort ::> computationUnit.dataOutPort to
            receiverPort ::> userInterface.dataInPort;
        interface : ControlInterface connect
            senderPort ::> userInterface.controlOutPort to
            receiverPort ::> controlPort;
    }

    requirement safetyReq : SafetyInterlockRequirement {
        subject :>> gauge = nuclearDensityGauge;
    }
    requirement autoCloseReq : ShutterAutoCloseRequirement {
        subject :>> gauge = nuclearDensityGauge;
    }
    requirement exposureReq : MinimumExposureRequirement {
        subject :>> gauge = nuclearDensityGauge;
    }
    requirement accuracyReq : MeasurementAccuracyRequirement {
        subject :>> gauge = nuclearDensityGauge;
    }
    requirement shieldingReq : SourceShieldingRequirement {
        subject :>> gauge = nuclearDensityGauge;
    }
    requirement authReq : AuthorizationRequirement {
        subject :>> gauge = nuclearDensityGauge;
    }

    individual def TestGauge :> NuclearDensityGauge;
    individual def SoilTestMaterial :> MaterialUnderTest;
    individual def AsphaltTestMaterial :> MaterialUnderTest;

    individual testGauge : TestGauge :> nuclearDensityGauge {
        timeslice soilTest {
            :>> selectedMode = MeasurementMode::directTransmission;
            :>> selectedMaterial = MaterialType::soil;
            :>> selectedDepth = 0.15;
            perform action :>> performMeasurement {
                in mode = MeasurementMode::directTransmission;
                in material = MaterialType::soil;
                in depth = 0.15;
                in densityCalibration = 1.85;
                in moistureCalibration = 0.42;
            }
        }
        then timeslice asphaltTest {
            :>> selectedMode = MeasurementMode::backscatter;
            :>> selectedMaterial = MaterialType::asphalt;
            :>> selectedDepth = 0.0;
            perform action :>> performMeasurement {
                in mode = MeasurementMode::backscatter;
                in material = MaterialType::asphalt;
                in depth = 0.0;
                in densityCalibration = 1.92;
                in moistureCalibration = 0.38;
            }
        }
    }
}
