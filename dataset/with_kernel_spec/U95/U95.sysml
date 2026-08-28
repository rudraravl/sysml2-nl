package 'Open Flow Microperfusion System' {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    private import ScalarValues::Integer;

    attribute def FlowRate :> Real;
    attribute def Pressure :> Real;
    attribute def Temperature :> Real;
    attribute def Volume :> Real;
    attribute def Concentration :> Real;
    attribute def TimeInterval :> Real;

    item def PerfusionFluid {
        attribute temperature : Temperature;
        attribute volume : Volume;
        attribute analyteConcentration : Concentration;
    }
    item def InterstitialFluid {
        attribute volume : Volume;
        attribute analyteConcentration : Concentration;
    }
    item def FluidSample {
        attribute volume : Volume;
        attribute analyteConcentration : Concentration;
        attribute collectionTime : TimeInterval;
    }
    item def FlowCommandSignal {
        attribute desiredFlowRate : FlowRate;
    }
    item def FlowRateSignal {
        attribute value : FlowRate;
    }
    item def PressureSignal {
        attribute value : Pressure;
    }

    port def FluidOutletPort {
        out item fluid : PerfusionFluid;
    }
    port def SampleOutletPort {
        out item sample : FluidSample;
    }
    port def PressureSignalPort {
        out item signal : PressureSignal;
    }
    port def FlowCommandPort {
        out item signal : FlowCommandSignal;
    }
    port def FlowRateSignalPort {
        out item signal : FlowRateSignal;
    }

    action def RegulateTemperature {
        in incomingFluid : PerfusionFluid;
        in targetTemperature : Temperature;
        out outgoingFluid : PerfusionFluid;
    }
    action def PumpFluid {
        in commandFlowRate : FlowRate;
        in incomingFluid : PerfusionFluid;
        out outgoingFluid : PerfusionFluid;
        out actualFlowRate : FlowRate;
    }
    action def ExchangeAcrossMembrane {
        in perfusate : PerfusionFluid;
        in tissueFluid : InterstitialFluid;
        out enrichedPerfusate : PerfusionFluid;
        out transmuralPressure : Pressure;
    }
    action def CollectTimedSample {
        in enrichedPerfusate : PerfusionFluid;
        in interval : TimeInterval;
        out sample : FluidSample;
    }
    action def MonitorPressureSafety {
        in currentPressure : Pressure;
        in safeThreshold : Pressure;
        out alarm : Boolean;
    }
    action def ControlFlowRate {
        in measuredFlowRate : FlowRate;
        in setPoint : FlowRate;
        out flowCommand : FlowRate;
    }

    part def SemiPermeableMembrane {
        attribute poreSize : Real;
        attribute surfaceArea : Real;
        attribute permeability : Real;
    }
    part def FluidReservoir {
        port fluidOut : FluidOutletPort;
        attribute capacity : Volume = 1000.0;
        attribute currentVolume : Volume = 1000.0;
    }
    part def TemperatureRegulator {
        port fluidIn : ~FluidOutletPort;
        port fluidOut : FluidOutletPort;
        attribute desiredTemperature : Temperature = 37.0;
        attribute currentTemperature : Temperature = 37.0;
        perform action regulateTemperature : RegulateTemperature {
            in incomingFluid = fluidIn.fluid;
            in targetTemperature = desiredTemperature;
            out outgoingFluid = fluidOut.fluid;
        }
    }
    part def MicrofluidicPump {
        port fluidIn : ~FluidOutletPort;
        port fluidOut : FluidOutletPort;
        port commandIn : ~FlowCommandPort;
        port flowSenseOut : FlowRateSignalPort;
        attribute flowRate : FlowRate;
        perform action pumpPerfusionFluid : PumpFluid {
            in commandFlowRate = commandIn.signal.desiredFlowRate;
            in incomingFluid = fluidIn.fluid;
            out outgoingFluid = fluidOut.fluid;
            out actualFlowRate = flowSenseOut.signal.value;
        }
    }
    part def MicroperfusionProbe {
        port perfusionIn : ~FluidOutletPort;
        port perfusionOut : FluidOutletPort;
        port pressureOut : PressureSignalPort;
        part membrane : SemiPermeableMembrane;
        item interstitialFluid : InterstitialFluid;
        perform action exchangeAcrossMembrane : ExchangeAcrossMembrane {
            in perfusate = perfusionIn.fluid;
            in tissueFluid = interstitialFluid;
            out enrichedPerfusate = perfusionOut.fluid;
            out transmuralPressure = pressureOut.signal.value;
        }
    }
    part def SampleCollector {
        port fluidIn : ~FluidOutletPort;
        port sampleOut : SampleOutletPort;
        attribute collectionInterval : TimeInterval = 10.0;
        attribute sampleCount : Integer = 0;
        perform action collectSample : CollectTimedSample {
            in enrichedPerfusate = fluidIn.fluid;
            in interval = collectionInterval;
            out sample = sampleOut.sample;
        }
    }
    part def FlowController {
        port flowSenseIn : ~FlowRateSignalPort;
        port commandOut : FlowCommandPort;
        attribute desiredFlowRate : FlowRate = 5.0;
        perform action controlFlow : ControlFlowRate {
            in measuredFlowRate = flowSenseIn.signal.value;
            in setPoint = desiredFlowRate;
            out flowCommand = commandOut.signal.desiredFlowRate;
        }
    }
    part def PressureMonitor {
        port pressureIn : ~PressureSignalPort;
        attribute safePressureThreshold : Pressure = 25.0;
        attribute measuredPressure : Pressure;
        attribute alarmTriggered : Boolean = measuredPressure > safePressureThreshold;
        perform action monitorPressure : MonitorPressureSafety {
            in currentPressure = pressureIn.signal.value;
            in safeThreshold = safePressureThreshold;
            out alarm = alarmTriggered;
        }
    }

    state def OFMOperation {
        initial state idle;
        state initializing;
        state perfusing;
        state errorState;

        transition from idle to initializing when true;
        transition from initializing to perfusing when temperatureRegulator.currentTemperature == temperatureRegulator.desiredTemperature;
        transition from perfusing to errorState when pressureMonitor.alarmTriggered;
        transition from errorState to idle when !pressureMonitor.alarmTriggered;
    }

    part def OFMSystem {
        port sampleOutPort : SampleOutletPort;

        part reservoir : FluidReservoir;
        part temperatureRegulator : TemperatureRegulator;
        part pump : MicrofluidicPump;
        part probe : MicroperfusionProbe;
        part sampleCollector : SampleCollector;
        part flowController : FlowController;
        part pressureMonitor : PressureMonitor;

        flow of PerfusionFluid
            from reservoir.fluidOut.fluid
            to temperatureRegulator.fluidIn.fluid;
        flow of PerfusionFluid
            from temperatureRegulator.fluidOut.fluid
            to pump.fluidIn.fluid;
        flow of PerfusionFluid
            from pump.fluidOut.fluid
            to probe.perfusionIn.fluid;
        flow of PerfusionFluid
            from probe.perfusionOut.fluid
            to sampleCollector.fluidIn.fluid;
        flow of FluidSample
            from sampleCollector.sampleOut.sample
            to sampleOutPort.sample;

        flow of FlowRateSignal
            from pump.flowSenseOut.signal
            to flowController.flowSenseIn.signal;
        flow of FlowCommandSignal
            from flowController.commandOut.signal
            to pump.commandIn.signal;
        flow of PressureSignal
            from probe.pressureOut.signal
            to pressureMonitor.pressureIn.signal;

        part ofmOperation : OFMOperation;
    }

    requirement def SafePressureRequirement {
        doc "The system shall maintain fluid pressure below the safe threshold to prevent tissue damage.";
    }
    requirement def ContinuousFlowRequirement {
        doc "The microfluidic pump shall maintain a constant positive flow rate throughout the perfusion session.";
    }
    requirement def PhysiologicalTemperatureRequirement {
        doc "The temperature regulator shall maintain perfusion fluid at physiological temperature.";
    }
    requirement def SampleCollectionRequirement {
        doc "The sample collector shall collect discrete samples at predefined time intervals.";
    }

    part ofmSystem : OFMSystem;

    requirement safePressure : SafePressureRequirement;
    requirement continuousFlow : ContinuousFlowRequirement;
    requirement physioTemp : PhysiologicalTemperatureRequirement;
    requirement sampleCollection : SampleCollectionRequirement;

    satisfy safePressure by ofmSystem;
    satisfy continuousFlow by ofmSystem;
    satisfy physioTemp by ofmSystem;
    satisfy sampleCollection by ofmSystem;
}
