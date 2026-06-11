package PulseDuplicatorModel {
    import ScalarValues::*;
    import ISQ::*;

    attribute def PressureValue {
        :>> quantityKind = ISQ::pressure;
        :>> unit = SI::pascal;
    }

    attribute def FlowRateValue {
        :>> quantityKind = ISQ::volumeFlowRate;
        :>> unit = SI::cubicMetrePerSecond;
    }

    attribute def VolumeValue {
        :>> quantityKind = ISQ::volume;
        :>> unit = SI::litre;
    }

    attribute def FrequencyValue {
        :>> quantityKind = ISQ::frequency;
        :>> unit = SI::hertz;
    }

    attribute def TemperatureValue {
        :>> quantityKind = ISQ::thermodynamicTemperature;
        :>> unit = SI::kelvin;
    }

    attribute def StrokeVolumeValue {
        :>> quantityKind = ISQ::volume;
        :>> unit = SI::millilitre;
    }

    item def TestFluid {
        attribute density : Real;
        attribute viscosity : Real;
        attribute temperature : TemperatureValue;
    }

    item def PressureWaveform {
        attribute systolicPressure : PressureValue;
        attribute diastolicPressure : PressureValue;
        attribute meanPressure : PressureValue;
        attribute cycleFrequency : FrequencyValue;
    }

    item def FlowWaveform {
        attribute peakFlowRate : FlowRateValue;
        attribute meanFlowRate : FlowRateValue;
        attribute forwardStrokeVolume : StrokeVolumeValue;
        attribute regurgitantVolume : StrokeVolumeValue;
    }

    port def FluidPort {
        inout fluid : TestFluid;
        inout pressure : PressureWaveform;
        inout flow : FlowWaveform;
    }

    port def SignalPort {
        inout command : Real;
        inout measurement : Real;
    }

    action def GeneratePulsatileFlow {
        in targetHeartRate : FrequencyValue;
        in targetStrokeVolume : StrokeVolumeValue;
        in fluidIn : TestFluid;
        out fluidOut : TestFluid;
        out pressureOut : PressureWaveform;
        out flowOut : FlowWaveform;
    }

    action def MeasureHemodynamics {
        in pressureIn : PressureWaveform;
        in flowIn : FlowWaveform;
        out measuredPressure : PressureWaveform;
        out measuredFlow : FlowWaveform;
    }

    action def RegulatePulseCycle {
        in measuredPressure : PressureWaveform;
        in measuredFlow : FlowWaveform;
        in targetPressure : PressureValue;
        in targetFlow : FlowRateValue;
        out actuatorCommand : Real;
    }

    state def PulseDuplicatorOperatingState {
        entry action initializeSystem;
        state Idle;
        state Priming;
        state Calibrating;
        state Running;
        state Fault;
        state Shutdown;

        transition first Idle;
        transition Idle_to_Priming
            first Idle
            then Priming;

        transition Priming_to_Calibrating
            first Priming
            then Calibrating;

        transition Calibrating_to_Running
            first Calibrating
            then Running;

        transition Running_to_Fault
            first Running
            then Fault;

        transition Fault_to_Shutdown
            first Fault
            then Shutdown;
    }

    part def ComplianceChamber {
        attribute chamberVolume : VolumeValue = 2.0 [SI::litre];
        attribute nominalCompliance : Real = 0.0012;
        port inlet : FluidPort;
        port outlet : FluidPort;
    }

    part def ResistanceElement {
        attribute adjustableResistance : Real = 1.0;
        port inlet : FluidPort;
        port outlet : FluidPort;
    }

    part def TestSection {
        attribute transparentVolume : VolumeValue = 0.35 [SI::litre];
        attribute valveMountDiameter : Real = 25.0;
        port inlet : FluidPort;
        port outlet : FluidPort;
    }

    part def WorkingFluidReservoir {
        attribute capacity : VolumeValue = 8.0 [SI::litre];
        attribute fillVolume : VolumeValue = 6.0 [SI::litre];
        port outlet : FluidPort;
        port returnInlet : FluidPort;
    }

    part def PulsatilePump {
        attribute maximumStrokeVolume : StrokeVolumeValue = 120.0 [SI::millilitre];
        attribute operatingHeartRate : FrequencyValue = 1.2 [SI::hertz];
        attribute nominalStrokeVolume : StrokeVolumeValue = 70.0 [SI::millilitre];
        port suction : FluidPort;
        port discharge : FluidPort;
        port commandPort : SignalPort;

        perform action generatePulse : GeneratePulsatileFlow;
    }

    part def SensorModule {
        port pressureTap : FluidPort;
        port flowTap : FluidPort;
        port signalOut : SignalPort;

        perform action measure : MeasureHemodynamics;
    }

    part def Controller {
        attribute targetHeartRate : FrequencyValue = 1.2 [SI::hertz];
        attribute targetStrokeVolume : StrokeVolumeValue = 70.0 [SI::millilitre];
        attribute targetMeanPressure : PressureValue = 13332.0 [SI::pascal];
        port sensorInput : SignalPort;
        port pumpCommand : SignalPort;

        perform action regulate : RegulatePulseCycle;
    }

    part def PulseDuplicator {
        attribute primaryFunction : String =
            "Generate repeatable physiologic pulsatile pressure and flow waveforms through a controlled test section for evaluating cardiovascular devices.";

        part reservoir : WorkingFluidReservoir;
        part pump : PulsatilePump;
        part aorticCompliance : ComplianceChamber;
        part peripheralResistance : ResistanceElement;
        part deviceTestSection : TestSection;
        part sensors : SensorModule;
        part controller : Controller;

        port testLoopInlet : FluidPort;
        port testLoopOutlet : FluidPort;

        connect reservoir.outlet to pump.suction;
        connect pump.discharge to aorticCompliance.inlet;
        connect aorticCompliance.outlet to deviceTestSection.inlet;
        connect deviceTestSection.outlet to peripheralResistance.inlet;
        connect peripheralResistance.outlet to reservoir.returnInlet;

        connect deviceTestSection.inlet to sensors.pressureTap;
        connect deviceTestSection.outlet to sensors.flowTap;
        connect sensors.signalOut to controller.sensorInput;
        connect controller.pumpCommand to pump.commandPort;

        connect testLoopInlet to deviceTestSection.inlet;
        connect testLoopOutlet to deviceTestSection.outlet;

        exhibit state operatingState : PulseDuplicatorOperatingState;
    }

    requirement def PrimaryFunctionRequirement {
        subject duplicator : PulseDuplicator;
        doc /* The pulse duplicator shall generate repeatable pulsatile flow and pressure conditions representative of cardiovascular circulation at a controlled heart rate and stroke volume. */
        require constraint {
            duplicator.pump.operatingHeartRate >= 0.5 [SI::hertz] and
            duplicator.pump.operatingHeartRate <= 3.0 [SI::hertz] and
            duplicator.pump.nominalStrokeVolume >= 20.0 [SI::millilitre] and
            duplicator.pump.nominalStrokeVolume <= 120.0 [SI::millilitre]
        }
    }

    requirement def ClosedLoopControlRequirement {
        subject duplicator : PulseDuplicator;
        doc /* The controller shall adjust pump actuation using pressure and flow measurements from the test section to maintain target waveform conditions. */
        require constraint {
            duplicator.controller.targetMeanPressure > 0.0 [SI::pascal]
        }
    }

    requirement def FluidContainmentRequirement {
        subject duplicator : PulseDuplicator;
        doc /* The fluid loop shall provide a continuous closed hydraulic path from reservoir through pump, compliance chamber, test section, resistance element, and back to reservoir. */
        require constraint {
            duplicator.reservoir.fillVolume <= duplicator.reservoir.capacity
        }
    }

    requirement def TestSectionAccessibilityRequirement {
        subject duplicator : PulseDuplicator;
        doc /* The test section shall provide a defined valve or device mounting region with inlet and outlet ports for hemodynamic measurement. */
        require constraint {
            duplicator.deviceTestSection.transparentVolume > 0.0 [SI::litre]
        }
    }

    part pulseDuplicatorSystem : PulseDuplicator;

    satisfy PrimaryFunctionRequirement by pulseDuplicatorSystem;
    satisfy ClosedLoopControlRequirement by pulseDuplicatorSystem;
    satisfy FluidContainmentRequirement by pulseDuplicatorSystem;
    satisfy TestSectionAccessibilityRequirement by pulseDuplicatorSystem;
}