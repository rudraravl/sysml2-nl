package 'Autonomous Ocean Cleanup Vessel' {
    private import ScalarValues::*;
    private import ISQ::*;

    package Types {
        attribute def PowerValue :> Real;
        attribute def EnergyValue :> Real;
        attribute def MassValue :> Real;
        attribute def DistanceValue :> Real;
        attribute def SpeedValue :> Real;
        attribute def VolumeValue :> Real;
        attribute def ConcentrationValue :> Real;
        attribute def Percentage :> Real;
        attribute def AreaValue :> Real;
        attribute def TimeValue :> Real;

        item def PlasticDebris {
            attribute mass : MassValue;
            attribute concentration : ConcentrationValue;
        }

        item def CompressedBlock {
            attribute mass : MassValue;
            attribute volume : VolumeValue;
        }

        item def NavigationCommand {
            attribute destination : String;
            attribute targetSpeed : SpeedValue;
        }

        item def StatusReport {
            attribute location : String;
            attribute powerLevel : Percentage;
            attribute plasticCollected : MassValue;
            attribute vesselState : String;
        }

        attribute def PlasticDetected;
        attribute def StorageFull;
        attribute def LowPowerAlert;
        attribute def PowerRestored;
        attribute def OffloadComplete;
        attribute def ReturnToBaseCommand;
        attribute def ArrivedAtOffload;
        attribute def DebrisDepleted;
        attribute def PatrolCommand;
    }

    package Definitions {
        private import Types::*;

        port def PowerOutPort {
            out power : PowerValue;
        }

        port def PowerInPort {
            in power : PowerValue;
        }

        port def DebrisFlowPort {
            out debris : PlasticDebris;
        }

        port def DebrisReceivePort {
            in debris : PlasticDebris;
        }

        port def BlockFlowPort {
            out block : CompressedBlock;
        }

        port def BlockReceivePort {
            in block : CompressedBlock;
        }

        port def DetectionOutPort {
            out debrisDetected : Boolean;
            out debrisLocation : String;
            out concentration : ConcentrationValue;
        }

        port def DetectionInPort {
            in debrisDetected : Boolean;
            in debrisLocation : String;
            in concentration : ConcentrationValue;
        }

        port def NavCommandPort {
            out course : String;
            out targetSpeed : SpeedValue;
        }

        port def NavReceivePort {
            in course : String;
            in targetSpeed : SpeedValue;
        }

        port def StatusOutPort {
            out report : StatusReport;
        }

        action def Patrol {
            out patrolStatus : String;
        }

        action def DetectPlastic {
            out debrisDetected : Boolean;
            out debrisLocation : String;
            out concentration : ConcentrationValue;
        }

        action def PlotCourse {
            in destination : String;
            out course : String;
            out targetSpeed : SpeedValue;
        }

        action def EngagePropulsion {
            in course : String;
            in targetSpeed : SpeedValue;
            out status : String;
        }

        action def CollectDebris {
            out debris : PlasticDebris;
        }

        action def ShredPlastic {
            in debris : PlasticDebris;
            out shredded : PlasticDebris;
        }

        action def CompressBlocks {
            in shredded : PlasticDebris;
            out block : CompressedBlock;
        }

        action def StoreBlocks {
            in block : CompressedBlock;
            out storedMass : MassValue;
        }

        action def ConservePower {
            in chargeLevel : Percentage;
            out status : String;
        }

        action def NavigateToOffload {
            in destination : String;
            out course : String;
        }

        action def OffloadBlocks {
            in storedMass : MassValue;
            out offloadStatus : String;
        }

        action def TransmitStatus {
            in location : String;
            in powerLevel : Percentage;
            in plasticCollected : MassValue;
            in vesselState : String;
            out report : StatusReport;
        }

        action def MonitorBattery {
            out chargeLevel : Percentage;
        }

        action def CollectAndProcess {
            action detect : DetectPlastic;
            then action plot : PlotCourse {
                in destination = detect.debrisLocation;
            }
            then action engage : EngagePropulsion {
                in course = plot.course;
                in targetSpeed = plot.targetSpeed;
            }
            then action collect : CollectDebris;
            then action shred : ShredPlastic {
                in debris = collect.debris;
            }
            then action compress : CompressBlocks {
                in shredded = shred.shredded;
            }
            then action store : StoreBlocks {
                in block = compress.block;
            }
            then done;
        }

        state def 'Vessel States';

        part def SolarArray {
            port powerOut : PowerOutPort;
            attribute outputPower : PowerValue;
            attribute panelArea : AreaValue;
        }

        part def BatterySystem {
            port powerIn : PowerInPort;
            port powerOut : PowerOutPort;
            attribute storedEnergy : EnergyValue;
            attribute maxCapacity : EnergyValue;
            attribute chargeLevel : Percentage;
            attribute minThreshold : Percentage;
        }

        part def OpticalSensor {
            port powerIn : PowerInPort;
            port detectionOut : DetectionOutPort;
            attribute isActive : Boolean;
            attribute range : DistanceValue;
        }

        part def SonarArray {
            port powerIn : PowerInPort;
            port detectionOut : DetectionOutPort;
            attribute isActive : Boolean;
            attribute depthRange : DistanceValue;
        }

        part def DetectionSystem {
            port powerIn : PowerInPort;
            port detectionOut : DetectionOutPort;
            part opticalSensor : OpticalSensor;
            part sonarArray : SonarArray;
            attribute debrisDetected : Boolean;
            attribute plasticConcentration : ConcentrationValue;
        }

        part def NavigationController {
            port powerIn : PowerInPort;
            port detectionIn : DetectionInPort;
            port navOut : NavCommandPort;
            attribute destination : String;
            attribute currentLocation : String;
            attribute isAutonomous : Boolean;
        }

        part def ConveyorBelt {
            port powerIn : PowerInPort;
            port debrisOut : DebrisFlowPort;
            attribute isActive : Boolean;
            attribute throughput : MassValue;
        }

        part def FilteringScreen {
            port debrisOut : DebrisFlowPort;
            attribute meshSize : DistanceValue;
        }

        part def CollectionMechanism {
            port powerIn : PowerInPort;
            port debrisOut : DebrisFlowPort;
            part conveyor : ConveyorBelt;
            part screen : FilteringScreen;
            attribute isActive : Boolean;
        }

        part def Shredder {
            port powerIn : PowerInPort;
            port debrisIn : DebrisReceivePort;
            port shreddedOut : DebrisFlowPort;
            attribute isActive : Boolean;
            attribute bladeSpeed : Real;
        }

        part def Compressor {
            port powerIn : PowerInPort;
            port debrisIn : DebrisReceivePort;
            port blockOut : BlockFlowPort;
            attribute isActive : Boolean;
            attribute compressionRatio : Real;
        }

        part def ProcessingUnit {
            port powerIn : PowerInPort;
            port debrisIn : DebrisReceivePort;
            port blockOut : BlockFlowPort;
            part shredder : Shredder;
            part compressor : Compressor;
            attribute isActive : Boolean;
        }

        part def StorageContainer {
            port blockIn : BlockReceivePort;
            attribute storedMass : MassValue;
            attribute maxCapacity : MassValue;
            attribute isFull : Boolean;
        }

        part def PropulsionSystem {
            port powerIn : PowerInPort;
            port navIn : NavReceivePort;
            attribute currentSpeed : SpeedValue;
            attribute heading : String;
        }

        part def CommunicationsModule {
            port powerIn : PowerInPort;
            port statusOut : StatusOutPort;
            attribute reportInterval : TimeValue;
            attribute lastReport : StatusReport;
        }

        part def CleanupVessel {
            attribute vesselId : String;
            attribute missionArea : String;
            attribute offloadLocation : String;
            attribute plasticCollected : MassValue;
            attribute powerLevel : Percentage;
            attribute powerThreshold : Percentage;
            attribute concentrationThreshold : ConcentrationValue;
            attribute currentLocation : String;

            part solarArray : SolarArray;
            part batterySystem : BatterySystem;
            part detectionSystem : DetectionSystem;
            part navigationController : NavigationController;
            part collectionMechanism : CollectionMechanism;
            part processingUnit : ProcessingUnit;
            part storageContainer : StorageContainer;
            part propulsionSystem : PropulsionSystem;
            part communicationsModule : CommunicationsModule;

            connect solarArray.powerOut to batterySystem.powerIn;
            connect batterySystem.powerOut to propulsionSystem.powerIn;
            connect batterySystem.powerOut to detectionSystem.powerIn;
            connect batterySystem.powerOut to collectionMechanism.powerIn;
            connect batterySystem.powerOut to processingUnit.powerIn;
            connect batterySystem.powerOut to navigationController.powerIn;
            connect batterySystem.powerOut to communicationsModule.powerIn;
            connect detectionSystem.detectionOut to navigationController.detectionIn;
            connect navigationController.navOut to propulsionSystem.navIn;
            connect collectionMechanism.debrisOut to processingUnit.debrisIn;
            connect processingUnit.blockOut to storageContainer.blockIn;

            exhibit state 'vessel states': 'Vessel States';
            perform action 'patrol': Patrol;
            perform action 'collect and process': CollectAndProcess;
            perform action 'conserve power': ConservePower;
            perform action 'navigate to offload': NavigateToOffload;
            perform action 'offload blocks': OffloadBlocks;
            perform action 'transmit status': TransmitStatus;
            perform action 'monitor battery': MonitorBattery;
        }
    }

    package Usages {
        private import Definitions::*;

        action 'patrol': Patrol;
        action 'collect and process': CollectAndProcess;
        action 'conserve power': ConservePower;
        action 'navigate to offload': NavigateToOffload;
        action 'offload blocks': OffloadBlocks;
        action 'transmit status': TransmitStatus;
        action 'monitor battery': MonitorBattery;

        part cleanupVessel : CleanupVessel {
            attribute vesselId = "OCV-001";
            attribute missionArea = "North Pacific Gyre";
            attribute offloadLocation = "Collection Station Alpha";
            attribute powerThreshold = 20;
            attribute concentrationThreshold = 0.7;
        }

        state 'vessel states': 'Vessel States' parallel {
            state 'mission states' {
                entry; then patrolling;

                state patrolling {
                    do 'patrol';
                    do 'transmit status';
                }
                accept 'PlasticDetected'
                    then collectingProcessing;

                state collectingProcessing {
                    entry 'collect and process';
                    do 'transmit status';
                }
                accept 'StorageFull'
                    do send new 'ReturnToBaseCommand'() to cleanupVessel.navigationController
                    then returningToOffload;
                accept 'DebrisDepleted'
                    then patrolling;

                state returningToOffload {
                    entry 'navigate to offload';
                    do 'transmit status';
                }
                accept 'ArrivedAtOffload'
                    then offloading;

                state offloading {
                    entry 'offload blocks';
                    do 'transmit status';
                }
                accept 'OffloadComplete'
                    then patrolling;
            }

            state 'power management states' {
                entry; then normalPower;

                state normalPower {
                    do 'monitor battery';
                }
                accept when cleanupVessel.batterySystem.chargeLevel < cleanupVessel.powerThreshold
                    do send new 'LowPowerAlert'() to cleanupVessel.communicationsModule
                    then powerConservation;

                state powerConservation {
                    entry 'conserve power';
                    do 'transmit status';
                }
                accept when cleanupVessel.batterySystem.chargeLevel > 50
                    then normalPower;
            }
        }
    }

    package Requirements {
        private import Definitions::*;
        private import Types::*;

        requirement def 'Solar Power Autonomy' {
            doc /* The vessel must operate autonomously powered entirely by solar energy. */
            subject vessel : CleanupVessel;
        }

        requirement def 'Debris Detection Capability' {
            doc /* The vessel must detect plastic debris on and below the surface using optical and sonar sensors. */
            subject vessel : CleanupVessel;
        }

        requirement def 'Collection and Processing' {
            doc /* The vessel must collect, shred, and compress plastic debris into dense blocks. */
            subject vessel : CleanupVessel;
        }

        requirement def 'Storage Capacity' {
            doc /* The vessel must store compressed plastic blocks in a high-capacity container. */
            subject vessel : CleanupVessel;
        }

        requirement def 'Autonomous Navigation' {
            doc /* The vessel must autonomously navigate to detected debris and offload locations. */
            subject vessel : CleanupVessel;
        }

        requirement def 'Communication Reporting' {
            doc /* The vessel must regularly transmit status, location, and plastic collected. */
            subject vessel : CleanupVessel;
        }

        requirement def 'Power Conservation Mode' {
            doc /* The vessel must enter power conservation when battery charge falls below threshold. */
            subject vessel : CleanupVessel;
        }

        requirement def 'Continuous Night Operation' {
            doc /* The vessel must operate through the night using stored solar energy. */
            subject vessel : CleanupVessel;
        }
    }
}
