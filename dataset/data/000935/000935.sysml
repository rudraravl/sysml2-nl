package SaqiyahWaterLiftingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def WaterFlowRate :> ISQ::VolumeFlowRateValue;
    attribute def RotationalSpeed :> ISQ::AngularVelocityValue;
    attribute def Torque :> ISQ::TorqueValue;
    attribute def Height :> ISQ::LengthValue;
    attribute def WaterVolume :> ISQ::VolumeValue;
    
    item def Water;
    
    port def MechanicalPowerPort {
        out torque : Torque;
        out speed : RotationalSpeed;
    }
    
    port def WaterIntakePort {
        in item water : Water;
        attribute intakeRate : WaterFlowRate;
    }
    
    port def WaterDischargePort {
        out item water : Water;
        attribute dischargeRate : WaterFlowRate;
    }
    
    part def AnimalDrive {
        doc /* Animal-powered drive mechanism that provides rotational power. */
        port powerOutput : MechanicalPowerPort;
        attribute driveTorque : Torque;
        attribute driveSpeed : RotationalSpeed;
    }
    
    part def HorizontalGearWheel {
        doc /* Horizontal wheel driven by animal, transfers power to vertical wheel. */
        in attribute inputTorque : Torque;
        in attribute inputSpeed : RotationalSpeed;
        out attribute outputTorque : Torque;
        out attribute outputSpeed : RotationalSpeed;
        attribute gearRatio : Real;
    }
    
    part def VerticalWaterWheel {
        doc /* Vertical wheel that drives the bucket chain. */
        in attribute inputTorque : Torque;
        in attribute inputSpeed : RotationalSpeed;
        out attribute wheelSpeed : RotationalSpeed;
        attribute wheelDiameter : Height;
    }
    
    part def BucketChain {
        doc /* Continuous chain of buckets that lift water from source to discharge. */
        in attribute chainSpeed : RotationalSpeed;
        port waterIntake : WaterIntakePort;
        port waterDischarge : WaterDischargePort;
        attribute numberOfBuckets : Integer;
        attribute bucketCapacity : WaterVolume;
        attribute liftHeight : Height;
        out attribute flowRate : WaterFlowRate;
    }
    
    part def WaterWell {
        doc /* Source of water at lower elevation. */
        port waterOutput : WaterDischargePort;
        attribute waterLevel : Height;
        attribute availableWater : WaterVolume;
    }
    
    part def IrrigationChannel {
        doc /* Destination channel at higher elevation for irrigation. */
        port waterInput : WaterIntakePort;
        attribute channelElevation : Height;
        attribute channelCapacity : WaterFlowRate;
    }
    
    part def Saqiyah {
        doc /* Traditional water-lifting device using animal power to raise water 
               from a well to an irrigation channel via a continuous bucket chain. */
        
        part animalDrive : AnimalDrive {
            attribute driveTorque : Torque;
            attribute driveSpeed : RotationalSpeed;
        }
        
        part horizontalWheel : HorizontalGearWheel {
            in attribute inputTorque : Torque = animalDrive.driveTorque;
            in attribute inputSpeed : RotationalSpeed = animalDrive.driveSpeed;
            attribute gearRatio : Real = 1.5;
            out attribute outputTorque : Torque;
            out attribute outputSpeed : RotationalSpeed;
        }
        
        part verticalWheel : VerticalWaterWheel {
            in attribute inputTorque : Torque = horizontalWheel.outputTorque;
            in attribute inputSpeed : RotationalSpeed = horizontalWheel.outputSpeed;
            attribute wheelDiameter : Height;
            out attribute wheelSpeed : RotationalSpeed;
        }
        
        part bucketChain : BucketChain {
            in attribute chainSpeed : RotationalSpeed = verticalWheel.wheelSpeed;
            attribute numberOfBuckets : Integer = 24;
            attribute bucketCapacity : WaterVolume;
            attribute liftHeight : Height;
            out attribute flowRate : WaterFlowRate;
        }
        
        part well : WaterWell {
            attribute waterLevel : Height;
            attribute availableWater : WaterVolume;
        }
        
        part channel : IrrigationChannel {
            attribute channelElevation : Height;
            attribute channelCapacity : WaterFlowRate;
        }
        
        connection waterCollection connect well.waterOutput to bucketChain.waterIntake;
        connection waterDelivery connect bucketChain.waterDischarge to channel.waterInput;
        
        perform action operateSaqiyah : LiftAndDeliverWater;
        
        exhibit state saqiyahStates : SaqiyahOperationStates;
    }
    
    action def LiftAndDeliverWater {
        doc /* Primary function: continuously lift water from well to irrigation channel. */
        
        in attribute sourceLevel : Height;
        in attribute targetLevel : Height;
        out attribute deliveredFlow : WaterFlowRate;
        
        first start;
        then merge continuousOperation;
        
        then action applyAnimalPower {
            out driveTorque : Torque;
            out driveSpeed : RotationalSpeed;
        }
        
        then action transferPowerToHorizontal {
            in inputTorque : Torque = applyAnimalPower.driveTorque;
            in inputSpeed : RotationalSpeed = applyAnimalPower.driveSpeed;
            out horizontalTorque : Torque;
            out horizontalSpeed : RotationalSpeed;
        }
        
        then action transferPowerToVertical {
            in horizontalTorque : Torque = transferPowerToHorizontal.horizontalTorque;
            in horizontalSpeed : RotationalSpeed = transferPowerToHorizontal.horizontalSpeed;
            out verticalSpeed : RotationalSpeed;
        }
        
        then action driveBucketChain {
            in chainSpeed : RotationalSpeed = transferPowerToVertical.verticalSpeed;
            out chainFlowRate : WaterFlowRate;
        }
        
        then action collectWaterFromWell {
            in sourceLevel : Height = LiftAndDeliverWater::sourceLevel;
            in flowRate : WaterFlowRate = driveBucketChain.chainFlowRate;
            out collectedWater : WaterFlowRate;
        }
        
        then action liftWaterVertically {
            in waterFlow : WaterFlowRate = collectWaterFromWell.collectedWater;
            in liftHeight : Height;
            out elevatedWater : WaterFlowRate;
        }
        
        then action dischargeToChannel {
            in elevatedWater : WaterFlowRate = liftWaterVertically.elevatedWater;
            in targetLevel : Height = LiftAndDeliverWater::targetLevel;
            out dischargedWater : WaterFlowRate;
        }
        
        then assign deliveredFlow := dischargeToChannel.dischargedWater;
        
        then decide;
            if deliveredFlow > 0.0 then continuousOperation;
            else stopOperation;
        
        action stopOperation;
        then done;
    }
    
    state def SaqiyahOperationStates {
        entry; then idle;
        
        state idle {
            doc /* System at rest, no water being lifted. */
        }
        
        transition startOperation
            first idle
            accept animalEngaged
            then active;
        
        state active {
            doc /* System actively lifting water. */
            
            state filling {
                doc /* Buckets descending and filling with water from well. */
            }
            
            transition fillingToAscending
                first filling
                accept bucketsFull
                then ascending;
            
            state ascending {
                doc /* Filled buckets ascending to discharge elevation. */
            }
            
            transition ascendingToDischarging
                first ascending
                accept reachedDischargePoint
                then discharging;
            
            state discharging {
                doc /* Buckets emptying water into irrigation channel. */
            }
            
            transition dischargingToFilling
                first discharging
                accept bucketsEmpty
                then filling;
        }
        
        transition stopOperation
            first active
            accept animalDisengaged
            then idle;
    }
    
    requirement def WaterLiftingCapability {
        doc /* The Saqiyah shall lift water from a lower elevation source 
               to a higher elevation irrigation channel using animal power. */
        
        require constraint minimumFlowRate {
            doc /* System shall deliver minimum required flow rate. */
        }
        
        require constraint liftCapability {
            doc /* System shall lift water to required elevation difference. */
        }
        
        require constraint continuousOperation {
            doc /* System shall operate continuously while power is applied. */
        }
    }
    
    requirement saqiyahPrimaryFunction : WaterLiftingCapability {
        doc /* Primary functional requirement for the Saqiyah water lifting system. */
        
        subject saqiyahSystem : Saqiyah;
        
        assume constraint animalPowerAvailable {
            doc /* Sufficient animal power is available for operation. */
        }
        
        assume constraint waterSourceAdequate {
            doc /* Well contains sufficient water for continuous operation. */
        }
        
        require constraint minimumFlowRate {
            attribute requiredFlowRate : WaterFlowRate;
            saqiyahSystem.bucketChain.flowRate >= requiredFlowRate
        }
        
        require constraint liftCapability {
            attribute requiredLiftHeight : Height;
            saqiyahSystem.channel.channelElevation >= 
                saqiyahSystem.well.waterLevel + requiredLiftHeight
        }
        
        require constraint continuousOperation {
            saqiyahSystem.operateSaqiyah.deliveredFlow > 0.0
        }
    }
    
    requirement def StructuralIntegrity {
        doc /* The Saqiyah structure shall maintain integrity under operational loads. */
    }
    
    requirement structuralRequirement : StructuralIntegrity {
        subject saqiyahSystem : Saqiyah;
        
        require constraint bucketChainStrength {
            doc /* Bucket chain shall support weight of filled buckets. */
        }
        
        require constraint wheelDurability {
            doc /* Wheels shall withstand continuous rotational loads. */
        }
    }
}
