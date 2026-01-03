package 'Artificio de Juanelo System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def Water {
        attribute volume : VolumeValue;
    }

    attribute def FlowRateValue :> Real;
    attribute def TorqueValue :> Real;
    attribute def AngularVelocityValue :> Real;

    port def WaterInputPort {
        in item water : Water;
        in attribute flowRate : FlowRateValue;
    }

    port def WaterOutputPort {
        out item water : Water;
        out attribute flowRate : FlowRateValue;
    }

    port def MechanicalPowerPort {
        in attribute torque : TorqueValue;
        in attribute angularVelocity : AngularVelocityValue;
    }

    port def MechanicalDrivePort {
        out attribute torque : TorqueValue;
        out attribute angularVelocity : AngularVelocityValue;
    }

    part def TagusRiver {
        attribute flowRate : FlowRateValue;
        attribute waterLevel : LengthValue;
        port waterSupply : WaterOutputPort;
    }

    part def WaterWheel {
        attribute diameter : LengthValue;
        attribute rotationalSpeed : AngularVelocityValue;
        port waterInput : WaterInputPort;
        port mechanicalDrive : MechanicalDrivePort;
    }

    part def BucketChain {
        attribute numberOfBuckets : Integer;
        attribute bucketCapacity : VolumeValue;
        attribute chainLength : LengthValue;
        port mechanicalInput : MechanicalPowerPort;
        port waterIntake : WaterInputPort;
        port waterDischarge : WaterOutputPort;
    }

    part def AlcazarReservoir {
        attribute capacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute elevation : LengthValue;
        port waterInput : WaterInputPort;
    }

    action def RotateWheel {
        in riverFlow : FlowRateValue;
        in wheelDiameter : LengthValue;
        out torque : TorqueValue;
        out angularVelocity : AngularVelocityValue;
    }

    action def FillBucket {
        in bucketCapacity : VolumeValue;
        in waterAvailable : VolumeValue;
        out filledVolume : VolumeValue;
    }

    action def LiftBucket {
        in torque : TorqueValue;
        in angularVelocity : AngularVelocityValue;
        in bucketWeight : MassValue;
        in liftHeight : LengthValue;
        out elevatedWater : VolumeValue;
    }

    action def DischargeWater {
        in elevatedWater : VolumeValue;
        out deliveredWater : VolumeValue;
    }

    action def WaterLiftingCycle {
        in targetVolume : VolumeValue;
        in bucketCapacity : VolumeValue;
        in liftHeight : LengthValue;
        in driveTorque : TorqueValue;
        in driveVelocity : AngularVelocityValue;
        out totalDelivered : VolumeValue;

        private attribute accumulated : VolumeValue := 0.0 [m^3];

        first start;
        then merge continueLifting;
        then decide;
            if accumulated < targetVolume then performCycle;
            if accumulated >= targetVolume then done;

        action performCycle {
            perform action fill : FillBucket {
                in bucketCapacity = bucketCapacity;
                in waterAvailable = bucketCapacity;
                out filledVolume;
            }
            then perform action lift : LiftBucket {
                in torque = driveTorque;
                in angularVelocity = driveVelocity;
                in bucketWeight = 10.0 [kg];
                in liftHeight = liftHeight;
                out elevatedWater;
            }
            then perform action discharge : DischargeWater {
                in elevatedWater = lift.elevatedWater;
                out deliveredWater;
            }
            then assign accumulated := accumulated + discharge.deliveredWater;
        }
        then assign totalDelivered := accumulated;
        then continueLifting;
    }

    state def ArtificioOperationStates {
        entry; then idle;
        
        state idle;
        state filling;
        state lifting;
        state discharging;

        accept at idle
            then filling
            when WaterAvailable;
        accept at filling
            then lifting
            when BucketFilled;
        accept at lifting
            then discharging
            when BucketAtTop;
        accept at discharging
            then idle
            when BucketEmptied;
    }

    part def ArtificioDeJuanelo {
        doc /* 
            The Artificio de Juanelo was a 16th-century hydraulic machine designed by 
            Juanelo Turriano to lift water from the Tagus River to the Alcázar of Toledo.
            The system used a water wheel powered by the river current to drive a chain 
            of buckets that lifted water approximately 100 meters vertically through a 
            series of oscillating towers and mechanical linkages.
        */

        part river : TagusRiver {
            attribute :>> flowRate = 300.0;
            attribute :>> waterLevel = 5.0 [m];
        }

        part wheel : WaterWheel {
            attribute :>> diameter = 8.0 [m];
            attribute :>> rotationalSpeed = 0.15;
            perform liftWater.rotateWheel;
        }

        part buckets : BucketChain {
            attribute :>> numberOfBuckets = 180;
            attribute :>> bucketCapacity = 8.0 [L];
            attribute :>> chainLength = 320.0 [m];
            perform liftWater.performCycle.lift;
        }

        part alcazar : AlcazarReservoir {
            attribute :>> capacity = 50000.0 [L];
            attribute :>> currentVolume = 0.0 [L];
            attribute :>> elevation = 98.0 [m];
        }

        connect river.waterSupply to wheel.waterInput;
        connect wheel.mechanicalDrive to buckets.mechanicalInput;
        connect river.waterSupply to buckets.waterIntake;
        connect buckets.waterDischarge to alcazar.waterInput;

        perform action liftWater : LiftWaterOperation;
    }

    action def LiftWaterOperation {
        first start;
        then merge continuousOperation;

        action rotateWheel : RotateWheel {
            in riverFlow = 300.0;
            in wheelDiameter = 8.0 [m];
            out torque;
            out angularVelocity;
        }
        then liftingCycle;

        action liftingCycle : WaterLiftingCycle {
            in targetVolume = 10000.0 [L];
            in bucketCapacity = 8.0 [L];
            in liftHeight = 98.0 [m];
            in driveTorque = rotateWheel.torque;
            in driveVelocity = rotateWheel.angularVelocity;
            out totalDelivered;
        }
        then decide;
            if liftingCycle.totalDelivered > 0.0 [L] then continuousOperation;
            if liftingCycle.totalDelivered <= 0.0 [L] then stopOperation;

        merge continuousOperation;
        then rotateWheel;

        action stopOperation;
        then done;
    }

    requirement def PrimaryMissionRequirement {
        doc /* The Artificio de Juanelo shall lift water from the Tagus River to the Alcázar of Toledo. */
    }

    requirement def WaterDeliveryRequirement {
        doc /* The system shall deliver sufficient water to meet the daily needs of the Alcázar. */
        
        require constraint minimumFlowRate {
            doc /* The system shall deliver at least 150 liters per minute. */
        }
    }

    requirement def LiftHeightRequirement {
        doc /* The system shall lift water to an elevation of at least 90 meters. */
        
        require constraint verticalLift {
            doc /* The vertical distance from river intake to reservoir discharge shall be approximately 98 meters. */
        }
    }

    requirement def EnergySourceRequirement {
        doc /* The system shall be powered exclusively by the river current. */
        
        require constraint renewablePower {
            doc /* No external power source shall be required for operation. */
        }
    }

    requirement <'1'> systemMissionRequirement {
        doc /* The Artificio de Juanelo shall supply water to the Alcázar of Toledo using only river power. */
        
        assume constraint riverFlowSufficient {
            doc /* The Tagus River provides adequate flow rate for continuous operation. */
        }
        
        require primaryMission : PrimaryMissionRequirement;
        require waterDelivery : WaterDeliveryRequirement;
        require liftHeight : LiftHeightRequirement;
        require energySource : EnergySourceRequirement;
    }

    part toledoWaterSystem {
        part artificio : ArtificioDeJuanelo;
        
        satisfy systemMissionRequirement by artificio;
    }
}
