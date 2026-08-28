package 'Reaction Turbine Power Generation System' {
    private import ISQ::*;
    private import SI::*;
    private import MeasurementReferences::DimensionOneValue;

    attribute def EfficiencyValue :> DimensionOneValue;
    attribute def DegreeOfReactionValue :> DimensionOneValue;
    attribute def PressureValue :> ISQ::pressure;
    attribute def TemperatureValue :> ISQ::thermodynamicTemperature;
    attribute def VelocityValue :> ISQ::velocity;
    attribute def AngularVelocityValue :> ISQ::angularVelocity;
    attribute def TorqueValue :> ISQ::torque;
    attribute def PowerValue :> ISQ::power;
    attribute def MassFlowRateValue :> ISQ::massFlowRate;
    attribute def SpecificEnergyValue :> ISQ::specificEnergy;

    item def WorkingFluid {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute massFlowRate : MassFlowRateValue;
        attribute specificEnthalpy : SpecificEnergyValue;
        attribute velocity : VelocityValue;
    }

    port def FluidPort {
        item workingFluid : WorkingFluid;
    }
    port def MechanicalPort {
        attribute torque : TorqueValue;
        attribute rotationalSpeed : AngularVelocityValue;
        attribute power : PowerValue;
    }
    port def ElectricalPort {
        attribute power : PowerValue;
    }
    port def SensorPort {
        attribute efficiency : EfficiencyValue;
        attribute degreeOfReaction : DegreeOfReactionValue;
        attribute power : PowerValue;
    }
    port def ControlPort {
        attribute desiredDegreeOfReaction : DegreeOfReactionValue;
    }

    calc def FluidPower {
        in massFlowRate : MassFlowRateValue;
        in enthalpyIn : SpecificEnergyValue;
        in enthalpyOut : SpecificEnergyValue;
        return power : PowerValue = massFlowRate * (enthalpyIn - enthalpyOut);
    }
    calc def StageEfficiency {
        in mechanicalPower : PowerValue;
        in fluidPower : PowerValue;
        return efficiency : EfficiencyValue = mechanicalPower / fluidPower;
    }
    calc def DegreeOfReactionCalc {
        in rotorPressureDrop : PressureValue;
        in stagePressureDrop : PressureValue;
        return degreeOfReaction : DegreeOfReactionValue = rotorPressureDrop / stagePressureDrop;
    }

    action def AccelerateFluid {
        in inletFluid : WorkingFluid;
        out outletFluid : WorkingFluid;
    }
    action def ExtractEnergy {
        in inletFluid : WorkingFluid;
        out outletFluid : WorkingFluid;
        out shaftPower : PowerValue;
        out shaftTorque : TorqueValue;
        out shaftSpeed : AngularVelocityValue;
    }
    action def GenerateElectricity {
        in mechanicalPower : PowerValue;
        in conversionEfficiency : EfficiencyValue;
        out electricalPower : PowerValue;
    }
    action def MonitorAndControl {
        in measuredEfficiency : EfficiencyValue;
        in measuredDegreeOfReaction : DegreeOfReactionValue;
        in targetEfficiency : EfficiencyValue;
        out desiredDegreeOfReaction : DegreeOfReactionValue;
    }

    part def Stator {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        perform action accelerateFluid : AccelerateFluid;
        bind accelerateFluid.inletFluid = fluidIn.workingFluid;
        bind accelerateFluid.outletFluid = fluidOut.workingFluid;
    }

    part def Rotor {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port shaftOutput : MechanicalPort;
        perform action extractEnergy : ExtractEnergy;
        bind extractEnergy.inletFluid = fluidIn.workingFluid;
        bind extractEnergy.outletFluid = fluidOut.workingFluid;
        bind extractEnergy.shaftPower = shaftOutput.power;
        bind extractEnergy.shaftTorque = shaftOutput.torque;
        bind extractEnergy.shaftSpeed = shaftOutput.rotationalSpeed;
    }

    part def Shaft {
        port mechanicalIn : MechanicalPort;
        port mechanicalOut : MechanicalPort;
    }

    part def Generator {
        port mechanicalIn : MechanicalPort;
        port electricalOut : ElectricalPort;
        attribute conversionEfficiency : EfficiencyValue = 0.95;
        perform action generateElectricity : GenerateElectricity;
        bind generateElectricity.mechanicalPower = mechanicalIn.power;
        bind generateElectricity.conversionEfficiency = conversionEfficiency;
        bind generateElectricity.electricalPower = electricalOut.power;
    }

    part def Controller {
        port sensorIn : SensorPort;
        port controlOut : ControlPort;
        attribute targetEfficiency : EfficiencyValue = 0.85;
        attribute minReaction : DegreeOfReactionValue = 0.4;
        attribute maxReaction : DegreeOfReactionValue = 0.6;
        attribute measuredEfficiency : EfficiencyValue;
        attribute measuredDegreeOfReaction : DegreeOfReactionValue;
        bind measuredEfficiency = sensorIn.efficiency;
        bind measuredDegreeOfReaction = sensorIn.degreeOfReaction;
        perform action monitorAndControl : MonitorAndControl;
        bind monitorAndControl.measuredEfficiency = measuredEfficiency;
        bind monitorAndControl.measuredDegreeOfReaction = measuredDegreeOfReaction;
        bind monitorAndControl.targetEfficiency = targetEfficiency;
        bind monitorAndControl.desiredDegreeOfReaction = controlOut.desiredDegreeOfReaction;
        state controllerStates {
            state monitoring;
            state adjusting;
            transition monitoring to adjusting {
                guard { measuredEfficiency < targetEfficiency }
            }
            transition adjusting to monitoring {
                guard { measuredEfficiency >= targetEfficiency }
            }
        }
    }

    part def TurbineStage {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port shaftOutput : MechanicalPort;
        port sensorOut : SensorPort;
        port controlIn : ControlPort;
        part stator : Stator;
        part rotor : Rotor;
        attribute fluidPowerIn : PowerValue;
        attribute efficiency : EfficiencyValue;
        attribute degreeOfReaction : DegreeOfReactionValue;
        attribute desiredDegreeOfReaction : DegreeOfReactionValue;
        attribute rotorDrop : PressureValue;
        attribute stageDrop : PressureValue;

        calc stageFluidPower : FluidPower {
            in massFlowRate = fluidIn.workingFluid.massFlowRate;
            in enthalpyIn = fluidIn.workingFluid.specificEnthalpy;
            in enthalpyOut = fluidOut.workingFluid.specificEnthalpy;
        }
        calc stageEff : StageEfficiency {
            in mechanicalPower = shaftOutput.power;
            in fluidPower = stageFluidPower.power;
        }
        calc stageReaction : DegreeOfReactionCalc {
            in rotorPressureDrop = rotorDrop;
            in stagePressureDrop = stageDrop;
        }

        bind fluidPowerIn = stageFluidPower.power;
        bind efficiency = stageEff.efficiency;
        bind degreeOfReaction = stageReaction.degreeOfReaction;
        bind desiredDegreeOfReaction = controlIn.desiredDegreeOfReaction;
        bind sensorOut.efficiency = efficiency;
        bind sensorOut.degreeOfReaction = degreeOfReaction;
        bind sensorOut.power = shaftOutput.power;

        connect fluidIn to stator.fluidIn;
        connect stator.fluidOut to rotor.fluidIn;
        connect rotor.fluidOut to fluidOut;
        connect rotor.shaftOutput to shaftOutput;
    }

    part def ReactionTurbineSystem {
        part turbineStage : TurbineStage;
        part shaft : Shaft;
        part generator : Generator;
        part controller : Controller;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port electricalOut : ElectricalPort;
        connect fluidIn to turbineStage.fluidIn;
        connect turbineStage.fluidOut to fluidOut;
        connect turbineStage.shaftOutput to shaft.mechanicalIn;
        connect shaft.mechanicalOut to generator.mechanicalIn;
        connect generator.electricalOut to electricalOut;
        connect turbineStage.sensorOut to controller.sensorIn;
        connect controller.controlOut to turbineStage.controlIn;
    }

    requirement def MinPowerOutputRequirement {
        doc /* The system shall deliver a minimum electrical power output of 500 kW. */
        subject system : ReactionTurbineSystem;
        attribute minPower : PowerValue = 500 [kW];
        require constraint { system.generator.electricalOut.power >= minPower }
    }

    requirement def EfficiencyThresholdRequirement {
        doc /* The controller shall maintain turbine efficiency at or above 85 percent. */
        subject controller : Controller;
        attribute minEfficiency : EfficiencyValue = 0.85;
        require constraint { controller.measuredEfficiency >= minEfficiency }
    }

    requirement def OptimalReactionRangeRequirement {
        doc /* The degree of reaction shall remain between 0.4 and 0.6 for balanced energy extraction. */
        subject stage : TurbineStage;
        attribute minReaction : DegreeOfReactionValue = 0.4;
        attribute maxReaction : DegreeOfReactionValue = 0.6;
        require constraint { stage.degreeOfReaction >= minReaction and stage.degreeOfReaction <= maxReaction }
    }

    requirement def EnergyConservationRequirement {
        doc /* The generated electrical power shall not exceed the fluid power entering the turbine stage. */
        subject system : ReactionTurbineSystem;
        require constraint { system.generator.electricalOut.power <= system.turbineStage.fluidPowerIn }
    }

    part system : ReactionTurbineSystem;
    satisfy MinPowerOutputRequirement by system;
    satisfy EfficiencyThresholdRequirement by system.controller;
    satisfy OptimalReactionRangeRequirement by system.turbineStage;
    satisfy EnergyConservationRequirement by system;
}
