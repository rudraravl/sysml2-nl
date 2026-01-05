package 'Noria Water Lifting System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def WaterFlowRate :> ISQ::VolumeFlowRateValue;
    attribute def RotationalSpeed :> ISQ::AngularVelocityValue;
    attribute def BucketCapacity :> ISQ::VolumeValue;
    attribute def LiftHeight :> ISQ::LengthValue;
    attribute def WaterLevel :> ISQ::LengthValue;
    attribute def BucketPosition :> Real;
    attribute def Efficiency :> Real;
    
    item def Water {
        attribute volume :> ISQ::volume;
        attribute flowRate :> ISQ::volumeFlowRate;
        attribute temperature :> ISQ::temperature;
    }
    
    port def WaterIntakePort {
        in item water : Water;
        attribute intakeRate :> ISQ::volumeFlowRate;
    }
    
    port def WaterDischargePort {
        out item water : Water;
        attribute dischargeRate :> ISQ::volumeFlowRate;
    }
    
    port def MechanicalDrivePort {
        in attribute torque :> ISQ::torque;
        in attribute angularVelocity :> ISQ::angularVelocity;
    }
    
    part def Bucket {
        attribute capacity :> ISQ::volume;
        attribute currentVolume :> ISQ::volume;
        attribute position : Real;
        attribute isFilled : Boolean;
        attribute fillLevel : Real;
        
        port waterIntake : WaterIntakePort;
        port waterDischarge : WaterDischargePort;
    }
    
    part def Wheel {
        attribute diameter :> ISQ::diameter;
        attribute radius :> ISQ::radius;
        attribute rotationSpeed :> ISQ::angularVelocity;
        attribute numberOfBuckets : ScalarValues::Integer;
        attribute currentAngle : Real;
        
        part buckets : Bucket[*] ordered;
        
        port driveInput : MechanicalDrivePort;
    }
    
    part def WaterSource {
        attribute waterLevel :> ISQ::length;
        attribute surfaceArea :> ISQ::area;
        attribute availableVolume :> ISQ::volume;
        attribute replenishmentRate :> ISQ::volumeFlowRate;
        
        port waterOutput : WaterDischargePort;
    }
    
    part def DischargeChannel {
        attribute elevation :> ISQ::length;
        attribute channelLength :> ISQ::length;
        attribute channelWidth :> ISQ::width;
        attribute channelDepth :> ISQ::length;
        attribute capacity :> ISQ::volume;
        
        port waterInput : WaterIntakePort;
        port waterOutput : WaterDischargePort;
    }
    
    part def DriveSystem {
        attribute driveTorque :> ISQ::torque;
        attribute drivePower :> ISQ::power;
        attribute driveSpeed :> ISQ::angularVelocity;
        attribute efficiency : Efficiency;
        
        port torqueOutput : MechanicalDrivePort;
    }
    
    part def SupportStructure {
        attribute height :> ISQ::height;
        attribute baseWidth :> ISQ::width;
        attribute material : String;
        attribute loadCapacity :> ISQ::force;
    }
    
    action def FillBucket {
        in bucket : Bucket;
        in sourceWater : Water;
        in submersionDepth : ISQ::LengthValue;
        out filledBucket : Bucket;
        
        first start;
        then action submerge {
            doc /* Bucket enters water source at lower position */
        }
        then action collectWater {
            doc /* Water flows into bucket through intake opening */
        }
        then action completeFill {
            doc /* Bucket reaches maximum capacity or exits water */
        }
        then done;
    }
    
    action def LiftWater {
        in bucket : Bucket;
        in liftHeight : LiftHeight;
        in rotationSpeed : RotationalSpeed;
        out elevatedBucket : Bucket;
        
        first start;
        then action ascend {
            doc /* Bucket rises along wheel circumference */
        }
        then action maintainWater {
            doc /* Water retained in bucket during vertical ascent */
        }
        then action reachTop {
            doc /* Bucket arrives at highest point of rotation */
        }
        then done;
    }
    
    action def DischargeBucket {
        in bucket : Bucket;
        in dischargeAngle : Real;
        out emptyBucket : Bucket;
        out dischargedWater : Water;
        
        first start;
        then action tilt {
            doc /* Bucket orientation changes at discharge point */
        }
        then action pourWater {
            doc /* Water flows out of bucket into discharge channel */
        }
        then action completeDischarge {
            doc /* Bucket emptied and ready for next cycle */
        }
        then done;
    }
    
    action def OperateNoria {
        in waterSource : WaterSource;
        in driveForce : ISQ::TorqueValue;
        in targetFlowRate : WaterFlowRate;
        out liftedWater : Water[*];
        out actualFlowRate : WaterFlowRate;
        
        first start;
        then merge continuousOperation;
        
        then action rotateWheel {
            doc /* Drive system applies torque to rotate wheel continuously */
        }
        
        then fork parallelBucketOperations;
        
        action fillBuckets : FillBucket[*] {
            doc /* Buckets at bottom position fill from water source */
        }
        
        action liftBuckets : LiftWater[*] {
            doc /* Filled buckets ascend along wheel circumference */
        }
        
        action dischargeBuckets : DischargeBucket[*] {
            doc /* Buckets at top position discharge into channel */
        }
        
        then join afterBucketCycle;
        
        then action collectDischargedWater {
            doc /* Discharged water accumulates in delivery channel */
        }
        
        then action measureFlowRate {
            doc /* Calculate actual water delivery rate */
        }
        
        then decide;
            if driveForce > 0.0 [SI::N*SI::m] then continuousOperation;
            if driveForce == 0.0 [SI::N*SI::m] then stopOperation;
        
        action stopOperation {
            doc /* Noria ceases operation when drive force removed */
        }
        then done;
    }
    
    state def BucketLifecycle {
        entry; then submerged;
        
        state submerged {
            doc /* Bucket positioned in water source, filling */
            entry action fillBucket : FillBucket;
        }
        then ascending;
        
        state ascending {
            doc /* Bucket rising with wheel rotation, retaining water */
            do action liftWater : LiftWater;
        }
        then discharging;
        
        state discharging {
            doc /* Bucket tilted at top, releasing water */
            entry action discharge : DischargeBucket;
        }
        then descending;
        
        state descending {
            doc /* Empty bucket returning to water source */
        }
        then submerged;
    }
    
    requirement def <'NOR-REQ-001'> WaterLiftingCapability {
        doc /* The noria system shall continuously lift water from a lower elevation 
               water source to a higher elevation discharge point through rotational 
               motion of buckets attached to a wheel. */
        
        subject noria : NoriaSystem;
        
        require constraint liftHeightPositive {
            noria.liftHeight > 0.0 [SI::m]
        }
        
        require constraint outputFlowPositive {
            noria.outputFlowRate > 0.0 [SI::m^3/SI::s]
        }
    }
    
    requirement def <'NOR-REQ-002'> ContinuousOperationRequirement {
        doc /* The noria shall operate continuously as long as drive force is applied 
               and water source is available. */
        
        subject noria : NoriaSystem;
        
        require constraint driveCondition {
            noria.driveSystem.driveTorque > 0.0 [SI::N*SI::m] and 
            noria.waterSource.waterLevel > 0.5 [SI::m] implies 
            noria.wheel.rotationSpeed > 0.0 [SI::rad/SI::s]
        }
    }
    
    requirement def <'NOR-REQ-003'> BucketEfficiencyRequirement {
        doc /* Each bucket shall fill to at least 75% capacity during submersion 
               to ensure efficient water transfer. */
        
        subject bucket : Bucket;
        
        require constraint fillEfficiency {
            bucket.currentVolume >= 0.75 * bucket.capacity
        }
    }
    
    requirement def <'NOR-REQ-004'> MinimumFlowRateRequirement {
        doc /* The noria system shall deliver a minimum flow rate based on wheel 
               diameter, rotation speed, and number of buckets. */
        
        subject noria : NoriaSystem;
        
        require constraint minimumFlow {
            noria.outputFlowRate >= 0.005 [SI::m^3/SI::s]
        }
    }
    
    requirement def <'NOR-REQ-005'> StructuralIntegrityRequirement {
        doc /* The support structure shall withstand the combined weight of the wheel, 
               buckets, and water load with adequate safety margin. */
        
        subject structure : SupportStructure;
        
        require constraint loadCapacity {
            structure.loadCapacity >= 15000.0 [SI::N]
        }
    }
    
    connection def DriveConnection {
        end source : DriveSystem::torqueOutput[1];
        end target : Wheel::driveInput[1];
    }
    
    connection def WaterFlowConnection {
        end source[1];
        end target[1];
        item water : Water;
    }
    
    part def NoriaSystem {
        attribute liftHeight : LiftHeight;
        attribute outputFlowRate : WaterFlowRate;
        attribute wheelDiameter : ISQ::DiameterValue;
        attribute numberOfBuckets : ScalarValues::Integer;
        attribute systemEfficiency : Efficiency;
        attribute operatingHours : ISQ::TimeValue;
        
        part waterSource : WaterSource {
            attribute waterLevel = 2.5 [SI::m];
            attribute surfaceArea = 50.0 [SI::m^2];
            attribute availableVolume = 125.0 [SI::m^3];
            attribute replenishmentRate = 0.01 [SI::m^3/SI::s];
        }
        
        part wheel : Wheel {
            attribute diameter = 8.0 [SI::m];
            attribute radius = 4.0 [SI::m];
            attribute rotationSpeed = 0.1047 [SI::rad/SI::s];
            attribute numberOfBuckets = 24;
            attribute currentAngle = 0.0;
            
            part buckets : Bucket[24] ordered {
                attribute capacity = 15.0 [SI::L];
                attribute currentVolume = 0.0 [SI::L];
                attribute position = 0.0;
                attribute isFilled = false;
                attribute fillLevel = 0.0;
            }
        }
        
        part driveSystem : DriveSystem {
            attribute driveTorque = 500.0 [SI::N*SI::m];
            attribute drivePower = 52.35 [SI::W];
            attribute driveSpeed = 0.1047 [SI::rad/SI::s];
            attribute efficiency = 0.85;
        }
        
        part dischargeChannel : DischargeChannel {
            attribute elevation = 6.0 [SI::m];
            attribute channelLength = 10.0 [SI::m];
            attribute channelWidth = 0.5 [SI::m];
            attribute channelDepth = 0.3 [SI::m];
            attribute capacity = 1.5 [SI::m^3];
        }
        
        part supportStructure : SupportStructure {
            attribute height = 9.0 [SI::m];
            attribute baseWidth = 3.0 [SI::m];
            attribute material = "reinforced timber";
            attribute loadCapacity = 20000.0 [SI::N];
        }
        
        connection wheelDrive : DriveConnection 
            connect driveSystem.torqueOutput to wheel.driveInput;
        
        connection waterIntake : WaterFlowConnection 
            connect waterSource.waterOutput to wheel.buckets.waterIntake;
        
        connection waterDischarge : WaterFlowConnection 
            connect wheel.buckets.waterDischarge to dischargeChannel.waterInput;
        
        perform action operateNoria : OperateNoria {
            in waterSource = NoriaSystem::waterSource;
            in driveForce = driveSystem.driveTorque;
            in targetFlowRate = 0.006 [SI::m^3/SI::s];
            out liftedWater : Water[*];
            out actualFlowRate : WaterFlowRate;
        }
    }
    
    part noriaSystem : NoriaSystem {
        attribute liftHeight = 6.0 [SI::m];
        attribute outputFlowRate = 0.006 [SI::m^3/SI::s];
        attribute wheelDiameter = 8.0 [SI::m];
        attribute numberOfBuckets = 24;
        attribute systemEfficiency = 0.72;
        attribute operatingHours = 0.0 [SI::s];
        
        satisfy <'NOR-REQ-001'> by noriaSystem;
        satisfy <'NOR-REQ-002'> by noriaSystem;
        satisfy <'NOR-REQ-003'> by noriaSystem.wheel.buckets;
        satisfy <'NOR-REQ-004'> by noriaSystem;
        satisfy <'NOR-REQ-005'> by noriaSystem.supportStructure;
    }
}
