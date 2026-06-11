package UrologyInstrumentSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def PressureValue :> Real {
        unit = Pa;
    }

    attribute def FlowRateValue :> Real {
        unit = L / min;
    }

    attribute def VolumeValue :> Real {
        unit = mL;
    }

    attribute def LengthValue :> Real {
        unit = mm;
    }

    attribute def TemperatureValue :> Real {
        unit = K;
    }

    attribute def ElectricPowerValue :> Real {
        unit = W;
    }

    attribute def TimeValue :> Real {
        unit = s;
    }

    attribute def ImageResolutionValue :> Integer;

    enum def SterilityState {
        enum sterile;
        enum disinfected;
        enum contaminated;
        enum singleUsePackaged;
    }

    enum def ProcedureMode {
        enum cystoscopy;
        enum ureteroscopy;
        enum lithotripsy;
        enum resection;
        enum irrigationOnly;
        enum diagnosticInspection;
    }

    enum def InstrumentOperationalState {
        enum packaged;
        enum prepared;
        enum inserted;
        enum active;
        enum withdrawn;
        enum reprocessing;
        enum retired;
    }

    item def IrrigationFluid {
        attribute volume : VolumeValue;
        attribute temperature : TemperatureValue;
        attribute sterility : SterilityState;
    }

    item def DrainageFluid {
        attribute volume : VolumeValue;
        attribute visibleBloodFraction : Real;
        attribute containsStoneFragments : Boolean;
    }

    item def OpticalImageFrame {
        attribute horizontalPixels : ImageResolutionValue;
        attribute verticalPixels : ImageResolutionValue;
        attribute frameRate : Real;
    }

    item def LaserEnergyPulse {
        attribute pulseEnergy : Real {
            unit = J;
        }
        attribute pulseDuration : TimeValue;
        attribute wavelength : LengthValue;
    }

    item def ResectedTissueSample {
        attribute sampleVolume : VolumeValue;
        attribute preservedForPathology : Boolean;
    }

    item def SterilizationRecord {
        attribute cycleTime : TimeValue;
        attribute peakTemperature : TemperatureValue;
        attribute passedBiologicalIndicator : Boolean;
    }

    port def FluidInletPort {
        in item fluid : IrrigationFluid;
    }

    port def FluidOutletPort {
        out item fluid : DrainageFluid;
    }

    port def ImageOutputPort {
        out item frame : OpticalImageFrame;
    }

    port def EnergyDeliveryPort {
        out item pulse : LaserEnergyPulse;
    }

    port def TissueExtractionPort {
        out item sample : ResectedTissueSample;
    }

    port def ControlInputPort {
        in attribute selectedMode : ProcedureMode;
        in attribute activationRequested : Boolean;
        in attribute targetIrrigationFlow : FlowRateValue;
        in attribute targetLaserPower : ElectricPowerValue;
    }

    port def StatusOutputPort {
        out attribute operationalState : InstrumentOperationalState;
        out attribute measuredIrrigationPressure : PressureValue;
        out attribute measuredFlowRate : FlowRateValue;
        out attribute readyForInsertion : Boolean;
        out attribute faultActive : Boolean;
    }

    part def UrologyInstrumentSystem {
        attribute primaryFunction : String = "Enable diagnostic visualization, fluid management, stone treatment, tissue manipulation, and specimen removal within the urinary tract through controlled minimally invasive instruments.";
        attribute selectedMode : ProcedureMode;
        attribute systemSterility : SterilityState;
        attribute maximumSafeIrrigationPressure : PressureValue = 8000.0;
        attribute nominalIrrigationFlow : FlowRateValue = 0.25;
        attribute maximumLaserPower : ElectricPowerValue = 120.0;

        port control : ControlInputPort;
        port status : StatusOutputPort;
        port irrigationIn : FluidInletPort;
        port drainageOut : FluidOutletPort;
        port videoOut : ImageOutputPort;
        port laserOut : EnergyDeliveryPort;
        port sampleOut : TissueExtractionPort;

        part endoscopicInstrument : EndoscopicInstrument;
        part irrigationSubsystem : IrrigationSubsystem;
        part visualizationSubsystem : VisualizationSubsystem;
        part lithotripsySubsystem : LithotripsySubsystem;
        part resectionSubsystem : ResectionSubsystem;
        part sterileHandlingSubsystem : SterileHandlingSubsystem;
        part userControlConsole : UserControlConsole;

        connect irrigationIn to irrigationSubsystem.supplyIn;
        connect irrigationSubsystem.deliveryOut to endoscopicInstrument.irrigationChannelIn;
        connect endoscopicInstrument.drainageChannelOut to irrigationSubsystem.returnIn;
        connect irrigationSubsystem.wasteOut to drainageOut;

        connect endoscopicInstrument.opticalDistalPort to visualizationSubsystem.imageIn;
        connect visualizationSubsystem.videoOut to videoOut;

        connect userControlConsole.controlOut to control;
        connect userControlConsole.instrumentCommandOut to endoscopicInstrument.controlIn;
        connect userControlConsole.irrigationCommandOut to irrigationSubsystem.controlIn;
        connect userControlConsole.laserCommandOut to lithotripsySubsystem.controlIn;
        connect userControlConsole.resectionCommandOut to resectionSubsystem.controlIn;

        connect lithotripsySubsystem.energyOut to endoscopicInstrument.workingChannelEnergyIn;
        connect endoscopicInstrument.distalEnergyOut to laserOut;

        connect resectionSubsystem.tissueOut to endoscopicInstrument.workingChannelTissueIn;
        connect endoscopicInstrument.tissueSampleOut to sampleOut;

        connect sterileHandlingSubsystem.sterilityStatusOut to endoscopicInstrument.sterilityStatusIn;
        connect irrigationSubsystem.pressureStatusOut to status;
        connect endoscopicInstrument.instrumentStatusOut to status;
    }

    part def EndoscopicInstrument {
        attribute outerDiameter : LengthValue = 21.0;
        attribute workingLength : LengthValue = 430.0;
        attribute fieldOfViewDegrees : Real = 90.0;
        attribute workingChannelDiameter : LengthValue = 3.2;
        attribute sterility : SterilityState;
        attribute operationalState : InstrumentOperationalState;

        port controlIn : ControlInputPort;
        port sterilityStatusIn : StatusOutputPort;
        port irrigationChannelIn : FluidInletPort;
        port drainageChannelOut : FluidOutletPort;
        port opticalDistalPort : ImageOutputPort;
        port workingChannelEnergyIn : EnergyDeliveryPort;
        port distalEnergyOut : EnergyDeliveryPort;
        port workingChannelTissueIn : TissueExtractionPort;
        port tissueSampleOut : TissueExtractionPort;
        port instrumentStatusOut : StatusOutputPort;

        part insertionShaft : InsertionShaft;
        part distalTip : DistalTip;
        part workingChannel : WorkingChannel;
        part irrigationChannel : IrrigationChannel;
        part drainageChannel : DrainageChannel;
        part handle : InstrumentHandle;

        connect irrigationChannelIn to irrigationChannel.inlet;
        connect irrigationChannel.outlet to distalTip.irrigationExit;
        connect distalTip.drainageEntry to drainageChannel.inlet;
        connect drainageChannel.outlet to drainageChannelOut;
        connect workingChannel.energyIn to workingChannelEnergyIn;
        connect workingChannel.energyOut to distalEnergyOut;
        connect workingChannel.tissueIn to workingChannelTissueIn;
        connect workingChannel.tissueOut to tissueSampleOut;
        connect distalTip.imageOut to opticalDistalPort;
    }

    part def InsertionShaft {
        attribute length : LengthValue = 430.0;
        attribute diameter : LengthValue = 21.0;
        attribute bendRadiusMinimum : LengthValue = 35.0;
        attribute biocompatible : Boolean = true;
    }

    part def DistalTip {
        attribute atraumaticRadius : LengthValue = 1.0;
        attribute illuminationPower : ElectricPowerValue = 4.0;

        port irrigationExit : FluidInletPort;
        port drainageEntry : FluidOutletPort;
        port imageOut : ImageOutputPort;
    }

    part def WorkingChannel {
        attribute innerDiameter : LengthValue = 3.2;
        attribute acceptsLaserFiber : Boolean = true;
        attribute acceptsBasket : Boolean = true;
        attribute acceptsForceps : Boolean = true;

        port energyIn : EnergyDeliveryPort;
        port energyOut : EnergyDeliveryPort;
        port tissueIn : TissueExtractionPort;
        port tissueOut : TissueExtractionPort;
    }

    part def IrrigationChannel {
        attribute innerDiameter : LengthValue = 2.0;
        attribute maximumFlow : FlowRateValue = 0.6;

        port inlet : FluidInletPort;
        port outlet : FluidInletPort;
    }

    part def DrainageChannel {
        attribute innerDiameter : LengthValue = 2.4;
        attribute maximumDrainageFlow : FlowRateValue = 0.7;

        port inlet : FluidOutletPort;
        port outlet : FluidOutletPort;
    }

    part def InstrumentHandle {
        attribute ergonomicGripForce : Real {
            unit = N;
        } = 12.0;
        attribute manualDeflectionAvailable : Boolean = true;
    }

    part def IrrigationSubsystem {
        attribute reservoirCapacity : VolumeValue = 3000.0;
        attribute currentReservoirVolume : VolumeValue;
        attribute commandedFlowRate : FlowRateValue;
        attribute measuredFlowRate : FlowRateValue;
        attribute measuredPressure : PressureValue;
        attribute pressureLimit : PressureValue = 8000.0;

        port controlIn : ControlInputPort;
        port pressureStatusOut : StatusOutputPort;
        port supplyIn : FluidInletPort;
        port deliveryOut : FluidInletPort;
        port returnIn : FluidOutletPort;
        port wasteOut : FluidOutletPort;

        part pump : IrrigationPump;
        part pressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        part wasteCollector : WasteCollector;

        connect supplyIn to pump.fluidIn;
        connect pump.fluidOut to deliveryOut;
        connect returnIn to wasteCollector.fluidIn;
        connect wasteCollector.fluidOut to wasteOut;
    }

    part def IrrigationPump {
        attribute maximumFlow : FlowRateValue = 0.8;
        attribute maximumPressure : PressureValue = 10000.0;
        attribute electricalPower : ElectricPowerValue = 35.0;

        port fluidIn : FluidInletPort;
        port fluidOut : FluidInletPort;
    }

    part def PressureSensor {
        attribute rangeMaximum : PressureValue = 15000.0;
        attribute accuracy : PressureValue = 50.0;
    }

    part def FlowSensor {
        attribute rangeMaximum : FlowRateValue = 1.0;
        attribute accuracy : FlowRateValue = 0.02;
    }

    part def WasteCollector {
        attribute capacity : VolumeValue = 5000.0;
        attribute sealedContainer : Boolean = true;

        port fluidIn : FluidOutletPort;
        port fluidOut : FluidOutletPort;
    }

    part def VisualizationSubsystem {
        attribute imageWidthPixels : ImageResolutionValue = 1920;
        attribute imageHeightPixels : ImageResolutionValue = 1080;
        attribute minimumFrameRate : Real = 30.0;
        attribute whiteBalanceEnabled : Boolean = true;

        port imageIn : ImageOutputPort;
        port videoOut : ImageOutputPort;

        part cameraSensor : CameraSensor;
        part lightSource : LightSource;
        part videoProcessor : VideoProcessor;
    }

    part def CameraSensor {
        attribute horizontalPixels : ImageResolutionValue = 1920;
        attribute verticalPixels : ImageResolutionValue = 1080;
        attribute lowLightMode : Boolean = true;
    }

    part def LightSource {
        attribute maximumPower : ElectricPowerValue = 25.0;
        attribute adjustableIntensity : Boolean = true;
    }

    part def VideoProcessor {
        attribute latency : TimeValue = 0.08;
        attribute recordsProcedure : Boolean = true;
    }

    part def LithotripsySubsystem {
        attribute enabled : Boolean;
        attribute selectedPower : ElectricPowerValue;
        attribute pulseRate : Real {
            unit = Hz;
        } = 15.0;
        attribute wavelength : LengthValue = 0.0021;

        port controlIn : ControlInputPort;
        port energyOut : EnergyDeliveryPort;

        part laserGenerator : LaserGenerator;
        part laserFiber : LaserFiber;

        connect laserGenerator.output to laserFiber.input;
        connect laserFiber.output to energyOut;
    }

    part def LaserGenerator {
        attribute maximumPower : ElectricPowerValue = 120.0;
        attribute pulseEnergyMaximum : Real {
            unit = J;
        } = 6.0;
        attribute interlockRequired : Boolean = true;

        port output : EnergyDeliveryPort;
    }

    part def LaserFiber {
        attribute coreDiameter : LengthValue = 0.365;
        attribute usableLength : LengthValue = 3000.0;

        port input : EnergyDeliveryPort;
        port output : EnergyDeliveryPort;
    }

    part def ResectionSubsystem {
        attribute cuttingPower : ElectricPowerValue = 80.0;
        attribute coagulationPower : ElectricPowerValue = 60.0;
        attribute tissueCaptureEnabled : Boolean = true;

        port controlIn : ControlInputPort;
        port tissueOut : TissueExtractionPort;

        part loopElectrode : LoopElectrode;
        part specimenTrap : SpecimenTrap;

        connect specimenTrap.sampleOut to tissueOut;
    }

    part def LoopElectrode {
        attribute loopWidth : LengthValue = 5.0;
        attribute loopDepth : LengthValue = 3.0;
        attribute insulatedShaft : Boolean = true;
    }

    part def SpecimenTrap {
        attribute retainedVolume : VolumeValue = 50.0;
        attribute removableForPathology : Boolean = true;

        port sampleOut : TissueExtractionPort;
    }

    part def SterileHandlingSubsystem {
        attribute packagingSterility : SterilityState = SterilityState::singleUsePackaged;
        attribute reprocessingAvailable : Boolean = true;

        port sterilityStatusOut : StatusOutputPort;

        part sterilizerInterface : SterilizerInterface;
        part sterileBarrier : SterileBarrier;
    }

    part def SterilizerInterface {
        attribute acceptedCycleTemperature : TemperatureValue = 407.0;
        attribute acceptedCycleTime : TimeValue = 240.0;
        attribute recordsCycle : Boolean = true;
    }

    part def SterileBarrier {
        attribute intact : Boolean;
        attribute expirationDays : Integer = 180;
    }

    part def UserControlConsole {
        attribute displaySize : LengthValue = 380.0;
        attribute footPedalEnabled : Boolean = true;
        attribute alarmVolume : Real {
            unit = dB;
        } = 65.0;

        port controlOut : ControlInputPort;
        port instrumentCommandOut : ControlInputPort;
        port irrigationCommandOut : ControlInputPort;
        port laserCommandOut : ControlInputPort;
        port resectionCommandOut : ControlInputPort;
    }

    action def PrepareInstrument {
        in attribute currentSterility : SterilityState;
        out attribute readyForInsertion : Boolean;

        first start;
        then verifySterileBarrier;
        then connectFluidLines;
        then verifyOptics;
        then complete;

        action verifySterileBarrier;
        action connectFluidLines;
        action verifyOptics;
        action complete;

        flow currentSterility to verifySterileBarrier.currentSterility;
        flow verifyOptics.readyForInsertion to readyForInsertion;
    }

    action def PerformDiagnosticCystoscopy {
        in item irrigation : IrrigationFluid;
        out item drainage : DrainageFluid;
        out item image : OpticalImageFrame;

        first insertInstrument;
        then startIrrigation;
        then illuminateField;
        then inspectBladderAndUrethra;
        then withdrawInstrument;

        action insertInstrument;
        action startIrrigation;
        action illuminateField;
        action inspectBladderAndUrethra;
        action withdrawInstrument;
    }

    action def PerformStoneFragmentation {
        in item irrigation : IrrigationFluid;
        in item laserPulse : LaserEnergyPulse;
        out item drainage : DrainageFluid;

        first positionScope;
        then confirmStoneVisualization;
        then enableLaserInterlock;
        then deliverPulses;
        then evacuateFragments;
        then disableLaser;

        action positionScope;
        action confirmStoneVisualization;
        action enableLaserInterlock;
        action deliverPulses;
        action evacuateFragments;
        action disableLaser;
    }

    action def PerformTissueResection {
        in attribute cuttingPower : ElectricPowerValue;
        out item sample : ResectedTissueSample;

        first visualizeTarget;
        then energizeLoop;
        then resectTissue;
        then captureSample;
        then stopEnergy;

        action visualizeTarget;
        action energizeLoop;
        action resectTissue;
        action captureSample;
        action stopEnergy;
    }

    state def UrologyInstrumentLifecycle {
        entry; then Packaged;

        state Packaged;
        state Prepared;
        state Inserted;
        state Active;
        state Withdrawn;
        state Reprocessing;
        state Retired;

        transition
            first Packaged
            accept prepareCommand
            then Prepared;

        transition
            first Prepared
            accept insertionConfirmed
            then Inserted;

        transition
            first Inserted
            accept activationRequested
            then Active;

        transition
            first Active
            accept deactivationRequested
            then Inserted;

        transition
            first Inserted
            accept withdrawalConfirmed
            then Withdrawn;

        transition
            first Withdrawn
            accept reprocessRequired
            then Reprocessing;

        transition
            first Reprocessing
            accept cyclePassed
            then Prepared;

        transition
            first Withdrawn
            accept disposeCommand
            then Retired;
    }

    state def IrrigationControlStateMachine {
        entry; then Off;

        state Off;
        state Priming;
        state RegulatedFlow;
        state PressureLimited;
        state Fault;

        transition
            first Off
            accept primeRequested
            then Priming;

        transition
            first Priming
            accept airPurged
            then RegulatedFlow;

        transition
            first RegulatedFlow
            accept pressureAboveLimit
            then PressureLimited;

        transition
            first PressureLimited
            accept pressureRecovered
            then RegulatedFlow;

        transition
            first RegulatedFlow
            accept sensorFault
            then Fault;

        transition
            first PressureLimited
            accept sensorFault
            then Fault;

        transition
            first Fault
            accept resetAfterService
            then Off;
    }

    requirement def PrimaryFunctionRequirement {
        id = "URO-SYS-REQ-001";
        text = "The system shall support minimally invasive urological diagnosis and treatment by providing visualization, controlled irrigation, drainage, energy delivery, tissue manipulation, and sample extraction through compatible urology instruments.";
    }

    requirement def SterilityRequirement {
        id = "URO-SYS-REQ-002";
        text = "The patient-contacting instrument path shall be sterile before insertion and shall provide a reprocessing or disposal path after use.";
    }

    requirement def IrrigationPressureRequirement {
        id = "URO-SYS-REQ-003";
        text = "The irrigation subsystem shall regulate delivered fluid pressure below the configured maximum safe pressure during operation.";
    }

    requirement def VisualizationRequirement {
        id = "URO-SYS-REQ-004";
        text = "The visualization subsystem shall provide real-time endoscopic imagery sufficient for instrument navigation and target identification.";
    }

    requirement def LithotripsySafetyRequirement {
        id = "URO-SYS-REQ-005";
        text = "The lithotripsy subsystem shall deliver laser energy only when the operator requests activation and the safety interlock is satisfied.";
    }

    requirement def TissueSampleRequirement {
        id = "URO-SYS-REQ-006";
        text = "The resection subsystem shall support removal and retention of tissue samples suitable for pathology handling.";
    }

    requirement def StatusMonitoringRequirement {
        id = "URO-SYS-REQ-007";
        text = "The system shall report operational state, irrigation pressure, flow rate, readiness, and active fault status to the operator.";
    }

    satisfy PrimaryFunctionRequirement by UrologyInstrumentSystem;
    satisfy SterilityRequirement by SterileHandlingSubsystem;
    satisfy IrrigationPressureRequirement by IrrigationSubsystem;
    satisfy VisualizationRequirement by VisualizationSubsystem;
    satisfy LithotripsySafetyRequirement by LithotripsySubsystem;
    satisfy TissueSampleRequirement by ResectionSubsystem;
    satisfy StatusMonitoringRequirement by UserControlConsole;

    constraint def SafeIrrigationPressure {
        in attribute measuredPressure : PressureValue;
        in attribute pressureLimit : PressureValue;
        require measuredPressure <= pressureLimit;
    }

    constraint def LaserPowerLimit {
        in attribute selectedPower : ElectricPowerValue;
        in attribute maximumLaserPower : ElectricPowerValue;
        require selectedPower <= maximumLaserPower;
    }

    constraint def AdequateVisualization {
        in attribute horizontalPixels : ImageResolutionValue;
        in attribute verticalPixels : ImageResolutionValue;
        in attribute frameRate : Real;
        require horizontalPixels >= 1280;
        require verticalPixels >= 720;
        require frameRate >= 30.0;
    }

    assert constraint SafeIrrigationPressure {
        measuredPressure = UrologyInstrumentSystem::irrigationSubsystem.measuredPressure;
        pressureLimit = UrologyInstrumentSystem::irrigationSubsystem.pressureLimit;
    }

    assert constraint LaserPowerLimit {
        selectedPower = UrologyInstrumentSystem::lithotripsySubsystem.selectedPower;
        maximumLaserPower = UrologyInstrumentSystem::maximumLaserPower;
    }

    assert constraint AdequateVisualization {
        horizontalPixels = UrologyInstrumentSystem::visualizationSubsystem.imageWidthPixels;
        verticalPixels = UrologyInstrumentSystem::visualizationSubsystem.imageHeightPixels;
        frameRate = UrologyInstrumentSystem::visualizationSubsystem.minimumFrameRate;
    }
}