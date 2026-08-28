package AirDrivenPumpingSystem {

import ScalarValues::*;

// ============= Value Types =============

value type PressureKPa :> Real;
value type VolumeL :> Real;
value type FlowRateLPM :> Real;

// ============= Enumerations =============

enum ControlCommandType {
    start;
    stop;
    reset;
}

enum PumpStateEnum {
    idle;
    priming;
    pumping;
    stopping;
    fault;
}

// ============= Item Definitions =============

item def CompressedAir {
    attribute pressure : PressureKPa;
    attribute flowRate : FlowRateLPM;
}

item def ProcessFluid {
    attribute pressure : PressureKPa;
    attribute volume : VolumeL;
    attribute flowRate : FlowRateLPM;
}

item def ControlMessage {
    attribute command : ControlCommandType;
}

// ============= Port Definitions =============

port def AirInPort {
    in air : CompressedAir;
}

port def AirOutPort {
    out air : CompressedAir;
}

port def FluidInPort {
    in fluid : ProcessFluid;
}

port def FluidOutPort {
    out fluid : ProcessFluid;
}

port def ExhaustOutPort {
    out exhaust : CompressedAir;
}

port def CmdInPort {
    in message : ControlMessage;
}

port def CmdOutPort {
    out message : ControlMessage;
}

port def PressureInPort {
    in pressure : PressureKPa;
}

port def PressureOutPort {
    out pressure : PressureKPa;
}

// ============= Part Definitions =============

part def AirCompressor {
    attribute outputPressure : PressureKPa = 700;
    attribute maxFlowRate : FlowRateLPM = 100;
    port airOut : AirOutPort;
}

part def PressureRegulator {
    attribute inputPressure : PressureKPa = 700;
    attribute outputPressure : PressureKPa = 600;
    attribute regulatedFlowRate : FlowRateLPM;
    port airIn : AirInPort;
    port airOut : AirOutPort;
}

part def FluidReservoir {
    attribute capacity : VolumeL = 100;
    attribute currentVolume : VolumeL = 100;
    attribute fluidPressure : PressureKPa = 101;
    port fluidOut : FluidOutPort;
}

part def AirDrivenPump {
    attribute maxDischargePressure : PressureKPa = 500;
    attribute maxFlowRate : FlowRateLPM = 80;
    attribute dischargePressure : PressureKPa;
    attribute currentPumpState : PumpStateEnum = PumpStateEnum::idle;
    attribute inletAirPressure : PressureKPa;
    attribute inletFluidPressure : PressureKPa;

    port airIn : AirInPort;
    port fluidIn : FluidInPort;
    port fluidOut : FluidOutPort;
    port exhaust : ExhaustOutPort;
    port controlIn : CmdInPort;

    state pumpStateMachine {
        state idle {
            entry / currentPumpState = PumpStateEnum::idle;
        }
        state priming {
            entry / currentPumpState = PumpStateEnum::priming;
        }
        state pumping {
            entry / currentPumpState = PumpStateEnum::pumping;
        }
        state stopping {
            entry / currentPumpState = PumpStateEnum::stopping;
        }
        state fault {
            entry / currentPumpState = PumpStateEnum::fault;
        }

        initial -> idle;
        idle -> priming when controlIn.message.command == ControlCommandType::start;
        priming -> pumping when dischargePressure >= 200;
        priming -> fault when dischargePressure > maxDischargePressure;
        pumping -> stopping when controlIn.message.command == ControlCommandType::stop;
        pumping -> fault when dischargePressure > maxDischargePressure;
        stopping -> idle when dischargePressure < 50;
        stopping -> priming when controlIn.message.command == ControlCommandType::start;
        fault -> idle when controlIn.message.command == ControlCommandType::reset;
    }
}

part def CheckValve {
    attribute crackingPressure : PressureKPa = 50;
    attribute inletPressure : PressureKPa;
    port fluidIn : FluidInPort;
    port fluidOut : FluidOutPort;

    state valveState {
        state closed;
        state open;
        initial -> closed;
        closed -> open when inletPressure > crackingPressure;
        open -> closed when inletPressure <= crackingPressure;
    }
}

part def FluidReceiver {
    attribute capacity : VolumeL = 80;
    attribute currentVolume : VolumeL = 0;
    attribute internalPressure : PressureKPa = 101;
    port fluidIn : FluidInPort;
    port pressureOut : PressureOutPort;

    bind pressureOut.pressure = internalPressure;
}

part def PressureSensor {
    attribute measurementRangeMin : PressureKPa = 0;
    attribute measurementRangeMax : PressureKPa = 1000;
    attribute measuredPressure : PressureKPa;
    port sensingIn : PressureInPort;
    port signalOut : PressureOutPort;

    bind measuredPressure = sensingIn.pressure;
    bind signalOut.pressure = measuredPressure;
}

part def SystemController {
    attribute targetPressure : PressureKPa = 400;
    attribute lowThreshold : PressureKPa = 350;
    attribute highThreshold : PressureKPa = 450;
    attribute currentPressure : PressureKPa;
    port signalIn : PressureInPort;
    port commandOut : CmdOutPort;

    bind currentPressure = signalIn.pressure;

    state controllerStateMachine {
        state pumpOff {
            entry / commandOut.message = ControlMessage { command = ControlCommandType::stop; };
        }
        state pumpOn {
            entry / commandOut.message = ControlMessage { command = ControlCommandType::start; };
        }

        initial -> pumpOff;
        pumpOff -> pumpOn when currentPressure < lowThreshold;
        pumpOn -> pumpOff when currentPressure > highThreshold;
    }
}

// ============= Top-Level System Assembly =============

part def AirPumpingSystem {
    part airCompressor : AirCompressor;
    part pressureRegulator : PressureRegulator;
    part fluidReservoir : FluidReservoir;
    part pump : AirDrivenPump;
    part checkValve : CheckValve;
    part fluidReceiver : FluidReceiver;
    part pressureSensor : PressureSensor;
    part systemController : SystemController;

    // Air supply chain
    connection airCompressor.airOut to pressureRegulator.airIn;
    connection pressureRegulator.airOut to pump.airIn;

    // Fluid supply chain
    connection fluidReservoir.fluidOut to pump.fluidIn;
    connection pump.fluidOut to checkValve.fluidIn;
    connection checkValve.fluidOut to fluidReceiver.fluidIn;

    // Pressure feedback loop
    connection fluidReceiver.pressureOut to pressureSensor.sensingIn;
    connection pressureSensor.signalOut to systemController.signalIn;

    // Control signal
    connection systemController.commandOut to pump.controlIn;
}

// ============= Requirements =============

requirement def AirSupplyPressureRequirement {
    subject compressor : AirCompressor;
    subject regulator : PressureRegulator;
    require compressor.outputPressure == 700;
    require regulator.outputPressure == 600;
}

requirement def FluidCapacityRequirement {
    subject reservoir : FluidReservoir;
    subject receiver : FluidReceiver;
    require reservoir.capacity == 100;
    require receiver.capacity == 80;
}

requirement def PumpFlowRateRequirement {
    subject pump : AirDrivenPump;
    require pump.maxFlowRate <= 80;
    require pump.maxFlowRate > 0;
}

requirement def PumpSafetyRequirement {
    subject pump : AirDrivenPump;
    require pump.maxDischargePressure >= 450;
    require pump.dischargePressure <= pump.maxDischargePressure;
}

requirement def PressureMaintenanceRequirement {
    subject controller : SystemController;
    subject receiver : FluidReceiver;
    require controller.targetPressure == 400;
    require controller.lowThreshold == 350;
    require controller.highThreshold == 450;
    require receiver.internalPressure >= 350;
    require receiver.internalPressure <= 450;
}

requirement def BackflowPreventionRequirement {
    subject checkValve : CheckValve;
    require checkValve.crackingPressure > 0;
}

requirement def PumpStateManagementRequirement {
    subject pump : AirDrivenPump;
    require pump.currentPumpState == PumpStateEnum::idle or
            pump.currentPumpState == PumpStateEnum::priming or
            pump.currentPumpState == PumpStateEnum::pumping or
            pump.currentPumpState == PumpStateEnum::stopping or
            pump.currentPumpState == PumpStateEnum::fault;
}

}
