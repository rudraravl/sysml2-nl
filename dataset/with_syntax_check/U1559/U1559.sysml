package MarsExplorationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def SurfaceTemperature :> ISQ::TemperatureValue;
    attribute def AtmosphericPressure :> ISQ::PressureValue;
    attribute def SolarIrradiance :> ISQ::IrradianceValue;
    attribute def DataRate :> ScalarValues::Real;
    attribute def SignalStrength :> ScalarValues::Real;

    item def ScienceData {
        attribute timestamp :> ISQ::time;
        attribute dataVolume :> ScalarValues::Real;
        attribute priority : ScalarValues::Integer;
    }

    item def NavigationData {
        attribute position :> ISQ::length;
        attribute heading :> ISQ::angle;
        attribute velocity :> ISQ::speed;
    }

    item def CommandMessage {
        attribute commandType : ScalarValues::String;
        attribute parameters : ScalarValues::String;
        attribute executionTime :> ISQ::time;
    }

    attribute def PowerLevel :> ISQ::PowerValue;
    attribute def EnergyCapacity :> ISQ::EnergyValue;
    attribute def DataVolume :> ScalarValues::Real;

    part def SolarPanel {
        attribute area :> ISQ::area;
        attribute efficiency :> ScalarValues::Real;
        port solarInput {
            in irradiance : SolarIrradiance;
        }
        port powerOut {
            out power : PowerLevel;
        }
    }

    part def BatteryModule {
        attribute capacity : EnergyCapacity;
        attribute stateOfCharge : ScalarValues::Real;
        attribute maxChargeRate : PowerLevel;
        attribute maxDischargeRate : PowerLevel;
        port chargeIn {
            in chargePower : PowerLevel;
        }
        port dischargeOut {
            out outputPower : PowerLevel;
        }
    }

    part def PowerManagementUnit {
        port solarIn {
            in solarPower : PowerLevel;
        }
        port batteryChargeOut {
            out chargePower : PowerLevel;
        }
        port batteryDischargeIn {
            in batteryPower : PowerLevel;
        }
        port systemPowerOut {
            out distributedPower : PowerLevel;
        }
    }

    part def HighGainAntenna {
        attribute gain :> ScalarValues::Real;
        attribute frequency :> ISQ::frequency;
        attribute pointingAccuracy :> ISQ::angle;
        port dataIn {
            in scienceData : ScienceData;
        }
        port signalOut {
            out transmittedSignal : DataRate;
        }
        port commandIn {
            in receivedCommand : CommandMessage;
        }
        port powerIn {
            in power : PowerLevel;
        }
    }

    part def MastCamera {
        attribute resolution : ScalarValues::Integer;
        attribute fieldOfView :> ISQ::angle;
        attribute spectralRange :> ISQ::length;
        port imageOut {
            out imageData : ScienceData;
        }
        port controlIn {
            in captureCommand : CommandMessage;
        }
        port powerIn {
            in power : PowerLevel;
        }
    }

    part def AlphaParticleXRaySpectrometer {
        attribute detectionRange :> ISQ::length;
        attribute sensitivity :> ScalarValues::Real;
        port sampleIn {
            in sampleContact : ScalarValues::Boolean;
        }
        port spectralOut {
            out spectralData : ScienceData;
        }
        port powerIn {
            in power : PowerLevel;
        }
    }

    part def RockAbrasionTool {
        attribute grindingDepth :> ISQ::length;
        attribute toolDiameter :> ISQ::length;
        port commandIn {
            in grindCommand : CommandMessage;
        }
        port statusOut {
            out grindingComplete : ScalarValues::Boolean;
        }
        port powerIn {
            in power : PowerLevel;
        }
    }

    part def WheelAssembly {
        attribute wheelDiameter :> ISQ::length;
        attribute motorTorque :> ISQ::TorqueValue;
        port driveIn {
            in driveCommand : NavigationData;
        }
        port positionOut {
            out wheelPosition :> ISQ::angle;
        }
        port powerIn {
            in power : PowerLevel;
        }
    }

    part def NavigationSystem {
        attribute positionAccuracy :> ISQ::length;
        port cameraIn {
            in navigationImages : ScienceData;
        }
        port imuIn {
            in inertialData : NavigationData;
        }
        port navigationOut {
            out currentPose : NavigationData;
        }
        port powerIn {
            in power : PowerLevel;
        }
    }

    part def ThermalControlSystem {
        attribute minOperatingTemp :> ISQ::temperature;
        attribute maxOperatingTemp :> ISQ::temperature;
        port ambientIn {
            in ambientTemp : SurfaceTemperature;
        }
        port regulatedOut {
            out internalTemp :> ISQ::temperature;
        }
        port powerIn {
            in power : PowerLevel;
        }
    }

    part def OnboardComputer {
        attribute processingPower : ScalarValues::Real;
        attribute memoryCapacity : ScalarValues::Real;
        port commandIn {
            in earthCommand : CommandMessage;
        }
        port scienceDataIn {
            in sensorData : ScienceData;
        }
        port navigationIn {
            in navData : NavigationData;
        }
        port controlOut {
            out systemControl : CommandMessage;
        }
        port dataOut {
            out processedData : ScienceData;
        }
        port powerIn {
            in power : PowerLevel;
        }
    }

    part def MarsRoverSystem {
        doc /* A robotic exploration system designed to traverse the Martian surface,
               conduct comprehensive geological and atmospheric analysis, and transmit
               scientific discoveries to Earth for study of Mars' past habitability. */

        attribute roverMass :> ISQ::mass;
        attribute missionDuration :> ISQ::time;
        attribute totalDistanceTraveled :> ISQ::length;

        part powerSubsystem {
            part solarArrays : SolarPanel[2] {
                attribute :>> area = 1.3 [SI::m^2];
                attribute :>> efficiency = 0.26;
            }
            part battery : BatteryModule {
                attribute :>> capacity = 140.0 [SI::W*SI::h];
                attribute :>> stateOfCharge = 0.80;
                attribute :>> maxChargeRate = 80.0 [SI::W];
                attribute :>> maxDischargeRate = 120.0 [SI::W];
            }
            part pmu : PowerManagementUnit;
        }

        part communicationsSubsystem {
            part hga : HighGainAntenna {
                attribute :>> gain = 28.0;
                attribute :>> frequency = 8.4e9 [SI::Hz];
                attribute :>> pointingAccuracy = 0.5 [SI::'°'];
            }
        }

        part scienceInstruments {
            part panoramicCameras : MastCamera[2] {
                attribute :>> resolution = 1024;
                attribute :>> fieldOfView = 16.0 [SI::'°'];
                attribute :>> spectralRange = 0.4e-6 [SI::m];
            }
            part apxs : AlphaParticleXRaySpectrometer {
                attribute :>> detectionRange = 2.0e-6 [SI::m];
                attribute :>> sensitivity = 0.92;
            }
            part rat : RockAbrasionTool {
                attribute :>> grindingDepth = 0.005 [SI::m];
                attribute :>> toolDiameter = 0.045 [SI::m];
            }
        }

        part mobilitySubsystem {
            part wheels : WheelAssembly[6] {
                attribute :>> wheelDiameter = 0.26 [SI::m];
                attribute :>> motorTorque = 40.0 [SI::N*SI::m];
            }
            part navigation : NavigationSystem {
                attribute :>> positionAccuracy = 0.1 [SI::m];
            }
        }

        part thermalSubsystem : ThermalControlSystem {
            attribute :>> minOperatingTemp = 218.0 [SI::K];
            attribute :>> maxOperatingTemp = 323.0 [SI::K];
        }

        part commandAndDataHandling : OnboardComputer {
            attribute :>> processingPower = 20.0;
            attribute :>> memoryCapacity = 256.0;
        }

        connect powerSubsystem.solarArrays.powerOut to powerSubsystem.pmu.solarIn;
        connect powerSubsystem.pmu.batteryChargeOut to powerSubsystem.battery.chargeIn;
        connect powerSubsystem.battery.dischargeOut to powerSubsystem.pmu.batteryDischargeIn;
        connect powerSubsystem.pmu.systemPowerOut to commandAndDataHandling.powerIn;
        connect powerSubsystem.pmu.systemPowerOut to communicationsSubsystem.hga.powerIn;
        connect powerSubsystem.pmu.systemPowerOut to scienceInstruments.panoramicCameras.powerIn;
        connect powerSubsystem.pmu.systemPowerOut to scienceInstruments.apxs.powerIn;
        connect powerSubsystem.pmu.systemPowerOut to scienceInstruments.rat.powerIn;
        connect powerSubsystem.pmu.systemPowerOut to mobilitySubsystem.wheels.powerIn;
        connect powerSubsystem.pmu.systemPowerOut to mobilitySubsystem.navigation.powerIn;
        connect powerSubsystem.pmu.systemPowerOut to thermalSubsystem.powerIn;
        connect communicationsSubsystem.hga.commandIn to commandAndDataHandling.commandIn;
        connect commandAndDataHandling.dataOut to communicationsSubsystem.hga.dataIn;
        connect scienceInstruments.panoramicCameras.imageOut to commandAndDataHandling.scienceDataIn;
        connect scienceInstruments.apxs.spectralOut to commandAndDataHandling.scienceDataIn;
        connect mobilitySubsystem.navigation.navigationOut to commandAndDataHandling.navigationIn;
        connect commandAndDataHandling.controlOut to scienceInstruments.panoramicCameras.controlIn;
        connect commandAndDataHandling.controlOut to scienceInstruments.rat.commandIn;
        connect commandAndDataHandling.controlOut to mobilitySubsystem.wheels.driveIn;

        perform action executeMarsExploration;
    }

    action def ReceiveEarthCommand {
        out command : CommandMessage;
    }

    action def PlanTraverse {
        in targetLocation :> ISQ::length;
        in currentPosition :> ISQ::length;
        out traversePath : NavigationData;
    }

    action def DriveToLocation {
        in path : NavigationData;
        out arrived : ScalarValues::Boolean;
        out finalPosition :> ISQ::length;
    }

    action def CaptureImages {
        out imageData : ScienceData;
    }

    action def PrepareRockSurface {
        out surfaceReady : ScalarValues::Boolean;
    }

    action def AnalyzeComposition {
        in surfaceReady : ScalarValues::Boolean;
        out compositionData : ScienceData;
    }

    action def TransmitToEarth {
        in data : ScienceData;
        out transmissionComplete : ScalarValues::Boolean;
    }

    action def MonitorPowerLevel {
        in batteryCharge : ScalarValues::Real;
        out powerSufficient : ScalarValues::Boolean;
    }

    action def EnterLowPowerMode;

    action def ChargeBatteries {
        in solarAvailable : ScalarValues::Boolean;
        out chargeComplete : ScalarValues::Boolean;
    }

    action def ExecuteMarsExploration {
        in missionStartTime :> ISQ::time;
        in plannedDuration :> ISQ::time;
        out samplesAnalyzed : ScalarValues::Integer;
        out distanceCovered :> ISQ::length;
        out dataTransmitted : DataVolume;
    }

    action executeMarsExploration : ExecuteMarsExploration {
        doc /* Primary exploration mission executing traverse, science, and communication cycles. */

        first start;
        then merge missionLoop;

        action checkPower : MonitorPowerLevel {
            in batteryCharge = 0.80;
            out powerSufficient : ScalarValues::Boolean;
        }

        then decide;
            if checkPower.powerSufficient then receiveCommand;
            else enterSafeMode;

        action receiveCommand : ReceiveEarthCommand {
            out command : CommandMessage;
        }

        then action planPath : PlanTraverse {
            in targetLocation = 100.0 [SI::m];
            in currentPosition = 0.0 [SI::m];
            out traversePath : NavigationData;
        }

        then action navigate : DriveToLocation {
            in path = planPath.traversePath;
            out arrived : ScalarValues::Boolean;
            out finalPosition :> ISQ::length;
        }

        then decide;
            if navigate.arrived then conductScience;
            else missionLoop;

        action conductScience {
            first action captureImages : CaptureImages {
                out imageData : ScienceData;
            }

            then action prepSurface : PrepareRockSurface {
                out surfaceReady : ScalarValues::Boolean;
            }

            then action analyzeRock : AnalyzeComposition {
                in surfaceReady = prepSurface.surfaceReady;
                out compositionData : ScienceData;
            }

            then action transmit : TransmitToEarth {
                in data = analyzeRock.compositionData;
                out transmissionComplete : ScalarValues::Boolean;
            }
        }

        then missionLoop;

        action enterSafeMode : EnterLowPowerMode;
        
        then action recharge : ChargeBatteries {
            in solarAvailable = true;
            out chargeComplete : ScalarValues::Boolean;
        }

        then missionLoop;
    }

    state machine def MissionOperations {
        initial state Initialization;
        state Traversing;
        state ScienceAcquisition;
        state DataTransmission;
        state LowPowerMode;
        state MissionComplete;

        transition init_to_traverse : Initialization -> Traversing;
        transition traverse_to_science : Traversing -> ScienceAcquisition;
        transition science_to_transmit : ScienceAcquisition -> DataTransmission;
        transition transmit_to_traverse : DataTransmission -> Traversing;
        transition any_to_lowpower : Traversing -> LowPowerMode;
        transition lowpower_to_traverse : LowPowerMode -> Traversing;
        transition any_to_complete : Traversing -> MissionComplete;
    }

    requirement def MissionRequirement;

    requirement <'REQ-MARS-001'> primaryExplorationObjective : MissionRequirement {
        doc /* The Mars Rover System shall autonomously explore the Martian surface to investigate
               geological formations, analyze rock and soil composition, and search for evidence of
               past water activity and potential biosignatures. */

        subject rover : MarsRoverSystem;

        require constraint scienceCapability {
            rover.scienceInstruments.apxs.sensitivity >= 0.90 and
            rover.scienceInstruments.panoramicCameras.resolution >= 1024
        }

        require constraint mobilityCapability {
            rover.mobilitySubsystem.wheels.wheelDiameter >= 0.20 [SI::m]
        }

        require constraint powerCapability {
            rover.powerSubsystem.battery.capacity >= 100.0 [SI::W*SI::h]
        }
    }

    requirement <'REQ-MARS-002'> environmentalSurvival : MissionRequirement {
        doc /* The Mars Rover System shall survive and operate in the extreme Martian environment
               with surface temperatures from -125°C to +20°C and atmospheric pressure of 600 Pa. */

        subject rover : MarsRoverSystem;

        require constraint thermalTolerance {
            rover.thermalSubsystem.minOperatingTemp <= 218.0 [SI::K] and
            rover.thermalSubsystem.maxOperatingTemp >= 293.0 [SI::K]
        }
    }

    requirement <'REQ-MARS-003'> missionDuration : MissionRequirement {
        doc /* The Mars Rover System shall maintain operational capability for a minimum of 90 sols
               (Martian days) to complete the primary science mission objectives. */

        subject rover : MarsRoverSystem;

        require constraint operationalLifetime {
            rover.missionDuration >= 90.0 [SI::d]
        }
    }

    requirement <'REQ-MARS-004'> communicationCapability : MissionRequirement {
        doc /* The Mars Rover System shall transmit scientific data to Earth at a minimum rate
               sufficient to downlink all collected science data within the mission duration. */

        subject rover : MarsRoverSystem;

        require constraint dataLink {
            rover.communicationsSubsystem.hga.frequency >= 8.0e9 [SI::Hz] and
            rover.communicationsSubsystem.hga.gain >= 25.0
        }
    }

    part marsRover : MarsRoverSystem {
        attribute :>> roverMass = 185.0 [SI::kg];
        attribute :>> missionDuration = 90.0 [SI::d];
        attribute :>> totalDistanceTraveled = 0.0 [SI::m];

        exhibit state missionState : MissionOperations;

        satisfy primaryExplorationObjective;
        satisfy environmentalSurvival;
        satisfy missionDuration;
        satisfy communicationCapability;
    }
}
