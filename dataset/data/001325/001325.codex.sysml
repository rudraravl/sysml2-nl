package ThreeDMicrofabricationSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def LaserPower :> Power {
        unit = W;
    }

    attribute def Wavelength :> Length {
        unit = nm;
    }

    attribute def ScanSpeed :> Speed {
        unit = mm / s;
    }

    attribute def FeatureSize :> Length {
        unit = um;
    }

    attribute def LayerThickness :> Length {
        unit = um;
    }

    attribute def TemperatureC :> Temperature {
        unit = K;
    }

    attribute def PressurePa :> Pressure {
        unit = Pa;
    }

    attribute def DoseEnergy :> Energy {
        unit = nJ;
    }

    item def PhotoresistMaterial {
        attribute viscosity : Real;
        attribute refractiveIndex : Real;
        attribute polymerizationThreshold : DoseEnergy;
        attribute cureShrinkagePercent : Real;
    }

    item def FabricationJob {
        attribute targetFeatureSize : FeatureSize;
        attribute layerThickness : LayerThickness;
        attribute totalLayers : Integer;
        attribute buildVolumeX : Length;
        attribute buildVolumeY : Length;
        attribute buildVolumeZ : Length;
    }

    item def MicroStructure {
        attribute minimumFeatureSize : FeatureSize;
        attribute height : Length;
        attribute width : Length;
        attribute depth : Length;
        attribute dimensionalError : Length;
        attribute isReleased : Boolean;
    }

    item def LaserBeam {
        attribute wavelength : Wavelength;
        attribute averagePower : LaserPower;
        attribute pulseEnergy : DoseEnergy;
        attribute focusDiameter : FeatureSize;
    }

    item def MotionCommand {
        attribute xPosition : Length;
        attribute yPosition : Length;
        attribute zPosition : Length;
        attribute scanSpeed : ScanSpeed;
        attribute exposureEnabled : Boolean;
    }

    item def ProcessTelemetry {
        attribute chamberTemperature : TemperatureC;
        attribute chamberPressure : PressurePa;
        attribute stagePositionError : Length;
        attribute opticalPowerMeasured : LaserPower;
        attribute currentLayer : Integer;
    }

    port def MaterialInputPort {
        in item material : PhotoresistMaterial;
    }

    port def JobInputPort {
        in item job : FabricationJob;
    }

    port def BeamOutputPort {
        out item beam : LaserBeam;
    }

    port def CommandPort {
        out item command : MotionCommand;
    }

    port def TelemetryPort {
        out item telemetry : ProcessTelemetry;
    }

    port def StructureOutputPort {
        out item structure : MicroStructure;
    }

    requirement def HighLevelFunctionRequirement {
        subject system : ThreeDMicrofabricationSystem;
        require constraint {
            system.primaryFunction == "Fabricate high-resolution three-dimensional microstructures by selectively polymerizing photosensitive material with focused laser exposure and precision stage motion."
        }
    }

    requirement def ResolutionRequirement {
        subject system : ThreeDMicrofabricationSystem;
        require constraint {
            system.fabricationHead.minimumVoxelDiameter <= 1.0 [um]
        }
    }

    requirement def BuildVolumeRequirement {
        subject system : ThreeDMicrofabricationSystem;
        require constraint {
            system.motionStage.travelX >= 10.0 [mm] and
            system.motionStage.travelY >= 10.0 [mm] and
            system.motionStage.travelZ >= 5.0 [mm]
        }
    }

    requirement def EnvironmentalStabilityRequirement {
        subject system : ThreeDMicrofabricationSystem;
        require constraint {
            system.processChamber.temperatureStability <= 0.5 [K] and
            system.processChamber.particleFiltered == true
        }
    }

    action def PrepareSubstrate {
        in item material : PhotoresistMaterial;
        out item coatedSubstrate : PhotoresistMaterial;
    }

    action def SliceGeometry {
        in item job : FabricationJob;
        out item commandStream : MotionCommand;
    }

    action def FocusLaser {
        in item beam : LaserBeam;
        out item focusedBeam : LaserBeam;
    }

    action def ExposeVoxel {
        in item focusedBeam : LaserBeam;
        in item command : MotionCommand;
        out item partiallyBuiltStructure : MicroStructure;
    }

    action def DevelopAndRelease {
        in item partiallyBuiltStructure : MicroStructure;
        out item finalStructure : MicroStructure;
    }

    state def FabricationControllerState {
        entry action initializeSystem;
        state idle;
        state loadingMaterial;
        state calibratingOptics;
        state fabricating;
        state developing;
        state complete;
        state fault;

        transition first idle;
        transition idle then loadingMaterial
            accept StartJob;

        transition loadingMaterial then calibratingOptics
            accept MaterialLoaded;

        transition calibratingOptics then fabricating
            accept CalibrationPassed;

        transition fabricating then developing
            accept BuildComplete;

        transition developing then complete
            accept ReleaseComplete;

        transition loadingMaterial then fault
            accept MaterialFault;

        transition calibratingOptics then fault
            accept OpticalFault;

        transition fabricating then fault
            accept MotionFault;

        transition fault then idle
            accept Reset;
    }

    part def LaserSource {
        attribute wavelength : Wavelength = 780 [nm];
        attribute maximumAveragePower : LaserPower = 500 [mW];
        attribute pulseEnergy : DoseEnergy = 2.5 [nJ];
        attribute repetitionRateHz : Real = 80000000.0;

        port beamOut : BeamOutputPort;
    }

    part def FabricationHead {
        attribute numericalAperture : Real = 1.4;
        attribute minimumVoxelDiameter : FeatureSize = 0.7 [um];
        attribute workingDistance : Length = 200 [um];

        port beamIn : BeamOutputPort;
        port focusedBeamOut : BeamOutputPort;
    }

    part def PrecisionMotionStage {
        attribute travelX : Length = 25 [mm];
        attribute travelY : Length = 25 [mm];
        attribute travelZ : Length = 10 [mm];
        attribute positioningResolution : Length = 20 [nm];
        attribute maximumScanSpeed : ScanSpeed = 50 [mm / s];

        port motionCommandIn : CommandPort;
        port telemetryOut : TelemetryPort;
    }

    part def ProcessChamber {
        attribute temperatureSetpoint : TemperatureC = 293.15 [K];
        attribute temperatureStability : TemperatureC = 0.2 [K];
        attribute pressureSetpoint : PressurePa = 101325 [Pa];
        attribute particleFiltered : Boolean = true;

        port materialIn : MaterialInputPort;
        port telemetryOut : TelemetryPort;
    }

    part def ProcessController {
        attribute activeLayer : Integer = 0;
        attribute primaryFunction : String =
            "Coordinate material handling, laser exposure, precision motion, and post-processing to fabricate 3D microstructures.";

        port jobIn : JobInputPort;
        port commandOut : CommandPort;
        port telemetryIn : TelemetryPort;

        perform state FabricationControllerState;
    }

    part def DevelopmentModule {
        attribute developerTemperature : TemperatureC = 295.15 [K];
        attribute rinseDuration : Time = 120 [s];
        attribute criticalPointDryingEnabled : Boolean = true;

        port structureIn : StructureOutputPort;
        port structureOut : StructureOutputPort;
    }

    part def ThreeDMicrofabricationSystem {
        attribute primaryFunction : String =
            "Fabricate high-resolution three-dimensional microstructures by selectively polymerizing photosensitive material with focused laser exposure and precision stage motion.";

        port jobInput : JobInputPort;
        port materialInput : MaterialInputPort;
        port finishedStructureOutput : StructureOutputPort;
        port processTelemetryOutput : TelemetryPort;

        part laserSource : LaserSource;
        part fabricationHead : FabricationHead;
        part motionStage : PrecisionMotionStage;
        part processChamber : ProcessChamber;
        part controller : ProcessController;
        part developmentModule : DevelopmentModule;

        connect laserSource.beamOut to fabricationHead.beamIn;
        connect controller.commandOut to motionStage.motionCommandIn;
        connect processChamber.telemetryOut to controller.telemetryIn;
        connect motionStage.telemetryOut to controller.telemetryIn;
        connect jobInput to controller.jobIn;
        connect materialInput to processChamber.materialIn;
        connect developmentModule.structureOut to finishedStructureOutput;
        connect processChamber.telemetryOut to processTelemetryOutput;

        perform action fabricationWorkflow {
            in item job : FabricationJob;
            in item resin : PhotoresistMaterial;
            out item completedDevice : MicroStructure;

            action prepare : PrepareSubstrate {
                in material = resin;
            }

            action slice : SliceGeometry {
                in job = job;
            }

            action focus : FocusLaser {
                in beam = laserSource.beamOut.beam;
            }

            action expose : ExposeVoxel {
                in focusedBeam = focus.focusedBeam;
                in command = slice.commandStream;
            }

            action release : DevelopAndRelease {
                in partiallyBuiltStructure = expose.partiallyBuiltStructure;
                out finalStructure = completedDevice;
            }

            succession prepare then slice;
            succession slice then focus;
            succession focus then expose;
            succession expose then release;
        }
    }

    part system : ThreeDMicrofabricationSystem;

    requirement highLevelFunction : HighLevelFunctionRequirement {
        subject system = system;
    }

    requirement resolution : ResolutionRequirement {
        subject system = system;
    }

    requirement buildVolume : BuildVolumeRequirement {
        subject system = system;
    }

    requirement environmentalStability : EnvironmentalStabilityRequirement {
        subject system = system;
    }

}