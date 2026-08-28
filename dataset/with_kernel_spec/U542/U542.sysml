package 'HighPressurePlungerPumpSubsystem' {
    private import ScalarValues::Real;

    attribute def Pressure;
    attribute def FlowRate;
    attribute def Temperature;
    attribute def Volume;
    attribute def RotationalSpeed;
    attribute def Torque;
    attribute def Power;

    item def Fluid {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute volume : Volume;
    }
    item def MechanicalPower {
        attribute speed : RotationalSpeed;
        attribute torque : Torque;
    }
    item def ReciprocatingMotion {
        attribute strokeLength : Real;
        attribute frequency : Real;
    }
    item def ElectricalPower {
        attribute power : Power;
    }
    item def PressureReading {
        attribute value : Pressure;
    }
    item def FlowReading {
        attribute value : FlowRate;
    }

    port def FluidInPort {
        in item fluid : Fluid;
    }
    port def FluidOutPort {
        out item fluid : Fluid;
    }
    port def DriveInPort {
        in item power : MechanicalPower;
    }
    port def DriveOutPort {
        out item power : MechanicalPower;
    }
    port def ReciprocatingDriveInPort {
        in item motion : ReciprocatingMotion;
    }
    port def ReciprocatingDriveOutPort {
        out item motion : ReciprocatingMotion;
    }
    port def ElectricalPowerInPort {
        in item power : ElectricalPower;
    }
    port def ElectricalPowerOutPort {
        out item power : ElectricalPower;
    }
    port def PressureReadingOutPort {
        out item reading : PressureReading;
    }
    port def PressureReadingInPort {
        in item reading : PressureReading;
    }
    port def FlowReadingOutPort {
        out item reading : FlowReading;
    }
    port def FlowReadingInPort {
        in item reading : FlowReading;
    }

    action def ConvertElectricalToMechanical {
        in electricalPower : ElectricalPower;
        out mechanicalPower : MechanicalPower;
    }
    action def TransferMechanicalPower {
        in inputPower : MechanicalPower;
        out outputPower : MechanicalPower;
    }
    action def ConvertRotationToReciprocation {
        in mechanicalPower : MechanicalPower;
        out motion1 : ReciprocatingMotion;
        out motion2 : ReciprocatingMotion;
        out motion3 : ReciprocatingMotion;
    }
    action def PressurizeFluid {
        in lowPressureFluid : Fluid;
        out highPressureFluid : Fluid;
    }
    action def PassFluidForward {
        in fluidIn : Fluid;
        out fluidOut : Fluid;
    }
    action def SplitFluidFlow {
        in input : Fluid;
        out output1 : Fluid;
        out output2 : Fluid;
        out output3 : Fluid;
    }
    action def CombineFluidFlow {
        in input1 : Fluid;
        in input2 : Fluid;
        in input3 : Fluid;
        out output : Fluid;
    }
    action def SensePressure {
        in fluid : Fluid;
        out reading : PressureReading;
        out outletFluid : Fluid;
    }
    action def SenseFlow {
        in fluid : Fluid;
        out reading : FlowReading;
        out outletFluid : Fluid;
    }
    action def DampPressurePulses {
        in highPressureFluid : Fluid;
        out steadyFluid : Fluid;
    }

    state def PlungerCycle {
        state IntakeStroke;
        state DischargeStroke;
        transition from IntakeStroke to DischargeStroke;
        transition from DischargeStroke to IntakeStroke;
    }

    part def SupplyReservoir {
        port outlet : FluidOutPort;
        item storedFluid : Fluid;
        attribute capacity : Volume;
    }

    part def ElectricMotor {
        port powerIn : ElectricalPowerInPort;
        port driveOut : DriveOutPort;
        perform action convert : ConvertElectricalToMechanical {
            in electricalPower = powerIn.power;
            out mechanicalPower = driveOut.power;
        }
    }

    part def DriveShaft {
        port driveIn : DriveInPort;
        port driveOut : DriveOutPort;
        perform action transfer : TransferMechanicalPower {
            in inputPower = driveIn.power;
            out outputPower = driveOut.power;
        }
    }

    part def CrankMechanism {
        port driveIn : DriveInPort;
        port plungerDrive1 : ReciprocatingDriveOutPort;
        port plungerDrive2 : ReciprocatingDriveOutPort;
        port plungerDrive3 : ReciprocatingDriveOutPort;
        perform action convert : ConvertRotationToReciprocation {
            in mechanicalPower = driveIn.power;
            out motion1 = plungerDrive1.motion;
            out motion2 = plungerDrive2.motion;
            out motion3 = plungerDrive3.motion;
        }
    }

    part def InletCheckValve {
        port inlet : FluidInPort;
        port outlet : FluidOutPort;
        perform action pass : PassFluidForward {
            in fluidIn = inlet.fluid;
            out fluidOut = outlet.fluid;
        }
    }

    part def DischargeCheckValve {
        port inlet : FluidInPort;
        port outlet : FluidOutPort;
        perform action pass : PassFluidForward {
            in fluidIn = inlet.fluid;
            out fluidOut = outlet.fluid;
        }
    }

    part def InletManifold {
        port inlet : FluidInPort;
        port out1 : FluidOutPort;
        port out2 : FluidOutPort;
        port out3 : FluidOutPort;
        perform action split : SplitFluidFlow {
            in input = inlet.fluid;
            out output1 = out1.fluid;
            out output2 = out2.fluid;
            out output3 = out3.fluid;
        }
    }

    part def DischargeManifold {
        port in1 : FluidInPort;
        port in2 : FluidInPort;
        port in3 : FluidInPort;
        port outlet : FluidOutPort;
        perform action combine : CombineFluidFlow {
            in input1 = in1.fluid;
            in input2 = in2.fluid;
            in input3 = in3.fluid;
            out output = outlet.fluid;
        }
    }

    part def PlungerChamber {
        port driveIn : ReciprocatingDriveInPort;
        port inlet : FluidInPort;
        port outlet : FluidOutPort;
        item workingFluid : Fluid;
        perform action pressurize : PressurizeFluid {
            in lowPressureFluid = inlet.fluid;
            out highPressureFluid = outlet.fluid;
        }
        state cycle : PlungerCycle;
    }

    part def TriplexPlungerPump {
        port inlet : FluidInPort;
        port outlet : FluidOutPort;
        port driveIn : DriveInPort;

        part inletManifold : InletManifold;
        part dischargeManifold : DischargeManifold;
        part crank : CrankMechanism;
        part plunger1 : PlungerChamber;
        part plunger2 : PlungerChamber;
        part plunger3 : PlungerChamber;
        part inletCheck1 : InletCheckValve;
        part inletCheck2 : InletCheckValve;
        part inletCheck3 : InletCheckValve;
        part dischargeCheck1 : DischargeCheckValve;
        part dischargeCheck2 : DischargeCheckValve;
        part dischargeCheck3 : DischargeCheckValve;

        bind inlet.fluid = inletManifold.inlet.fluid;
        bind outlet.fluid = dischargeManifold.outlet.fluid;
        bind driveIn.power = crank.driveIn.power;

        flow of ReciprocatingMotion from crank.plungerDrive1.motion to plunger1.driveIn.motion;
        flow of ReciprocatingMotion from crank.plungerDrive2.motion to plunger2.driveIn.motion;
        flow of ReciprocatingMotion from crank.plungerDrive3.motion to plunger3.driveIn.motion;

        flow of Fluid from inletManifold.out1.fluid to inletCheck1.inlet.fluid;
        flow of Fluid from inletManifold.out2.fluid to inletCheck2.inlet.fluid;
        flow of Fluid from inletManifold.out3.fluid to inletCheck3.inlet.fluid;

        flow of Fluid from inletCheck1.outlet.fluid to plunger1.inlet.fluid;
        flow of Fluid from inletCheck2.outlet.fluid to plunger2.inlet.fluid;
        flow of Fluid from inletCheck3.outlet.fluid to plunger3.inlet.fluid;

        flow of Fluid from plunger1.outlet.fluid to dischargeCheck1.inlet.fluid;
        flow of Fluid from plunger2.outlet.fluid to dischargeCheck2.inlet.fluid;
        flow of Fluid from plunger3.outlet.fluid to dischargeCheck3.inlet.fluid;

        flow of Fluid from dischargeCheck1.outlet.fluid to dischargeManifold.in1.fluid;
        flow of Fluid from dischargeCheck2.outlet.fluid to dischargeManifold.in2.fluid;
        flow of Fluid from dischargeCheck3.outlet.fluid to dischargeManifold.in3.fluid;
    }

    part def DischargePressureVessel {
        port inlet : FluidInPort;
        port outlet : FluidOutPort;
        attribute capacity : Volume;
        item storedFluid : Fluid;
        perform action damp : DampPressurePulses {
            in highPressureFluid = inlet.fluid;
            out steadyFluid = outlet.fluid;
        }
    }

    part def PressureSensor {
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port reading : PressureReadingOutPort;
        perform action sense : SensePressure {
            in fluid = fluidIn.fluid;
            out reading = reading.reading;
            out outletFluid = fluidOut.fluid;
        }
    }

    part def FlowMeter {
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port reading : FlowReadingOutPort;
        perform action sense : SenseFlow {
            in fluid = fluidIn.fluid;
            out reading = reading.reading;
            out outletFluid = fluidOut.fluid;
        }
    }

    part def Monitor {
        port inletPressure : PressureReadingInPort;
        port outletPressure : PressureReadingInPort;
        port dischargeFlow : FlowReadingInPort;
    }

    part def PowerSupply {
        port outlet : ElectricalPowerOutPort;
    }

    part def PumpSubsystem {
        port outlet : FluidOutPort;

        part reservoir : SupplyReservoir;
        part motor : ElectricMotor;
        part shaft : DriveShaft;
        part pump : TriplexPlungerPump;
        part vessel : DischargePressureVessel;
        part inletSensor : PressureSensor;
        part outletSensor : PressureSensor;
        part flowMeter : FlowMeter;
        part monitor : Monitor;
        part powerSupply : PowerSupply;

        flow of ElectricalPower from powerSupply.outlet.power to motor.powerIn.power;
        flow of MechanicalPower from motor.driveOut.power to shaft.driveIn.power;
        flow of MechanicalPower from shaft.driveOut.power to pump.driveIn.power;

        flow of Fluid from reservoir.outlet.fluid to inletSensor.fluidIn.fluid;
        flow of Fluid from inletSensor.fluidOut.fluid to pump.inlet.fluid;
        flow of Fluid from pump.outlet.fluid to outletSensor.fluidIn.fluid;
        flow of Fluid from outletSensor.fluidOut.fluid to vessel.inlet.fluid;
        flow of Fluid from vessel.outlet.fluid to flowMeter.fluidIn.fluid;

        bind outlet.fluid = flowMeter.fluidOut.fluid;

        flow of PressureReading from inletSensor.reading.reading to monitor.inletPressure.reading;
        flow of PressureReading from outletSensor.reading.reading to monitor.outletPressure.reading;
        flow of FlowReading from flowMeter.reading.reading to monitor.dischargeFlow.reading;
    }

    requirement def HighPressureDelivery {
        subject pump : TriplexPlungerPump;
        objective {
            doc "The pump must deliver fluid at high pressure.";
        }
    }
    requirement def PulseDampening {
        subject vessel : DischargePressureVessel;
        objective {
            doc "The discharge vessel must dampen pressure pulses.";
        }
    }
    requirement def PerformanceMonitoring {
        subject monitor : Monitor;
        objective {
            doc "The system must monitor inlet pressure, outlet pressure, and flow rate.";
        }
    }

    part highPressurePumpSubsystem : PumpSubsystem;
}
