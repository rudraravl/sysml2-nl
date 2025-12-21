// Create a part called AvionicMotor. It uses electrical power to generate mechanical torque. It has three properties: rated power in kilowatts, nominal voltage in volts, and maximum speed in RPM.
package AvionicMotorSystem {
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::*;

    attribute def RPMUnit :> DimensionOneUnit = 1/min;
    attribute <rpm> revolutionsPerMinute : RPMUnit;

    item def ElectricalPower {
        attribute voltage :> ISQ::electricPotential;
        attribute current :> ISQ::electricCurrent;
        attribute power :> ISQ::power;
    }

    item def MechanicalPower {
        attribute torque :> ISQ::torque;
        attribute angularSpeed : Real;
        attribute power :> ISQ::power;
    }

    port def ElectricalPort {
        in item electricalPower : ElectricalPower;
    }

    port def MechanicalPort {
        out item mechanicalPower : MechanicalPower;
    }

    part def AvionicMotor {
        doc /* An avionic motor that converts electrical power to mechanical torque. */

        attribute ratedPower :> ISQ::power;
        attribute nominalVoltage :> ISQ::electricPotential;
        attribute maximumSpeed : Real;

        attribute efficiency : Real;
        attribute torqueConstant :> ISQ::torque / ISQ::electricCurrent;
        attribute backEmfConstant :> ISQ::electricPotential / ISQ::angularVelocity;
        attribute windingResistance :> ISQ::resistance;
        attribute windingInductance :> ISQ::inductance;
        attribute rotorInertia :> ISQ::momentOfInertia;

        port electricalInput : ElectricalPort;
        port mechanicalOutput : MechanicalPort;

        attribute def MotorState {
            attribute currentSpeed : Real;
            attribute currentTorque :> ISQ::torque;
            attribute currentCurrent :> ISQ::electricCurrent;
            attribute temperature :> ISQ::thermodynamicTemperature;
        }

        attribute motorState : MotorState;

        action def ConvertPower {
            in inputVoltage :> ISQ::electricPotential;
            in inputCurrent :> ISQ::electricCurrent;
            in loadTorque :> ISQ::torque;
            out outputTorque :> ISQ::torque;
            out outputSpeed : Real;
        }

        perform action convertElectricalToMechanical : ConvertPower {
            in inputVoltage = electricalInput.electricalPower.voltage;
            in inputCurrent = electricalInput.electricalPower.current;
            out outputTorque = mechanicalOutput.mechanicalPower.torque;
            out outputSpeed = mechanicalOutput.mechanicalPower.angularSpeed;
        }

        state def MotorOperatingStates {
            entry; then off;

            state off;
            state starting;
            state running;
            state overload;
            state fault;

            transition off_to_starting
                first off
                accept PowerOnCommand
                then starting;

            transition starting_to_running
                first starting
                if motorState.currentSpeed >= 0.8 * maximumSpeed
                then running;

            transition running_to_overload
                first running
                if electricalInput.electricalPower.current > 1.5 * (ratedPower / nominalVoltage)
                then overload;

            transition overload_to_running
                first overload
                if electricalInput.electricalPower.current <= (ratedPower / nominalVoltage)
                then running;

            transition running_to_fault
                first running
                if motorState.temperature > 423.15[K]
                then fault;

            transition overload_to_fault
                first overload
                if motorState.temperature > 423.15[K]
                then fault;

            transition fault_to_off
                first fault
                accept ResetCommand
                then off;

            transition running_to_off
                first running
                accept PowerOffCommand
                then off;
        }

        exhibit state motorBehavior : MotorOperatingStates;

        constraint ElectricalPowerBalance {
            electricalInput.electricalPower.power == 
                electricalInput.electricalPower.voltage * electricalInput.electricalPower.current;
        }

        constraint MechanicalPowerOutput {
            mechanicalOutput.mechanicalPower.power == 
                mechanicalOutput.mechanicalPower.torque * mechanicalOutput.mechanicalPower.angularSpeed;
        }

        constraint TorqueGeneration {
            mechanicalOutput.mechanicalPower.torque == 
                torqueConstant * electricalInput.electricalPower.current;
        }

        constraint BackEmf {
            electricalInput.electricalPower.voltage == 
                electricalInput.electricalPower.current * windingResistance + 
                backEmfConstant * mechanicalOutput.mechanicalPower.angularSpeed;
        }
    }

    requirement def MotorPerformanceRequirement {
        subject motor : AvionicMotor;
    }

    requirement def RatedPowerRequirement :> MotorPerformanceRequirement {
        doc /* The motor shall deliver rated power at nominal voltage. */
        attribute actualPower :> ISQ::power;
        attribute requiredPower :> ISQ::power;
        require constraint { actualPower >= requiredPower }
    }

    requirement def MaximumSpeedRequirement :> MotorPerformanceRequirement {
        doc /* The motor shall not exceed maximum rated speed. */
        attribute actualSpeed : Real;
        attribute maxSpeed : Real;
        require constraint { actualSpeed <= maxSpeed }
    }

    requirement def VoltageRangeRequirement :> MotorPerformanceRequirement {
        doc /* The motor shall operate within specified voltage range. */
        attribute operatingVoltage :> ISQ::electricPotential;
        attribute minVoltage :> ISQ::electricPotential;
        attribute maxVoltage :> ISQ::electricPotential;
        require constraint { 
            operatingVoltage >= minVoltage and operatingVoltage <= maxVoltage 
        }
    }

    requirement def EfficiencyRequirement :> MotorPerformanceRequirement {
        doc /* The motor shall maintain minimum efficiency at rated load. */
        attribute actualEfficiency : Real;
        attribute minEfficiency : Real;
        require constraint { actualEfficiency >= minEfficiency }
    }

    part avionicMotorInstance : AvionicMotor {
        attribute redefines ratedPower = 5.0[kW];
        attribute redefines nominalVoltage = 28.0[V];
        attribute redefines maximumSpeed = 12000.0;
        attribute redefines efficiency = 0.92;
        attribute redefines torqueConstant = 0.04[N*m/A];
        attribute redefines backEmfConstant = 0.04[V*s/rad];
        attribute redefines windingResistance = 0.05[Ω];
        attribute redefines windingInductance = 0.002[H];
        attribute redefines rotorInertia = 0.001[kg*m^2];
    }

    requirement ratedPowerReq : RatedPowerRequirement {
        subject motor = avionicMotorInstance;
        attribute redefines requiredPower = 5.0[kW];
        attribute redefines actualPower = avionicMotorInstance.mechanicalOutput.mechanicalPower.power;
    }

    requirement maxSpeedReq : MaximumSpeedRequirement {
        subject motor = avionicMotorInstance;
        attribute redefines actualSpeed = avionicMotorInstance.motorState.currentSpeed;
        attribute redefines maxSpeed = avionicMotorInstance.maximumSpeed;
    }

    requirement voltageRangeReq : VoltageRangeRequirement {
        subject motor = avionicMotorInstance;
        attribute redefines operatingVoltage = avionicMotorInstance.electricalInput.electricalPower.voltage;
        attribute redefines minVoltage = 22.0[V];
        attribute redefines maxVoltage = 32.0[V];
    }

    requirement efficiencyReq : EfficiencyRequirement {
        subject motor = avionicMotorInstance;
        attribute redefines actualEfficiency = avionicMotorInstance.efficiency;
        attribute redefines minEfficiency = 0.90;
    }

    part def PowerSupply {
        attribute outputVoltage :> ISQ::electricPotential;
        attribute maxCurrent :> ISQ::electricCurrent;
        port output : ElectricalPort;
    }

    part def MechanicalLoad {
        attribute loadInertia :> ISQ::momentOfInertia;
        attribute frictionCoefficient : Real;
        port input : MechanicalPort;
    }

    part motorSystem {
        part powerSupply : PowerSupply {
            attribute redefines outputVoltage = 28.0[V];
            attribute redefines maxCurrent = 200.0[A];
        }

        part motor : AvionicMotor :> avionicMotorInstance;

        part mechanicalLoad : MechanicalLoad {
            attribute redefines loadInertia = 0.005[kg*m^2];
            attribute redefines frictionCoefficient = 0.01;
        }

        connect powerSupply.output to motor.electricalInput;
        connect motor.mechanicalOutput to mechanicalLoad.input;
    }

    analysis def MotorPerformanceAnalysis {
        subject motor : AvionicMotor;
        return outputTorque :> ISQ::torque;
        return outputPower :> ISQ::power;
        return operatingEfficiency : Real;

        objective performanceObjective {
            doc /* Analyze motor performance under rated conditions. */
            require ratedPowerReq;
            require maxSpeedReq;
            require voltageRangeReq;
            require efficiencyReq;
        }
    }
}
