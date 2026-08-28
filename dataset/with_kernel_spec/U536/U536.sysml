package 'Noria Water Lifting System' {
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::*;
    private import NumericalFunctions::*;

    item def Water {
        attribute volume : VolumeValue;
    }

    attribute def StartCommand;
    attribute def StopCommand;

    port def WaterPort {
        out item water : Water;
    }

    port def TorquePort {
        out attribute torque : TorqueValue;
    }

    part def Bucket {
        attribute capacity : VolumeValue = 15 [L];
        attribute emptyMass : MassValue = 5 [kg];
        attribute currentVolume : VolumeValue default 0 [L];
        attribute currentWaterMass : MassValue = (currentVolume / capacity) * 15 [kg];
    }

    part def Wheel {
        attribute diameter : LengthValue = 8 [m];
        attribute mass : MassValue = 800 [kg];
        part buckets : Bucket[24];
        attribute totalEmptyBucketMass : MassValue = sum(buckets.emptyMass);
        attribute maxWaterMass : MassValue = 360 [kg] {
            doc /* Worst-case load assuming all 24 buckets full (24 * 15 L water approx 360 kg). */
        }
        attribute totalSupportedMass : MassValue = mass + totalEmptyBucketMass + maxWaterMass;
        port torqueInPort : ~TorquePort;
        port waterInPort : ~WaterPort;
        port waterOutPort : WaterPort;
    }

    part def SupportStructure {
        attribute height : LengthValue = 9 [m];
        attribute material : String = 'reinforced timber';
        attribute loadCapacity : MassValue = 5000 [kg];
    }

    part def DriveSystem {
        port torqueOutPort : TorquePort;
        attribute outputTorque : TorqueValue = 1200 [N*m];
        attribute isActive : Boolean = true;
    }

    part def WaterSource {
        port waterOutPort : WaterPort;
        attribute hasWater : Boolean = true;
        attribute waterLevel : LengthValue = 2 [m];
    }

    part def DischargeChannel {
        port waterInPort : ~WaterPort;
        attribute elevation : LengthValue = 8 [m];
    }

    action def OperateNoria {
        in driveActive : Boolean;
        in sourceHasWater : Boolean;
        out liftedWater : Water;
        loop {
            accept startCommand : StartCommand;
            then action {
                action 'dip' {
                    out water : Water;
                }
                flow 'dip'.water to 'lift'.water;
                action 'lift' {
                    in water : Water;
                    out water : Water;
                }
                flow 'lift'.water to 'pour'.water;
                action 'pour' {
                    in water : Water;
                    out water : Water;
                }
                flow 'pour'.water to liftedWater;
                action 'return' {}
            }
            then action accept stopCommand : StopCommand;
        }
    }

    part def NoriaSystem {
        part supportStructure : SupportStructure;
        part wheel : Wheel;
        part driveSystem : DriveSystem;
        part waterSource : WaterSource;
        part dischargeChannel : DischargeChannel;

        attribute isOperating : Boolean = driveSystem.isActive and waterSource.hasWater;

        connection torqueConnection from driveSystem.torqueOutPort to wheel.torqueInPort;
        flow of water : Water
            from waterSource.waterOutPort.water
            to wheel.waterInPort.water;
        flow of water : Water
            from wheel.waterOutPort.water
            to dischargeChannel.waterInPort.water;

        perform action operate : OperateNoria {
            in driveActive = driveSystem.isActive;
            in sourceHasWater = waterSource.hasWater;
            out liftedWater = wheel.waterOutPort.water;
        }

        assert constraint structuralIntegrity {
            supportStructure.loadCapacity >= wheel.totalSupportedMass
        }
    }

    requirement def StructuralIntegrityRequirement {
        in supportCapacity : MassValue;
        in totalSupportedMass : MassValue;
        doc /* The support structure shall safely support the combined weight of the wheel, the buckets, and the water being lifted. */
        constraint { supportCapacity >= totalSupportedMass }
    }

    requirement def ContinuousOperationRequirement {
        in driveActive : Boolean;
        in sourceHasWater : Boolean;
        in isOperating : Boolean;
        doc /* The Noria shall provide a continuous flow of water from the water source to the elevated discharge channel as long as the drive system is active and the water source has sufficient water. */
        constraint { (driveActive and sourceHasWater) implies isOperating }
    }

    part noriaSystem : NoriaSystem;

    requirement structuralIntegrity : StructuralIntegrityRequirement {
        in supportCapacity = noriaSystem.supportStructure.loadCapacity;
        in totalSupportedMass = noriaSystem.wheel.totalSupportedMass;
    }

    requirement continuousOperation : ContinuousOperationRequirement {
        in driveActive = noriaSystem.driveSystem.isActive;
        in sourceHasWater = noriaSystem.waterSource.hasWater;
        in isOperating = noriaSystem.isOperating;
    }

    satisfy structuralIntegrity by noriaSystem;
    satisfy continuousOperation by noriaSystem;
}
