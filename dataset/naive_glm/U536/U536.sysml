package NoriaSystem {

    import ScalarValues::*;
    import ScalarFunctions::*;

    // ===== Value Types with Units =====
    value def Length :> Real { unit "m"; }
    value def Height :> Real { unit "m"; }
    value def Diameter :> Real { unit "m"; }
    value def Volume :> Real { unit "L"; }
    value def Torque :> Real { unit "N*m"; }
    value def RotationalSpeed :> Real { unit "rpm"; }
    value def FlowRate :> Real { unit "L/s"; }
    value def Force :> Real { unit "N"; }
    value def Mass :> Real { unit "kg"; }
    value def Angle :> Real { unit "deg"; }
    value def Power :> Real { unit "W"; }
    value def Duration :> Real { unit "s"; }
    value def Density :> Real { unit "kg/L"; }

    // ===== Items =====
    item def Water {
        attribute density : Density = 1.0 [kg/L];
    }

    item def StructuralLoad {
        attribute weight : Force;
        attribute description : String;
    }

    // ===== Port Definitions =====
    port def TorquePort {
        out attribute torque : Torque;
        out attribute speed : RotationalSpeed;
    }

    port def WaterFlowPort {
        out item water : Water;
        attribute flowRate : FlowRate;
    }

    port def StructuralPort {
        out attribute load : Force;
    }

    // ===== Part Definitions =====

    part def SupportStructure {
        attribute height : Height = 9 [m];
        attribute material : String = "reinforced timber";
        attribute loadCapacity : Force = 50000 [N];
        attribute currentLoad : Force = 0 [N];

        port basePort : StructuralPort;
        port topPort : StructuralPort;

        action def transferLoad {
            in load : Force;
            out reaction : Force;
        }
    }

    part def Bucket {
        attribute capacity : Volume = 15 [L];
        attribute currentVolume : Volume = 0 [L];
        attribute positionAngle : Angle = 0 [deg];
        attribute isFull : Boolean = false;
        attribute isEmpty : Boolean = true;
        attribute tiltAngle : Angle = 0 [deg];

        port intakePort : WaterFlowPort;
        port dischargePort : WaterFlowPort;

        state def BucketCycle {
            state Empty {
                entry { currentVolume = 0 [L]; isEmpty = true; isFull = false; }
            }
            state Filling {
                entry { isEmpty = false; }
            }
            state Full {
                entry { isFull = true; currentVolume = capacity; }
            }
            state Lifting;
            state Pouring {
                entry { tiltAngle = 120 [deg]; }
            }
            state Descending {
                entry { tiltAngle = 0 [deg]; }
            }

            transition from Empty to Filling
                when positionAngle > 330 [deg] or positionAngle < 30 [deg];
            transition from Filling to Full
                when currentVolume >= capacity;
            transition from Full to Lifting
                when positionAngle >= 30 [deg] and positionAngle < 170 [deg];
            transition from Lifting to Pouring
                when positionAngle >= 170 [deg];
            transition from Pouring to Descending
                when currentVolume <= 0 [L];
            transition from Descending to Empty
                when positionAngle >= 330 [deg];
        }

        state machine : BucketCycle;

        action def scoopWater {
            in sourceWater : Water;
            out scoopedWater : Water;
            // Fill bucket from water source
        }

        action def pourWater {
            in storedWater : Water;
            out dischargedWater : Water;
            // Tilt and empty bucket into discharge channel
        }
    }

    part def Wheel {
        attribute diameter : Diameter = 8 [m];
        attribute radius : Length = 4 [m];
        attribute numberOfBuckets : Integer = 24;
        attribute angularSpeed : RotationalSpeed = 2 [rpm];
        attribute bucketSpacing : Angle = 15 [deg];
        attribute wheelMass : Mass = 800 [kg];
        attribute structuralLoad : Force = 0 [N];

        port drivePort : TorquePort;
        port rimPort : WaterFlowPort;
        port axlePort : TorquePort;
        port supportPort : StructuralPort;

        part buckets : Bucket[24] {
            // Each bucket mounted at 15 degree intervals around the rim
        }

        action def rotate {
            in appliedTorque : Torque;
            out rotation : RotationalSpeed;
            // Convert torque to rotational motion
        }
    }

    part def Axle {
        attribute length : Length = 4 [m];
        attribute diameter : Length = 0.15 [m];
        attribute material : String = "steel";
        attribute maxTorque : Torque = 5000 [N*m];

        port driveEnd : TorquePort;
        port wheelEnd : TorquePort;

        action def transmitTorque {
            in inputTorque : Torque;
            out outputTorque : Torque;
        }
    }

    part def DriveSystem {
        attribute outputTorque : Torque = 2000 [N*m];
        attribute driveSpeed : RotationalSpeed = 2 [rpm];
        attribute powerInput : Power = 500 [W];
        attribute isActive : Boolean = false;
        attribute driveType : String = "water wheel";

        port outputPort : TorquePort;

        action def applyTorque {
            in power : Power;
            out torque : Torque;
            out speed : RotationalSpeed;
        }

        action def startDrive {
            out active : Boolean = true;
        }

        action def stopDrive {
            out active : Boolean = false;
        }
    }

    part def WaterSource {
        attribute sourceType : String = "river";
        attribute waterLevel : Height = 0 [m];
        attribute hasWater : Boolean = true;
        attribute availableFlow : FlowRate = 50 [L/s];

        port outletPort : WaterFlowPort;

        action def provideWater {
            out water : Water;
            out rate : FlowRate;
        }
    }

    part def DischargeChannel {
        attribute elevation : Height = 7 [m];
        attribute flowRate : FlowRate = 0 [L/s];
        attribute channelLength : Length = 10 [m];
        attribute material : String = "stone";

        port inletPort : WaterFlowPort;

        action def receiveWater {
            in water : Water;
            in rate : FlowRate;
            out deliveredFlow : FlowRate;
        }
    }

    // ===== Connection Definitions =====
    connection def TorqueConnection {
        end source : TorquePort;
        end target : TorquePort;
    }

    connection def WaterConnection {
        end source : WaterFlowPort;
        end target : WaterFlowPort;
    }

    connection def StructuralConnection {
        end loaded : StructuralPort;
        end support : StructuralPort;
    }

    // ===== Top-Level Noria System =====
    part def Noria {
        attribute systemDiameter : Diameter = 8 [m];
        attribute supportHeight : Height = 9 [m];
        attribute totalBuckets : Integer = 24;
        attribute bucketCapacity : Volume = 15 [L];
        attribute theoreticalFlowRate : FlowRate = 0 [L/s];
        attribute isOperational : Boolean = false;

        part supportStructure : SupportStructure;
        part wheel : Wheel;
        part driveSystem : DriveSystem;
        part waterSource : WaterSource;
        part dischargeChannel : DischargeChannel;
        part axle : Axle;

        connection driveToAxle : TorqueConnection
            connect driveSystem.outputPort to axle.driveEnd;

        connection axleToWheel : TorqueConnection
            connect axle.wheelEnd to wheel.drivePort;

        connection sourceToWheel : WaterConnection
            connect waterSource.outletPort to wheel.rimPort;

        connection wheelToChannel : WaterConnection
            connect wheel.rimPort to dischargeChannel.inletPort;

        connection wheelToSupport : StructuralConnection
            connect wheel.supportPort to supportStructure.topPort;

        action def computeFlowRate {
            in bucketCount : Integer;
            in capacity : Volume;
            in speed : RotationalSpeed;
            out flow : FlowRate;
            // flow = (bucketCount * capacity * speed) / 60
        }

        action def computeStructuralLoad {
            in wheelMass : Mass;
            in bucketCount : Integer;
            in bucketCapacity : Volume;
            in waterDensity : Density;
            out totalLoad : Force;
            // totalLoad = (wheelMass + bucketCount * bucketCapacity * waterDensity) * 9.81
        }

        state def OperationState {
            state Idle {
                entry { isOperational = false; }
            }
            state Starting {
                entry { driveSystem.isActive = true; }
            }
            state Running {
                entry { isOperational = true; }
                do {
                    theoreticalFlowRate = (wheel.numberOfBuckets * bucketCapacity * wheel.angularSpeed) / 60 [s];
                }
            }
            state Stopped {
                entry { driveSystem.isActive = false; isOperational = false; }
            }

            transition from Idle to Starting
                when driveSystem.isActive == true;
            transition from Starting to Running
                when wheel.angularSpeed > 0 [rpm];
            transition from Running to Stopped
                when driveSystem.isActive == false or waterSource.hasWater == false;
            transition from Stopped to Idle
                when driveSystem.isActive == false;
        }

        state machine : OperationState;
    }

    // ===== Requirements =====
    requirement def LiftWaterRequirement {
        subject noria : Noria;
        objective {
            doc /* The Noria shall lift water from a low-lying source to a higher elevation for irrigation. */
        }
    }

    requirement def WheelDiameterRequirement {
        subject wheel : Wheel;
        attribute requiredDiameter : Diameter = 8 [m];
        objective {
            wheel.diameter == requiredDiameter
        }
    }

    requirement def SupportHeightRequirement {
        subject support : SupportStructure;
        attribute requiredHeight : Height = 9 [m];
        objective {
            support.height == requiredHeight
        }
    }

    requirement def SupportMaterialRequirement {
        subject support : SupportStructure;
        attribute requiredMaterial : String = "reinforced timber";
        objective {
            support.material == requiredMaterial
        }
    }

    requirement def BucketCountRequirement {
        subject wheel : Wheel;
        attribute requiredCount : Integer = 24;
        objective {
            wheel.numberOfBuckets == requiredCount
        }
    }

    requirement def BucketCapacityRequirement {
        subject bucket : Bucket;
        attribute requiredCapacity : Volume = 15 [L];
        objective {
            bucket.capacity == requiredCapacity
        }
    }

    requirement def ContinuousOperationRequirement {
        subject noria : Noria;
        objective {
            doc /* The system shall operate continuously as long as the drive system is active and the water source has sufficient water. */
        }
    }

    requirement def StructuralIntegrityRequirement {
        subject support : SupportStructure;
        attribute minimumLoadCapacity : Force = 30000 [N];
        objective {
            doc /* The support structure shall safely support the combined weight of the wheel, buckets, and water being lifted. */
            support.loadCapacity >= minimumLoadCapacity
        }
    }

    requirement def DischargeElevationRequirement {
        subject channel : DischargeChannel;
        attribute minimumElevation : Height = 7 [m];
        objective {
            channel.elevation >= minimumElevation
        }
    }

    requirement def DriveTorqueRequirement {
        subject drive : DriveSystem;
        attribute minimumTorque : Torque = 1500 [N*m];
        objective {
            drive.outputTorque >= minimumTorque
        }
    }

    requirement def BucketCycleRequirement {
        subject bucket : Bucket;
        objective {
            doc /* Each bucket shall dip into the water source at the bottom, lift water upward, tilt and pour at the top, and return empty to repeat the cycle. */
        }
    }

    // ===== Requirement Satisfaction =====
    part def NoriaSystemVerification {
        part noria : Noria;

        requirement liftReq : LiftWaterRequirement {
            subject = noria;
        }
        requirement diameterReq : WheelDiameterRequirement {
            subject = noria.wheel;
        }
        requirement heightReq : SupportHeightRequirement {
            subject = noria.supportStructure;
        }
        requirement materialReq : SupportMaterialRequirement {
            subject = noria.supportStructure;
        }
        requirement bucketCountReq : BucketCountRequirement {
            subject = noria.wheel;
        }
        requirement bucketCapReq : BucketCapacityRequirement {
            subject = noria.wheel.buckets[1];
        }
        requirement continuousReq : ContinuousOperationRequirement {
            subject = noria;
        }
        requirement structuralReq : StructuralIntegrityRequirement {
            subject = noria.supportStructure;
        }
        requirement dischargeReq : DischargeElevationRequirement {
            subject = noria.dischargeChannel;
        }
        requirement torqueReq : DriveTorqueRequirement {
            subject = noria.driveSystem;
        }
        requirement cycleReq : BucketCycleRequirement {
            subject = noria.wheel.buckets[1];
        }
    }
}
