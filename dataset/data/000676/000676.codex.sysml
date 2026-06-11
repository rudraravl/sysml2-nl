package MediastinoscopeSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def LengthValue :> ISQ::length {
        unit = SI::millimetre;
    }

    attribute def DiameterValue :> ISQ::length {
        unit = SI::millimetre;
    }

    attribute def AngleValue :> ISQ::planeAngle {
        unit = SI::degree;
    }

    attribute def LuminousFluxValue :> ISQ::luminousFlux {
        unit = SI::lumen;
    }

    attribute def TemperatureValue :> ISQ::thermodynamicTemperature {
        unit = SI::degreeCelsius;
    }

    attribute def VoltageValue :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def PowerValue :> ISQ::power {
        unit = SI::watt;
    }

    attribute def PressureValue :> ISQ::pressure {
        unit = SI::kilopascal;
    }

    item def OpticalImage {
        attribute resolutionWidth : Integer;
        attribute resolutionHeight : Integer;
        attribute fieldOfView : AngleValue;
        attribute illuminationLevel : LuminousFluxValue;
    }

    item def LightEnergy {
        attribute luminousFlux : LuminousFluxValue;
        attribute colorTemperature : TemperatureValue;
    }

    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute power : PowerValue;
    }

    item def TissueSample {
        attribute sampleDiameter : DiameterValue;
        attribute sampleLength : LengthValue;
        attribute sourceRegion : String;
    }

    item def InstrumentCommand {
        attribute commandName : String;
        attribute commandTime : Real;
    }

    item def SterileBarrierStatus {
        attribute isSterile : Boolean;
        attribute integrityConfirmed : Boolean;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def LightOutputPort {
        out item light : LightEnergy;
    }

    port def ImageOutputPort {
        out item image : OpticalImage;
    }

    port def ToolChannelPort {
        in item command : InstrumentCommand;
        out item sample : TissueSample;
    }

    port def PatientInterfacePort {
        out item light : LightEnergy;
        out item image : OpticalImage;
        inout item tissueSample : TissueSample;
    }

    port def SterilityStatusPort {
        out item status : SterileBarrierStatus;
    }

    part def LightSource {
        attribute maximumFlux : LuminousFluxValue = 900 [SI::lumen];
        attribute operatingPower : PowerValue = 12 [SI::watt];
        port powerIn : PowerInputPort;
        port lightOut : LightOutputPort;

        action emitColdLight {
            in item electricalPower : ElectricalPower;
            out item emittedLight : LightEnergy;
        }
    }

    part def OpticalScope {
        attribute shaftLength : LengthValue = 160 [SI::millimetre];
        attribute outerDiameter : DiameterValue = 10 [SI::millimetre];
        attribute viewingAngle : AngleValue = 0 [SI::degree];
        attribute fieldOfView : AngleValue = 70 [SI::degree];
        port lightIn : LightOutputPort;
        port imageOut : ImageOutputPort;
        port patientEnd : PatientInterfacePort;

        action transmitIlluminatedView {
            in item incidentLight : LightEnergy;
            out item mediastinalImage : OpticalImage;
        }
    }

    part def WorkingChannel {
        attribute innerDiameter : DiameterValue = 5 [SI::millimetre];
        attribute usableLength : LengthValue = 150 [SI::millimetre];
        port toolPort : ToolChannelPort;
        port patientEnd : PatientInterfacePort;

        action passBiopsyInstrument {
            in item command : InstrumentCommand;
            out item sample : TissueSample;
        }
    }

    part def HandleAssembly {
        attribute gripDiameter : DiameterValue = 32 [SI::millimetre];
        port commandPort : ToolChannelPort;
        port powerPort : PowerInputPort;

        action stabilizeScope {
            in item surgeonCommand : InstrumentCommand;
        }
    }

    part def CameraAdapter {
        attribute sensorWidthPixels : Integer = 1920;
        attribute sensorHeightPixels : Integer = 1080;
        port imageIn : ImageOutputPort;
        port videoOut : ImageOutputPort;

        action convertOpticalImageToVideo {
            in item opticalImage : OpticalImage;
            out item videoFrame : OpticalImage;
        }
    }

    part def SterileSheath {
        attribute minimumBarrierLength : LengthValue = 180 [SI::millimetre];
        attribute maximumAllowedLeakPressure : PressureValue = 0 [SI::kilopascal];
        port statusOut : SterilityStatusPort;

        action verifyBarrierIntegrity {
            out item status : SterileBarrierStatus;
        }
    }

    part def MediastinalAccessPath {
        attribute nominalIncisionLength : LengthValue = 25 [SI::millimetre];
        attribute targetDepth : LengthValue = 80 [SI::millimetre];
        port patientInterface : PatientInterfacePort;
    }

    part def Mediastinoscope {
        attribute overallLength : LengthValue = 220 [SI::millimetre];
        attribute shaftOuterDiameter : DiameterValue = 10 [SI::millimetre];
        attribute maximumDistalTemperature : TemperatureValue = 41 [SI::degreeCelsius];

        port externalPower : PowerInputPort;
        port externalCommand : ToolChannelPort;
        port videoOutput : ImageOutputPort;
        port patientInterface : PatientInterfacePort;
        port sterilityOutput : SterilityStatusPort;

        part lightSource : LightSource;
        part opticalScope : OpticalScope;
        part workingChannel : WorkingChannel;
        part handle : HandleAssembly;
        part cameraAdapter : CameraAdapter;
        part sterileSheath : SterileSheath;

        connect externalPower.power to lightSource.powerIn.power;
        connect lightSource.lightOut.light to opticalScope.patientEnd.light;
        connect opticalScope.imageOut.image to cameraAdapter.imageIn.image;
        connect cameraAdapter.videoOut.image to videoOutput.image;
        connect externalCommand.command to handle.commandPort.command;
        connect handle.commandPort.command to workingChannel.toolPort.command;
        connect workingChannel.toolPort.sample to externalCommand.sample;
        connect opticalScope.patientEnd.light to patientInterface.light;
        connect opticalScope.patientEnd.image to patientInterface.image;
        connect workingChannel.patientEnd.tissueSample to patientInterface.tissueSample;
        connect sterileSheath.statusOut.status to sterilityOutput.status;

        action provideIlluminatedMediastinalVisualization {
            in item power : ElectricalPower;
            in item command : InstrumentCommand;
            out item image : OpticalImage;
            out item sample : TissueSample;

            first start;
            then verifySterility;
            then illuminate;
            then visualize;
            then guideTool;
            then collectSample;
            then finish;

            action verifySterility : sterileSheath.verifyBarrierIntegrity;
            action illuminate : lightSource.emitColdLight;
            action visualize : opticalScope.transmitIlluminatedView;
            action guideTool : handle.stabilizeScope;
            action collectSample : workingChannel.passBiopsyInstrument;
        }

        state def OperatingStateMachine {
            state SterilePackaged;
            state Prepared;
            state Inserted;
            state Visualizing;
            state Sampling;
            state Withdrawn;
            state Reprocessed;
            state Fault;

            entry; then SterilePackaged;

            transition SterilePackaged_to_Prepared
                first SterilePackaged
                accept InstrumentCommand
                if commandName == "prepare"
                then Prepared;

            transition Prepared_to_Inserted
                first Prepared
                accept InstrumentCommand
                if commandName == "insert"
                then Inserted;

            transition Inserted_to_Visualizing
                first Inserted
                accept ElectricalPower
                if power > 0 [SI::watt]
                then Visualizing;

            transition Visualizing_to_Sampling
                first Visualizing
                accept InstrumentCommand
                if commandName == "biopsy"
                then Sampling;

            transition Sampling_to_Visualizing
                first Sampling
                accept TissueSample
                then Visualizing;

            transition Visualizing_to_Withdrawn
                first Visualizing
                accept InstrumentCommand
                if commandName == "withdraw"
                then Withdrawn;

            transition Withdrawn_to_Reprocessed
                first Withdrawn
                accept InstrumentCommand
                if commandName == "reprocess"
                then Reprocessed;

            transition any_to_Fault
                first SterilePackaged, Prepared, Inserted, Visualizing, Sampling, Withdrawn
                accept InstrumentCommand
                if commandName == "fault"
                then Fault;
        }
    }

    part mediastinalPatientPath : MediastinalAccessPath;
    part mediastinoscopeSystem : Mediastinoscope;

    connect mediastinoscopeSystem.patientInterface.light to mediastinalPatientPath.patientInterface.light;
    connect mediastinoscopeSystem.patientInterface.image to mediastinalPatientPath.patientInterface.image;
    connect mediastinoscopeSystem.patientInterface.tissueSample to mediastinalPatientPath.patientInterface.tissueSample;

    requirement def PrimaryFunctionRequirement {
        doc /* The mediastinoscope shall provide a rigid illuminated viewing and instrument pathway into the superior mediastinum so a clinician can inspect mediastinal anatomy and obtain tissue samples under direct visualization. */
    }

    requirement def IlluminationRequirement {
        attribute minimumFlux : LuminousFluxValue = 500 [SI::lumen];
        doc /* The light source shall deliver sufficient cool illumination through the distal end of the scope for visual identification of mediastinal structures. */
    }

    requirement def VisualizationRequirement {
        attribute minimumHorizontalResolution : Integer = 1280;
        attribute minimumVerticalResolution : Integer = 720;
        attribute minimumFieldOfView : AngleValue = 60 [SI::degree];
        doc /* The optical and camera path shall provide a clear image of the operative field with adequate resolution and field of view. */
    }

    requirement def WorkingChannelRequirement {
        attribute minimumChannelDiameter : DiameterValue = 4 [SI::millimetre];
        doc /* The working channel shall permit passage of compatible biopsy instruments while maintaining the viewing path. */
    }

    requirement def ThermalSafetyRequirement {
        attribute maximumDistalSurfaceTemperature : TemperatureValue = 41 [SI::degreeCelsius];
        doc /* The distal surface temperature shall remain below the thermal safety limit during normal illuminated operation. */
    }

    requirement def SterilityRequirement {
        doc /* The system shall maintain a sterile patient-contact barrier until completion of the mediastinoscopy procedure. */
    }

    requirement primaryFunction : PrimaryFunctionRequirement {
        subject mediastinoscopeSystem;
    }

    requirement illumination : IlluminationRequirement {
        subject mediastinoscopeSystem.lightSource;
        require constraint { mediastinoscopeSystem.lightSource.maximumFlux >= illumination.minimumFlux; }
    }

    requirement visualization : VisualizationRequirement {
        subject mediastinoscopeSystem.cameraAdapter;
        require constraint {
            mediastinoscopeSystem.cameraAdapter.sensorWidthPixels >= visualization.minimumHorizontalResolution and
            mediastinoscopeSystem.cameraAdapter.sensorHeightPixels >= visualization.minimumVerticalResolution and
            mediastinoscopeSystem.opticalScope.fieldOfView >= visualization.minimumFieldOfView;
        }
    }

    requirement workingChannelAccess : WorkingChannelRequirement {
        subject mediastinoscopeSystem.workingChannel;
        require constraint { mediastinoscopeSystem.workingChannel.innerDiameter >= workingChannelAccess.minimumChannelDiameter; }
    }

    requirement thermalSafety : ThermalSafetyRequirement {
        subject mediastinoscopeSystem;
        require constraint { mediastinoscopeSystem.maximumDistalTemperature <= thermalSafety.maximumDistalSurfaceTemperature; }
    }

    requirement sterility : SterilityRequirement {
        subject mediastinoscopeSystem.sterileSheath;
    }
}