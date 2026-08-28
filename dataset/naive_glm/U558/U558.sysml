package Saqiyah {
    import ScalarValues::*;
    import SI::*;

    // ---- Value types ----
    attribute def RotationalSpeed :> Real { unit "rpm"; }
    attribute def Torque :> Real { unit "N*m"; }
    attribute def LiftHeight :> Real { unit "m"; }
    attribute def BucketVolume :> Real { unit "L"; }
    attribute def VolumetricFlowRate :> Real { unit "L/s"; }
    attribute def LinearSpeed :> Real { unit "m/s"; }
    attribute def GearRatio :> Real;
    attribute def BucketCount :> Integer;

    // ---- Items ----
    item def Water;

    // ---- Port definitions ----
    port def RotationalPort {
        out attribute speed : RotationalSpeed;
        out attribute torque : Torque;
    }

    port def WaterInPort {
        in item water : Water;
    }

    port def WaterOutPort {
        out item water : Water;
    }

    // ---- Requirements ----
    requirement def LiftWaterRequirement {
        attribute requiredLiftHeight : LiftHeight;
        attribute requiredFlowRate : VolumetricFlowRate;
        requirement {
            doc { "The Saqiyah shall lift water to the required height and deliver a consistent flow rate." }
        }
    }

    requirement def ContinuousOperationRequirement {
        attribute minOperatingSpeed : RotationalSpeed;
        attribute maxOperatingSpeed : RotationalSpeed;
        requirement {
            doc { "The Saqiyah shall operate continuously at low speed within the specified range." }
        }
    }

    requirement SaqiyahLiftRequirement : LiftWaterRequirement {
        attribute redefines requiredLiftHeight = 5.0 [m];
        attribute redefines requiredFlowRate = 2.0 [L/s];
    }

    requirement SaqiyahOperationRequirement : ContinuousOperationRequirement {
        attribute redefines minOperatingSpeed = 2.0 [rpm];
        attribute redefines maxOperatingSpeed = 6.0 [rpm];
    }

    // ---- Part definitions ----
    part def Animal {
        attribute species : String;
        attribute walkingSpeed : LinearSpeed;
        port out animalPower : RotationalPort;
        attribute generatedTorque : Torque;
        attribute generatedSpeed : RotationalSpeed;

        action def WalkInCircle {
            out animalSpeed : RotationalSpeed;
            out animalTorque : Torque;
        }
        perform WalkInCircle;
    }

    part def HorizontalGearWheel {
        attribute teeth : Integer;
        attribute radius : Length;
        attribute gearRatioToVertical : GearRatio;
        port in driveInput : RotationalPort;
        port out driveOutput : RotationalPort;

        action def TransferRotation {
            in inputSpeed : RotationalSpeed;
            in inputTorque : Torque;
            out outputSpeed : RotationalSpeed;
            out outputTorque : Torque;
        }
    }

    part def VerticalWaterWheel {
        attribute teeth : Integer;
        attribute radius : Length;
        port in driveInput : RotationalPort;
        port out chainDrive : RotationalPort;
        attribute wheelSpeed : RotationalSpeed;

        action def RotateWheel {
            in inputSpeed : RotationalSpeed;
            out chainSpeed : LinearSpeed;
        }
    }

    part def Bucket {
        attribute capacity : BucketVolume;
        attribute filled : Boolean = false;
        attribute waterContent : Water;

        action def Fill {
            in wellWater : Water;
            out filledBucket : Water;
        }

        action def Ascend {
            in filledBucket : Water;
        }

        action def Discharge {
            in filledBucket : Water;
            out dischargedWater : Water;
        }

        action def Descend {
            out emptyBucket : Bucket;
        }
    }

    part def BucketChain {
        attribute bucketCount : BucketCount;
        attribute chainLength : Length;
        part buckets : Bucket[bucketCount];
        port in driveInput : RotationalPort;
        port out waterDischarge : WaterOutPort;
        port in waterIntake : WaterInPort;

        action def CycleBuckets {
            in water : Water;
            out liftedWater : Water;
        }
    }

    part def Well {
        attribute depth : Length;
        port out waterSource : WaterOutPort;
        item waterSupply : Water;
    }

    part def IrrigationChannel {
        attribute elevation : LiftHeight;
        port in waterInlet : WaterInPort;
        item receivedWater : Water;
    }

    part def SaqiyahSystem {
        attribute designLiftHeight : LiftHeight = 5.0 [m];
        attribute designFlowRate : VolumetricFlowRate = 2.0 [L/s];
        attribute operatingSpeed : RotationalSpeed;

        satisfy SaqiyahLiftRequirement;
        satisfy SaqiyahOperationRequirement;

        part animal : Animal {
            attribute redefines species = "ox";
            attribute redefines walkingSpeed = 0.6 [m/s];
            attribute redefines generatedTorque = 400.0 [N*m];
            attribute redefines generatedSpeed = 4.0 [rpm];
        }

        part horizontalWheel : HorizontalGearWheel {
            attribute redefines teeth = 96;
            attribute redefines radius = 2.0 [m];
            attribute redefines gearRatioToVertical = 3.0;
        }

        part verticalWheel : VerticalWaterWheel {
            attribute redefines teeth = 32;
            attribute redefines radius = 1.5 [m];
        }

        part chain : BucketChain {
            attribute redefines bucketCount = 24;
            attribute redefines chainLength = 20.0 [m];
        }

        part well : Well {
            attribute redefines depth = 6.0 [m];
        }

        part channel : IrrigationChannel {
            attribute redefines elevation = 5.0 [m];
        }

        connection animalToHorizontal connect animal.animalPower to horizontalWheel.driveInput;
        connection horizontalToVertical connect horizontalWheel.driveOutput to verticalWheel.driveInput;
        connection verticalToChain connect verticalWheel.chainDrive to chain.driveInput;
        connection wellToChain connect well.waterSource to chain.waterIntake;
        connection chainToChannel connect chain.waterDischarge to channel.waterInlet;

        state def SaqiyahStateMachine {
            state idle;
            state active {
                state filling;
                state ascending;
                state discharging;
                state descending;
                transition filling_to_ascending first filling then ascending;
                transition ascending_to_discharging first ascending then discharging;
                transition discharging_to_descending first discharging then descending;
                transition descending_to_filling first descending then filling;
            }
            transition idle_to_active first idle then active when animal.generatedSpeed > 0.0 [rpm];
            transition active_to_idle first active then idle when animal.generatedSpeed == 0.0 [rpm];
        }

        exhibit SaqiyahStateMachine;

        action def OperateSaqiyah {
            in animalSpeed : RotationalSpeed;
            out deliveredWater : Water;
            perform animal.WalkInCircle;
            perform horizontalWheel.TransferRotation;
            perform verticalWheel.RotateWheel;
            perform chain.CycleBuckets;
        }
    }
}
