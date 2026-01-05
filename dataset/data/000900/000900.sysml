package 'Impeller Pump System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def RotationalSpeed :> ISQ::AngularVelocityValue {
        attribute :>> num : Real;
        attribute :>> mRef : AngularVelocityUnit;
    }

    attribute def FlowRate :> ISQ::VolumeFlowRateValue {
        attribute :>> num : Real;
        attribute :>> mRef : VolumeFlowRateUnit;
    }

    attribute def PressureRise :> ISQ::PressureValue {
        attribute :>> num : Real;
        attribute :>> mRef : PressureUnit;
    }

    attribute def FluidDensity :> ISQ::DensityValue {
        attribute :>> num : Real;
        attribute :>> mRef : DensityUnit;
    }

    attribute def ImpellerDiameter :> ISQ::LengthValue {
        attribute :>> num : Real;
        attribute :>> mRef : LengthUnit;
    }

    attribute def MotorCommand;
    attribute def StartCommand;
    attribute def StopCommand;

    item def Fluid {
        attribute density : FluidDensity;
        attribute viscosity : ISQ::DynamicViscosityValue;
    }

    port def FluidInletPort {
        in attribute inletPressure : PressureValue;
        in attribute inletFlowRate : FlowRate;
        in attribute fluidDensity : FluidDensity;
    }

    port def FluidOutletPort {
        out attribute outletPressure : PressureValue;
        out attribute outletFlowRate : FlowRate;
    }

    port def PowerInputPort {
        in attribute motorCommand : MotorCommand;
        in attribute inputPower : PowerValue;
    }

    port def ShaftPort {
        attribute torque : TorqueValue;
        attribute speed : RotationalSpeed;
    }

    part def Motor {
        port powerInput : PowerInputPort;
        port shaftOutput : ShaftPort;

        attribute efficiency : Real;
        attribute ratedPower : PowerValue;

        perform action convertPowerToRotation {
            in command : MotorCommand = powerInput.motorCommand;
            in power : PowerValue = powerInput.inputPower;
            out torque : TorqueValue;
            out speed : RotationalSpeed;
        }
    }

    part def ImpellerBlade {
        attribute bladeAngle : ISQ::AngleValue;
        attribute bladeLength : LengthValue;
        attribute bladeThickness : LengthValue;
    }

    part def Impeller {
        attribute diameter : ImpellerDiameter;
        attribute numberOfBlades : Integer;

        port shaftInput : ShaftPort;
        port fluidInlet : FluidInletPort;
        port fluidOutlet : FluidOutletPort;

        part blades : ImpellerBlade[6];

        perform action impartEnergyToFluid {
            in torque : TorqueValue = shaftInput.torque;
            in speed : RotationalSpeed = shaftInput.speed;
            in inletPressure : PressureValue = fluidInlet.inletPressure;
            in inletFlow : FlowRate = fluidInlet.inletFlowRate;
            in density : FluidDensity = fluidInlet.fluidDensity;
            out outletPressure : PressureValue;
            out outletFlow : FlowRate;
        }
    }

    part def Casing {
        attribute innerDiameter : LengthValue;
        attribute wallThickness : LengthValue;

        port fluidInlet : FluidInletPort;
        port fluidOutlet : FluidOutletPort;

        perform action directFluidFlow {
            in inletFlow : FlowRate = fluidInlet.inletFlowRate;
            out outletFlow : FlowRate;
        }
    }

    part def Shaft {
        attribute diameter : LengthValue;
        attribute length : LengthValue;
        attribute material : String;

        port input : ShaftPort;
        port output : ShaftPort;

        perform action transmitTorque {
            in inputTorque : TorqueValue = input.torque;
            out outputTorque : TorqueValue;
        }
    }

    action def AccelerateFluid {
        in rotationalSpeed : RotationalSpeed;
        in fluidDensity : FluidDensity;
        in impellerDiameter : ImpellerDiameter;
        in inletFlowRate : FlowRate;
        out centrifugalForce : ForceValue;
        out velocityIncrease : SpeedValue;
    }

    action def ConvertVelocityToPressure {
        in velocityIncrease : SpeedValue;
        in fluidDensity : FluidDensity;
        out pressureRise : PressureRise;
    }

    action def DischargeFluid {
        in pressureRise : PressureRise;
        in inletPressure : PressureValue;
        in flowRate : FlowRate;
        out outletPressure : PressureValue;
        out outletFlowRate : FlowRate;
    }

    part def ImpellerSystem {
        doc /* 
            An impeller-based pumping system that increases fluid pressure and flow rate 
            through rotational energy transfer from a motor-driven impeller to the working fluid.
        */

        port systemFluidInlet : FluidInletPort;
        port systemFluidOutlet : FluidOutletPort;
        port systemPowerInput : PowerInputPort;

        part motor : Motor {
            attribute :>> efficiency = 0.92;
            attribute :>> ratedPower = 5000.0 [SI::W];
        }

        part shaft : Shaft {
            attribute :>> material = "Stainless Steel";
            attribute :>> diameter = 0.05 [SI::m];
            attribute :>> length = 0.3 [SI::m];
        }

        part impeller : Impeller {
            attribute :>> numberOfBlades = 6;
            attribute :>> diameter = 0.25 [SI::m];
        }

        part casing : Casing {
            attribute :>> innerDiameter = 0.3 [SI::m];
            attribute :>> wallThickness = 0.01 [SI::m];
        }

        connect motor.shaftOutput to shaft.input;
        connect shaft.output to impeller.shaftInput;
        connect systemFluidInlet to casing.fluidInlet;
        connect casing.fluidInlet to impeller.fluidInlet;
        connect impeller.fluidOutlet to casing.fluidOutlet;
        connect casing.fluidOutlet to systemFluidOutlet;
        connect systemPowerInput to motor.powerInput;

        perform action pumpFluid {
            first start;
            then accept startCmd : StartCommand;
            then loop {
                action accelerate : AccelerateFluid {
                    in rotationalSpeed = motor.shaftOutput.speed;
                    in fluidDensity = systemFluidInlet.fluidDensity;
                    in impellerDiameter = impeller.diameter;
                    in inletFlowRate = systemFluidInlet.inletFlowRate;
                    out centrifugalForce;
                    out velocityIncrease;
                }

                flow accelerate.velocityIncrease to convertVelocity.velocityIncrease;

                action convertVelocity : ConvertVelocityToPressure {
                    in velocityIncrease;
                    in fluidDensity = systemFluidInlet.fluidDensity;
                    out pressureRise;
                }

                flow convertVelocity.pressureRise to discharge.pressureRise;

                action discharge : DischargeFluid {
                    in pressureRise;
                    in inletPressure = systemFluidInlet.inletPressure;
                    in flowRate = systemFluidInlet.inletFlowRate;
                    out outletPressure;
                    out outletFlowRate;
                }

                then accept stopCmd : StopCommand;
            }
            then done;
        }
    }

    requirement def PerformanceRequirement {
        attribute requiredFlowRate : FlowRate;
        attribute requiredPressureRise : PressureRise;
        attribute maximumPowerConsumption : PowerValue;
    }

    part impellerSystem : ImpellerSystem;

    requirement <'REQ-001'> impellerPerformance : PerformanceRequirement {
        doc /* 
            The impeller system shall deliver the specified flow rate 
            with the required pressure rise while not exceeding maximum power consumption.
        */

        subject impellerSystem;

        require constraint flowRateRequirement {
            impellerSystem.systemFluidOutlet.outletFlowRate >= requiredFlowRate
        }

        require constraint pressureRiseRequirement {
            impellerSystem.systemFluidOutlet.outletPressure - 
            impellerSystem.systemFluidInlet.inletPressure >= requiredPressureRise
        }

        require constraint powerConsumptionLimit {
            impellerSystem.systemPowerInput.inputPower <= maximumPowerConsumption
        }
    }

    requirement <'REQ-002'> reliabilityRequirement {
        doc /* 
            The impeller system shall operate continuously for minimum 
            operational duration without failure.
        */

        subject impellerSystem;

        attribute minimumOperationalHours : Real;

        require constraint continuousOperation {
            minimumOperationalHours >= 10000.0
        }
    }
}
