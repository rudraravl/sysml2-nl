package NASAInspiredMarsSurfaceScienceSystem {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Temperature;
    attribute def Power;
    attribute def Voltage;
    attribute def Current;
    attribute def DataRate;
    attribute def DataVolume;
    attribute def Distance;
    attribute def Duration;
    attribute def Mass;
    attribute def Force;
    attribute def Speed;
    attribute def Angle;

    item def SolarIrradiance;
    item def RegolithSample {
        attribute sampleMass : Mass;
        attribute sampleDepth : Distance;
        attribute collectionSiteId : String;
        attribute contaminationRisk : Real;
    }

    item def ScienceImage {
        attribute resolutionMegapixels : Real;
        attribute wavelengthBand : String;
        attribute compressedSize : DataVolume;
        attribute targetSiteId : String;
    }

    item def SpectralObservation {
        attribute wavelengthStart : Real;
        attribute wavelengthEnd : Real;
        attribute mineralConfidence : Real;
        attribute targetSiteId : String;
    }

    item def NavigationCommand {
        attribute commandedDistance : Distance;
        attribute commandedHeading : Angle;
        attribute maximumSpeed : Speed;
    }

    item def RoverTelemetry {
        attribute batteryStateOfCharge : Real;
        attribute thermalBusTemperature : Temperature;
        attribute faultCount : Integer;
        attribute positionUncertainty : Distance;
        attribute storedScienceData : DataVolume;
    }

    item def UplinkPlan {
        attribute solNumber : Integer;
        attribute traverseGoal : Distance;
        attribute sciencePriority : Integer;
        attribute downlinkWindowStart : Duration;
    }

    item def DownlinkPacket {
        attribute packetId : Integer;
        attribute packetSize : DataVolume;
        attribute priority : Integer;
        attribute containsScienceData : Boolean;
    }

    port def PowerPort {
        out item electricalPower : Power;
        attribute busVoltage : Voltage;
        attribute currentLimit : Current;
    }

    port def DataPort {
        in item commandIn : UplinkPlan;
        out item telemetryOut : RoverTelemetry;
        out item dataOut : DownlinkPacket;
        attribute nominalRate : DataRate;
    }

    port def DriveCommandPort {
        in item command : NavigationCommand;
        out item odometry : RoverTelemetry;
    }

    port def SamplePort {
        out item acquiredSample : RegolithSample;
    }

    port def ImagingPort {
        out item image : ScienceImage;
    }

    port def SpectrometerPort {
        out item spectrum : SpectralObservation;
    }

    part def MarsSurfaceScienceRover {
        attribute dryMass : Mass = 1025 [kg];
        attribute maximumTraversePerSol : Distance = 200 [m];
        attribute nominalBusVoltage : Voltage = 28 [V];
        attribute minimumOperatingTemperature : Temperature = -55 [K];
        attribute maximumOperatingTemperature : Temperature = 323 [K];
        attribute primaryFunction : String =
            "Autonomously traverse a planetary surface, collect contextual science observations and regolith samples, and relay prioritized findings to mission control.";

        port powerIn : PowerPort;
        port telecom : DataPort;
        port driveInterface : DriveCommandPort;
        port sampleOutput : SamplePort;
        port imagingOutput : ImagingPort;
        port spectroscopyOutput : SpectrometerPort;

        part powerSystem : RoverPowerSystem;
        part mobilitySystem : SixWheelMobilitySystem;
        part avionics : RoverAvionics;
        part telecomSystem : DeepSpaceTelecomSystem;
        part sciencePayload : SciencePayload;
        part thermalControl : ThermalControlSystem;
        part sampleCachingSystem : SampleCachingSystem;

        connect powerSystem.roverPower to powerIn;
        connect powerSystem.avionicsPower to avionics.powerIn;
        connect powerSystem.mobilityPower to mobilitySystem.powerIn;
        connect powerSystem.payloadPower to sciencePayload.powerIn;
        connect powerSystem.telecomPower to telecomSystem.powerIn;
        connect powerSystem.thermalPower to thermalControl.powerIn;
        connect powerSystem.cachingPower to sampleCachingSystem.powerIn;

        connect avionics.telecomData to telecomSystem.dataInterface;
        connect telecomSystem.earthLink to telecom;
        connect avionics.driveCommand to mobilitySystem.commandPort;
        connect mobilitySystem.commandPort to driveInterface;

        connect sciencePayload.imagePort to imagingOutput;
        connect sciencePayload.spectrometerPort to spectroscopyOutput;
        connect sciencePayload.samplePort to sampleCachingSystem.sampleIn;
        connect sampleCachingSystem.sampleOut to sampleOutput;

        connect thermalControl.thermalStatus to avionics.thermalData;
        connect powerSystem.powerStatus to avionics.powerData;
        connect sciencePayload.payloadData to avionics.payloadData;
        connect sampleCachingSystem.cacheData to avionics.sampleData;

        perform missionBehavior : RoverMissionStateMachine;
    }

    part def RoverPowerSystem {
        attribute batteryCapacity : Real = 4200;
        attribute usableEnergyMargin : Real = 0.25;
        attribute radioisotopeThermalPower : Power = 2000 [W];
        attribute continuousElectricalPower : Power = 110 [W];
        attribute peakDischargePower : Power = 900 [W];

        port roverPower : PowerPort;
        port avionicsPower : PowerPort;
        port mobilityPower : PowerPort;
        port payloadPower : PowerPort;
        port telecomPower : PowerPort;
        port thermalPower : PowerPort;
        port cachingPower : PowerPort;
        port powerStatus : DataPort;

        action def AllocatePower {
            in attribute requestedMobilityPower : Power;
            in attribute requestedPayloadPower : Power;
            in attribute requestedTelecomPower : Power;
            out attribute approvedMobilityPower : Power;
            out attribute approvedPayloadPower : Power;
            out attribute approvedTelecomPower : Power;
        }
    }

    part def SixWheelMobilitySystem {
        attribute wheelCount : Integer = 6;
        attribute maximumSlope : Angle = 30 [deg];
        attribute nominalTraverseSpeed : Speed = 0.042 [m/s];
        attribute obstacleClearance : Distance = 0.35 [m];
        attribute wheelDiameter : Distance = 0.525 [m];

        port powerIn : PowerPort;
        port commandPort : DriveCommandPort;

        part leftFrontWheel : WheelAssembly;
        part leftMiddleWheel : WheelAssembly;
        part leftRearWheel : WheelAssembly;
        part rightFrontWheel : WheelAssembly;
        part rightMiddleWheel : WheelAssembly;
        part rightRearWheel : WheelAssembly;
        part rockerBogieSuspension : RockerBogieSuspension;

        action def ExecuteTraverse {
            in item navCommand : NavigationCommand;
            out item traverseTelemetry : RoverTelemetry;
            attribute slipLimit : Real = 0.35;
            attribute maximumStepHeight : Distance = 0.30 [m];
        }
    }

    part def WheelAssembly {
        attribute driveTorque : Real = 45;
        attribute steeringRange : Angle = 180 [deg];
        attribute wheelTemperature : Temperature;
    }

    part def RockerBogieSuspension {
        attribute differentialTravelLimit : Angle = 25 [deg];
        attribute chassisStabilityMargin : Real = 0.20;
    }

    part def RoverAvionics {
        attribute processorRedundancy : Integer = 2;
        attribute nonvolatileStorage : DataVolume = 256 [GB];
        attribute autonomousNavigationEnabled : Boolean = true;
        attribute faultProtectionEnabled : Boolean = true;

        port powerIn : PowerPort;
        port telecomData : DataPort;
        port driveCommand : DriveCommandPort;
        port thermalData : DataPort;
        port powerData : DataPort;
        port payloadData : DataPort;
        port sampleData : DataPort;

        action def PlanSolActivities {
            in item uplink : UplinkPlan;
            in item currentTelemetry : RoverTelemetry;
            out item driveCommand : NavigationCommand;
            out attribute scienceSequenceId : Integer;
        }

        action def DetectAndRespondToFault {
            in item telemetry : RoverTelemetry;
            out attribute enterSafeMode : Boolean;
            out attribute inhibitedSubsystem : String;
        }
    }

    part def DeepSpaceTelecomSystem {
        attribute xBandRate : DataRate = 2000 [bit/s];
        attribute uhfRelayRate : DataRate = 2000000 [bit/s];
        attribute highGainAntennaPointingAccuracy : Angle = 0.5 [deg];

        port powerIn : PowerPort;
        port dataInterface : DataPort;
        port earthLink : DataPort;

        part highGainAntenna : Antenna;
        part lowGainAntenna : Antenna;
        part uhfRelayRadio : RelayRadio;

        action def DownlinkPrioritizedData {
            in item telemetry : RoverTelemetry;
            in item sciencePacket : DownlinkPacket;
            out item deliveredPacket : DownlinkPacket;
        }
    }

    part def Antenna {
        attribute gain : Real;
        attribute pointingAzimuth : Angle;
        attribute pointingElevation : Angle;
    }

    part def RelayRadio {
        attribute relayCompatibility : String = "Mars orbiter UHF proximity link";
        attribute transmitPower : Power = 15 [W];
    }

    part def SciencePayload {
        attribute instrumentCount : Integer = 5;
        attribute sciencePowerLimit : Power = 300 [W];
        attribute dailyScienceDataBudget : DataVolume = 1200 [MB];

        port powerIn : PowerPort;
        port imagePort : ImagingPort;
        port spectrometerPort : SpectrometerPort;
        port samplePort : SamplePort;
        port payloadData : DataPort;

        part panoramicMastCamera : MultispectralCamera;
        part navigationCamera : NavigationCamera;
        part microscopicImager : MicroscopicImager;
        part laserSpectrometer : LaserSpectrometer;
        part coringDrill : CoringDrill;

        action def CharacterizeTarget {
            in attribute targetSiteId : String;
            out item image : ScienceImage;
            out item spectrum : SpectralObservation;
            out attribute samplingRecommended : Boolean;
        }
    }

    part def MultispectralCamera {
        attribute fieldOfView : Angle = 15 [deg];
        attribute detectorResolution : Real = 20;
        attribute bands : Integer = 12;
        port imageOut : ImagingPort;
    }

    part def NavigationCamera {
        attribute stereoBaseline : Distance = 0.42 [m];
        attribute fieldOfView : Angle = 45 [deg];
        port imageOut : ImagingPort;
    }

    part def MicroscopicImager {
        attribute spatialResolution : Distance = 0.00003 [m];
        attribute workingDistance : Distance = 0.05 [m];
        port imageOut : ImagingPort;
    }

    part def LaserSpectrometer {
        attribute maximumStandoffDistance : Distance = 7 [m];
        attribute laserPulseEnergy : Real = 14;
        attribute spectralRangeStart : Real = 240;
        attribute spectralRangeEnd : Real = 850;
        port spectrumOut : SpectrometerPort;
    }

    part def CoringDrill {
        attribute coreDiameter : Distance = 0.013 [m];
        attribute maximumDrillDepth : Distance = 0.07 [m];
        attribute percussionForce : Force = 600 [N];
        port sampleOut : SamplePort;
    }

    part def SampleCachingSystem {
        attribute cacheTubeCapacity : Integer = 30;
        attribute sealedTubeCount : Integer;
        attribute maximumSampleMassPerTube : Mass = 0.015 [kg];

        port powerIn : PowerPort;
        port sampleIn : SamplePort;
        port sampleOut : SamplePort;
        port cacheData : DataPort;

        part sampleTubeCarousel : SampleTubeCarousel;
        part hermeticSealer : HermeticSealer;

        action def CacheSample {
            in item acquiredSample : RegolithSample;
            out item sealedSample : RegolithSample;
            out attribute tubeId : Integer;
        }
    }

    part def SampleTubeCarousel {
        attribute availableTubes : Integer = 30;
        attribute rotationAccuracy : Angle = 1 [deg];
    }

    part def HermeticSealer {
        attribute sealTemperature : Temperature = 773 [K];
        attribute sealVerificationLeakRate : Real = 0.000001;
    }

    part def ThermalControlSystem {
        attribute survivalHeaterPower : Power = 160 [W];
        attribute warmElectronicsBoxSetpoint : Temperature = 253 [K];
        attribute radiatorArea : Real = 1.7;

        port powerIn : PowerPort;
        port thermalStatus : DataPort;

        action def MaintainTemperature {
            in attribute measuredAvionicsTemperature : Temperature;
            in attribute measuredPayloadTemperature : Temperature;
            out attribute heaterCommandPower : Power;
            out attribute louverPosition : Real;
        }
    }

    state def RoverMissionStateMachine {
        entry action InitializeMissionSystems;

        state AwaitingUplink;
        state PlanningSol;
        state Traversing;
        state PerformingScience;
        state CachingSample;
        state DownlinkingData;
        state SafeMode;
        state MissionComplete;

        transition first AwaitingUplink;
        transition AwaitingUplink to PlanningSol
            accept UplinkPlan;
        transition PlanningSol to Traversing
            if missionPlan.traverseGoal > 0 [m];
        transition PlanningSol to PerformingScience
            if missionPlan.sciencePriority >= 1;
        transition Traversing to PerformingScience
            if traverseTelemetry.positionUncertainty < 2 [m];
        transition PerformingScience to CachingSample
            if samplingRecommended == true;
        transition PerformingScience to DownlinkingData
            if samplingRecommended == false;
        transition CachingSample to DownlinkingData
            if sealedTubeCount >= 1;
        transition DownlinkingData to AwaitingUplink
            if downlinkWindowClosed == true;
        transition AwaitingUplink to MissionComplete
            if missionElapsedSols >= 687;
        transition PlanningSol to SafeMode
            if detectedFault == true;
        transition Traversing to SafeMode
            if detectedFault == true;
        transition PerformingScience to SafeMode
            if detectedFault == true;
        transition CachingSample to SafeMode
            if detectedFault == true;
        transition DownlinkingData to SafeMode
            if detectedFault == true;
        transition SafeMode to AwaitingUplink
            if recoveryCommandReceived == true;
    }

    action def InitializeMissionSystems {
        out attribute initialized : Boolean;
    }

    action def HighLevelSurfaceScienceMission {
        in item solPlan : UplinkPlan;
        out item engineeringTelemetry : RoverTelemetry;
        out item scienceReturn : DownlinkPacket;

        first start;
        then plan : RoverAvionics::PlanSolActivities;
        then drive : SixWheelMobilitySystem::ExecuteTraverse;
        then observe : SciencePayload::CharacterizeTarget;
        then cache : SampleCachingSystem::CacheSample;
        then transmit : DeepSpaceTelecomSystem::DownlinkPrioritizedData;
        then done;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The rover shall autonomously traverse a planetary surface, collect science observations and regolith samples, and communicate prioritized telemetry and science products to mission control. */
        subject rover : MarsSurfaceScienceRover;
        require constraint {
            rover.maximumTraversePerSol >= 100 [m]
        }
    }

    requirement def PowerSurvivalRequirement {
        doc /* The rover shall preserve essential avionics, telecom, and thermal control functions when available continuous electrical power is below nominal mission demand. */
        subject rover : MarsSurfaceScienceRover;
        require constraint {
            rover.powerSystem.continuousElectricalPower >= 100 [W]
        }
    }

    requirement def ScienceDataRequirement {
        doc /* The rover shall acquire contextual imagery and mineralogical observations for each selected science target before sample caching. */
        subject payload : SciencePayload;
        require constraint {
            payload.instrumentCount >= 4
        }
    }

    requirement def MobilityRequirement {
        doc /* The rover mobility system shall traverse uneven terrain with six independently driven wheels and maintain chassis stability on slopes up to thirty degrees. */
        subject mobility : SixWheelMobilitySystem;
        require constraint {
            mobility.wheelCount == 6 and mobility.maximumSlope >= 30 [deg]
        }
    }

    requirement def TelecomRequirement {
        doc /* The rover shall support both direct-to-Earth X-band communications and relay communications through an orbital proximity link. */
        subject telecom : DeepSpaceTelecomSystem;
        require constraint {
            telecom.xBandRate >= 1000 [bit/s] and telecom.uhfRelayRate >= 1000000 [bit/s]
        }
    }

    requirement def SampleCachingRequirement {
        doc /* The rover shall seal and store multiple regolith core samples in individual cache tubes for future retrieval. */
        subject cache : SampleCachingSystem;
        require constraint {
            cache.cacheTubeCapacity >= 20 and cache.maximumSampleMassPerTube >= 0.01 [kg]
        }
    }

    requirement def FaultProtectionRequirement {
        doc /* The avionics shall detect critical subsystem faults and command a safe operating state that preserves power, thermal control, and communications. */
        subject avionics : RoverAvionics;
        require constraint {
            avionics.faultProtectionEnabled == true and avionics.processorRedundancy >= 2
        }
    }

    satisfy PrimaryFunctionRequirement by MarsSurfaceScienceRover;
    satisfy PowerSurvivalRequirement by RoverPowerSystem;
    satisfy ScienceDataRequirement by SciencePayload;
    satisfy MobilityRequirement by SixWheelMobilitySystem;
    satisfy TelecomRequirement by DeepSpaceTelecomSystem;
    satisfy SampleCachingRequirement by SampleCachingSystem;
    satisfy FaultProtectionRequirement by RoverAvionics;
}