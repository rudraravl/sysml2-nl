package 'Solenoid Actuation System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def ElectricCurrent :> ISQ::ElectricCurrentValue {
        attribute :>> num : Real;
        attribute :>> mRef : ElectricCurrentUnit;
    }

    attribute def Voltage :> ISQ::ElectricPotentialValue {
        attribute :>> num : Real;
        attribute :>> mRef : ElectricPotentialUnit;
    }

    attribute def Force :> ISQ::ForceValue {
        attribute :>> num : Real;
        attribute :>> mRef : ForceUnit;
    }

    attribute def Displacement :> ISQ::LengthValue {
        attribute :>> num : Real;
        attribute :>> mRef : LengthUnit;
    }

    attribute def MagneticFlux :> ISQ::MagneticFluxValue {
        attribute :>> num : Real;
        attribute :>> mRef : MagneticFluxUnit;
    }

    attribute def ControlCommand;
    attribute def ActivateCommand :> ControlCommand;
    attribute def DeactivateCommand :> ControlCommand;

    port def ElectricalInputPort {
        in attribute voltage : Voltage;
        out attribute current : ElectricCurrent;
    }

    port def MechanicalOutputPort {
        out attribute force : Force;
        out attribute displacement : Displacement;
    }

    port def ControlInputPort {
        in attribute command : ControlCommand;
    }

    part def ElectromagneticCoil {
        attribute resistance : Real;
        attribute inductance : Real;
        attribute turns : Integer;
        port electricalIn : ElectricalInputPort;
        out attribute magneticFlux : MagneticFlux;
    }

    part def Plunger {
        attribute mass : ISQ::MassValue;
        attribute position : Displacement;
        attribute maxStroke : Displacement;
        in attribute appliedForce : Force;
        port mechanicalOut : MechanicalOutputPort;
    }

    part def ReturnSpring {
        attribute springConstant : Real;
        attribute preload : Force;
        in attribute compression : Displacement;
        out attribute springForce : Force;
    }

    part def SolenoidHousing {
        attribute material : String;
        attribute length : Displacement;
        attribute diameter : Displacement;
    }

    action def EnergizeCoil {
        in appliedVoltage : Voltage;
        in coilResistance : Real;
        in coilInductance : Real;
        out steadyStateCurrent : ElectricCurrent;
        out generatedFlux : MagneticFlux;
    }

    action def GenerateElectromagneticForce {
        in magneticFlux : MagneticFlux;
        in plungerPosition : Displacement;
        in airGap : Displacement;
        out electromagneticForce : Force;
    }

    action def CalculateSpringForce {
        in springConstant : Real;
        in compression : Displacement;
        in preload : Force;
        out restoringForce : Force;
    }

    action def UpdatePlungerPosition {
        in netForce : Force;
        in plungerMass : ISQ::MassValue;
        in currentPosition : Displacement;
        in deltaTime : ISQ::TimeValue;
        out newPosition : Displacement;
        out velocity : ISQ::SpeedValue;
    }

    action def DeenergizeCoil {
        in currentFlux : MagneticFlux;
        in coilInductance : Real;
        out decayingCurrent : ElectricCurrent;
        out decayingFlux : MagneticFlux;
    }

    part def Solenoid {
        attribute ratedVoltage : Voltage;
        attribute maximumStroke : Displacement;
        attribute actuationTime : ISQ::TimeValue;
        attribute holdingForce : Force;

        port controlPort : ControlInputPort;
        port powerPort : ElectricalInputPort;
        port outputPort : MechanicalOutputPort;

        part coil : ElectromagneticCoil {
            attribute :>> resistance = 8.5;
            attribute :>> inductance = 0.035;
            attribute :>> turns = 750;
        }

        part plunger : Plunger {
            attribute :>> mass = 0.025 [SI::kg];
            attribute :>> position = 0.0 [SI::mm];
            attribute :>> maxStroke = 12.0 [SI::mm];
        }

        part spring : ReturnSpring {
            attribute :>> springConstant = 850.0;
            attribute :>> preload = 5.0 [SI::N];
        }

        part housing : SolenoidHousing {
            attribute :>> material = "Ferromagnetic Steel";
            attribute :>> length = 60.0 [SI::mm];
            attribute :>> diameter = 18.0 [SI::mm];
        }

        connection electricalConnection connect powerPort to coil.electricalIn;
    }

    action def OperateSolenoidActuator {
        in activationCommand : ActivateCommand;
        in deactivationCommand : DeactivateCommand;
        in supplyVoltage : Voltage;
        out actuatorDisplacement : Displacement;
        out actuatorForce : Force;

        first start;
        then merge operationLoop;

        then action receiveCommand {
            in activate = activationCommand;
            in deactivate = deactivationCommand;
            out currentCommand : ControlCommand;
        }

        then decide;
            if receiveCommand.currentCommand then activateSequence;
            else deactivateSequence;

        action activateSequence {
            action energizeCoilAction : EnergizeCoil {
                in appliedVoltage = supplyVoltage;
                in coilResistance = 8.5;
                in coilInductance = 0.035;
                out steadyStateCurrent;
                out generatedFlux;
            }
            flow energizeCoilAction.generatedFlux to generateForceAction.magneticFlux;

            action generateForceAction : GenerateElectromagneticForce {
                in magneticFlux;
                in plungerPosition = 0.0 [SI::mm];
                in airGap = 12.0 [SI::mm];
                out electromagneticForce;
            }
            flow generateForceAction.electromagneticForce to movePlungerAction.netForce;

            action movePlungerAction : UpdatePlungerPosition {
                in netForce;
                in plungerMass = 0.025 [SI::kg];
                in currentPosition = 0.0 [SI::mm];
                in deltaTime = 0.001 [SI::s];
                out newPosition;
                out velocity;
            }
        }
        then assign actuatorDisplacement := activateSequence.movePlungerAction.newPosition;
        then assign actuatorForce := activateSequence.generateForceAction.electromagneticForce;
        then operationLoop;

        action deactivateSequence {
            action deenergizeCoilAction : DeenergizeCoil {
                in currentFlux = 0.8 [SI::Wb];
                in coilInductance = 0.035;
                out decayingCurrent;
                out decayingFlux;
            }

            action returnSpringAction : CalculateSpringForce {
                in springConstant = 850.0;
                in compression = 12.0 [SI::mm];
                in preload = 5.0 [SI::N];
                out restoringForce;
            }
            flow returnSpringAction.restoringForce to returnPlungerAction.netForce;

            action returnPlungerAction : UpdatePlungerPosition {
                in netForce;
                in plungerMass = 0.025 [SI::kg];
                in currentPosition = 12.0 [SI::mm];
                in deltaTime = 0.001 [SI::s];
                out newPosition;
                out velocity;
            }
        }
        then assign actuatorDisplacement := deactivateSequence.returnPlungerAction.newPosition;
        then assign actuatorForce := 0.0 [SI::N];
        then operationLoop;
    }

    requirement def SolenoidFunctionalRequirement {
        doc /* The solenoid shall convert electrical energy into controlled linear mechanical motion. */

        require constraint actuationForceConstraint {
            doc /* The solenoid shall generate sufficient electromagnetic force to overcome spring resistance and external loads. */
        }

        require constraint responseTimeConstraint {
            doc /* The solenoid shall achieve full stroke displacement within specified actuation time. */
        }

        require constraint strokeLengthConstraint {
            doc /* The solenoid shall provide repeatable linear displacement over its rated stroke length. */
        }
    }

    requirement <'SOL-REQ-001'> primarySolenoidRequirement : SolenoidFunctionalRequirement {
        doc /* The solenoid actuation system shall reliably convert electrical control signals into precise, 
               repeatable linear mechanical motion for applications including valve control, locking mechanisms, 
               and automated switching devices. */

        subject solenoidActuator : Solenoid;

        assume constraint powerSupplyStable {
            doc /* Electrical power supply provides stable DC voltage within rated operating range. */
        }

        assume constraint mechanicalLoadWithinLimits {
            doc /* External mechanical load does not exceed solenoid force capacity. */
        }

        require constraint actuationForceConstraint {
            doc /* Solenoid shall generate minimum 25 Newtons of force at rated voltage. */
        }

        require constraint responseTimeConstraint {
            doc /* Solenoid shall complete full stroke within 40 milliseconds from activation signal. */
        }

        require constraint strokeLengthConstraint {
            doc /* Solenoid shall provide 12 millimeters of linear stroke with repeatability within 0.1 millimeters. */
        }

        require constraint operationalLifeConstraint {
            doc /* Solenoid shall operate reliably for minimum 2 million actuation cycles. */
        }

        require constraint powerConsumptionConstraint {
            doc /* Solenoid shall not exceed 15 Watts continuous power consumption in energized state. */
        }
    }

    part solenoidActuationSystem {
        part actuator : Solenoid {
            attribute :>> ratedVoltage = 24.0 [SI::V];
            attribute :>> maximumStroke = 12.0 [SI::mm];
            attribute :>> actuationTime = 0.04 [SI::s];
            attribute :>> holdingForce = 30.0 [SI::N];
        }

        perform action operateActuator : OperateSolenoidActuator;

        satisfy primarySolenoidRequirement by actuator;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Solenoid Actuation System'::*;

    action orchestrator {
        action energizeCoilActionProbe : EnergizeCoil {
            // TODO(human): unsupported input type for appliedVoltage: Voltage (unsupported structured payload members: mRef)
            in coilResistance = 0.0;
            in coilInductance = 0.0;
        }
        first energizeCoilActionProbe;
    }
}
