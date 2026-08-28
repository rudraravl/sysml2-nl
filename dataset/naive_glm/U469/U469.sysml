package ArtificioDeJuanelo {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types with Units ----

    value def Height :> Real { doc "Vertical distance in meters" }
    value def VolumetricFlowRate :> Real { doc "Cubic meters per second" }
    value def AngularVelocity :> Real { doc "Radians per second" }
    value def Torque :> Real { doc "Newton-meters" }
    value def Volume :> Real { doc "Cubic meters" }
    value def MassFlowRate :> Real { doc "Kilograms per second" }
    value def BucketCount :> Integer { doc "Number of buckets on the chain" }
    value def RotationCount :> Integer { doc "Revolutions per minute" }

    attribute liftHeight : Height = 100 [m];
    attribute riverFlowRate : VolumetricFlowRate = 15 [m^3/s];
    attribute bucketVolume : Volume = 0.008 [m^3];
    attribute totalBuckets : BucketCount = 200;
    attribute wheelDiameter : Length = 6 [m];
    attribute chainSpeed : LinearVelocity = 0.5 [m/s];
    attribute wheelRPM : RotationCount = 2;

    // ---- Item Types ----

    item def Water {
        attribute temperature : Temperature = 15 [K];
        attribute density : MassDensity = 1000 [kg/m^3];
    }

    item def RiverCurrent {
        attribute flowRate : VolumetricFlowRate;
        attribute velocity : LinearVelocity;
    }

    // ---- Port Definitions ----

    port def WaterFlowPort {
        out item water : Water;
        attribute flowRate : VolumetricFlowRate;
    }

    port def MechanicalRotationPort {
        out attribute angularVelocity : AngularVelocity;
        out attribute torque : Torque;
    }

    port def WaterTransportPort {
        out item water : Water;
        attribute volumePerCycle : Volume;
    }

    port def WaterDischargePort {
        in item water : Water;
        attribute dischargeRate : VolumetricFlowRate;
    }

    // ---- Requirements ----

    requirement def LiftRequirement {
        doc "The machine shall lift water from the Tagus River to the Alcázar."
        attribute requiredLiftHeight : Height = 100 [m];
        subject liftingSystem;
        require liftingSystem.liftDistance >= requiredLiftHeight;
    }

    requirement def ContinuousOperationRequirement {
        doc "The machine shall operate continuously powered only by river current."
        subject powerSource;
        require powerSource.source == "TagusRiverCurrent";
    }

    requirement def BucketCycleRequirement {
        doc "Each bucket shall complete the cycle: fill, lift, discharge, return."
        subject bucket;
        require bucket.cycleComplete == true;
    }

    requirement def DischargeRequirement {
        doc "Water shall be discharged into the Alcázar reservoir at the top."
        subject dischargeSystem;
        require dischargeSystem.dischargeLocation == "AlcázarReservoir";
    }

    requirement def WaterSupplyRequirement {
        doc "The machine shall provide a steady water supply to the palace."
        attribute minSupplyRate : VolumetricFlowRate = 0.05 [m^3/s];
        subject supplySystem;
        require supplySystem.outputRate >= minSupplyRate;
    }

    // ---- Parts ----

    part def TagusRiver {
        port riverFlowPort : WaterFlowPort {
            attribute flowRate : VolumetricFlowRate = 15 [m^3/s];
        }
        attribute currentVelocity : LinearVelocity = 1.2 [m/s];
        attribute waterDepth : Length = 3 [m];
    }

    part def WaterWheel {
        port inflowPort : WaterFlowPort;
        port rotationOutPort : MechanicalRotationPort;
        attribute diameter : Length = 6 [m];
        attribute bladeCount : Integer = 12;
        attribute angularVelocity : AngularVelocity = 0.21 [rad/s];
        attribute outputTorque : Torque = 5000 [N*m];
        attribute efficiency : Real = 0.65;

        action def RotateByCurrent {
            in item incomingWater : Water;
            out attribute generatedTorque : Torque;
            out attribute generatedAngularVelocity : AngularVelocity;
        }

        perform action rotate : RotateByCurrent {
            in item incomingWater = inflowPort.water;
            out attribute generatedTorque = outputTorque;
            out attribute generatedAngularVelocity = angularVelocity;
        }
    }

    part def MechanicalPowerTransfer {
        port rotationInPort : MechanicalRotationPort;
        port rotationOutPort : MechanicalRotationPort;
        attribute gearRatio : Real = 3.0;
        attribute efficiency : Real = 0.85;

        action def TransferPower {
            in attribute inputTorque : Torque;
            in attribute inputAngularVelocity : AngularVelocity;
            out attribute outputTorque : Torque;
            out attribute outputAngularVelocity : AngularVelocity;
        }

        perform action transfer : TransferPower {
            in attribute inputTorque = rotationInPort.torque;
            in attribute inputAngularVelocity = rotationInPort.angularVelocity;
            out attribute outputTorque = rotationOutPort.torque;
            out attribute outputAngularVelocity = rotationOutPort.angularVelocity;
        }
    }

    part def Bucket {
        attribute id : Integer;
        attribute capacity : Volume = 0.008 [m^3];
        attribute currentVolume : Volume;
        attribute cycleComplete : Boolean = false;
        attribute position : String;

        port intakePort : WaterTransportPort;
        port dischargePort : WaterDischargePort;

        state def BucketCycle {
            entry action { set currentVolume = 0 [m^3]; }

            state Filling {
                entry action { set position = "RiverBottom"; }
                do action FillBucket {
                    in item riverWater : Water;
                    out item filledWater : Water;
                    attribute fillVolume : Volume = capacity;
                }
                transition fillToLift
                    first if currentVolume >= capacity then to Lifting;
            }

            state Lifting {
                entry action { set position = "Ascending"; }
                do action LiftWater {
                    in item waterToLift : Water;
                    attribute liftDistance : Height = liftHeight;
                }
                transition liftToDischarge
                    first if position == "Top" then to Discharging;
            }

            state Discharging {
                entry action { set position = "AlcazarReservoir"; }
                do action DischargeWater {
                    in item waterToDischarge : Water;
                    out item dischargedWater : Water;
                }
                transition dischargeToReturn
                    first if currentVolume == 0 [m^3] then to Returning;
            }

            state Returning {
                entry action { set position = "Descending"; }
                do action ReturnEmpty {
                    attribute descendDistance : Height = liftHeight;
                }
                transition returnToFill
                    first if position == "RiverBottom" then to Filling;
            }

            transition initial to Filling;
        }

        exhibit state bucketCycle : BucketCycle;
    }

    part def BucketChain {
        port drivePort : MechanicalRotationPort;
        port waterIntakePort : WaterFlowPort;
        port waterDeliveryPort : WaterDischargePort;

        attribute bucketCount : BucketCount = 200;
        attribute chainLength : Length = 250 [m];
        attribute chainSpeed : LinearVelocity = 0.5 [m/s];
        attribute totalLiftHeight : Height = 100 [m];

        part buckets : Bucket[bucketCount] {
            attribute id = indexof;
        }

        action def DriveChain {
            in attribute inputTorque : Torque;
            in attribute inputAngularVelocity : AngularVelocity;
            out attribute chainLinearSpeed : LinearVelocity;
        }

        perform action drive : DriveChain {
            in attribute inputTorque = drivePort.torque;
            in attribute inputAngularVelocity = drivePort.angularVelocity;
            out attribute chainLinearSpeed = chainSpeed;
        }

        action def CoordinateBucketCycle {
            in item riverWater : Water;
            out item deliveredWater : Water;
            attribute activeBuckets : BucketCount = bucketCount;
        }

        perform action coordinate : CoordinateBucketCycle {
            in item riverWater = waterIntakePort.water;
            out item deliveredWater = waterDeliveryPort.water;
        }
    }

    part def AlcázarReservoir {
        port intakePort : WaterDischargePort;
        attribute capacity : Volume = 50 [m^3];
        attribute currentLevel : Volume;
        attribute location : String = "ToledoAlcazarHilltop";
        attribute elevation : Height = 100 [m];

        action def ReceiveWater {
            in item incomingWater : Water;
            out attribute reservoirLevel : Volume;
        }

        perform action receive : ReceiveWater {
            in item incomingWater = intakePort.water;
            out attribute reservoirLevel = currentLevel;
        }
    }

    part def ArtificioDeJuanelo {
        doc "The Artificio de Juanelo: a 16th-century water-lifting machine powered by the Tagus River."

        attribute machineName : String = "Artificio de Juanelo";
        attribute constructionYear : Integer = 1569;
        attribute location : String = "Toledo, Spain";
        attribute totalLiftHeight : Height = 100 [m];

        satisfy LiftRequirement {
            subject liftingSystem = bucketChain;
            attribute liftDistance = totalLiftHeight;
        }

        satisfy ContinuousOperationRequirement {
            subject powerSource = tagusRiver;
            attribute source = "TagusRiverCurrent";
        }

        satisfy DischargeRequirement {
            subject dischargeSystem = alcazarReservoir;
            attribute dischargeLocation = "AlcazarReservoir";
        }

        satisfy WaterSupplyRequirement {
            subject supplySystem = self;
            attribute outputRate = 0.06 [m^3/s];
        }

        part tagusRiver : TagusRiver {
            attribute currentVelocity = 1.2 [m/s];
        }

        part waterWheel : WaterWheel {
            attribute diameter = 6 [m];
            attribute bladeCount = 12;
            attribute angularVelocity = 0.21 [rad/s];
            attribute outputTorque = 5000 [N*m];
        }

        part powerTransfer : MechanicalPowerTransfer {
            attribute gearRatio = 3.0;
            attribute efficiency = 0.85;
        }

        part bucketChain : BucketChain {
            attribute bucketCount = 200;
            attribute chainLength = 250 [m];
            attribute chainSpeed = 0.5 [m/s];
            attribute totalLiftHeight = 100 [m];

            part buckets : Bucket[200] {
                attribute id = indexof;
                attribute capacity = 0.008 [m^3];
            }
        }

        part alcazarReservoir : AlcázarReservoir {
            attribute capacity = 50 [m^3];
            attribute elevation = 100 [m];
        }

        // ---- Connections ----

        connection riverToWheel : WaterFlowPort
            connect tagusRiver.riverFlowPort to waterWheel.inflowPort;

        connection wheelToTransfer : MechanicalRotationPort
            connect waterWheel.rotationOutPort to powerTransfer.rotationInPort;

        connection transferToChain : MechanicalRotationPort
            connect powerTransfer.rotationOutPort to bucketChain.drivePort;

        connection riverToChain : WaterFlowPort
            connect tagusRiver.riverFlowPort to bucketChain.waterIntakePort;

        connection chainToReservoir : WaterDischargePort
            connect bucketChain.waterDeliveryPort to alcazarReservoir.intakePort;

        // ---- Overall System Behavior ----

        state def SystemOperation {

            state Starting {
                entry action { set systemStatus = "Initializing"; }
                do action InitializeSystem {
                    out attribute wheelReady : Boolean = true;
                    out attribute chainReady : Boolean = true;
                }
                transition startToRunning
                    first if wheelReady and chainReady then to Running;
            }

            state Running {
                entry action { set systemStatus = "Operational"; }
                do action OperateMachine {
                    in item riverWater : Water;
                    out item liftedWater : Water;
                    attribute liftHeight : Height = 100 [m];
                    attribute bucketsActive : BucketCount = 200;
                }

                parallel wheelOperation {
                    do action SpinWheel {
                        in item current : Water;
                        out attribute torque : Torque = 5000 [N*m];
                    }
                }

                parallel chainOperation {
                    do action DriveBuckets {
                        in attribute torque : Torque;
                        out attribute chainSpeed : LinearVelocity = 0.5 [m/s];
                    }
                }

                parallel liftingOperation {
                    do action LiftWaterColumn {
                        in item water : Water;
                        out item elevatedWater : Water;
                        attribute height : Height = 100 [m];
                    }
                }

                parallel dischargeOperation {
                    do action DischargeToReservoir {
                        in item elevatedWater : Water;
                        out item storedWater : Water;
                    }
                }

                transition runningToStopped
                    first if systemStatus == "StopRequested" then to Stopped;
            }

            state Stopped {
                entry action { set systemStatus = "Halted"; }
                do action ShutdownSystem {
                    out attribute allBucketsSecured : Boolean = true;
                }
                transition stoppedToStarting
                    first if systemStatus == "RestartRequested" then to Starting;
            }

            transition initial to Starting;
        }

        exhibit state systemOperation : SystemOperation;

        action def OperateMachine {
            in item riverWater : Water;
            out item liftedWater : Water;
            attribute liftHeight : Height = 100 [m];
            attribute bucketsActive : BucketCount = 200;
        }
    }

}
