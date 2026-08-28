package ESPSystemModel {
    private import ISQ::*;
    private import ScalarValues::*;
    private import SI::*;

    item def ReservoirFluid;
    item def ProducedFluid;
    item def Oil;
    item def Gas;
    item def Water;

    item def DownholeData {
        attribute bottomHolePressure :> ISQ::pressure;
        attribute motorTemperature :> ISQ::temperature;
        attribute vibrationLevel :> ISQ::acceleration;
    }

    item def SurfaceFlowData {
        attribute productionRate :> ISQ::volumeFlowRate;
    }

    item def VFDCommand {
        attribute frequency :> ISQ::frequency;
        attribute voltage :> ISQ::electricPotential;
    }

    item def ElectricalPower {
        attribute frequency :> ISQ::frequency;
        attribute voltage :> ISQ::electricPotential;
        attribute current :> ISQ::electricCurrent;
    }

    item def MechanicalPower {
        attribute torque :> ISQ::torque;
        attribute speed :> ISQ::frequency;
    }

    item def StartSignal;
    item def RunSignal;
    item def FaultSignal;
    item def ResetSignal;

    port def DownholeDataOutPort { out data : DownholeData; }
    port def DownholeDataInPort { in data : DownholeData; }
    port def SurfaceFlowOutPort { out data : SurfaceFlowData; }
    port def SurfaceFlowInPort { in data : SurfaceFlowData; }
    port def VFDCommandOutPort { out cmd : VFDCommand; }
    port def VFDCommandInPort { in cmd : VFDCommand; }
    port def PowerOutPort { out pwr : ElectricalPower; }
    port def PowerInPort { in pwr : ElectricalPower; }
    port def MechanicalOutPort { out mech : MechanicalPower; }
    port def MechanicalInPort { in mech : MechanicalPower; }
    port def FluidOutPort { out fluid : ProducedFluid; }
    port def FluidInPort { in fluid : ProducedFluid; }
    port def ReservoirFluidInPort { in fluid : ReservoirFluid; }
    port def OilOutPort { out oil : Oil; }
    port def GasOutPort { out gas : Gas; }
    port def WaterOutPort { out water : Water; }

    action def senseDownholeConditions { out data : DownholeData; }
    action def measureFlowRate { out data : SurfaceFlowData; }
    action def computeVFDCommand {
        in targetFlow : SurfaceFlowData;
        in actualFlow : SurfaceFlowData;
        in downholeData : DownholeData;
        out cmd : VFDCommand;
    }
    action def monitorSafetyLimits {
        in downholeData : DownholeData;
        out faultDetected : Boolean;
    }
    action def adjustOutputFrequency {
        in cmd : VFDCommand;
        out pwr : ElectricalPower;
    }
    action def convertElectricalToMechanical {
        in pwr : ElectricalPower;
        out mech : MechanicalPower;
    }
    action def pumpFluid {
        in mech : MechanicalPower;
        in reservoirFluid : ReservoirFluid;
        out producedFluid : ProducedFluid;
    }
    action def separateFluids {
        in producedFluid : ProducedFluid;
        out oil : Oil;
        out gas : Gas;
        out water : Water;
    }
    action def controlProduction;
    action def monitorSafety;
    action def controlAndMonitor;
    action def initializeSystem;
    action def rampUpPower;
    action def shutdownSystem;
    action def logFault;

    part def DownholeSensorPackage {
        port dataOut : DownholeDataOutPort;
        perform action senseDownholeConditions;
    }

    part def ElectricMotor {
        port powerIn : PowerInPort;
        port mechOut : MechanicalOutPort;
        attribute temperature :> ISQ::temperature;
        perform action convertElectricalToMechanical;
    }

    part def CentrifugalPump {
        port mechIn : MechanicalInPort;
        port fluidIn : ReservoirFluidInPort;
        port fluidOut : FluidOutPort;
        perform action pumpFluid;
    }

    part def DownholeAssembly {
        port powerIn : PowerInPort;
        port dataOut : DownholeDataOutPort;
        port fluidIn : ReservoirFluidInPort;
        port fluidOut : FluidOutPort;

        part motor : ElectricMotor;
        part pump : CentrifugalPump;
        part sensors : DownholeSensorPackage;

        bind powerIn = motor.powerIn;
        bind dataOut = sensors.dataOut;
        bind fluidIn = pump.fluidIn;
        bind fluidOut = pump.fluidOut;

        flow mechFlow of MechanicalPower
            from motor.mechOut.mech to pump.mechIn.mech;
    }

    part def VariableFrequencyDrive {
        port cmdIn : VFDCommandInPort;
        port powerOut : PowerOutPort;
        perform action adjustOutputFrequency;
    }

    part def SurfaceController {
        port downholeDataIn : DownholeDataInPort;
        port flowDataIn : SurfaceFlowInPort;
        port cmdOut : VFDCommandOutPort;
        attribute targetFlowRate :> ISQ::volumeFlowRate;
        perform action computeVFDCommand;
        perform action monitorSafetyLimits;
    }

    part def FlowMeter {
        port dataOut : SurfaceFlowOutPort;
        perform action measureFlowRate;
    }

    part def ProductionTubing {
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
    }

    part def Separator {
        port fluidIn : FluidInPort;
        port oilOut : OilOutPort;
        port gasOut : GasOutPort;
        port waterOut : WaterOutPort;
        perform action separateFluids;
    }

    state def ESPSystemStates {
        entry; then idle;
        state idle {
            do action initializeSystem;
        }
        state starting {
            do action rampUpPower;
        }
        state running {
            do action controlAndMonitor;
        }
        state fault {
            entry action shutdownSystem;
            do action logFault;
        }

        transition idle_to_starting
            first idle
            accept StartSignal
            then starting;
        transition starting_to_running
            first starting
            accept RunSignal
            then running;
        transition running_to_fault
            first running
            accept FaultSignal
            then fault;
        transition fault_to_idle
            first fault
            accept ResetSignal
            then idle;
    }

    part def ESPSystem {
        attribute targetFlowRate :> ISQ::volumeFlowRate;

        part surfaceController : SurfaceController;
        part vfd : VariableFrequencyDrive;
        part downholeAssembly : DownholeAssembly;
        part flowMeter : FlowMeter;
        part productionTubing : ProductionTubing;
        part separator : Separator;

        perform action controlProduction;
        perform action monitorSafety;
        perform action controlAndMonitor;
        perform action initializeSystem;
        perform action rampUpPower;
        perform action shutdownSystem;
        perform action logFault;

        exhibit state systemStates : ESPSystemStates;

        flow downholeDataFlow of DownholeData
            from downholeAssembly.dataOut.data to surfaceController.downholeDataIn.data;
        flow surfaceFlowDataFlow of SurfaceFlowData
            from flowMeter.dataOut.data to surfaceController.flowDataIn.data;
        flow vfdCmdFlow of VFDCommand
            from surfaceController.cmdOut.cmd to vfd.cmdIn.cmd;
        flow powerFlow of ElectricalPower
            from vfd.powerOut.pwr to downholeAssembly.powerIn.pwr;
        flow producedFluidFlow of ProducedFluid
            from downholeAssembly.fluidOut.fluid to productionTubing.fluidIn.fluid;
        flow tubingFluidFlow of ProducedFluid
            from productionTubing.fluidOut.fluid to separator.fluidIn.fluid;
    }

    requirement def ProductionRateRequirement {
        doc /* The system shall maintain the production rate within 10% of the target flow rate. */
        attribute targetRate :> ISQ::volumeFlowRate;
        attribute actualRate :> ISQ::volumeFlowRate;
        constraint { actualRate >= 0.9 * targetRate and actualRate <= 1.1 * targetRate }
    }

    requirement def SafetyShutdownRequirement {
        doc /* The system shall automatically shut down if motor temperature exceeds 150 degC, bottom-hole pressure drops below 500 psi, or vibration exceeds 5g. */
        attribute maxMotorTemp :> ISQ::temperature;
        attribute minBottomHolePressure :> ISQ::pressure;
        attribute maxVibration :> ISQ::acceleration;
    }

    requirement def SeparationRequirement {
        doc /* The separator shall process produced fluid into distinct oil, gas, and water streams. */
    }

    part espSystem : ESPSystem;

    requirement productionRateReq : ProductionRateRequirement;
    requirement safetyShutdownReq : SafetyShutdownRequirement;
    requirement separationReq : SeparationRequirement;

    satisfy productionRateReq by espSystem.surfaceController;
    satisfy safetyShutdownReq by espSystem.surfaceController;
    satisfy separationReq by espSystem.separator;
}
