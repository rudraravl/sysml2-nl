package OceanCleanupVessel {

    // ─── Value Types & Units ───────────────────────────────────
    package Units {
        attribute def LengthUnit :> ISQ::LengthUnit;
        attribute def MassUnit :> ISQ::MassUnit;
        attribute def EnergyUnit :> ISQ::EnergyUnit;
        attribute def PowerUnit :> ISQ::PowerUnit;
        attribute def TimeUnit :> ISQ::TimeUnit;
        attribute def VelocityUnit :> ISQ::VelocityUnit;
        attribute def AreaUnit :> ISQ::AreaUnit;
        attribute def VolumeUnit :> ISQ::VolumeUnit;
        attribute def AngleUnit :> ISQ::AngleUnit;
        attribute def TemperatureUnit :> ISQ::TemperatureUnit;
        attribute def FrequencyUnit :> ISQ::FrequencyUnit;
    }

    value def Length :> Real { unit = Units::LengthUnit; }
    value def Mass :> Real { unit = Units::MassUnit; }
    value def Energy :> Real { unit = Units::EnergyUnit; }
    value def Power :> Real { unit = Units::PowerUnit; }
    value def Duration :> Real { unit = Units::TimeUnit; }
    value def Velocity :> Real { unit = Units::VelocityUnit; }
    value def Area :> Real { unit = Units::AreaUnit; }
    value def Volume :> Real { unit = Units::VolumeUnit; }
    value def Angle :> Real { unit = Units::AngleUnit; }
    value def Temperature :> Real { unit = Units::TemperatureUnit; }
    value def Frequency :> Real { unit = Units::FrequencyUnit; }
    value def Percentage :> Real;
    value def Distance :> Length;

    // ─── Item Definitions ──────────────────────────────────────
    item def PlasticDebris {
        attribute mass : Mass;
        attribute particleSize : Length;
        attribute density : Real;
    }

    item def ShreddedPlastic {
        attribute mass : Mass;
        attribute shredSize : Length;
    }

    item def CompressedBlock {
        attribute mass : Mass;
        attribute volume : Volume;
        attribute density : Real;
        attribute blockId : String;
    }

    item def SolarEnergy {
        attribute amount : Energy;
        attribute irradiance : Real;
    }

    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
        attribute power : Power;
    }

    item def NavigationData {
        attribute latitude : Angle;
        attribute longitude : Angle;
        attribute heading : Angle;
        attribute speed : Velocity;
        attribute timestamp : Duration;
    }

    item def DetectionData {
        attribute debrisDetected : Boolean;
        attribute debrisMass : Mass;
        attribute debrisLocation : NavigationData;
        attribute confidence : Percentage;
        attribute detectionRange : Length;
    }

    item def StatusReport {
        attribute vesselId : String;
        attribute location : NavigationData;
        attribute powerLevel : Percentage;
        attribute storageFill : Percentage;
        attribute totalCollected : Mass;
        attribute missionState : String;
        attribute timestamp : Duration;
    }

    item def MissionPlan {
        attribute patrolAreaId : String;
        attribute waypoints : NavigationData[0..*];
        attribute priority : Integer;
        attribute offloadLocation : NavigationData;
    }

    item def Seawater {
        attribute salinity : Real;
        attribute temperature : Temperature;
    }

    // ─── Port Definitions ──────────────────────────────────────
    port def PowerPort {
        out power : ElectricalPower;
    }

    port def PowerInPort {
        in power : ElectricalPower;
    }

    port def SolarEnergyPort {
        out energy : SolarEnergy;
    }

    port def DetectionDataPort {
        out detectionData : DetectionData;
    }

    port def NavigationDataPort {
        out navData : NavigationData;
    }

    port def CommandPort {
        in missionPlan : MissionPlan;
        out statusReport : StatusReport;
    }

    port def PlasticInflowPort {
        in debris : PlasticDebris;
    }

    port def PlasticTransferPort {
        out shredded : ShreddedPlastic;
    }

    port def BlockOutputPort {
        out block : CompressedBlock;
    }

    port def PropulsionCommandPort {
        out thrust : Real;
        out rudderAngle : Angle;
    }

    // ─── Subsystem Part Definitions ────────────────────────────
    part def SolarPanelArray {
        attribute panelCount : Integer;
        attribute totalArea : Area;
        attribute efficiency : Percentage;
        attribute maxOutput : Power;
        port solarOut : SolarEnergyPort;
        
        action def GenerateEnergy {
            in irradiance : Real;
            out generated : SolarEnergy;
        }
        
        perform GenerateEnergy;
    }

    part def BatterySystem {
        attribute capacity : Energy;
        attribute currentCharge : Energy;
        attribute chargeLevel : Percentage;
        attribute minOperationalThreshold : Percentage = 20;
        attribute criticalThreshold : Percentage = 10;
        port powerIn : PowerInPort;
        port powerOut : PowerPort;
        
        action def ChargeBattery {
            in energy : SolarEnergy;
            out stored : Energy;
        }
        
        action def DischargeBattery {
            in demand : Power;
            out supplied : ElectricalPower;
        }
        
        perform ChargeBattery;
        perform DischargeBattery;
    }

    part def OpticalSensor {
        attribute resolution : Real;
        attribute fieldOfView : Angle;
        attribute maxRange : Length;
        attribute frameRate : Frequency;
        port detectionOut : DetectionDataPort;
        
        action def ScanSurface {
            out detectionData : DetectionData;
        }
        
        perform ScanSurface;
    }

    part def SonarArray {
        attribute frequency : Frequency;
        attribute beamWidth : Angle;
        attribute maxDepth : Length;
        attribute numTransducers : Integer;
        port detectionOut : DetectionDataPort;
        
        action def ScanSubsurface {
            out detectionData : DetectionData;
        }
        
        perform ScanSubsurface;
    }

    part def DetectionSystem {
        part opticalSensor : OpticalSensor;
        part sonarArray : SonarArray;
        port detectionOut : DetectionDataPort;
        
        action def FuseDetectionData {
            in opticalData : DetectionData;
            in sonarData : DetectionData;
            out fusedData : DetectionData;
        }
        
        perform FuseDetectionData;
        
        connection opticalSensor.detectionOut to FuseDetectionData.opticalData;
        connection sonarArray.detectionOut to FuseDetectionData.sonarData;
    }

    part def NavigationController {
        attribute currentPosition : NavigationData;
        attribute targetPosition : NavigationData;
        attribute maxSpeed : Velocity;
        port navOut : NavigationDataPort;
        port propulsionCmdOut : PropulsionCommandPort;
        
        action def PlotCourse {
            in current : NavigationData;
            in target : NavigationData;
            out heading : Angle;
            out speed : Velocity;
        }
        
        action def NavigateTo {
            in destination : NavigationData;
            out thrust : Real;
            out rudder : Angle;
        }
        
        perform PlotCourse;
        perform NavigateTo;
    }

    part def PropulsionSystem {
        attribute maxThrust : Real;
        attribute maxRudderAngle : Angle = 35;
        port cmdIn : PropulsionCommandPort;
        
        action def ApplyThrust {
            in thrust : Real;
            in rudderAngle : Angle;
        }
        
        perform ApplyThrust;
    }

    part def CollectionMechanism {
        attribute beltWidth : Length;
        attribute meshSize : Length;
        attribute intakeRate : Real;
        port plasticIn : PlasticInflowPort;
        port shreddedOut : PlasticTransferPort;
        
        action def CollectDebris {
            in seawater : Seawater;
            in debris : PlasticDebris;
            out collected : PlasticDebris;
        }
        
        action def ConveyAndFilter {
            in collected : PlasticDebris;
            out separated : PlasticDebris;
        }
        
        perform CollectDebris;
        perform ConveyAndFilter;
    }

    part def Shredder {
        attribute bladeCount : Integer;
        attribute maxShredSize : Length;
        attribute motorPower : Power;
        port plasticIn : PlasticInflowPort;
        port shreddedOut : PlasticTransferPort;
        
        action def ShredPlastic {
            in debris : PlasticDebris;
            out shredded : ShreddedPlastic;
        }
        
        perform ShredPlastic;
    }

    part def Compressor {
        attribute compressionForce : Real;
        attribute blockVolume : Volume;
        attribute cycleTime : Duration;
        port shreddedIn : PlasticTransferPort;
        port blockOut : BlockOutputPort;
        
        action def CompressPlastic {
            in shredded : ShreddedPlastic;
            out block : CompressedBlock;
        }
        
        perform CompressPlastic;
    }

    part def ProcessingUnit {
        part shredder : Shredder;
        part compressor : Compressor;
        port plasticIn : PlasticInflowPort;
        port blockOut : BlockOutputPort;
        
        connection shredder.shreddedOut to compressor.shreddedIn;
    }

    part def StorageContainer {
        attribute maxCapacity : Mass;
        attribute currentLoad : Mass;
        attribute fillLevel : Percentage;
        attribute blockCount : Integer;
        port blockIn : BlockOutputPort;
        
        action def StoreBlock {
            in block : CompressedBlock;
        }
        
        action def OffloadBlocks {
            out blocks : CompressedBlock[0..*];
        }
        
        perform StoreBlock;
        perform OffloadBlocks;
    }

    part def CommunicationsModule {
        attribute transmitFrequency : Frequency;
        attribute bandwidth : Real;
        attribute antennaType : String;
        port commandPort : CommandPort;
        
        action def TransmitStatus {
            in report : StatusReport;
        }
        
        action def ReceiveMissionPlan {
            out plan : MissionPlan;
        }
        
        perform TransmitStatus;
        perform ReceiveMissionPlan;
    }

    part def GPSReceiver {
        attribute updateRate : Frequency;
        attribute accuracy : Length;
        port navOut : NavigationDataPort;
        
        action def GetPosition {
            out position : NavigationData;
        }
        
        perform GetPosition;
    }

    part def CentralCommand {
        attribute commandId : String;
        port commandPort : CommandPort;
        
        action def ReceiveStatus {
            in report : StatusReport;
        }
        
        action def DispatchMission {
            out plan : MissionPlan;
        }
        
        perform ReceiveStatus;
        perform DispatchMission;
    }

    // ─── Main Vessel Part ───────────────────────────────────────
    part def AutonomousCleanupVessel {
        attribute vesselId : String = "OCV-001";
        attribute vesselLength : Length;
        attribute vesselBeam : Length;
        attribute vesselDraft : Length;
        attribute displacement : Mass;
        attribute operationalRange : Distance;
        attribute missionDuration : Duration;
        
        // Subsystem parts
        part solarArray : SolarPanelArray {
            attribute panelCount = 48;
            attribute totalArea = 120.0;
            attribute efficiency = 22.0;
            attribute maxOutput = 5000.0;
        }
        
        part battery : BatterySystem {
            attribute capacity = 40000.0;
            attribute currentCharge = 40000.0;
            attribute chargeLevel = 100.0;
        }
        
        part detectionSystem : DetectionSystem {
            part opticalSensor : OpticalSensor {
                attribute resolution = 3840.0;
                attribute fieldOfView = 120.0;
                attribute maxRange = 200.0;
                attribute frameRate = 30.0;
            }
            part sonarArray : SonarArray {
                attribute frequency = 200.0;
                attribute beamWidth = 45.0;
                attribute maxDepth = 10.0;
                attribute numTransducers = 8;
            }
        }
        
        part navController : NavigationController {
            attribute maxSpeed = 4.0;
        }
        
        part propulsion : PropulsionSystem {
            attribute maxThrust = 2000.0;
        }
        
        part collectionMech : CollectionMechanism {
            attribute beltWidth = 3.0;
            attribute meshSize = 0.005;
            attribute intakeRate = 50.0;
        }
        
        part processingUnit : ProcessingUnit {
            part shredder : Shredder {
                attribute bladeCount = 12;
                attribute maxShredSize = 0.02;
                attribute motorPower = 500.0;
            }
            part compressor : Compressor {
                attribute compressionForce = 50000.0;
                attribute blockVolume = 0.05;
                attribute cycleTime = 120.0;
            }
        }
        
        part storage : StorageContainer {
            attribute maxCapacity = 2000.0;
            attribute currentLoad = 0.0;
            attribute fillLevel = 0.0;
            attribute blockCount = 0;
        }
        
        part comms : CommunicationsModule {
            attribute transmitFrequency = 0.01;
            attribute bandwidth = 100.0;
            attribute antennaType = "Satellite";
        }
        
        part gps : GPSReceiver {
            attribute updateRate = 1.0;
            attribute accuracy = 3.0;
        }
        
        // Ports
        port powerDistribution : PowerPort;
        port externalComms : CommandPort;
        
        // Internal connections — power distribution
        connection solarArray.solarOut to battery.powerIn;
        connection battery.powerOut to powerDistribution;
        
        // Internal connections — detection and navigation
        connection detectionSystem.detectionOut to navController.navOut;
        connection gps.navOut to navController.navOut;
        connection navController.propulsionCmdOut to propulsion.cmdIn;
        
        // Internal connections — collection and processing
        connection collectionMech.shreddedOut to processingUnit.plasticIn;
        connection processingUnit.blockOut to storage.blockIn;
        
        // Internal connections — communications
        connection comms.commandPort to externalComms;
        
        // ─── State Machine ─────────────────────────────────────
        state def OperationalStateMachine {
            attribute powerLevel : Percentage;
            attribute storageFill : Percentage;
            attribute debrisDetected : Boolean;
            attribute missionComplete : Boolean;
            
            state Patrolling {
                entry action {
                    // Begin patrol pattern within designated area
                }
                do action PatrolArea {
                    // Follow waypoints, scan continuously
                }
                transition to Intercepting
                    if debrisDetected == true;
                transition to PowerConservation
                    if powerLevel < battery.minOperationalThreshold;
                transition to Offloading
                    if storageFill >= 100.0;
            }
            
            state Intercepting {
                entry action {
                    // Plot course to detected debris location
                }
                do action NavigateToDebris {
                    // Autonomously navigate to debris concentration
                }
                transition to Collecting
                    if debrisDetected == true;
                transition to Patrolling
                    if debrisDetected == false;
            }
            
            state Collecting {
                entry action {
                    // Activate collection mechanism and processing unit
                }
                do action CollectAndProcess {
                    // Operate conveyor belts, shredder, and compressor
                }
                transition to Patrolling
                    if debrisDetected == false;
                transition to PowerConservation
                    if powerLevel < battery.minOperationalThreshold;
                transition to Offloading
                    if storageFill >= 100.0;
            }
            
            state PowerConservation {
                entry action {
                    // Reduce non-essential power consumption
                }
                do action ConservePower {
                    // Minimal propulsion, reduced sensor usage, charge battery
                }
                transition to Patrolling
                    if powerLevel >= 50.0;
                transition to EmergencyLowPower
                    if powerLevel < battery.criticalThreshold;
            }
            
            state EmergencyLowPower {
                entry action {
                    // Halt all non-essential systems, maximize solar charging
                }
                do action EmergencyCharge {
                    // Wait for battery to reach safe level
                }
                transition to PowerConservation
                    if powerLevel >= 20.0;
            }
            
            state Offloading {
                entry action {
                    // Navigate to designated offload location
                }
                do action NavigateToOffload {
                    // Autonomously travel to offload point
                }
                transition to Unloading
                    if atOffloadLocation == true;
            }
            
            state Unloading {
                entry action {
                    // Discharge compressed blocks
                }
                do action OffloadBlocks {
                    // Empty storage container
                }
                transition to Patrolling
                    if storageFill == 0.0;
            }
            
            state Faulted {
                entry action {
                    // Enter safe mode, transmit distress signal
                }
                do action SafeMode {
                    // Await remote diagnostics
                }
            }
            
            transition initial to Patrolling;
        }
        
        perform OperationalStateMachine;
    }

    // ─── Requirements ──────────────────────────────────────────
    requirement def PowerAutonomyRequirement {
        doc "The vessel shall be fully powered by solar energy with battery storage for continuous operation."
        attribute minBatteryCapacity : Energy = 40000.0;
        attribute minSolarOutput : Power = 5000.0;
        attribute minNightOperation : Duration = 12.0;
        subject vessel : AutonomousCleanupVessel;
        objective {
            verify vessel.battery.capacity >= minBatteryCapacity
            and vessel.solarArray.maxOutput >= minSolarOutput
        }
    }

    requirement def DetectionRequirement {
        doc "The vessel shall detect plastic debris on the surface and subsurface using optical and sonar sensors."
        attribute minDetectionRange : Length = 200.0;
        attribute minSubsurfaceDepth : Length = 10.0;
        attribute minConfidence : Percentage = 75.0;
        subject vessel : AutonomousCleanupVessel;
        objective {
            verify vessel.detectionSystem.opticalSensor.maxRange >= minDetectionRange
            and vessel.detectionSystem.sonarArray.maxDepth >= minSubsurfaceDepth
        }
    }

    requirement def CollectionRequirement {
        doc "The vessel shall collect plastic debris via conveyor belts and filtering screens."
        attribute minBeltWidth : Length = 3.0;
        attribute maxMeshSize : Length = 0.005;
        attribute minIntakeRate : Real = 50.0;
        subject vessel : AutonomousCleanupVessel;
        objective {
            verify vessel.collectionMech.beltWidth >= minBeltWidth
            and vessel.collectionMech.meshSize <= maxMeshSize
        }
    }

    requirement def ProcessingRequirement {
        doc "The vessel shall shred and compress collected plastic into dense blocks."
        attribute maxShredSize : Length = 0.02;
        attribute minCompressionForce : Real = 50000.0;
        subject vessel : AutonomousCleanupVessel;
        objective {
            verify vessel.processingUnit.shredder.maxShredSize <= maxShredSize
            and vessel.processingUnit.compressor.compressionForce >= minCompressionForce
        }
    }

    requirement def StorageRequirement {
        doc "The vessel shall store compressed plastic blocks in a high-capacity container."
        attribute minStorageCapacity : Mass = 2000.0;
        subject vessel : AutonomousCleanupVessel;
        objective {
            verify vessel.storage.maxCapacity >= minStorageCapacity
        }
    }

    requirement def AutonomousOperationRequirement {
        doc "The vessel shall operate autonomously through intelligent state management."
        attribute requiredStates : String = "Patrolling, Intercepting, Collecting, PowerConservation, Offloading";
        subject vessel : AutonomousCleanupVessel;
        objective {
            verify vessel.OperationalStateMachine.isDefined
        }
    }

    requirement def CommunicationsRequirement {
        doc "The vessel shall transmit status, location, and collection data to central command."
        attribute minTransmitFrequency : Frequency = 0.01;
        subject vessel : AutonomousCleanupVessel;
        objective {
            verify vessel.comms.transmitFrequency >= minTransmitFrequency
        }
    }

    requirement def MissionEnduranceRequirement {
        doc "The vessel shall sustain long-duration missions at sea without human intervention."
        attribute minMissionDuration : Duration = 2592000.0;
        subject vessel : AutonomousCleanupVessel;
        objective {
            verify vessel.missionDuration >= minMissionDuration
        }
    }

    // ─── Top-level System with External Connections ───────────
    part CleanupSystem {
        part vessel : AutonomousCleanupVessel;
        part command : CentralCommand;
        
        connection vessel.externalComms to command.commandPort;
        
        satisfy PowerAutonomyRequirement by vessel;
        satisfy DetectionRequirement by vessel;
        satisfy CollectionRequirement by vessel;
        satisfy ProcessingRequirement by vessel;
        satisfy StorageRequirement by vessel;
        satisfy AutonomousOperationRequirement by vessel;
        satisfy CommunicationsRequirement by vessel;
        satisfy MissionEnduranceRequirement by vessel;
    }

}
