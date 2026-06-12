package KineticEnergySystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def RealValue :> ScalarValues::Real;
    attribute def PositiveReal :> RealValue {
        constraint nonNegative {
            self >= 0.0
        }
    }

    attribute def MassValue :> PositiveReal {
        unit = kg;
    }

    attribute def VelocityValue :> RealValue {
        unit = m / s;
    }

    attribute def AngularVelocityValue :> RealValue {
        unit = rad / s;
    }

    attribute def EnergyValue :> PositiveReal {
        unit = J;
    }

    attribute def PowerValue :> RealValue {
        unit = W;
    }

    attribute def ForceValue :> RealValue {
        unit = N;
    }

    attribute def TorqueValue :> RealValue {
        unit = N * m;
    }

    attribute def EfficiencyValue :> PositiveReal {
        constraint range {
            self >= 0.0 and self <= 1.0
        }
    }

    attribute def TimeValue :> PositiveReal {
        unit = s;
    }

    item def MechanicalMotion {
        attribute mass : MassValue;
        attribute velocity : VelocityValue;
        attribute kineticEnergy : EnergyValue;
    }

    item def RotationalMotion {
        attribute inertia : MassValue;
        attribute angularVelocity : AngularVelocityValue;
        attribute rotationalEnergy : EnergyValue;
    }

    item def ElectricalEnergy {
        attribute energy : EnergyValue;
        attribute voltage : RealValue;
        attribute current : RealValue;
    }

    item def ThermalLoss {
        attribute heatEnergy : EnergyValue;
        attribute lossPower : PowerValue;
    }

    port def MechanicalInputPort {
        in item incomingMotion : MechanicalMotion;
    }

    port def RotationalPowerPort {
        out item shaftMotion : RotationalMotion;
    }

    port def ElectricalOutputPort {
        out item generatedEnergy : ElectricalEnergy;
    }

    port def ThermalLossPort {
        out item rejectedHeat : ThermalLoss;
    }

    part def KineticEnergySystem {
        attribute systemMass : MassValue = 1200 [kg];
        attribute inputVelocity : VelocityValue;
        attribute capturedKineticEnergy : EnergyValue;
        attribute deliveredElectricalEnergy : EnergyValue;
        attribute conversionEfficiency : EfficiencyValue = 0.82;
        attribute maximumSafeVelocity : VelocityValue = 35 [m / s];
        attribute minimumHarvestVelocity : VelocityValue = 3 [m / s];

        port mechanicalInput : MechanicalInputPort;
        port rotationalTransfer : RotationalPowerPort;
        port electricalOutput : ElectricalOutputPort;
        port thermalLossOutput : ThermalLossPort;

        part motionSensor : MotionSensor;
        part energyCaptureUnit : EnergyCaptureUnit;
        part flywheelModule : FlywheelModule;
        part generator : ElectricGenerator;
        part powerController : PowerController;
        part protectionUnit : ProtectionUnit;

        connect mechanicalInput to motionSensor.sensedMotion;
        connect mechanicalInput to energyCaptureUnit.motionInput;
        connect energyCaptureUnit.rotationalOutput to flywheelModule.rotationalInput;
        connect flywheelModule.rotationalOutput to generator.shaftInput;
        connect generator.electricalOutput to powerController.rawElectricalInput;
        connect powerController.conditionedElectricalOutput to electricalOutput;
        connect energyCaptureUnit.thermalLossOutput to thermalLossOutput;
        connect generator.thermalLossOutput to thermalLossOutput;
        connect motionSensor.velocitySignal to protectionUnit.velocityInput;
        connect protectionUnit.limitCommand to energyCaptureUnit.limitInput;

        calc kineticEnergyCalculation {
            in mass : MassValue;
            in velocity : VelocityValue;
            return energy : EnergyValue;
            energy = 0.5 * mass * velocity * velocity;
        }

        calc deliveredEnergyCalculation {
            in captured : EnergyValue;
            in efficiency : EfficiencyValue;
            return delivered : EnergyValue;
            delivered = captured * efficiency;
        }

        action operateSystem {
            first startMonitoring;
            then evaluateMotion;
            then decideHarvesting;
            then captureEnergy;
            then convertEnergy;
            then deliverEnergy;

            action startMonitoring {
                motionSensor.monitorMotion();
            }

            action evaluateMotion {
                inputVelocity = motionSensor.measuredVelocity;
                capturedKineticEnergy = kineticEnergyCalculation(systemMass, inputVelocity);
            }

            action decideHarvesting {
                if inputVelocity < minimumHarvestVelocity then idle;
                if inputVelocity >= minimumHarvestVelocity and inputVelocity <= maximumSafeVelocity then enableHarvest;
                if inputVelocity > maximumSafeVelocity then protectSystem;
            }

            action idle {
                powerController.enterStandby();
            }

            action enableHarvest {
                energyCaptureUnit.engageCapture();
            }

            action protectSystem {
                protectionUnit.activateOverspeedProtection();
            }

            action captureEnergy {
                energyCaptureUnit.extractMechanicalEnergy();
                flywheelModule.storeRotationalEnergy();
            }

            action convertEnergy {
                generator.convertRotationalToElectrical();
                deliveredElectricalEnergy = deliveredEnergyCalculation(capturedKineticEnergy, conversionEfficiency);
            }

            action deliverEnergy {
                powerController.regulateOutput();
            }
        }

        state machine energySystemStates {
            state Off;
            state Monitoring;
            state Harvesting;
            state Converting;
            state Delivering;
            state Protected;
            state Faulted;

            initial then Off;

            transition Off_to_Monitoring
                first Off
                accept startCommand
                then Monitoring;

            transition Monitoring_to_Harvesting
                first Monitoring
                if inputVelocity >= minimumHarvestVelocity and inputVelocity <= maximumSafeVelocity
                then Harvesting;

            transition Monitoring_to_Protected
                first Monitoring
                if inputVelocity > maximumSafeVelocity
                then Protected;

            transition Harvesting_to_Converting
                first Harvesting
                if energyCaptureUnit.captureTorque > 0 [N * m]
                then Converting;

            transition Converting_to_Delivering
                first Converting
                if generator.generatedPower > 0 [W]
                then Delivering;

            transition Delivering_to_Monitoring
                first Delivering
                if inputVelocity < minimumHarvestVelocity
                then Monitoring;

            transition Protected_to_Monitoring
                first Protected
                accept resetCommand
                if inputVelocity <= maximumSafeVelocity
                then Monitoring;

            transition Any_to_Faulted
                first Monitoring
                if protectionUnit.faultDetected
                then Faulted;
        }
    }

    part def MotionSensor {
        attribute measuredVelocity : VelocityValue;
        attribute samplePeriod : TimeValue = 0.02 [s];

        port sensedMotion : MechanicalInputPort;
        port velocitySignal {
            out attribute velocity : VelocityValue;
        }

        action monitorMotion {
            measuredVelocity = sensedMotion.incomingMotion.velocity;
        }
    }

    part def EnergyCaptureUnit {
        attribute captureForce : ForceValue;
        attribute captureTorque : TorqueValue;
        attribute mechanicalInputPower : PowerValue;
        attribute heatLossPower : PowerValue;
        attribute captureEfficiency : EfficiencyValue = 0.90;

        port motionInput : MechanicalInputPort;
        port rotationalOutput : RotationalPowerPort;
        port thermalLossOutput : ThermalLossPort;
        port limitInput {
            in attribute torqueLimit : TorqueValue;
        }

        action engageCapture {
            captureForce = motionInput.incomingMotion.mass * motionInput.incomingMotion.velocity / 1 [s];
        }

        action extractMechanicalEnergy {
            mechanicalInputPower = captureForce * motionInput.incomingMotion.velocity;
            captureTorque = limitInput.torqueLimit;
            heatLossPower = mechanicalInputPower * (1.0 - captureEfficiency);
        }
    }

    part def FlywheelModule {
        attribute flywheelInertia : MassValue = 42 [kg];
        attribute angularSpeed : AngularVelocityValue;
        attribute storedEnergy : EnergyValue;
        attribute maximumStoredEnergy : EnergyValue = 2.5e6 [J];

        port rotationalInput : RotationalPowerPort;
        port rotationalOutput : RotationalPowerPort;

        calc rotationalEnergyCalculation {
            in inertia : MassValue;
            in speed : AngularVelocityValue;
            return energy : EnergyValue;
            energy = 0.5 * inertia * speed * speed;
        }

        action storeRotationalEnergy {
            angularSpeed = rotationalInput.shaftMotion.angularVelocity;
            storedEnergy = rotationalEnergyCalculation(flywheelInertia, angularSpeed);
        }
    }

    part def ElectricGenerator {
        attribute generatorEfficiency : EfficiencyValue = 0.91;
        attribute generatedPower : PowerValue;
        attribute generatedEnergy : EnergyValue;
        attribute thermalLossPower : PowerValue;

        port shaftInput : RotationalPowerPort;
        port electricalOutput : ElectricalOutputPort;
        port thermalLossOutput : ThermalLossPort;

        action convertRotationalToElectrical {
            generatedPower = shaftInput.shaftMotion.rotationalEnergy * generatorEfficiency / 1 [s];
            thermalLossPower = shaftInput.shaftMotion.rotationalEnergy * (1.0 - generatorEfficiency) / 1 [s];
            generatedEnergy = shaftInput.shaftMotion.rotationalEnergy * generatorEfficiency;
        }
    }

    part def PowerController {
        attribute outputVoltage : RealValue = 400;
        attribute outputCurrent : RealValue;
        attribute regulatedPower : PowerValue;
        attribute standbyPower : PowerValue = 5 [W];

        port rawElectricalInput : ElectricalOutputPort;
        port conditionedElectricalOutput : ElectricalOutputPort;

        action regulateOutput {
            regulatedPower = rawElectricalInput.generatedEnergy.energy / 1 [s];
            outputCurrent = regulatedPower / outputVoltage;
        }

        action enterStandby {
            regulatedPower = standbyPower;
        }
    }

    part def ProtectionUnit {
        attribute overspeedThreshold : VelocityValue = 35 [m / s];
        attribute faultDetected : Boolean = false;
        attribute commandedTorqueLimit : TorqueValue = 0 [N * m];

        port velocityInput {
            in attribute velocity : VelocityValue;
        }

        port limitCommand {
            out attribute torqueLimit : TorqueValue;
        }

        action activateOverspeedProtection {
            commandedTorqueLimit = 0 [N * m];
            limitCommand.torqueLimit = commandedTorqueLimit;
        }

        action clearFault {
            faultDetected = false;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /* The kinetic energy system shall capture kinetic energy from moving mass, transform it into controlled rotational energy, convert it into electrical energy, and deliver regulated electrical output while limiting unsafe operating conditions. */

        subject system : KineticEnergySystem;

        require constraint {
            system.deliveredElectricalEnergy == system.capturedKineticEnergy * system.conversionEfficiency
        }
    }

    requirement def KineticEnergyCalculationRequirement {
        doc
        /* The system shall compute translational kinetic energy as one half of mass multiplied by velocity squared. */

        subject system : KineticEnergySystem;

        require constraint {
            system.capturedKineticEnergy == 0.5 * system.systemMass * system.inputVelocity * system.inputVelocity
        }
    }

    requirement def SafeOperationRequirement {
        doc
        /* The system shall enter protected operation when measured velocity exceeds the maximum safe velocity. */

        subject system : KineticEnergySystem;

        require constraint {
            system.inputVelocity <= system.maximumSafeVelocity or system.protectionUnit.commandedTorqueLimit == 0 [N * m]
        }
    }

    requirement def MinimumHarvestRequirement {
        doc
        /* The system shall harvest energy only when input velocity is at or above the minimum harvest velocity. */

        subject system : KineticEnergySystem;

        require constraint {
            system.inputVelocity >= system.minimumHarvestVelocity implies system.energyCaptureUnit.captureTorque >= 0 [N * m]
        }
    }

    requirement def EfficiencyRequirement {
        doc
        /* The complete conversion chain shall deliver at least seventy-five percent of captured kinetic energy as regulated electrical energy during normal harvesting. */

        subject system : KineticEnergySystem;

        require constraint {
            system.conversionEfficiency >= 0.75
        }
    }

    part kineticEnergyRecoverySystem : KineticEnergySystem {
        attribute systemMass = 1200 [kg];
        attribute inputVelocity = 18 [m / s];
        attribute conversionEfficiency = 0.82;
        attribute maximumSafeVelocity = 35 [m / s];
        attribute minimumHarvestVelocity = 3 [m / s];
    }

}