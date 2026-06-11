package FetoscopySystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Length :> ISQ::length {
        unit = SI::metre;
    }

    attribute def Diameter :> ISQ::length {
        unit = SI::millimetre;
    }

    attribute def VolumeFlowRate {
        unit = SI::litre / SI::minute;
    }

    attribute def Pressure {
        unit = SI::pascal;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::degreeCelsius;
    }

    attribute def OpticalPower {
        unit = SI::watt;
    }

    attribute def ElectricalPower {
        unit = SI::watt;
    }

    attribute def TimeDuration :> ISQ::time {
        unit = SI::second;
    }

    attribute def ImageResolution {
        width : Integer;
        height : Integer;
    }

    item def SterileIrrigationFluid {
        attribute temperature : Temperature;
        attribute flowRate : VolumeFlowRate;
        attribute pressure : Pressure;
    }

    item def AmnioticFluid {
        attribute temperature : Temperature;
        attribute pressure : Pressure;
    }

    item def EndoscopicImageFrame {
        attribute resolution : ImageResolution;
        attribute frameRate : Real;
        attribute illuminationLevel : Real;
    }

    item def ControlCommand {
        attribute commandId : String;
        attribute commandValue : Real;
    }

    item def ClinicalObservation {
        attribute findingText : String;
        attribute timestamp : TimeDuration;
        attribute confidence : Real;
    }

    item def LaserEnergy {
        attribute power : OpticalPower;
        attribute wavelength : Length;
        attribute pulseDuration : TimeDuration;
    }

    port def OpticalImagingPort {
        out item frame : EndoscopicImageFrame;
    }

    port def IlluminationPort {
        out item opticalFlux : LaserEnergy;
    }

    port def FluidPort {
        inout item fluid : SterileIrrigationFluid;
    }

    port def AmnioticAccessPort {
        inout item medium : AmnioticFluid;
        out item image : EndoscopicImageFrame;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def ObservationPort {
        out item observation : ClinicalObservation;
    }

    port def PowerPort {
        in item power : ElectricalPower;
    }

    part def FetoscopySystem {
        attribute primaryFunction : String = "Provide minimally invasive visual access to the fetus, placenta, umbilical cord, and amniotic cavity to support diagnosis and targeted intrauterine intervention.";
        attribute nominalOuterDiameter : Diameter = 3.3 [SI::millimetre];
        attribute maximumInsertionLength : Length = 0.35 [SI::metre];

        port operatorCommand : CommandPort;
        port powerInput : PowerPort;
        port clinicalOutput : ObservationPort;
        port uterineInterface : AmnioticAccessPort;

        part fetoscope : Fetoscope;
        part imagingConsole : ImagingConsole;
        part illuminationSource : IlluminationSource;
        part irrigationPump : IrrigationPump;
        part accessCannula : AccessCannula;
        part procedureController : ProcedureController;
        part optionalLaserModule : LaserTherapyModule;

        connect powerInput to imagingConsole.powerInput;
        connect powerInput to illuminationSource.powerInput;
        connect powerInput to irrigationPump.powerInput;
        connect powerInput to procedureController.powerInput;
        connect operatorCommand to procedureController.commandInput;

        connect procedureController.scopeCommand to fetoscope.commandInput;
        connect procedureController.pumpCommand to irrigationPump.commandInput;
        connect procedureController.lightCommand to illuminationSource.commandInput;
        connect procedureController.laserCommand to optionalLaserModule.commandInput;

        connect illuminationSource.lightOutput to fetoscope.lightInput;
        connect fetoscope.imageOutput to imagingConsole.imageInput;
        connect imagingConsole.observationOutput to clinicalOutput;

        connect irrigationPump.fluidOutput to fetoscope.fluidInput;
        connect fetoscope.distalAccess to accessCannula.scopeAccess;
        connect accessCannula.uterineAccess to uterineInterface;

        connect optionalLaserModule.energyOutput to fetoscope.therapyInput;

        perform procedureController.manageProcedure;
        perform imagingConsole.processVisualization;
        perform fetoscope.navigateAndObserve;
    }

    part def Fetoscope {
        attribute outerDiameter : Diameter = 2.0 [SI::millimetre];
        attribute workingChannelDiameter : Diameter = 1.2 [SI::millimetre];
        attribute fieldOfView : Real = 90.0;
        attribute insertionDepth : Length;
        attribute lensTemperature : Temperature;

        port commandInput : CommandPort;
        port lightInput : IlluminationPort;
        port fluidInput : FluidPort;
        port therapyInput : IlluminationPort;
        port imageOutput : OpticalImagingPort;
        port distalAccess : AmnioticAccessPort;

        part distalLens : DistalLens;
        part fiberBundle : FiberOpticBundle;
        part workingChannel : WorkingChannel;
        part steeringSection : SteeringSection;

        connect lightInput to fiberBundle.lightInput;
        connect fiberBundle.lightOutput to distalLens.illuminationInput;
        connect distalLens.imageOutput to imageOutput;
        connect fluidInput to workingChannel.fluidPort;
        connect workingChannel.distalPort to distalAccess;
        connect therapyInput to workingChannel.therapyPort;

        action navigateAndObserve {
            in item command : ControlCommand;
            out item frame : EndoscopicImageFrame;
            first start;
            then adjustSteering;
            then illuminateField;
            then acquireImage;
            then transmitImage;
            then done;

            action adjustSteering;
            action illuminateField;
            action acquireImage;
            action transmitImage;
        }

        state def ScopeOperationalState {
            state Sterile;
            state Inserted;
            state Navigating;
            state Imaging;
            state Irrigating;
            state TherapyReady;
            state Withdrawn;

            initial then Sterile;

            transition Sterile_to_Inserted
                first Sterile
                accept ControlCommand
                if command.commandId == "insert"
                then Inserted;

            transition Inserted_to_Navigating
                first Inserted
                accept ControlCommand
                if command.commandId == "steer"
                then Navigating;

            transition Navigating_to_Imaging
                first Navigating
                accept ControlCommand
                if command.commandId == "capture"
                then Imaging;

            transition Imaging_to_Irrigating
                first Imaging
                accept ControlCommand
                if command.commandId == "irrigate"
                then Irrigating;

            transition Imaging_to_TherapyReady
                first Imaging
                accept ControlCommand
                if command.commandId == "enableTherapy"
                then TherapyReady;

            transition TherapyReady_to_Imaging
                first TherapyReady
                accept ControlCommand
                if command.commandId == "disableTherapy"
                then Imaging;

            transition Imaging_to_Withdrawn
                first Imaging
                accept ControlCommand
                if command.commandId == "withdraw"
                then Withdrawn;
        }
    }

    part def DistalLens {
        attribute focalLength : Length = 1.8 [SI::millimetre];
        attribute lensDiameter : Diameter = 1.0 [SI::millimetre];

        port illuminationInput : IlluminationPort;
        port imageOutput : OpticalImagingPort;
    }

    part def FiberOpticBundle {
        attribute transmissionEfficiency : Real = 0.82;

        port lightInput : IlluminationPort;
        port lightOutput : IlluminationPort;
    }

    part def WorkingChannel {
        attribute channelDiameter : Diameter = 1.2 [SI::millimetre];

        port fluidPort : FluidPort;
        port therapyPort : IlluminationPort;
        port distalPort : AmnioticAccessPort;
    }

    part def SteeringSection {
        attribute maximumDeflectionAngle : Real = 45.0;
        attribute responseTime : TimeDuration = 0.4 [SI::second];
    }

    part def ImagingConsole {
        attribute displayedResolution : ImageResolution = (width = 1920, height = 1080);
        attribute nominalFrameRate : Real = 30.0;

        port powerInput : PowerPort;
        port imageInput : OpticalImagingPort;
        port observationOutput : ObservationPort;

        action processVisualization {
            in item frame : EndoscopicImageFrame;
            out item observation : ClinicalObservation;
            first receiveFrame;
            then correctColor;
            then enhanceContrast;
            then displayAnatomy;
            then recordObservation;
            then done;

            action receiveFrame;
            action correctColor;
            action enhanceContrast;
            action displayAnatomy;
            action recordObservation;
        }
    }

    part def IlluminationSource {
        attribute adjustablePower : OpticalPower = 5.0 [SI::watt];
        attribute maximumPower : OpticalPower = 10.0 [SI::watt];

        port powerInput : PowerPort;
        port commandInput : CommandPort;
        port lightOutput : IlluminationPort;
    }

    part def IrrigationPump {
        attribute minimumFlowRate : VolumeFlowRate = 0.02 [SI::litre / SI::minute];
        attribute maximumFlowRate : VolumeFlowRate = 0.20 [SI::litre / SI::minute];
        attribute pressureLimit : Pressure = 4000.0 [SI::pascal];

        port powerInput : PowerPort;
        port commandInput : CommandPort;
        port fluidOutput : FluidPort;

        state def PumpState {
            state Off;
            state Priming;
            state FlowControlled;
            state PressureLimited;
            state Fault;

            initial then Off;

            transition Off_to_Priming
                first Off
                accept ControlCommand
                if command.commandId == "prime"
                then Priming;

            transition Priming_to_FlowControlled
                first Priming
                accept ControlCommand
                if command.commandId == "startFlow"
                then FlowControlled;

            transition FlowControlled_to_PressureLimited
                first FlowControlled
                if fluid.pressure > pressureLimit
                then PressureLimited;

            transition PressureLimited_to_FlowControlled
                first PressureLimited
                if fluid.pressure <= pressureLimit
                then FlowControlled;

            transition FlowControlled_to_Off
                first FlowControlled
                accept ControlCommand
                if command.commandId == "stopFlow"
                then Off;

            transition PressureLimited_to_Fault
                first PressureLimited
                if fluid.pressure > 1.25 * pressureLimit
                then Fault;
        }
    }

    part def AccessCannula {
        attribute cannulaOuterDiameter : Diameter = 3.3 [SI::millimetre];
        attribute sealingPressureCapacity : Pressure = 5000.0 [SI::pascal];

        port scopeAccess : AmnioticAccessPort;
        port uterineAccess : AmnioticAccessPort;
    }

    part def LaserTherapyModule {
        attribute wavelength : Length = 0.000000532 [SI::metre];
        attribute maximumPower : OpticalPower = 30.0 [SI::watt];
        attribute enabled : Boolean = false;

        port powerInput : PowerPort;
        port commandInput : CommandPort;
        port energyOutput : IlluminationPort;

        state def LaserSafetyState {
            state Disabled;
            state Armed;
            state Emitting;
            state LockedOut;

            initial then Disabled;

            transition Disabled_to_Armed
                first Disabled
                accept ControlCommand
                if command.commandId == "armLaser"
                then Armed;

            transition Armed_to_Emitting
                first Armed
                accept ControlCommand
                if command.commandId == "fireLaser"
                then Emitting;

            transition Emitting_to_Armed
                first Emitting
                accept ControlCommand
                if command.commandId == "stopLaser"
                then Armed;

            transition Armed_to_Disabled
                first Armed
                accept ControlCommand
                if command.commandId == "disarmLaser"
                then Disabled;

            transition Emitting_to_LockedOut
                first Emitting
                if energyOutput.opticalFlux.power > maximumPower
                then LockedOut;
        }
    }

    part def ProcedureController {
        attribute activeMode : String = "standby";
        attribute maximumProcedureDuration : TimeDuration = 7200.0 [SI::second];

        port powerInput : PowerPort;
        port commandInput : CommandPort;
        port scopeCommand : CommandPort;
        port pumpCommand : CommandPort;
        port lightCommand : CommandPort;
        port laserCommand : CommandPort;

        action manageProcedure {
            first initializeSystem;
            then verifySterility;
            then coordinateInsertion;
            then regulateIllumination;
            then regulateIrrigation;
            then supportObservation;
            then coordinateWithdrawal;
            then done;

            action initializeSystem;
            action verifySterility;
            action coordinateInsertion;
            action regulateIllumination;
            action regulateIrrigation;
            action supportObservation;
            action coordinateWithdrawal;
        }

        state def ProcedureState {
            state Standby;
            state PreProcedureCheck;
            state AccessEstablished;
            state VisualizationActive;
            state InterventionActive;
            state Completed;
            state Aborted;

            initial then Standby;

            transition Standby_to_PreProcedureCheck
                first Standby
                accept ControlCommand
                if command.commandId == "startProcedure"
                then PreProcedureCheck;

            transition PreProcedureCheck_to_AccessEstablished
                first PreProcedureCheck
                accept ControlCommand
                if command.commandId == "confirmAccess"
                then AccessEstablished;

            transition AccessEstablished_to_VisualizationActive
                first AccessEstablished
                accept ControlCommand
                if command.commandId == "beginVisualization"
                then VisualizationActive;

            transition VisualizationActive_to_InterventionActive
                first VisualizationActive
                accept ControlCommand
                if command.commandId == "beginIntervention"
                then InterventionActive;

            transition InterventionActive_to_VisualizationActive
                first InterventionActive
                accept ControlCommand
                if command.commandId == "endIntervention"
                then VisualizationActive;

            transition VisualizationActive_to_Completed
                first VisualizationActive
                accept ControlCommand
                if command.commandId == "completeProcedure"
                then Completed;

            transition PreProcedureCheck_to_Aborted
                first PreProcedureCheck
                accept ControlCommand
                if command.commandId == "abort"
                then Aborted;

            transition VisualizationActive_to_Aborted
                first VisualizationActive
                accept ControlCommand
                if command.commandId == "abort"
                then Aborted;

            transition InterventionActive_to_Aborted
                first InterventionActive
                accept ControlCommand
                if command.commandId == "abort"
                then Aborted;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The fetoscopy system shall provide minimally invasive direct visualization of fetal, placental, umbilical cord, and amniotic cavity anatomy through a controlled uterine access path. */
    }

    requirement def ImageQualityRequirement {
        doc /* The fetoscopy system shall provide real-time endoscopic video with at least 1280 by 720 pixel resolution at no less than 25 frames per second during visualization. */
        require constraint {
            FetoscopySystem::imagingConsole.displayedResolution.width >= 1280 and
            FetoscopySystem::imagingConsole.displayedResolution.height >= 720 and
            FetoscopySystem::imagingConsole.nominalFrameRate >= 25.0
        }
    }

    requirement def DiameterRequirement {
        doc /* The fetoscopy system shall limit the inserted scope diameter to support minimally invasive access. */
        require constraint {
            FetoscopySystem::fetoscope.outerDiameter <= 2.2 [SI::millimetre]
        }
    }

    requirement def IrrigationSafetyRequirement {
        doc /* The irrigation subsystem shall limit intra-amniotic irrigation pressure to reduce the risk of overdistension. */
        require constraint {
            FetoscopySystem::irrigationPump.pressureLimit <= 4000.0 [SI::pascal]
        }
    }

    requirement def IlluminationSafetyRequirement {
        doc /* The illumination subsystem shall provide adjustable visible illumination while limiting optical output to reduce thermal exposure. */
        require constraint {
            FetoscopySystem::illuminationSource.maximumPower <= 10.0 [SI::watt]
        }
    }

    requirement def LaserInterlockRequirement {
        doc /* If therapeutic laser delivery is used, laser emission shall occur only when the therapy module is armed and commanded by the procedure controller. */
    }

    requirement def SterileFluidRequirement {
        doc /* The fetoscopy system shall deliver sterile irrigation fluid through the working channel to maintain visual clarity in the amniotic cavity. */
    }

    requirement def ObservationOutputRequirement {
        doc /* The fetoscopy system shall produce clinical observations derived from real-time endoscopic images for operator assessment and documentation. */
    }

    satisfy PrimaryFunctionRequirement by FetoscopySystem;
    satisfy ImageQualityRequirement by ImagingConsole;
    satisfy DiameterRequirement by Fetoscope;
    satisfy IrrigationSafetyRequirement by IrrigationPump;
    satisfy IlluminationSafetyRequirement by IlluminationSource;
    satisfy LaserInterlockRequirement by LaserTherapyModule;
    satisfy SterileFluidRequirement by IrrigationPump;
    satisfy ObservationOutputRequirement by ImagingConsole;

    package OperationalScenario {
        action def PerformDiagnosticFetoscopy {
            in item operatorStart : ControlCommand;
            out item documentedObservation : ClinicalObservation;

            first prepareSystem;
            then establishUterineAccess;
            then insertFetoscope;
            then illuminateAmnioticCavity;
            then irrigateForClarity;
            then inspectFetalAndPlacentalStructures;
            then documentFindings;
            then withdrawScope;
            then done;

            action prepareSystem;
            action establishUterineAccess;
            action insertFetoscope;
            action illuminateAmnioticCavity;
            action irrigateForClarity;
            action inspectFetalAndPlacentalStructures;
            action documentFindings;
            action withdrawScope;
        }

        part diagnosticUseCase : FetoscopySystem {
            perform PerformDiagnosticFetoscopy;
        }
    }
}