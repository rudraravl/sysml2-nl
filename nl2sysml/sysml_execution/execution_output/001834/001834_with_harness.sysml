package 'AutonomousOceanCleanupSystem' {
    private import ISQ::*;
    private import ScalarValues::*;
    private import SI::*;
    
    doc /* 
        This model describes an autonomous ocean plastic collection system inspired by 
        ocean cleanup technologies featured in Popular Science. The system uses solar-powered 
        autonomous vessels to detect, collect, and process ocean plastic debris, converting 
        waste into compressed recyclable material while operating continuously at sea.
    */
    
    attribute def PlasticConcentration :> Real;
    attribute def GPSCoordinate :> Real;
    attribute def SystemStatus;
    
    alias WaterSpeed for SpeedValue;
    alias PlasticMass for MassValue;
    alias SolarPower for PowerValue;
    alias BatteryCapacity for EnergyValue;
    alias CollectionRate for MassFlowRateValue;
    alias StorageVolume for VolumeValue;
    
    item def PlasticDebris {
        attribute mass : PlasticMass;
        attribute debrisType : String;
        attribute location : GPSCoordinate[2];
    }
    
    item def CompressedPlastic {
        attribute mass : PlasticMass;
        attribute volume : StorageVolume;
        attribute density : Real;
    }
    
    item def NavigationData {
        attribute latitude : GPSCoordinate;
        attribute longitude : GPSCoordinate;
        attribute heading : AngleValue;
        attribute speed : WaterSpeed;
    }
    
    item def SensorData {
        attribute plasticConcentration : PlasticConcentration;
        attribute waterDepth : LengthValue;
        attribute currentSpeed : WaterSpeed;
    }
    
    port def PowerInputPort {
        in attribute power : SolarPower;
    }
    
    port def PowerOutputPort {
        out attribute power : SolarPower;
    }
    
    port def DataPort {
        flow data : SensorData;
    }
    
    port def NavigationPort {
        flow navData : NavigationData;
    }
    
    port def PlasticIntakePort {
        in item debris : PlasticDebris;
    }
    
    port def PlasticOutputPort {
        out item compressed : CompressedPlastic;
    }
    
    part def SolarPanelArray {
        attribute totalArea : AreaValue;
        attribute efficiency : Real;
        attribute peakPower : SolarPower;
        port powerOut : PowerOutputPort;
    }
    
    part def BatterySystem {
        attribute capacity : BatteryCapacity;
        attribute currentCharge : BatteryCapacity;
        attribute voltage : EnergyValue;
        port chargeIn : PowerInputPort;
        port powerOut : PowerOutputPort;
    }
    
    part def PropulsionSystem {
        attribute maxThrust : ForceValue;
        attribute currentSpeed : WaterSpeed;
        port powerIn : PowerInputPort;
        port navControl : NavigationPort;
    }
    
    part def PlasticDetectionSystem {
        attribute detectionRange : LengthValue;
        attribute accuracy : Real;
        port powerIn : PowerInputPort;
        port sensorOut : DataPort;
        
        part opticalSensor {
            attribute resolution : Real;
            attribute fieldOfView : AngleValue;
        }
        
        part sonarArray {
            attribute frequency : FrequencyValue;
            attribute range : LengthValue;
        }
    }
    
    part def CollectionMechanism {
        attribute intakeWidth : LengthValue;
        attribute maxCollectionRate : CollectionRate;
        port powerIn : PowerInputPort;
        port plasticIn : PlasticIntakePort;
        
        part conveyorBelt {
            attribute speed : WaterSpeed;
            attribute width : LengthValue;
        }
        
        part filteringScreen {
            attribute meshSize : LengthValue;
            attribute efficiency : Real;
        }
    }
    
    part def ProcessingUnit {
        attribute compressionRatio : Real;
        attribute processingRate : CollectionRate;
        port powerIn : PowerInputPort;
        port plasticOut : PlasticOutputPort;
        
        part shredder {
            attribute bladeSpeed : AngularSpeedValue;
            attribute throughput : CollectionRate;
        }
        
        part compressor {
            attribute pressure : PressureValue;
            attribute cycleTime : DurationValue;
        }
    }
    
    part def StorageContainer {
        attribute maxCapacity : StorageVolume;
        attribute currentLoad : PlasticMass;
        attribute compartments : Integer;
        port plasticIn : PlasticOutputPort;
    }
    
    part def NavigationController {
        attribute currentPosition : GPSCoordinate[2];
        attribute targetPosition : GPSCoordinate[2];
        port navOut : NavigationPort;
        port sensorIn : DataPort;
    }
    
    part def CommunicationModule {
        attribute transmitPower : PowerValue;
        attribute dataRate : Real;
        port powerIn : PowerInputPort;
    }
    
    action def DetectPlastic {
        in sensorData : SensorData;
        out plasticLocation : GPSCoordinate[2];
        out concentration : PlasticConcentration;
    }
    
    action def NavigateToTarget {
        in currentPos : GPSCoordinate[2];
        in targetPos : GPSCoordinate[2];
        out navigationCmd : NavigationData;
    }
    
    action def CollectDebris {
        in debrisLocation : GPSCoordinate[2];
        in collectionRate : CollectionRate;
        out collectedMass : PlasticMass;
    }
    
    action def ProcessPlastic {
        in rawPlastic : PlasticMass;
        out compressedOutput : CompressedPlastic;
    }
    
    action def MonitorPower {
        in solarInput : SolarPower;
        in batteryCharge : BatteryCapacity;
        out operationalStatus : Boolean;
    }
    
    action def TransmitStatus {
        in systemData : SensorData;
        in position : GPSCoordinate[2];
    }
    
    action def AutonomousCleanupOperation {
        in attribute operationDuration :> ISQ::time;
        in attribute targetArea : GPSCoordinate[4];
        
        attribute totalCollected : PlasticMass;
        attribute currentWaypoint : Integer;
        attribute operationTime : DurationValue;
        
        first start;
        then merge mainLoop;
        
        then action monitorPower : MonitorPower {
            in solarInput;
            in batteryCharge;
            out operationalStatus;
        }
        
        then decide;
            if monitorPower.operationalStatus then scanAndCollect;
            if not monitorPower.operationalStatus then conservePower;
        
        action scanAndCollect {
            action detect : DetectPlastic {
                in sensorData;
                out plasticLocation;
                out concentration;
            }
            
            then decide;
                if detect.concentration > 0.1 then navigateAndCollect;
                if detect.concentration <= 0.1 then continuePatrol;
            
            action navigateAndCollect {
                action navigate : NavigateToTarget {
                    in currentPos;
                    in targetPos = detect.plasticLocation;
                    out navigationCmd;
                }
                
                then action collect : CollectDebris {
                    in debrisLocation = detect.plasticLocation;
                    in collectionRate;
                    out collectedMass;
                }
                
                then action process : ProcessPlastic {
                    in rawPlastic = collect.collectedMass;
                    out compressedOutput;
                }
                
                then checkStorage;
            }
            
            action continuePatrol {
                then checkStorage;
            }
            
            action checkStorage {
                then decide;
                    if totalCollected < 5000.0 then transmitAndContinue;
                    if totalCollected >= 5000.0 then returnToBase;
            }
            
            action transmitAndContinue {
                action transmit : TransmitStatus {
                    in systemData;
                    in position;
                }
                then decide;
                    if operationTime < operationDuration then mainLoop;
                    if operationTime >= operationDuration then missionComplete;
            }
            
            action returnToBase {
                then missionComplete;
            }
        }
        
        action conservePower {
            then mainLoop;
        }
        
        action missionComplete {
            then done;
        }
    }
    
    state def CleanupSystemStates {
        entry; then idle;
        
        state idle;
        accept DeployCommand;
        then initializing;
        
        state initializing;
        then patrolling;
        
        state patrolling;
        if plasticDetected then collecting;
        if batteryLow then charging;
        if storageNearFull then returning;
        
        state collecting;
        if collectionComplete then processing;
        if batteryLow then charging;
        
        state processing;
        then patrolling;
        
        state charging;
        if batteryFull then patrolling;
        
        state returning;
        then offloading;
        
        state offloading;
        then idle;
        
        accept EmergencyStop;
        then idle;
    }
    
    part oceanCleanupVessel {
        attribute vesselID : String;
        attribute deploymentDate : String;
        
        part solar : SolarPanelArray {
            attribute totalArea = 25.0;
            attribute efficiency = 0.22;
            attribute peakPower = 5500.0;
        }
        
        part battery : BatterySystem {
            attribute capacity = 50.0;
            attribute voltage = 48.0;
        }
        
        part propulsion : PropulsionSystem {
            attribute maxThrust = 2000.0;
        }
        
        part detection : PlasticDetectionSystem {
            attribute detectionRange = 100.0;
            attribute accuracy = 0.95;
        }
        
        part collector : CollectionMechanism {
            attribute intakeWidth = 3.0;
            attribute maxCollectionRate = 500.0;
        }
        
        part processor : ProcessingUnit {
            attribute compressionRatio = 10.0;
            attribute processingRate = 400.0;
        }
        
        part storage : StorageContainer {
            attribute maxCapacity = 10.0;
            attribute compartments = 4;
        }
        
        part navigator : NavigationController;
        
        part comms : CommunicationModule {
            attribute transmitPower = 50.0;
        }
        
        connect solar.powerOut to battery.chargeIn;
        connect battery.powerOut to propulsion.powerIn;
        connect battery.powerOut to detection.powerIn;
        connect battery.powerOut to collector.powerIn;
        connect battery.powerOut to processor.powerIn;
        connect battery.powerOut to comms.powerIn;
        
        connect detection.sensorOut to navigator.sensorIn;
        connect navigator.navOut to propulsion.navControl;
        
        perform action cleanupMission : AutonomousCleanupOperation;
        exhibit state operationalBehavior : CleanupSystemStates;
    }
    
    requirement def <'REQ-001'> CollectionCapabilityRequirement {
        doc /* The system shall collect and process a minimum of 2000 kg of ocean plastic 
                per 24-hour operational cycle under normal sea conditions. */
        
        subject vessel : oceanCleanupVessel;
        
        require constraint {
            vessel.collector.maxCollectionRate >= 500.0
        }
    }
    
    requirement def <'REQ-002'> EnergyAutonomyRequirement {
        doc /* The system shall operate autonomously for at least 30 days using solar power 
                with battery backup for nighttime and low-light conditions. */
        
        subject vessel : oceanCleanupVessel;
        
        require constraint {
            vessel.battery.capacity >= 50.0 and
            vessel.solar.peakPower >= 5000.0
        }
    }
    
    requirement def <'REQ-003'> DetectionAccuracyRequirement {
        doc /* The plastic detection system shall identify plastic debris with minimum 
                90% accuracy at ranges up to 100 meters. */
        
        subject vessel : oceanCleanupVessel;
        
        require constraint {
            vessel.detection.accuracy >= 0.90 and
            vessel.detection.detectionRange >= 100.0
        }
    }
    
    requirement def <'REQ-004'> StorageCapacityRequirement {
        doc /* The onboard storage shall accommodate at least 5000 kg of compressed 
                plastic before requiring offload. */
        
        subject vessel : oceanCleanupVessel;
        
        require constraint {
            vessel.storage.maxCapacity >= 10.0
        }
    }
    
    requirement def <'REQ-005'> NavigationPrecisionRequirement {
        doc /* The autonomous navigation system shall maintain position accuracy 
                within 5 meters of target coordinates. */
        
        subject vessel : oceanCleanupVessel;
        
        require constraint {
            vessel.navigator.currentPosition[0] != 0.0 and
            vessel.navigator.currentPosition[1] != 0.0
        }
    }
    
    requirement missionRequirements {
        doc /* Top-level requirements for autonomous ocean cleanup system. */
        
        require collectionCapability : CollectionCapabilityRequirement;
        require energyAutonomy : EnergyAutonomyRequirement;
        require detectionAccuracy : DetectionAccuracyRequirement;
        require storageCapacity : StorageCapacityRequirement;
        require navigationPrecision : NavigationPrecisionRequirement;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ISQ::*;
    private import ScalarValues::*;
    private import SI::*;
    private import AutonomousOceanCleanupSystem::*;

    part testSubject = oceanCleanupVessel {
        exhibit state sm : CleanupSystemStates;
    }

    action orchestrator {
        action detectProbe : DetectPlastic {
            // TODO(human): unsupported input type for sensorData: SensorData (unsupported structured payload members: currentSpeed)
        }
        first detectProbe;
    }
}
