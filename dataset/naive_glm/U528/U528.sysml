package FluidTransferSystem {

    import ScalarValues::*;

    attribute def Volume :> Real { unit 'L'; }
    attribute def FlowRate :> Real { unit 'L/min'; }
    attribute def Pressure :> Real { unit 'bar'; }
    attribute def Voltage :> Real { unit 'V'; }
    attribute def Current :> Real { unit 'A'; }
    attribute def Length :> Real { unit 'm'; }
    attribute def Diameter :> Real { unit 'mm'; }

    item def Fluid;
    item def Debris;

    port def FluidPort {
        attribute pressure : Pressure;
        attribute flow : FlowRate;
        item fluid : Fluid;
    }

    port def ElectricPowerPort {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    port def SignalPort {
        attribute value : Real;
    }

    part def Reservoir {
        attribute capacity : Volume;
        attribute currentLevel : Volume;
        port fluidOut : FluidPort;
    }

    part def StrainerFilter {
        attribute meshSize : Diameter;
        attribute retainedDebris : Debris[*];
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
    }

    part def Pipe {
        attribute length : Length;
        attribute innerDiameter : Diameter;
        attribute material : String;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
    }

    part def CheckValve {
        attribute crackingPressure : Pressure;
        attribute backflowPrevented : Boolean;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
    }

    part def FlowMeter {
        attribute measuredFlow : FlowRate;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port flowSignal : SignalPort;
    }

    part def PressureSensor {
        attribute measuredPressure : Pressure;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port pressureSignal : SignalPort;
    }

    part def DestinationTank {
        attribute capacity : Volume;
        attribute currentLevel : Volume;
        port fluidIn : FluidPort;
    }

    part def PowerSupply {
        attribute outputVoltage : Voltage;
        attribute maxCurrent : Current;
        port powerOut : ElectricPowerPort;
    }

    part def PMDCMotor {
        attribute type : String = "permanent magnet DC";
        attribute nominalVoltage : Voltage;
        attribute nominalCurrent : Current;
        port powerIn : ElectricPowerPort;
        attribute speed : Real;
    }

    part def JabscoPump {
        attribute modelNumber : String = "50880-1000";
        attribute housingMaterial : String = "bronze";
        attribute impellerMaterial : String = "nitrile rubber";
        attribute selfPriming : Boolean = true;
        attribute nominalFlowRate : FlowRate = 15;
        attribute maxPressure : Pressure = 3;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port powerIn : ElectricPowerPort;

        part motor : PMDCMotor {
            redefines nominalVoltage = 12;
        }

        action def PrimeSequence {
            in duration_s : Real;
        }
        action def TransferFluid {
            in flowRate : FlowRate;
        }

        exhibit state def Lifecycle {
            state idle;
            state selfPriming;
            state running;
            state stopped;
            state fault;

            transition t1 from idle to selfPriming when startCommand;
            transition t2 from selfPriming to running when primeComplete;
            transition t3 from selfPriming to fault when primeFailed;
            transition t4 from running to stopped when stopCommand;
            transition t5 from running to fault when faultDetected;
            transition t6 from stopped to idle when reset;
            transition t7 from fault to idle when faultCleared;
        }
    }

    part def Controller {
        attribute startCommand : Boolean;
        attribute stopCommand : Boolean;
        attribute reset : Boolean;
        attribute faultCleared : Boolean;
        port flowInput : SignalPort;
        port pressureInput : SignalPort;
        port powerControl : ElectricPowerPort;
    }

    part def FluidTransferSystem {

        part sourceReservoir : Reservoir {
            redefines capacity = 100;
            redefines currentLevel = 100;
        }

        part strainer : StrainerFilter {
            redefines meshSize = 0.5;
        }

        part suctionPipe : Pipe {
            redefines length = 2.0;
            redefines innerDiameter = 25;
            redefines material = "reinforced rubber";
        }

        part pump : JabscoPump;

        part dischargePipe : Pipe {
            redefines length = 3.0;
            redefines innerDiameter = 20;
            redefines material = "stainless steel";
        }

        part checkValve : CheckValve {
            redefines crackingPressure = 0.1;
            redefines backflowPrevented = true;
        }

        part flowMeter : FlowMeter;

        part pressureSensor : PressureSensor;

        part destinationTank : DestinationTank {
            redefines capacity = 50;
            redefines currentLevel = 0;
        }

        part powerSupply : PowerSupply {
            redefines outputVoltage = 12;
            redefines maxCurrent = 15;
        }

        part controller : Controller;

        connect sourceReservoir.fluidOut to strainer.fluidIn;
        connect strainer.fluidOut to suctionPipe.fluidIn;
        connect suctionPipe.fluidOut to pump.fluidIn;
        connect pump.fluidOut to dischargePipe.fluidIn;
        connect dischargePipe.fluidOut to checkValve.fluidIn;
        connect checkValve.fluidOut to flowMeter.fluidIn;
        connect flowMeter.fluidOut to pressureSensor.fluidIn;
        connect pressureSensor.fluidOut to destinationTank.fluidIn;

        connect powerSupply.powerOut to pump.powerIn;
        connect powerSupply.powerOut to controller.powerControl;
        connect flowMeter.flowSignal to controller.flowInput;
        connect pressureSensor.pressureSignal to controller.pressureInput;
    }

    requirement def NominalFlowRateRequirement {
        attribute requiredFlowRate : FlowRate = 15;
        subject system : FluidTransferSystem;
        require system.pump.nominalFlowRate == requiredFlowRate;
    }

    requirement def MaxPressureRequirement {
        attribute maxOperatingPressure : Pressure = 3;
        subject system : FluidTransferSystem;
        require system.pump.maxPressure <= maxOperatingPressure;
    }

    requirement def SelfPrimingRequirement {
        subject pump : JabscoPump;
        require pump.selfPriming == true;
    }

    requirement def BackflowPreventionRequirement {
        subject valve : CheckValve;
        require valve.backflowPrevented == true;
    }

    requirement def DebrisFiltrationRequirement {
        subject strainer : StrainerFilter;
        require strainer.meshSize <= 0.5;
    }

    requirement def PowerSupplyRequirement {
        attribute requiredVoltage : Voltage = 12;
        subject supply : PowerSupply;
        require supply.outputVoltage == requiredVoltage;
    }

    requirement def ReservoirCapacityRequirement {
        attribute sourceCapacity : Volume = 100;
        attribute destinationCapacity : Volume = 50;
        subject system : FluidTransferSystem;
        require system.sourceReservoir.capacity == sourceCapacity;
        require system.destinationTank.capacity == destinationCapacity;
    }

    requirement package FluidTransferRequirements {
        requirement r1 : NominalFlowRateRequirement;
        requirement r2 : MaxPressureRequirement;
        requirement r3 : SelfPrimingRequirement;
        requirement r4 : BackflowPreventionRequirement;
        requirement r5 : DebrisFiltrationRequirement;
        requirement r6 : PowerSupplyRequirement;
        requirement r7 : ReservoirCapacityRequirement;
    }

}
