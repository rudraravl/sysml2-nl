package ThreeDimensionalMicrofabricationModel {
    import ScalarValues::*;

    attribute def MicrometerValue :> Real {
        doc /* Unit: micrometre, symbol um. */
    }

    attribute def NanometerValue :> Real {
        doc /* Unit: nanometre, symbol nm. */
    }

    attribute def FemtosecondValue :> Real {
        doc /* Unit: femtosecond, symbol fs. */
    }

    attribute def MilliwattValue :> Real {
        doc /* Unit: milliwatt, symbol mW. */
    }

    attribute def MillijouleValue :> Real {
        doc /* Unit: millijoule, symbol mJ. */
    }

    attribute def MillipascalSecondValue :> Real {
        doc /* Unit: millipascal second, symbol mPa*s. */
    }

    attribute def CelsiusValue :> Real {
        doc /* Unit: degree Celsius, symbol degC. */
    }

    attribute def KilopascalValue :> Real {
        doc /* Unit: kilopascal, symbol kPa. */
    }

    attribute def VoltValue :> Real {
        doc /* Unit: volt, symbol V. */
    }

    attribute def AmpereValue :> Real {
        doc /* Unit: ampere, symbol A. */
    }

    attribute def HertzValue :> Real {
        doc /* Unit: hertz, symbol Hz. */
    }

    attribute def MicrometerPerSecondValue :> Real {
        doc /* Unit: micrometre per second, symbol um/s. */
    }

    attribute def PercentValue :> Real {
        doc /* Unit: percent, symbol %. */
    }

    attribute def CountValue :> Integer {
        doc /* Unit: count. */
    }

    enum def FabricationMode {
        enum standby;
        enum twoPhotonPolymerization;
        enum layerInspection;
        enum postCure;
        enum maintenance;
        enum faultRecovery;
    }

    item def DigitalMicroDesign {
        attribute designIdentifier : String;
        attribute voxelGridCount : CountValue;
        attribute nominalPartX_um : MicrometerValue;
        attribute nominalPartY_um : MicrometerValue;
        attribute nominalPartZ_um : MicrometerValue;
        attribute targetMinimumFeature_um : MicrometerValue;
        attribute layerThickness_um : MicrometerValue;
        attribute acceptedFileFormat : String;
    }

    item def SlicedToolpath {
        attribute sliceCount : CountValue;
        attribute pointCount : CountValue;
        attribute hatchSpacing_um : MicrometerValue;
        attribute exposureSpeed_um_per_s : MicrometerPerSecondValue;
        attribute layerThickness_um : MicrometerValue;
    }

    item def PhotopolymerResin {
        attribute resinName : String;
        attribute viscosity_mPa_s : MillipascalSecondValue;
        attribute absorptionWavelength_nm : NanometerValue;
        attribute refractiveIndex : Real;
        attribute recommendedDose_mJ : MillijouleValue;
        attribute solidsContent_percent : PercentValue;
    }

    item def FemtosecondPulseTrain {
        attribute centerWavelength_nm : NanometerValue;
        attribute pulseWidth_fs : FemtosecondValue;
        attribute repetitionRate_Hz : HertzValue;
        attribute averagePower_mW : MilliwattValue;
    }

    item def ControlCommand {
        attribute commandIdentifier : String;
        attribute mode : FabricationMode;
        attribute requestedTime_s : Real;
    }

    item def PowerOnCommand :> ControlCommand;
    item def StartFabricationCommand :> ControlCommand;
    item def PauseFabricationCommand :> ControlCommand;
    item def ResumeFabricationCommand :> ControlCommand;
    item def AbortFabricationCommand :> ControlCommand;
    item def MaintenanceCommand :> ControlCommand;

    item def StatusReport {
        attribute mode : FabricationMode;
        attribute ready : Boolean;
        attribute faultPresent : Boolean;
        attribute message : String;
    }

    item def MeasurementData {
        attribute measuredFeatureWidth_um : MicrometerValue;
        attribute measuredLayerHeight_um : MicrometerValue;
        attribute measuredRegistrationError_nm : NanometerValue;
        attribute surfaceDefectCount : CountValue;
        attribute passInspection : Boolean;
    }

    item def EnvironmentalCondition {
        attribute chamberTemperature_degC : CelsiusValue;
        attribute chamberPressure_kPa : KilopascalValue;
        attribute oxygenConcentration_percent : PercentValue;
        attribute relativeHumidity_percent : PercentValue;
    }

    item def ElectricalPower {
        attribute voltage_V : VoltValue;
        attribute current_A : AmpereValue;
        attribute frequency_Hz : HertzValue;
    }

    item def Coolant {
        attribute inletTemperature_degC : CelsiusValue;
        attribute flowRate_L_per_min : Real;
    }

    item def WasteResin {
        attribute collectedVolume_uL : Real;
        attribute contaminationPercent : PercentValue;
    }

    item def MicrofabricatedPart {
        attribute partIdentifier : String;
        attribute actualX_um : MicrometerValue;
        attribute actualY_um : MicrometerValue;
        attribute actualZ_um : MicrometerValue;
        attribute minimumResolvedFeature_um : MicrometerValue;
        attribute layerCount : CountValue;
        attribute releasedFromSubstrate : Boolean;
        attribute postCured : Boolean;
    }

    item def ProcessRecord {
        attribute recordIdentifier : String;
        attribute exposureDuration_s : Real;
        attribute totalLayers : CountValue;
        attribute averageLaserPower_mW : MilliwattValue;
        attribute maximumRegistrationError_nm : NanometerValue;
        attribute finalInspectionPassed : Boolean;
    }

    port def ElectricalPowerPort {
        inout item power : ElectricalPower;
    }

    port def CoolantPort {
        inout item coolant : Coolant;
    }

    port def DesignDataPort {
        inout item design : DigitalMicroDesign;
    }

    port def ToolpathDataPort {
        inout item toolpath : SlicedToolpath;
    }

    port def ControlPort {
        inout item command : ControlCommand;
        inout item status : StatusReport;
    }

    port def MeasurementPort {
        inout item measurement : MeasurementData;
    }

    port def EnvironmentPort {
        inout item condition : EnvironmentalCondition;
    }

    port def ResinPort {
        inout item resin : PhotopolymerResin;
    }

    port def WastePort {
        inout item waste : WasteResin;
    }

    port def OpticalBeamPort {
        inout item beam : FemtosecondPulseTrain;
    }

    port def PartPort {
        inout item microPart : MicrofabricatedPart;
    }

    port def ProcessRecordPort {
        inout item record : ProcessRecord;
    }

    port def MechanicalMountPort {
        inout item positionMeasurement : MeasurementData;
        inout item motionCommand : ControlCommand;
    }

    action def ReceiveDesign {
        in item submittedDesign : DigitalMicroDesign;
        out item acceptedDesign : DigitalMicroDesign;
    }

    action def SliceDesignIntoToolpath {
        in item acceptedDesign : DigitalMicroDesign;
        out item generatedToolpath : SlicedToolpath;
    }

    action def ConditionResin {
        in item rawResin : PhotopolymerResin;
        out item conditionedResin : PhotopolymerResin;
    }

    action def CalibrateLaserAndStage {
        in item command : ControlCommand;
        out item calibrationMeasurement : MeasurementData;
    }

    action def ExposeVoxelPath {
        in item toolpath : SlicedToolpath;
        in item resin : PhotopolymerResin;
        in item pulses : FemtosecondPulseTrain;
        out item partiallyBuiltPart : MicrofabricatedPart;
    }

    action def InspectLayerGeometry {
        in item partiallyBuiltPart : MicrofabricatedPart;
        out item inspectionMeasurement : MeasurementData;
    }

    action def PostCureAndRelease {
        in item partiallyBuiltPart : MicrofabricatedPart;
        out item releasedPart : MicrofabricatedPart;
    }

    action def GenerateProcessRecord {
        in item finalPart : MicrofabricatedPart;
        in item finalMeasurement : MeasurementData;
        out item processRecord : ProcessRecord;
    }

    action def FabricateThreeDimensionalMicrostructure {
        doc /* Primary high-level function: transform a digital three-dimensional microdesign and photopolymer resin into a precise released three-dimensional microfabricated part through coordinated ultrafast optical exposure, nanoscale positioning, in-process metrology, and post-cure. */

        in item design : DigitalMicroDesign;
        in item resin : PhotopolymerResin;
        in item startCommand : StartFabricationCommand;
        out item completedPart : MicrofabricatedPart;
        out item record : ProcessRecord;

        action receiveDesign : ReceiveDesign;
        action sliceDesign : SliceDesignIntoToolpath;
        action conditionResin : ConditionResin;
        action calibrate : CalibrateLaserAndStage;
        action expose : ExposeVoxelPath;
        action inspect : InspectLayerGeometry;
        action postCureAndRelease : PostCureAndRelease;
        action generateRecord : GenerateProcessRecord;

        succession s1 first receiveDesign then sliceDesign;
        succession s2 first sliceDesign then conditionResin;
        succession s3 first conditionResin then calibrate;
        succession s4 first calibrate then expose;
        succession s5 first expose then inspect;
        succession s6 first inspect then postCureAndRelease;
        succession s7 first postCureAndRelease then generateRecord;
    }

    state def MicrofabricationLifecycle {
        state off;
        state idle;
        state loadingDesign;
        state preparingMaterial;
        state calibrating;
        state fabricating;
        state inspecting;
        state postCuring;
        state complete;
        state paused;
        state fault;
        state maintenance;

        transition initialTransition first off then idle;
        transition startLoading first idle accept StartFabricationCommand then loadingDesign;
        transition materialPreparation first loadingDesign then preparingMaterial;
        transition calibrationStart first preparingMaterial then calibrating;
        transition fabricationStart first calibrating then fabricating;
        transition inspectionStart first fabricating then inspecting;
        transition postCureStart first inspecting then postCuring;
        transition completion first postCuring then complete;
        transition resetToIdle first complete then idle;
        transition pauseFabrication first fabricating accept PauseFabricationCommand then paused;
        transition resumeFabrication first paused accept ResumeFabricationCommand then fabricating;
        transition abortFromFabrication first fabricating accept AbortFabricationCommand then fault;
        transition abortFromPaused first paused accept AbortFabricationCommand then fault;
        transition enterMaintenance first idle accept MaintenanceCommand then maintenance;
        transition exitMaintenance first maintenance then idle;
    }

    part def ProcessController {
        port designIn : DesignDataPort;
        port toolpathOut : ToolpathDataPort;
        port operatorControl : ControlPort;
        port laserControl : ControlPort;
        port opticsControl : ControlPort;
        port stageControl : ControlPort;
        port materialControl : ControlPort;
        port chamberControl : ControlPort;
        port metrologyControl : ControlPort;
        port postCureControl : ControlPort;
        port measurementIn : MeasurementPort;
        port recordOut : ProcessRecordPort;

        attribute processorClock_Hz : HertzValue = 2400000000.0;
        attribute closedLoopUpdateRate_Hz : HertzValue = 1000.0;
        attribute maximumAllowedRegistrationError_nm : NanometerValue = 100.0;
        attribute currentMode : FabricationMode = FabricationMode::standby;

        perform action fabricationWorkflow : FabricateThreeDimensionalMicrostructure;
        exhibit state lifecycle : MicrofabricationLifecycle;
    }

    part def UltrafastLaserSource {
        port electricalPowerIn : ElectricalPowerPort;
        port coolantIn : CoolantPort;
        port control : ControlPort;
        port beamOut : OpticalBeamPort;

        attribute centerWavelength_nm : NanometerValue = 780.0;
        attribute pulseWidth_fs : FemtosecondValue = 120.0;
        attribute repetitionRate_Hz : HertzValue = 80000000.0;
        attribute nominalAveragePower_mW : MilliwattValue = 450.0;
        attribute powerStability_percent : PercentValue = 1.0;
    }

    part def BeamDeliverySubsystem {
        port beamIn : OpticalBeamPort;
        port beamOut : OpticalBeamPort;
        port control : ControlPort;
        port measurementOut : MeasurementPort;

        attribute objectiveNumericalAperture : Real = 1.40;
        attribute galvoSettlingTime_ms : Real = 0.5;
        attribute focusSpotDiameter_um : MicrometerValue = 0.35;
        attribute beamPointingStability_nm : NanometerValue = 50.0;
    }

    part def NanoPositioningStage {
        port control : ControlPort;
        port mount : MechanicalMountPort;
        port measurementOut : MeasurementPort;

        attribute travelX_um : MicrometerValue = 500.0;
        attribute travelY_um : MicrometerValue = 500.0;
        attribute travelZ_um : MicrometerValue = 300.0;
        attribute bidirectionalRepeatability_nm : NanometerValue = 25.0;
        attribute maximumScanSpeed_um_per_s : MicrometerPerSecondValue = 20000.0;
    }

    part def MaterialHandlingSubsystem {
        port resinIn : ResinPort;
        port conditionedResinOut : ResinPort;
        port wasteOut : WastePort;
        port control : ControlPort;

        attribute reservoirCapacity_uL : Real = 250.0;
        attribute dispenseResolution_uL : Real = 0.05;
        attribute filterPoreSize_um : MicrometerValue = 0.2;
        attribute resinTemperatureSetpoint_degC : CelsiusValue = 23.0;
    }

    part def ProcessChamber {
        port resinIn : ResinPort;
        port beamIn : OpticalBeamPort;
        port stageMount : MechanicalMountPort;
        port environment : EnvironmentPort;
        port control : ControlPort;
        port partOut : PartPort;
        port wasteOut : WastePort;

        attribute nominalTemperature_degC : CelsiusValue = 23.0;
        attribute nominalPressure_kPa : KilopascalValue = 101.3;
        attribute maximumOxygenConcentration_percent : PercentValue = 1.0;
        attribute cleanZoneParticleLimit_per_m3 : Real = 3520.0;

        part buildSubstrate {
            attribute substrateDiameter_um : MicrometerValue = 10000.0;
            attribute substrateFlatness_nm : NanometerValue = 100.0;
            attribute surfaceTreatment : String = "silane adhesion promoter";
        }
    }

    part def InProcessMetrologySubsystem {
        port control : ControlPort;
        port partIn : PartPort;
        port measurementOut : MeasurementPort;

        attribute lateralResolution_nm : NanometerValue = 200.0;
        attribute axialResolution_nm : NanometerValue = 500.0;
        attribute measurementFieldX_um : MicrometerValue = 250.0;
        attribute measurementFieldY_um : MicrometerValue = 250.0;
        attribute inspectionUpdateRate_Hz : HertzValue = 10.0;
    }

    part def PostCureAndReleaseSubsystem {
        port control : ControlPort;
        port partIn : PartPort;
        port partOut : PartPort;
        port wasteOut : WastePort;

        attribute uvWavelength_nm : NanometerValue = 365.0;
        attribute uvPower_mW : MilliwattValue = 100.0;
        attribute postCureDuration_s : Real = 120.0;
        attribute releaseBathTemperature_degC : CelsiusValue = 25.0;
    }

    part def FacilityServices {
        port electricalPowerOut : ElectricalPowerPort;
        port coolantOut : CoolantPort;
        port environmentOut : EnvironmentPort;

        attribute supplyVoltage_V : VoltValue = 230.0;
        attribute supplyCurrent_A : AmpereValue = 16.0;
        attribute coolantTemperature_degC : CelsiusValue = 20.0;
        attribute roomTemperature_degC : CelsiusValue = 22.0;
    }

    part def OperatorStation {
        port designOut : DesignDataPort;
        port commandAndStatus : ControlPort;
        port recordIn : ProcessRecordPort;

        attribute displayResolutionPixels : CountValue = 3840;
        attribute supportedDesignFormat : String = "STL, STEP, OASIS";
    }

    part def ThreeDimensionalMicrofabricationSystem {
        doc /* System based on three-dimensional microfabrication using two-photon polymerization. Its primary function is to create high-resolution three-dimensional microstructures from digital geometry and photosensitive resin. */

        port designInput : DesignDataPort;
        port commandInterface : ControlPort;
        port microPartOutput : PartPort;
        port processRecordOutput : ProcessRecordPort;
        port resinInput : ResinPort;
        port wasteOutput : WastePort;
        port facilityPowerInput : ElectricalPowerPort;
        port facilityCoolantInput : CoolantPort;
        port facilityEnvironmentInput : EnvironmentPort;

        attribute nominalBuildVolumeX_um : MicrometerValue = 500.0;
        attribute nominalBuildVolumeY_um : MicrometerValue = 500.0;
        attribute nominalBuildVolumeZ_um : MicrometerValue = 300.0;
        attribute minimumPrintableFeature_um : MicrometerValue = 0.7;
        attribute nominalLayerThickness_um : MicrometerValue = 0.5;
        attribute nominalThroughputPartsPerHour : Real = 4.0;
        attribute primaryFunctionStatement : String = "Convert a digital 3D microdesign and photopolymer resin into a precise released 3D microfabricated part.";

        part controller : ProcessController;
        part laser : UltrafastLaserSource;
        part beamDelivery : BeamDeliverySubsystem;
        part stage : NanoPositioningStage;
        part materialHandling : MaterialHandlingSubsystem;
        part chamber : ProcessChamber;
        part metrology : InProcessMetrologySubsystem;
        part postCureRelease : PostCureAndReleaseSubsystem;

        connection designToController connect designInput to controller.designIn;
        connection commandToController connect commandInterface to controller.operatorControl;
        connection recordFromController connect controller.recordOut to processRecordOutput;

        connection powerToLaser connect facilityPowerInput to laser.electricalPowerIn;
        connection coolantToLaser connect facilityCoolantInput to laser.coolantIn;
        connection environmentToChamber connect facilityEnvironmentInput to chamber.environment;

        connection controllerToLaser connect controller.laserControl to laser.control;
        connection controllerToOptics connect controller.opticsControl to beamDelivery.control;
        connection controllerToStage connect controller.stageControl to stage.control;
        connection controllerToMaterialHandling connect controller.materialControl to materialHandling.control;
        connection controllerToChamber connect controller.chamberControl to chamber.control;
        connection controllerToMetrology connect controller.metrologyControl to metrology.control;
        connection controllerToPostCure connect controller.postCureControl to postCureRelease.control;

        connection laserBeamToOptics connect laser.beamOut to beamDelivery.beamIn;
        connection focusedBeamToChamber connect beamDelivery.beamOut to chamber.beamIn;

        connection resinFeedToMaterialHandling connect resinInput to materialHandling.resinIn;
        connection conditionedResinToChamber connect materialHandling.conditionedResinOut to chamber.resinIn;
        connection chamberWasteToWasteOutput connect chamber.wasteOut to wasteOutput;
        connection postCureWasteToWasteOutput connect postCureRelease.wasteOut to wasteOutput;

        connection stageToChamberMount connect stage.mount to chamber.stageMount;
        connection chamberPartToMetrology connect chamber.partOut to metrology.partIn;
        connection chamberPartToPostCure connect chamber.partOut to postCureRelease.partIn;
        connection finalPartOutput connect postCureRelease.partOut to microPartOutput;

        connection opticsMeasurementToController connect beamDelivery.measurementOut to controller.measurementIn;
        connection stageMeasurementToController connect stage.measurementOut to controller.measurementIn;
        connection metrologyMeasurementToController connect metrology.measurementOut to controller.measurementIn;

        perform action primaryFabricationFunction : FabricateThreeDimensionalMicrostructure;
        exhibit state operationalLifecycle : MicrofabricationLifecycle;
    }

    constraint def BuildVolumeAdequacy {
        in x_um : MicrometerValue;
        in y_um : MicrometerValue;
        in z_um : MicrometerValue;
        in requiredX_um : MicrometerValue;
        in requiredY_um : MicrometerValue;
        in requiredZ_um : MicrometerValue;

        require constraint {
            x_um >= requiredX_um and y_um >= requiredY_um and z_um >= requiredZ_um
        }
    }

    constraint def ResolutionAdequacy {
        in printableFeature_um : MicrometerValue;
        in requiredFeature_um : MicrometerValue;

        require constraint {
            printableFeature_um <= requiredFeature_um
        }
    }

    constraint def LayerThicknessAdequacy {
        in layerThickness_um : MicrometerValue;
        in requiredLayerThickness_um : MicrometerValue;

        require constraint {
            layerThickness_um <= requiredLayerThickness_um
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The three-dimensional microfabrication system shall perform the high-level function of converting digital micro-scale geometry and photosensitive material into a released, inspected, three-dimensional microfabricated part. */

        subject system : ThreeDimensionalMicrofabricationSystem;

        require constraint {
            system.primaryFunctionStatement == "Convert a digital 3D microdesign and photopolymer resin into a precise released 3D microfabricated part."
        }
    }

    requirement def MicrofabricationPerformanceRequirement {
        doc /* The system shall support sub-micrometre feature fabrication within a micro-scale build volume sufficient for representative microdevices. */

        subject system : ThreeDimensionalMicrofabricationSystem;

        require constraint {
            system.minimumPrintableFeature_um <= 1.0 and
            system.nominalLayerThickness_um <= 1.0 and
            system.nominalBuildVolumeX_um >= 200.0 and
            system.nominalBuildVolumeY_um >= 200.0 and
            system.nominalBuildVolumeZ_um >= 100.0
        }
    }

    requirement def InProcessInspectionRequirement {
        doc /* The system shall include in-process metrology capable of detecting layer geometry and registration errors before post-cure release. */

        subject metrology : InProcessMetrologySubsystem;

        require constraint {
            metrology.lateralResolution_nm <= 250.0 and
            metrology.axialResolution_nm <= 750.0 and
            metrology.inspectionUpdateRate_Hz >= 1.0
        }
    }

    part microfabricationWorkcell : ThreeDimensionalMicrofabricationSystem {
        attribute nominalBuildVolumeX_um = 500.0;
        attribute nominalBuildVolumeY_um = 500.0;
        attribute nominalBuildVolumeZ_um = 300.0;
        attribute minimumPrintableFeature_um = 0.7;
        attribute nominalLayerThickness_um = 0.5;
        attribute nominalThroughputPartsPerHour = 4.0;
    }

    part facility : FacilityServices;
    part operatorStation : OperatorStation;

    connection operatorDesignToWorkcell connect operatorStation.designOut to microfabricationWorkcell.designInput;
    connection operatorCommandToWorkcell connect operatorStation.commandAndStatus to microfabricationWorkcell.commandInterface;
    connection workcellRecordToOperator connect microfabricationWorkcell.processRecordOutput to operatorStation.recordIn;

    connection facilityPowerToWorkcell connect facility.electricalPowerOut to microfabricationWorkcell.facilityPowerInput;
    connection facilityCoolantToWorkcell connect facility.coolantOut to microfabricationWorkcell.facilityCoolantInput;
    connection facilityEnvironmentToWorkcell connect facility.environmentOut to microfabricationWorkcell.facilityEnvironmentInput;

    requirement primaryFunctionReq : PrimaryFunctionRequirement {
        subject system = microfabricationWorkcell;
    }

    requirement performanceReq : MicrofabricationPerformanceRequirement {
        subject system = microfabricationWorkcell;
    }

    requirement inspectionReq : InProcessInspectionRequirement {
        subject metrology = microfabricationWorkcell.metrology;
    }

    satisfy primaryFunctionReq by microfabricationWorkcell;
    satisfy performanceReq by microfabricationWorkcell;
    satisfy inspectionReq by microfabricationWorkcell.metrology;
}
