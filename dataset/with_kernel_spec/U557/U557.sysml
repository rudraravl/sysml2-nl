package 'Rushton Turbine Mixing System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Quantities::*;
    private import MeasurementReferences::*;

    attribute def RotationalSpeedUnit :> DerivedUnit {
        private attribute timePF: QuantityPowerFactor[1] { :>> quantity = isq.Time; :>> exponent = -1; }
        attribute :>> quantityDimension { :>> quantityPowerFactors = (timePF); }
    }
    attribute def RotationalSpeedValue :> ScalarQuantityValue {
        :>> num : Real;
        :>> mRef : RotationalSpeedUnit;
    }
    attribute rpm : RotationalSpeedUnit = 2 * 3.141592653589793 * 'rad' / (60 * 's');

    item def Fluid;
    item def StartCommand;
    item def StopCommand;

    port def MechanicalPort {
        out torque : TorqueValue;
        out speed : RotationalSpeedValue;
    }
    port def FluidPort {
        in item inflow : Fluid;
        out item outflow : Fluid;
    }
    port def ControlPort {
        in item start : StartCommand;
        in item stop : StopCommand;
    }

    part def Baffle {
        attribute width : LengthValue;
        attribute height : LengthValue;
        attribute thickness : LengthValue;
    }

    part def ElectricMotor {
        attribute ratedPower : PowerValue;
        attribute targetSpeed : RotationalSpeedValue;
        port mechanicalOut : MechanicalPort;
        port controlIn : ~ControlPort;
    }

    part def DriveShaft {
        attribute length : LengthValue;
        attribute diameter : LengthValue;
        port mechanicalIn : ~MechanicalPort;
        port mechanicalOut : MechanicalPort;
    }

    part def RushtonImpeller {
        attribute diameter : LengthValue;
        attribute bladeCount : Integer = 6;
        attribute bladeWidth : LengthValue;
        attribute bladeHeight : LengthValue;
        port mechanicalIn : ~MechanicalPort;
        port fluidPort : FluidPort;
    }

    part def MixingVessel {
        attribute tankDiameter : LengthValue;
        attribute tankHeight : LengthValue;
        attribute workingVolume : VolumeValue;
        attribute crossSectionArea : AreaValue = 3.141592653589793 * (tankDiameter / 2.0) ** 2;
        port fluidInPort : ~FluidPort;
        port fluidOutPort : FluidPort;
        port mechanicalIn : ~MechanicalPort;
        part baffles : Baffle[4] {
            :>> width = 0.1 * tankDiameter;
            :>> height = 0.8 * tankHeight;
            :>> thickness = 0.012 * tankDiameter;
        }
        part shaft : DriveShaft {
            :>> length = tankHeight;
            :>> diameter = 0.05 * tankDiameter;
        }
        part impeller : RushtonImpeller {
            :>> diameter = 0.4 * tankDiameter;
            :>> bladeWidth = 0.2 * diameter;
            :>> bladeHeight = 0.25 * diameter;
        }
        bind shaft.mechanicalIn = mechanicalIn;
        bind impeller.mechanicalIn = shaft.mechanicalOut;
    }

    action def 'Spin Shaft' {
        in speed : RotationalSpeedValue;
        out shaftSpeed : RotationalSpeedValue;
    }
    action def 'Rotate Impeller' {
        in shaftSpeed : RotationalSpeedValue;
        in impellerDiameter : LengthValue;
        out radialFlow : Fluid;
        out tipSpeed : SpeedValue;
    }
    action def 'Deflect at Wall' {
        in radialFlow : Fluid;
        in baffleCount : Integer;
        out upperCirculation : Fluid;
        out lowerCirculation : Fluid;
    }
    action def 'Circulate and Mix' {
        in upperCirculation : Fluid;
        in lowerCirculation : Fluid;
        in tankVolume : VolumeValue;
        out mixedFluid : Fluid;
    }
    action def 'Mixing Process' {
        in speed : RotationalSpeedValue;
        in impellerDiameter : LengthValue;
        in baffleCount : Integer;
        in tankVolume : VolumeValue;
        out mixedFluid : Fluid;
        loop {
            action 'spin shaft': 'Spin Shaft' {
                in speed = speed;
                out shaftSpeed : RotationalSpeedValue;
            }
            flow 'spin shaft'.shaftSpeed to 'rotate impeller'.shaftSpeed;
            action 'rotate impeller': 'Rotate Impeller' {
                in shaftSpeed : RotationalSpeedValue;
                in impellerDiameter = impellerDiameter;
                out radialFlow : Fluid;
                out tipSpeed : SpeedValue;
            }
            flow 'rotate impeller'.radialFlow to 'deflect at wall'.radialFlow;
            action 'deflect at wall': 'Deflect at Wall' {
                in radialFlow : Fluid;
                in baffleCount = baffleCount;
                out upperCirculation : Fluid;
                out lowerCirculation : Fluid;
            }
            flow 'deflect at wall'.upperCirculation to 'circulate and mix'.upperCirculation;
            flow 'deflect at wall'.lowerCirculation to 'circulate and mix'.lowerCirculation;
            action 'circulate and mix': 'Circulate and Mix' {
                in upperCirculation : Fluid;
                in lowerCirculation : Fluid;
                in tankVolume = tankVolume;
                out mixedFluid = mixedFluid;
            }
        }
    }

    part def RushtonTurbineSystem {
        attribute targetImpellerSpeed : RotationalSpeedValue = 200 [rpm];
        attribute targetTipSpeed : SpeedValue = 5.0 * 'm' / 's';
        attribute maxMixingTime : TimeValue = 300 * 's';

        part motor : ElectricMotor {
            :>> ratedPower = 200000 * 'W';
            :>> targetSpeed = targetImpellerSpeed;
        }
        part vessel : MixingVessel {
            :>> tankDiameter = 2.0 * 'm';
            :>> tankHeight = 3.0 * 'm';
            :>> workingVolume = 8.0 * 'm' ** 3;
        }
        bind motor.mechanicalOut = vessel.mechanicalIn;
        port controlPort : ~ControlPort;
        bind controlPort = motor.controlIn;

        state mixingSystemStates {
            entry; then Idle;
            state Idle;
            accept StartCommand then Running;
            state Running {
                do action 'mixing process': 'Mixing Process' {
                    in speed = motor.targetSpeed;
                    in impellerDiameter = vessel.impeller.diameter;
                    in baffleCount = 4;
                    in tankVolume = vessel.workingVolume;
                    out mixedFluid : Fluid;
                }
            }
            accept StopCommand then SpinningDown;
            state SpinningDown;
            then Idle;
        }
    }

    part system : RushtonTurbineSystem;

    requirement def MixingSpeedRequirement {
        attribute actualSpeed : RotationalSpeedValue;
        attribute requiredSpeed : RotationalSpeedValue;
        require constraint { actualSpeed >= requiredSpeed }
    }
    requirement targetMixingSpeed : MixingSpeedRequirement {
        :>> requiredSpeed = 200 [rpm];
        :>> actualSpeed = system.targetImpellerSpeed;
    }
    requirement def TipSpeedRequirement {
        attribute actualTipSpeed : SpeedValue;
        attribute requiredTipSpeed : SpeedValue;
        require constraint { actualTipSpeed >= requiredTipSpeed }
    }
    requirement tipSpeedReq : TipSpeedRequirement {
        :>> requiredTipSpeed = 5.0 * 'm' / 's';
        :>> actualTipSpeed = system.targetTipSpeed;
    }
    requirement def MixingTimeRequirement {
        attribute actualMixingTime : TimeValue;
        attribute maxMixingTime : TimeValue;
        require constraint { actualMixingTime <= maxMixingTime }
    }
    requirement mixingTimeReq : MixingTimeRequirement {
        :>> maxMixingTime = 300 * 's';
        :>> actualMixingTime = system.maxMixingTime;
    }
    requirement def BaffleCountRequirement {
        attribute actualBaffleCount : Integer;
        attribute requiredBaffleCount : Integer;
        require constraint { actualBaffleCount == requiredBaffleCount }
    }
    requirement baffleCountReq : BaffleCountRequirement {
        :>> requiredBaffleCount = 4;
        :>> actualBaffleCount = 4;
    }
}
