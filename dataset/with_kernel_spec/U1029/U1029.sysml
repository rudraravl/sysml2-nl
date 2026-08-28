package AutomotiveDifferentialSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    alias Torque for ISQ::TorqueValue;
    alias AngularSpeed for ISQ::AngularVelocityValue;

    port def RotationalPowerPort {
        inout torque : Torque;
        inout angularSpeed : AngularSpeed;
    }

    interface def RotationalPowerTransfer {
        end source : RotationalPowerPort;
        end sink : RotationalPowerPort;
        flow source.torque to sink.torque;
        flow source.angularSpeed to sink.angularSpeed;
    }

    action def TransferTorque {
        in inputTorque : Torque;
        in inputSpeed : AngularSpeed;
        out outputTorque : Torque;
        out outputSpeed : AngularSpeed;
    }

    action def DistributeTorque {
        in inputTorque : Torque;
        in leftSpeed : AngularSpeed;
        in rightSpeed : AngularSpeed;
        out leftWheelTorque : Torque;
        out rightWheelTorque : Torque;
    }

    state machine def DifferentialOperatingBehavior {
        in inputTorque : Torque;
        in leftWheelSpeed : AngularSpeed;
        in rightWheelSpeed : AngularSpeed;

        state idle;
        state straightDriving;
        state cornering;

        transition from idle to straightDriving
            when inputTorque > 0.0 [N*m] and leftWheelSpeed == rightWheelSpeed;
        transition from idle to cornering
            when inputTorque > 0.0 [N*m] and leftWheelSpeed != rightWheelSpeed;
        transition from straightDriving to cornering
            when leftWheelSpeed != rightWheelSpeed;
        transition from cornering to straightDriving
            when leftWheelSpeed == rightWheelSpeed;
        transition from straightDriving to idle
            when inputTorque == 0.0 [N*m];
        transition from cornering to idle
            when inputTorque == 0.0 [N*m];
    }

    constraint def EqualTorqueSplit {
        in leftTorque : Torque;
        in rightTorque : Torque;
        leftTorque == rightTorque;
    }

    constraint def TorqueBalance {
        in inputTorque : Torque;
        in leftTorque : Torque;
        in rightTorque : Torque;
        inputTorque == leftTorque + rightTorque;
    }

    constraint def TorqueCapacity {
        in appliedTorque : Torque;
        in maxRatedTorque : Torque;
        appliedTorque <= maxRatedTorque;
    }

    requirement def StructuralIntegrityRequirement {
        doc /* All differential system components shall withstand the maximum rated engine torque without failure. */
        attribute maxRatedTorque : Torque;
    }

    requirement structuralIntegrityRequirement : StructuralIntegrityRequirement {
        attribute :>> maxRatedTorque = 1000 [N*m];
    }

    part def Driveshaft {
        port input : RotationalPowerPort;
        port output : RotationalPowerPort;

        action transferTorque : TransferTorque {
            in inputTorque = input.torque;
            in inputSpeed = input.angularSpeed;
            out outputTorque = output.torque;
            out outputSpeed = output.angularSpeed;
        }
    }

    part def DifferentialGearSet {
        port input : RotationalPowerPort;
        port leftOutput : RotationalPowerPort;
        port rightOutput : RotationalPowerPort;

        action distributeTorque : DistributeTorque {
            in inputTorque = input.torque;
            in leftSpeed = leftOutput.angularSpeed;
            in rightSpeed = rightOutput.angularSpeed;
            out leftWheelTorque = leftOutput.torque;
            out rightWheelTorque = rightOutput.torque;
        }

        exhibit state machine operatingMode : DifferentialOperatingBehavior {
            in inputTorque = input.torque;
            in leftWheelSpeed = leftOutput.angularSpeed;
            in rightWheelSpeed = rightOutput.angularSpeed;
        }
    }

    part def HalfAxle {
        port input : RotationalPowerPort;
        port output : RotationalPowerPort;

        action transferTorque : TransferTorque {
            in inputTorque = input.torque;
            in inputSpeed = input.angularSpeed;
            out outputTorque = output.torque;
            out outputSpeed = output.angularSpeed;
        }
    }

    part def Wheel {
        port input : RotationalPowerPort;
        port roadContact : RotationalPowerPort;
    }

    part def DifferentialSystem {
        port driveshaftInput : RotationalPowerPort;
        port leftRoadOutput : RotationalPowerPort;
        port rightRoadOutput : RotationalPowerPort;

        part driveshaft : Driveshaft;
        part differential : DifferentialGearSet;
        part leftHalfAxle : HalfAxle;
        part rightHalfAxle : HalfAxle;
        part leftWheel : Wheel;
        part rightWheel : Wheel;

        connect driveshaftInput to driveshaft.input;
        connect driveshaft.output to differential.input;
        connect differential.leftOutput to leftHalfAxle.input;
        connect differential.rightOutput to rightHalfAxle.input;
        connect leftHalfAxle.output to leftWheel.input;
        connect rightHalfAxle.output to rightWheel.input;
        connect leftWheel.roadContact to leftRoadOutput;
        connect rightWheel.roadContact to rightRoadOutput;

        assert constraint equalTorqueSplit : EqualTorqueSplit {
            in leftTorque = leftHalfAxle.output.torque;
            in rightTorque = rightHalfAxle.output.torque;
        }

        assert constraint torqueBalance : TorqueBalance {
            in inputTorque = driveshaftInput.torque;
            in leftTorque = leftHalfAxle.output.torque;
            in rightTorque = rightHalfAxle.output.torque;
        }

        assert constraint structuralIntegrityConstraint : TorqueCapacity {
            in appliedTorque = driveshaftInput.torque;
            in maxRatedTorque = structuralIntegrityRequirement.maxRatedTorque;
        }
    }
}
