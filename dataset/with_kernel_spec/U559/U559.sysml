package IndustrialScoopWheelSystem {
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::*;

    package Definitions {
        item def BulkMaterial;

        part def ScoopBucket {
            attribute capacity : ISQ::Volume = 0.05 [m^3];
            attribute isFull : Boolean = false;
        }

        part def RotatingWheel {
            attribute diameter : ISQ::Length = 4 [m];
            part buckets : ScoopBucket[12];
            attribute rotationSpeed : ISQ::AngularVelocity;
            in item materialIn : BulkMaterial;
            out item materialOut : BulkMaterial;

            perform action rotate : RotateWheel;
            perform action fillBuckets : FillBuckets;
            perform action dischargeMaterial : DischargeMaterial;
        }

        action def RotateWheel;
        action def FillBuckets;
        action def DischargeMaterial;

        part def ElectricMotor {
            attribute power : ISQ::Power = 22 [kW];
            attribute torque : ISQ::Torque;
            in port controlSignal;
            out port mechanicalDrive;
            perform action providePower : ProvideMotorPower;
        }

        action def ProvideMotorPower;

        part def InputHopper {
            in item materialIn : BulkMaterial;
            out item materialOut : BulkMaterial;
            perform action regulateFeed : RegulateMaterialFeed;
        }

        action def RegulateMaterialFeed;

        part def DischargeChute {
            in item materialIn : BulkMaterial;
            out item materialOut : BulkMaterial;
            perform action guideMaterial : GuideMaterialFlow;
        }

        action def GuideMaterialFlow;

        attribute def StartCommand;
        attribute def AccelerateCommand;
        attribute def RunCommand;
        attribute def StopCommand;
        attribute def StoppedCommand;
        attribute def EmergencyStopCommand;
        attribute def ResetCommand;

        state def ControlStates {
            entry; then stopped;
            state stopped;
            accept StartCommand then starting;
            state starting;
            accept AccelerateCommand then accelerating;
            state accelerating;
            accept RunCommand then running;
            state running;
            accept StopCommand then stopping;
            accept EmergencyStopCommand then emergencyStopped;
            state stopping;
            accept StoppedCommand then stopped;
            accept EmergencyStopCommand then emergencyStopped;
            state emergencyStopped;
            accept ResetCommand then stopped;
        }

        part def CentralControlUnit {
            in port operatorCommand;
            out port motorControl;
            exhibit state 'control states': ControlStates;
            perform action processCommands : ProcessOperatorCommands;
        }

        action def ProcessOperatorCommands;

        part def ScoopWheelSystem {
            part wheel : RotatingWheel;
            part motor : ElectricMotor;
            part controller : CentralControlUnit;
            part hopper : InputHopper;
            part chute : DischargeChute;

            connect hopper.materialOut to wheel.materialIn;
            connect wheel.materialOut to chute.materialIn;
            connect controller.motorControl to motor.controlSignal;
        }
    }

    package Requirements {
        private import Definitions::*;

        requirement def SystemRequirements {
            subject system : ScoopWheelSystem;

            requirement WheelDiameter {
                doc /* The wheel must have a diameter of 4 meters. */
                require system.wheel.diameter == 4 [m];
            }

            requirement BucketCount {
                doc /* The wheel must have 12 scoop buckets. */
                require system.wheel.buckets->size == 12;
            }

            requirement MotorPower {
                doc /* The motor must provide 22 kW of power. */
                require system.motor.power == 22 [kW];
            }

            requirement OperationalSafety {
                doc /* The system must be able to be brought to a controlled halt or shut down immediately in an emergency. */
            }

            requirement MaterialHandling {
                doc /* The system must efficiently transfer bulk materials from the input hopper to the discharge chute. */
            }
        }
    }
}
