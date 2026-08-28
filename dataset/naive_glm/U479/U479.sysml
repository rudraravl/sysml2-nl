package IndustrialFluidPumpingSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value Types ----
    def VolumeFlowRate :> Real { unit 'm3/s'; }
    def PressureValue :> Real { unit 'Pa'; }
    def PowerValue :> Real { unit 'W'; }
    def LengthValue :> Real { unit 'm'; }
    def VolumeValue :> Real { unit 'm3'; }
    def RotationalSpeed :> Real { unit 'rpm'; }
    def TemperatureValue :> Real { unit 'K'; }
    def MassDensityValue :> Real { unit 'kg/m3'; }
    def DiameterValue :> Real { unit 'm'; }

    // ---- Item Types ----
    item def Liquid {
        attribute density : MassDensityValue;
        attribute temperature : TemperatureValue;
    }

    item def Water :> Liquid {
        attribute redef density : MassDensityValue = 1000 [kg/m3];
        attribute redef temperature : TemperatureValue = 293.15 [K];
    }

    // ---- Port Definitions ----
    port def FluidPort {
        attribute pressure : PressureValue;
        attribute flowRate : VolumeFlowRate;
        item liquid : Liquid;
    }

    port def ElectricalPowerPort {
        attribute power : PowerValue;
        attribute voltage : Real;
        attribute current : Real;
    }

    port def ControlSignalPort {
        attribute command : String;
        attribute setpoint : VolumeFlowRate;
    }

    port def MeasurementPort {
        attribute measuredValue : Real;
        attribute signalType : String;
    }

    // ---- Requirements ----
    requirement def PumpingSystemRequirement {
        subject : IndustrialFluidPumpingSystem;
        doc /* The system shall transfer liquid from a source reservoir to a pressurized discharge vessel. */
    }

    requirement def MotorPowerRequirement {
        doc /* The electric motor shall have a rated power of 22 kW. */
        attribute ratedPower : PowerValue = 22000 [W];
    }

    requirement def ReservoirCapacityRequirement {
        doc /* The source reservoir shall have a capacity of 50 cubic meters. */
        attribute capacity : VolumeValue = 50 [m3];
    }

    requirement def SuctionPipeLengthRequirement {
        doc /* The suction pipe shall be 15 meters in length. */
        attribute length : LengthValue = 15 [m];
    }

    requirement def DischargePipeLengthRequirement {
        doc /* The discharge pipe shall be 100 meters in length. */
        attribute length : LengthValue = 100 [m];
    }

    requirement def InstrumentationRequirement {
        doc /* The system shall be instrumented with pressure sensors at inlet and outlet, a flow meter in the discharge line, and a control valve on the discharge side. */
    }

    requirement def LifecycleRequirement {
        doc /* The pump shall operate through idle, starting, running, cavitation, overload, and stopping states with appropriate transitions. */
    }

    // ---- Part Definitions ----

    part def Impeller {
        attribute diameter : DiameterValue = 0.25 [m];
        attribute rotationalSpeed : RotationalSpeed;
        attribute maxSpeed : RotationalSpeed = 2950 [rpm];
    }

    part def VoluteCasing {
        attribute material : String = "Cast Iron";
        attribute inletDiameter : DiameterValue = 0.1 [m];
        attribute outletDiameter : DiameterValue = 0.08 [m];
    }

    part def Shaft {
        attribute material : String = "Stainless Steel";
        attribute length : LengthValue = 0.5 [m];
        attribute diameter : DiameterValue = 0.04 [m];
    }

    part def CentrifugalPump {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port motorConnection : ElectricalPowerPort;
        port controlInterface : ControlSignalPort;

        attribute ratedPower : PowerValue = 22000 [W];
        attribute ratedFlow : VolumeFlowRate = 0.05 [m3/s];
        attribute ratedHead : PressureValue = 500000 [Pa];

        part impeller : Impeller;
        part volute : VoluteCasing;
        part shaft : Shaft;

        flow through inlet to outlet of Liquid;

        exhibit state def PumpLifecycle {
            entry; then idle;

            state idle;
            state starting;
            state running;
            state cavitation;
            state overload;
            state stopping;

            transition idle to starting
                when controlInterface.command == "start";

            transition starting to running
                when impeller.rotationalSpeed >= impeller.maxSpeed * 0.98;

            transition running to cavitation
                when inlet.pressure < 20000 [Pa];

            transition cavitation to running
                when inlet.pressure >= 20000 [Pa];

            transition running to overload
                when motorConnection.power > 24200 [W];

            transition overload to running
                when motorConnection.power <= 22000 [W];

            transition running to stopping
                when controlInterface.command == "stop";

            transition cavitation to stopping
                when controlInterface.command == "stop";

            transition overload to stopping
                when controlInterface.command == "stop";

            transition stopping to idle
                when impeller.rotationalSpeed <= 10 [rpm];
        }
    }

    part def ElectricMotor {
        port powerInput : ElectricalPowerPort;
        port mechanicalOutput : ElectricalPowerPort;
        port controlInterface : ControlSignalPort;

        attribute ratedPower : PowerValue = 22000 [W];
        attribute ratedVoltage : Real = 400;
        attribute ratedCurrent : Real = 40;
        attribute currentPower : PowerValue;
        attribute currentSpeed : RotationalSpeed;
        attribute maxSpeed : RotationalSpeed = 2950 [rpm];

        exhibit state def MotorLifecycle {
            entry; then off;

            state off;
            state accelerating;
            state atSpeed;
            state decelerating;

            transition off to accelerating
                when controlInterface.command == "start";

            transition accelerating to atSpeed
                when currentSpeed >= maxSpeed * 0.98;

            transition atSpeed to decelerating
                when controlInterface.command == "stop";

            transition decelerating to off
                when currentSpeed <= 10 [rpm];
        }
    }

    part def Reservoir {
        port fluidOutlet : FluidPort;
        attribute capacity : VolumeValue = 50 [m3];
        attribute currentVolume : VolumeValue;
        attribute fluid : Liquid;
    }

    part def DischargeVessel {
        port fluidInlet : FluidPort;
        attribute capacity : VolumeValue = 30 [m3];
        attribute currentVolume : VolumeValue;
        attribute targetPressure : PressureValue = 300000 [Pa];
        attribute fluid : Liquid;
    }

    part def Pipe {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute length : LengthValue;
        attribute diameter : DiameterValue = 0.1 [m];
        attribute roughness : Real = 0.00015;
        flow through inlet to outlet of Liquid;
    }

    part def SuctionPipe :> Pipe {
        attribute redef length : LengthValue = 15 [m];
    }

    part def DischargePipe :> Pipe {
        attribute redef length : LengthValue = 100 [m];
    }

    part def PressureSensor {
        port measurementPort : MeasurementPort;
        port fluidInterface : FluidPort;
        attribute measuredPressure : PressureValue;
        attribute range : PressureValue = 1000000 [Pa];
        attribute accuracy : Real = 0.01;

        action def measure {
            in fluidPressure : PressureValue;
            out reading : PressureValue;
        }
    }

    part def InletPressureSensor :> PressureSensor {
        attribute redef measuredPressure : PressureValue;
    }

    part def OutletPressureSensor :> PressureSensor {
        attribute redef range : PressureValue = 2000000 [Pa];
    }

    part def FlowMeter {
        port measurementPort : MeasurementPort;
        port fluidInterface : FluidPort;
        attribute measuredFlowRate : VolumeFlowRate;
        attribute range : VolumeFlowRate = 0.2 [m3/s];
        attribute accuracy : Real = 0.005;

        action def measure {
            in fluidFlow : VolumeFlowRate;
            out reading : VolumeFlowRate;
        }
    }

    part def ControlValve {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port controlInterface : ControlSignalPort;
        attribute opening : Real = 1.0;
        attribute maxOpening : Real = 1.0;
        attribute minOpening : Real = 0.0;
        flow through inlet to outlet of Liquid;

        action def adjust {
            in command : String;
            in setpoint : VolumeFlowRate;
            out newOpening : Real;
        }
    }

    part def PumpController {
        port inletPressureInput : MeasurementPort;
        port outletPressureInput : MeasurementPort;
        port flowInput : MeasurementPort;
        port motorControl : ControlSignalPort;
        port valveControl : ControlSignalPort;
        port operatorInterface : ControlSignalPort;

        attribute desiredFlowRate : VolumeFlowRate = 0.04 [m3/s];
        attribute cavitationThreshold : PressureValue = 20000 [Pa];
        attribute overloadThreshold : PowerValue = 24200 [W];

        action def monitorAndControl {
            in inletPressure : PressureValue;
            in outletPressure : PressureValue;
            in flowRate : VolumeFlowRate;
            in motorPower : PowerValue;
            out motorCommand : String;
            out valveSetpoint : VolumeFlowRate;

            if inletPressure < cavitationThreshold then {
                motorCommand = "reduce";
            } else if motorPower > overloadThreshold then {
                motorCommand = "reduce";
            } else {
                motorCommand = "normal";
            }

            if flowRate < desiredFlowRate then {
                valveSetpoint = desiredFlowRate;
            } else {
                valveSetpoint = desiredFlowRate;
            }
        }
    }

    // ---- Top-level System ----
    part def IndustrialFluidPumpingSystem {
        satisfy PumpingSystemRequirement;
        satisfy InstrumentationRequirement;
        satisfy LifecycleRequirement;

        port systemInlet : FluidPort;
        port systemOutlet : FluidPort;
        port operatorInterface : ControlSignalPort;

        attribute systemFlowRate : VolumeFlowRate;
        attribute systemPressure : PressureValue;
        attribute operationalStatus : String;

        part sourceReservoir : Reservoir {
            attribute redef capacity : VolumeValue = 50 [m3];
            attribute redef currentVolume : VolumeValue = 50 [m3];
            attribute redef fluid : Water;
        }

        part suctionPipe : SuctionPipe;

        part pump : CentrifugalPump {
            attribute redef ratedPower : PowerValue = 22000 [W];
            part redef impeller : Impeller {
                attribute redef diameter : DiameterValue = 0.25 [m];
            }
            part redef volute : VoluteCasing;
            part redef shaft : Shaft;
        }

        part motor : ElectricMotor {
            attribute redef ratedPower : PowerValue = 22000 [W];
            satisfy MotorPowerRequirement;
        }

        part dischargePipe : DischargePipe;

        part dischargeVessel : DischargeVessel {
            attribute redef targetPressure : PressureValue = 300000 [Pa];
            attribute redef fluid : Water;
        }

        part inletPressureSensor : InletPressureSensor;
        part outletPressureSensor : OutletPressureSensor;
        part flowMeter : FlowMeter;
        part controlValve : ControlValve;
        part controller : PumpController;

        connection sourceReservoir.fluidOutlet to suctionPipe.inlet;
        connection suctionPipe.outlet to pump.inlet;
        connection pump.outlet to controlValve.inlet;
        connection controlValve.outlet to dischargePipe.inlet;
        connection dischargePipe.outlet to dischargeVessel.fluidInlet;

        connection pump.motorConnection to motor.mechanicalOutput;

        connection inletPressureSensor.fluidInterface to pump.inlet;
        connection outletPressureSensor.fluidInterface to pump.outlet;
        connection flowMeter.fluidInterface to dischargePipe.inlet;

        connection inletPressureSensor.measurementPort to controller.inletPressureInput;
        connection outletPressureSensor.measurementPort to controller.outletPressureInput;
        connection flowMeter.measurementPort to controller.flowInput;

        connection controller.motorControl to motor.controlInterface;
        connection controller.motorControl to pump.controlInterface;
        connection controller.valveControl to controlValve.controlInterface;
        connection operatorInterface to controller.operatorInterface;

        flow through systemInlet to systemOutlet of Liquid;
    }
}
