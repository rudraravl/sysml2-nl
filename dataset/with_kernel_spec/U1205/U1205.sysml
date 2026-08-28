package 'ElectronicSewingMachineSystem' {
    private import ScalarValues::Real;
    private import ISQ::PressureValue;
    private import ISQ::AngularVelocityValue;
    private import ISQ::LengthValue;
    private import ISQ::ForceValue;

    package Definitions {
        item def Thread;
        item def UpperThread :> Thread;
        item def LowerThread :> Thread;
        item def Fabric;
        item def Stitch {
            attribute length : LengthValue;
        }

        attribute def PedalPressure :> PressureValue;
        attribute def MotorSpeed :> AngularVelocityValue;
        attribute def StitchLength :> LengthValue;
        attribute def PresserForce :> ForceValue;
        attribute def ControlSignal;

        event def ThreadLoaded;
        event def FabricPositioned;
        event def PauseRequested;
        event def ResumeRequested;
        event def BrokenThreadDetected;
        event def ResetRequested;

        port def PedalSignalPort {
            out pressure : PedalPressure;
        }
        port def MotorControlPort {
            out speed : MotorSpeed;
        }
        port def MechanicalDrivePort {
            out driveSpeed : MotorSpeed;
        }
        port def ThreadOutputPort {
            out item thread : Thread;
        }
        port def ThreadInputPort {
            in item thread : Thread;
        }
        port def FabricPort {
            inout item fabric : Fabric;
        }
        port def PresserForcePort {
            out force : PresserForce;
        }
        port def CommandPort {
            out command : ControlSignal;
        }
        port def FeedCommandPort {
            out distance : StitchLength;
        }

        part def FootPedal {
            port signalOut : PedalSignalPort;
            attribute appliedPressure : PedalPressure;
        }

        part def ElectricMotor {
            port controlIn : ~MotorControlPort;
            port mechanicalOut : MechanicalDrivePort;
            attribute currentSpeed : MotorSpeed;
        }

        part def ControlUnit {
            port pedalIn : ~PedalSignalPort;
            port motorOut : MotorControlPort;
            port bobbinOut : CommandPort;
            port feedDogOut : FeedCommandPort;
            port presserOut : PresserForcePort;
        }

        part def MainSpool {
            port threadOut : ThreadOutputPort;
            item upperThread : UpperThread;
        }

        part def TensionRegulator {
            port threadIn : ThreadInputPort;
            port threadOut : ThreadOutputPort;
            attribute tension : Real;
        }

        part def Needle {
            port threadIn : ThreadInputPort;
            attribute position : LengthValue;
        }

        part def NeedleBar {
            port driveIn : ~MechanicalDrivePort;
            part needle : Needle;
        }

        part def Bobbin {
            port threadOut : ThreadOutputPort;
            item lowerThread : LowerThread;
        }

        part def BobbinAssembly {
            port commandIn : ~CommandPort;
            port threadOut : ThreadOutputPort;
            part bobbin : Bobbin;
            bind threadOut = bobbin.threadOut;
            attribute rotationAngle : Real;
        }

        part def PresserFoot {
            port forceIn : ~PresserForcePort;
            port fabricContact : FabricPort;
            attribute appliedForce : PresserForce;
        }

        part def FeedDog {
            port commandIn : ~FeedCommandPort;
            port fabricDrive : FabricPort;
            attribute feedDistance : StitchLength;
        }

        part def FabricBed {
            port fabricPort : FabricPort;
            item fabric : Fabric;
        }

        action def GenerateMotorSpeed {
            in pedalPressure : PedalPressure;
            out motorSpeed : MotorSpeed;
        }

        action def DriveNeedleDown {
            in driveSpeed : MotorSpeed;
            in upperThread : Thread;
            out needlePosition : LengthValue;
        }

        action def FormLockstitch {
            in upperThread : Thread;
            in lowerThread : Thread;
            in fabric : Fabric;
            out stitch : Stitch;
        }

        action def RetractNeedle {
            in driveSpeed : MotorSpeed;
            out needlePosition : LengthValue;
        }

        action def AdvanceFabric {
            in distance : StitchLength;
            inout fabric : Fabric;
        }

        action def StitchCycle {
            in pedalPressure : PedalPressure;
            in upperThread : Thread;
            in lowerThread : Thread;
            inout fabric : Fabric;
            in stitchLength : StitchLength;
            out stitch : Stitch;

            action generateSpeed : GenerateMotorSpeed {
                in pedalPressure = StitchCycle::pedalPressure;
            }

            action driveDown : DriveNeedleDown {
                in driveSpeed = generateSpeed.motorSpeed;
                in upperThread = StitchCycle::upperThread;
            }

            action interlock : FormLockstitch {
                in upperThread = StitchCycle::upperThread;
                in lowerThread = StitchCycle::lowerThread;
                in fabric = StitchCycle::fabric;
                out stitch = StitchCycle::stitch;
            }

            action retract : RetractNeedle {
                in driveSpeed = generateSpeed.motorSpeed;
            }

            action advance : AdvanceFabric {
                in distance = StitchCycle::stitchLength;
                inout fabric = StitchCycle::fabric;
            }

            first start;
            then generateSpeed;
            then driveDown;
            then interlock;
            then retract;
            then advance;
        }

        state def SewingMachineStates {
            state idle {
                transition to preparation on event ThreadLoaded;
            }
            state preparation {
                transition to active on event FabricPositioned;
            }
            state active {
                transition to paused on event PauseRequested;
                transition to errorState on event BrokenThreadDetected;
            }
            state paused {
                transition to active on event ResumeRequested;
                transition to errorState on event BrokenThreadDetected;
            }
            state errorState {
                transition to preparation on event ResetRequested;
            }
        }
    }

    package Usages {
        public import Definitions::*;

        part sewingMachine {
            part footPedal : FootPedal;
            part controlUnit : ControlUnit;
            part motor : ElectricMotor;
            part mainSpool : MainSpool;
            part tensionRegulator : TensionRegulator;
            part needleBar : NeedleBar;
            part bobbinAssembly : BobbinAssembly;
            part presserFoot : PresserFoot;
            part feedDog : FeedDog;
            part fabricBed : FabricBed;

            attribute stitchLength : StitchLength = 2.5;

            flow pedalPressureFlow of PedalPressure
                from footPedal.signalOut.pressure
                to controlUnit.pedalIn.pressure;

            flow motorSpeedFlow of MotorSpeed
                from controlUnit.motorOut.speed
                to motor.controlIn.speed;

            flow driveFlow of MotorSpeed
                from motor.mechanicalOut.driveSpeed
                to needleBar.driveIn.driveSpeed;

            flow upperThreadSupplyFlow of Thread
                from mainSpool.threadOut.thread
                to tensionRegulator.threadIn.thread;

            flow regulatedThreadFlow of Thread
                from tensionRegulator.threadOut.thread
                to needleBar.needle.threadIn.thread;

            flow lowerThreadFlow of Thread
                from bobbinAssembly.threadOut.thread
                to needleBar.needle.threadIn.thread;

            flow bobbinCommandFlow of ControlSignal
                from controlUnit.bobbinOut.command
                to bobbinAssembly.commandIn.command;

            flow feedDogCommandFlow of StitchLength
                from controlUnit.feedDogOut.distance
                to feedDog.commandIn.distance;

            flow presserForceFlow of PresserForce
                from controlUnit.presserOut.force
                to presserFoot.forceIn.force;

            connect presserFoot.fabricContact to fabricBed.fabricPort;
            connect feedDog.fabricDrive to fabricBed.fabricPort;

            perform sewingCycle : StitchCycle {
                in pedalPressure = footPedal.signalOut.pressure;
                in upperThread = tensionRegulator.threadOut.thread;
                in lowerThread = bobbinAssembly.threadOut.thread;
                inout fabric = fabricBed.fabricPort.fabric;
                in stitchLength = sewingMachine::stitchLength;
            }

            perform states : SewingMachineStates;
        }

        requirement SpeedProportionalToPedal {
            text 'The electric motor speed shall be directly proportional to the foot pedal pressure applied by the user.';
        }

        requirement LockstitchFormation {
            text 'Each sewing cycle shall interlock the upper thread from the needle with the lower thread from the bobbin to form a secure lockstitch.';
        }

        requirement FabricAdvancePrecision {
            text 'The feed dog shall advance the fabric by a precise stitch length after each stitch formation.';
        }

        requirement ThreadBreakErrorHandling {
            text 'The control unit shall detect a broken thread and transition the machine to an error state.';
        }

        requirement ContinuousSeamFormation {
            text 'The system shall create a continuous and uniform seam by repeating the stitch formation and fabric advance cycle.';
        }
    }
}
