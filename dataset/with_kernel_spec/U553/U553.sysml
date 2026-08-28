package 'Fluid Pumping System' {
    private import ISQ::PressureValue;
    private import ISQ::VolumeValue;
    private import ISQ::VolumeFlowRateValue;
    private import ISQ::PowerValue;
    private import ISQ::LengthValue;
    private import ISQ::DurationValue;
    private import SI::Pa;
    private import SI::m;
    private import SI::m3;
    private import SI::s;
    private import SI::h;
    private import SI::W;
    private import ScalarValues::Real;
    public import Definitions::*;
    public import Usages::*;
    public import Requirements::*;

    package Definitions {
        item def Fluid;

        port def FluidPort {
            attribute pressure : PressureValue;
            out item fluid : Fluid;
        }

        port def ShaftPort {
            out power : PowerValue;
        }

        port def ElectricalPowerPort {
            in power : PowerValue;
        }

        action def PumpFluid {
            in fluidIn : Fluid;
            in shaftPower : PowerValue;
            out fluidOut : Fluid;
        }

        action def DriveMotor {
            in electricPower : PowerValue;
            out shaftPower : PowerValue;
        }

        part def SourceReservoir {
            port fluidOut : FluidPort;
            port returnIn : ~FluidPort;
            item fluid : Fluid {
                attribute volume : VolumeValue = 10.0 [m3];
            }
        }

        part def Strainer {
            port fluidIn : ~FluidPort;
            port fluidOut : FluidPort;
            flow fluidIn.fluid to fluidOut.fluid;
        }

        part def PressureSensor {
            port fluidIn : ~FluidPort;
            port fluidOut : FluidPort;
            attribute sensedPressure : PressureValue;
            flow fluidIn.fluid to fluidOut.fluid;
        }

        part def FlowMeter {
            port fluidIn : ~FluidPort;
            port fluidOut : FluidPort;
            attribute volumetricFlowRate : VolumeFlowRateValue;
            flow fluidIn.fluid to fluidOut.fluid;
        }

        part def PumpHousing {
            port suction : ~FluidPort;
            port discharge : FluidPort;
        }

        part def Vane {
            attribute length : LengthValue = 0.15 [m];
            attribute thickness : LengthValue = 0.005 [m];
        }

        part def Rotor {
            attribute eccentricOffset : LengthValue = 0.010 [m];
            part vanes : Vane[4];
        }

        part def DriveShaft {
            port shaftInput : ~ShaftPort;
        }

        part def Bearing {
            attribute innerDiameter : LengthValue = 0.030 [m];
            attribute frictionFactor : Real = 0.001;
        }

        part def Seal {
            attribute leakRate : VolumeFlowRateValue = 0.000000001 [m3/s];
        }

        part def RotaryVanePump {
            port suction : ~FluidPort;
            port discharge : FluidPort;
            port shaftInput : ~ShaftPort;
            part housing : PumpHousing;
            part rotor : Rotor;
            part shaft : DriveShaft;
            part bearing : Bearing[2];
            part seal : Seal;
            perform action pumpFluid : PumpFluid {
                in fluidIn = suction.fluid;
                in shaftPower = shaftInput.power;
                out fluidOut = discharge.fluid;
            }
        }

        part def ElectricMotor {
            port electricalIn : ElectricalPowerPort;
            port shaftOut : ShaftPort;
            attribute ratedPower : PowerValue = 15000 [W];
            attribute efficiency : Real = 0.93;
            perform action drive : DriveMotor {
                in electricPower = electricalIn.power;
                out shaftPower = shaftOut.power;
            }
        }

        part def ElectricPowerSupply {
            port powerOut : ~ElectricalPowerPort;
        }

        part def CheckValve {
            port inlet : ~FluidPort;
            port outlet : FluidPort;
            flow inlet.fluid to outlet.fluid;
        }

        part def PressureReliefValve {
            port inlet : ~FluidPort;
            port outlet : FluidPort;
            port returnOut : FluidPort;
            attribute setPressure : PressureValue;
            flow inlet.fluid to outlet.fluid;
        }

        part def PressureVessel {
            port fluidIn : ~FluidPort;
            attribute capacity : VolumeValue = 5.0 [m3];
            attribute maxOperatingPressure : PressureValue = 1500000 [Pa];
            item fluid : Fluid {
                attribute volume : VolumeValue;
            }
        }

        state def ReliefValveControl {
            in processPressure : PressureValue;
            in setPressure : PressureValue;
            entry; then closed;
            state closed;
            accept when processPressure > setPressure then relieving;
            state relieving;
            accept when processPressure <= setPressure then closed;
        }

        requirement def FlowRateRequirement {
            doc /* The system shall deliver fluid at the specified flow rate. */
            attribute minFlowRate : VolumeFlowRateValue;
            attribute maxFlowRate : VolumeFlowRateValue;
        }

        requirement def PressureRequirement {
            doc /* The system shall maintain discharge pressure within limits. */
            attribute minPressure : PressureValue;
            attribute maxPressure : PressureValue;
        }

        requirement def EfficiencyRequirement {
            doc /* The pump and motor combination shall meet the efficiency target. */
            attribute efficiency : Real;
        }

        requirement def ReliabilityRequirement {
            doc /* The system shall be reliable over its service life. */
            attribute meanTimeBetweenFailure : DurationValue;
        }
    }

    package Usages {
        part context {
            part source : SourceReservoir;
            part strainer : Strainer;
            part suctionSensor : PressureSensor;
            part pump : RotaryVanePump;
            part motor : ElectricMotor;
            part powerSupply : ElectricPowerSupply;
            part checkValve : CheckValve;
            part dischargeSensor : PressureSensor;
            part flowMeter : FlowMeter;
            part reliefValve : PressureReliefValve {
                attribute setPressure : PressureValue = 1200000 [Pa];
            }
            part destination : PressureVessel;

            flow of fluid : Fluid from source.fluidOut.fluid to strainer.fluidIn.fluid;
            flow of fluid : Fluid from strainer.fluidOut.fluid to suctionSensor.fluidIn.fluid;
            flow of fluid : Fluid from suctionSensor.fluidOut.fluid to pump.suction.fluid;
            connect powerSupply.powerOut to motor.electricalIn;
            connect motor.shaftOut to pump.shaftInput;
            flow of fluid : Fluid from pump.discharge.fluid to checkValve.inlet.fluid;
            flow of fluid : Fluid from checkValve.outlet.fluid to dischargeSensor.fluidIn.fluid;
            flow of fluid : Fluid from dischargeSensor.fluidOut.fluid to flowMeter.fluidIn.fluid;
            flow of fluid : Fluid from flowMeter.fluidOut.fluid to reliefValve.inlet.fluid;
            flow of fluid : Fluid from reliefValve.outlet.fluid to destination.fluidIn.fluid;
            flow of fluid : Fluid from reliefValve.returnOut.fluid to source.returnIn.fluid;
            
            exhibit state reliefControl : ReliefValveControl {
                in processPressure = dischargeSensor.sensedPressure;
                in setPressure = reliefValve.setPressure;
            }
        }
    }

    package Requirements {
        requirement flowRateRequirement : FlowRateRequirement {
            attribute minFlowRate : VolumeFlowRateValue = 0.0005 [m3/s];
            attribute maxFlowRate : VolumeFlowRateValue = 0.002 [m3/s];
        }

        requirement pressureRequirement : PressureRequirement {
            attribute minPressure : PressureValue = 500000 [Pa];
            attribute maxPressure : PressureValue = 1500000 [Pa];
        }

        requirement efficiencyRequirement : EfficiencyRequirement {
            attribute efficiency : Real = 0.82;
        }

        requirement reliabilityRequirement : ReliabilityRequirement {
            attribute meanTimeBetweenFailure : DurationValue = 20000 [h];
        }
    }
}
