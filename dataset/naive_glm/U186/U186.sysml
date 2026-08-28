package CharcotShowerHydrotherapySystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value def TemperatureValue :> Real {
        unit '°C';
    }
    value def PressureValue :> Real {
        unit 'bar';
    }
    value def FlowRateValue :> Real {
        unit 'L/min';
    }
    value def DurationValue :> Real {
        unit 's';
    }
    value def CycleCount :> Integer;
    value def PowerValue :> Real {
        unit 'W';
    }

    // ===== Item Types =====
    item def Water {
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }
    item def HotWater :> Water;
    item def ColdWater :> Water;
    item def MixedWater :> Water;

    // ===== Port Definitions =====
    port def WaterInPort {
        in item water : Water;
    }
    port def WaterOutPort {
        out item water : Water;
    }
    port def HotWaterOutPort {
        out item water : HotWater;
    }
    port def ColdWaterOutPort {
        out item water : ColdWater;
    }
    port def MixedWaterOutPort {
        out item water : MixedWater;
    }

    flow def WaterFlow {
        item : Water;
    }

    // ===== Control Signal Definitions =====
    item def ControlCommand {
        attribute commandId : String;
        attribute timestamp : String;
    }
    item def StartTherapyCommand :> ControlCommand;
    item def StopTherapyCommand :> ControlCommand;
    item def SetParametersCommand :> ControlCommand {
        attribute hotTemp : TemperatureValue;
        attribute coldTemp : TemperatureValue;
        attribute hotPhaseDuration : DurationValue;
        attribute coldPhaseDuration : DurationValue;
        attribute cycleCount : CycleCount;
    }
    item def ValvePositionCommand :> ControlCommand {
        attribute hotMixRatio : Real;
        attribute coldMixRatio : Real;
    }
    item def ShutoffCommand :> ControlCommand;
    item def SensorReading :> ControlCommand {
        attribute measuredTemperature : TemperatureValue;
        attribute measuredPressure : PressureValue;
    }
    item def FaultAlert :> ControlCommand {
        attribute faultCode : String;
        attribute description : String;
    }

    port def CommandOutPort {
        out item command : ControlCommand;
    }
    port def CommandInPort {
        in item command : ControlCommand;
    }
    port def SensorFeedbackPort {
        out item reading : SensorReading;
    }
    port def FaultPort {
        out item alert : FaultAlert;
    }

    // ===== Requirements =====
    requirement def TherapyDeliveryRequirement {
        subject : CharcotShowerSystem;
        objective {
            doc /* The system shall deliver contrast water therapy by alternating hot and cold water phases. */
        }
        require subject.hotPhaseTemperature == 40 [°C];
        require subject.coldPhaseTemperature == 15 [°C];
        require subject.maxSafeTemperature == 45 [°C];
    }

    requirement def SafetyRequirement {
        subject : CharcotShowerSystem;
        objective {
            doc /* The system shall automatically shut off water flow if output temperature exceeds the maximum safe limit. */
        }
        require subject.safetyShutoffValve.cutsFlow when subject.outputTemperature > 45 [°C];
    }

    requirement def PressureRegulationRequirement {
        subject : CharcotShowerSystem;
        objective {
            doc /* The system shall deliver water at a consistent therapeutic pressure. */
        }
        require subject.outputPressure >= 1.5 [bar] and subject.outputPressure <= 3.0 [bar];
    }

    requirement def CycleControlRequirement {
        subject : CharcotShowerSystem;
        objective {
            doc /* The system shall cycle through hot and cold phases for the prescribed number of cycles. */
        }
        require subject.completedCycles == subject.programmedCycles;
    }

    // ===== Part Definitions =====
    part def WaterSupply {
        port supplyOut : WaterOutPort;
        attribute supplyPressure : PressureValue = 2.0 [bar];
        attribute supplyTemperature : TemperatureValue = 20 [°C];
    }

    part def WaterSplitter {
        port inlet : WaterInPort;
        port hotPathOut : WaterOutPort;
        port coldPathOut : WaterOutPort;
        flow through inlet.water to hotPathOut.water;
        flow through inlet.water to coldPathOut.water;
    }

    part def WaterHeater {
        port waterIn : WaterInPort;
        port waterOut : HotWaterOutPort;
        port cmdIn : CommandInPort;
        attribute targetTemperature : TemperatureValue = 45 [°C];
        attribute heatingPower : PowerValue = 5000 [W];
        attribute currentTemperature : TemperatureValue;
        action def HeatWater {
            in inWater : Water;
            out outWater : HotWater;
        }
        action heat : HeatWater {
            in inWater = waterIn.water;
            out outWater = waterOut.water;
        }
    }

    part def WaterChiller {
        port waterIn : WaterInPort;
        port waterOut : ColdWaterOutPort;
        port cmdIn : CommandInPort;
        attribute targetTemperature : TemperatureValue = 10 [°C];
        attribute coolingPower : PowerValue = 4000 [W];
        attribute currentTemperature : TemperatureValue;
        action def ChillWater {
            in inWater : Water;
            out outWater : ColdWater;
        }
        action chill : ChillWater {
            in inWater = waterIn.water;
            out outWater = waterOut.water;
        }
    }

    part def MixingValveAssembly {
        port hotWaterIn : WaterInPort;
        port coldWaterIn : WaterInPort;
        port mixedWaterOut : MixedWaterOutPort;
        port cmdIn : CommandInPort;
        attribute hotMixRatio : Real = 0.5;
        attribute coldMixRatio : Real = 0.5;
        attribute currentMixedTemperature : TemperatureValue;
        action def MixWater {
            in hotWater : HotWater;
            in coldWater : ColdWater;
            in hotRatio : Real;
            in coldRatio : Real;
            out mixedWater : MixedWater;
        }
        action mix : MixWater {
            in hotWater = hotWaterIn.water;
            in coldWater = coldWaterIn.water;
            in hotRatio = hotMixRatio;
            in coldRatio = coldMixRatio;
            out mixedWater = mixedWaterOut.water;
        }
    }

    part def SafetyShutoffValve {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        port cmdIn : CommandInPort;
        port faultOut : FaultPort;
        attribute maxSafeTemperature : TemperatureValue = 45 [°C];
        attribute isOpen : Boolean = true;
        attribute cutsFlow : Boolean = false;
        action def MonitorTemperature {
            in inWater : Water;
            out safe : Boolean;
        }
        action monitor : MonitorTemperature {
            in inWater = waterIn.water;
            out safe = isOpen;
        }
        action def ShutoffFlow {
            out shutoff : Boolean;
        }
        action shutoff : ShutoffFlow {
            out shutoff = cutsFlow;
        }
    }

    part def PressureRegulator {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        port cmdIn : CommandInPort;
        attribute targetPressure : PressureValue = 2.0 [bar];
        attribute currentPressure : PressureValue;
        action def RegulatePressure {
            in inWater : Water;
            in target : PressureValue;
            out outWater : Water;
        }
        action regulate : RegulatePressure {
            in inWater = waterIn.water;
            in target = targetPressure;
            out outWater = waterOut.water;
        }
    }

    part def JetNozzleArray {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        attribute nozzleCount : Integer = 8;
        attribute sprayPattern : String = "Multi-stream";
        action def DeliverWater {
            in inWater : Water;
            out outWater : Water;
        }
        action deliver : DeliverWater {
            in inWater = waterIn.water;
            out outWater = waterOut.water;
        }
    }

    part def TemperaturePressureSensor {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        port feedbackOut : SensorFeedbackPort;
        attribute measuredTemperature : TemperatureValue;
        attribute measuredPressure : PressureValue;
        action def MeasureWater {
            in inWater : Water;
            out reading : SensorReading;
        }
        action measure : MeasureWater {
            in inWater = waterIn.water;
            out reading = feedbackOut.reading;
        }
    }

    part def OperatorInterface {
        port cmdOut : CommandOutPort;
        port feedbackIn : CommandInPort;
        attribute displayStatus : String;
        action def AcceptInput {
            out command : ControlCommand;
        }
        action acceptInput : AcceptInput {
            out command = cmdOut.command;
        }
    }

    part def TherapyControlUnit {
        port operatorCmdIn : CommandInPort;
        port heaterCmdOut : CommandOutPort;
        port chillerCmdOut : CommandOutPort;
        port valveCmdOut : CommandOutPort;
        port shutoffCmdOut : CommandOutPort;
        port regulatorCmdOut : CommandOutPort;
        port sensorFeedbackIn : CommandInPort;
        port faultIn : CommandInPort;
        port operatorFeedbackOut : CommandOutPort;

        attribute hotPhaseTemperature : TemperatureValue = 40 [°C];
        attribute coldPhaseTemperature : TemperatureValue = 15 [°C];
        attribute hotPhaseDuration : DurationValue = 180 [s];
        attribute coldPhaseDuration : DurationValue = 120 [s];
        attribute programmedCycles : CycleCount = 5;
        attribute completedCycles : CycleCount = 0;
        attribute currentPhase : String = "None";
        attribute outputTemperature : TemperatureValue;
        attribute outputPressure : PressureValue;

        state machine def TherapyStateMachine {
            entry; then Standby;

            state Standby;
            transition from Standby to Initializing
                on operatorCmdIn.command :> StartTherapyCommand;

            state Initializing {
                entry {
                    completedCycles = 0;
                    currentPhase = "Initializing";
                }
                do send SetParametersCommand(hotTemp = hotPhaseTemperature,
                    coldTemp = coldPhaseTemperature,
                    hotPhaseDuration = hotPhaseDuration,
                    coldPhaseDuration = coldPhaseDuration,
                    cycleCount = programmedCycles) to heaterCmdOut;
                do send SetParametersCommand(hotTemp = hotPhaseTemperature,
                    coldTemp = coldPhaseTemperature,
                    hotPhaseDuration = hotPhaseDuration,
                    coldPhaseDuration = coldPhaseDuration,
                    cycleCount = programmedCycles) to chillerCmdOut;
            }
            transition from Initializing to HotPhaseActive
                when completedCycles < programmedCycles;

            state HotPhaseActive {
                entry {
                    currentPhase = "Hot";
                    do send ValvePositionCommand(hotMixRatio = 1.0, coldMixRatio = 0.0) to valveCmdOut;
                }
                do wait hotPhaseDuration;
            }
            transition from HotPhaseActive to ColdPhaseActive
                when HotPhaseActive.done;

            state ColdPhaseActive {
                entry {
                    currentPhase = "Cold";
                    do send ValvePositionCommand(hotMixRatio = 0.0, coldMixRatio = 1.0) to valveCmdOut;
                }
                do wait coldPhaseDuration;
            }
            transition from ColdPhaseActive to HotPhaseActive
                when ColdPhaseActive.done and completedCycles + 1 < programmedCycles {
                completedCycles = completedCycles + 1;
            }
            transition from ColdPhaseActive to Standby
                when ColdPhaseActive.done and completedCycles + 1 >= programmedCycles {
                completedCycles = completedCycles + 1;
                currentPhase = "None";
            }

            state EmergencyShutdown {
                entry {
                    currentPhase = "Emergency";
                    do send ShutoffCommand() to shutoffCmdOut;
                }
            }
            transition from HotPhaseActive to EmergencyShutdown
                on faultIn.command :> FaultAlert;
            transition from ColdPhaseActive to EmergencyShutdown
                on faultIn.command :> FaultAlert;
            transition from Initializing to EmergencyShutdown
                on faultIn.command :> FaultAlert;
            transition from EmergencyShutdown to Standby
                on operatorCmdIn.command :> StopTherapyCommand;
        }

        part therapyStateMachine : TherapyStateMachine;

        action def ProcessSensorFeedback {
            in reading : SensorReading;
            out updateTemp : TemperatureValue;
            out updatePressure : PressureValue;
        }
        action processFeedback : ProcessSensorFeedback {
            in reading = sensorFeedbackIn.command :> SensorReading;
            out updateTemp = outputTemperature;
            out updatePressure = outputPressure;
        }
    }

    // ===== System Assembly =====
    part def CharcotShowerSystem {
        satisfy TherapyDeliveryRequirement;
        satisfy SafetyRequirement;
        satisfy PressureRegulationRequirement;
        satisfy CycleControlRequirement;

        attribute hotPhaseTemperature : TemperatureValue = 40 [°C];
        attribute coldPhaseTemperature : TemperatureValue = 15 [°C];
        attribute maxSafeTemperature : TemperatureValue = 45 [°C];
        attribute outputTemperature : TemperatureValue;
        attribute outputPressure : PressureValue;
        attribute programmedCycles : CycleCount = 5;
        attribute completedCycles : CycleCount = 0;
        attribute safetyShutoffValve : ref SafetyShutoffValve;

        part waterSupply : WaterSupply {
            attribute supplyPressure : PressureValue = 2.0 [bar];
        }
        part splitter : WaterSplitter;
        part heater : WaterHeater;
        part chiller : WaterChiller;
        part mixingValve : MixingValveAssembly;
        part safetyValve : SafetyShutoffValve;
        part pressureRegulator : PressureRegulator;
        part nozzleArray : JetNozzleArray;
        part sensor : TemperaturePressureSensor;
        part controlUnit : TherapyControlUnit;
        part operatorInterface : OperatorInterface;

        connection waterSupplyToSplitter : WaterFlow connect waterSupply.supplyOut to splitter.inlet;
        connection splitterToHeater : WaterFlow connect splitter.hotPathOut to heater.waterIn;
        connection splitterToChiller : WaterFlow connect splitter.coldPathOut to chiller.waterIn;
        connection heaterToMixingValve : WaterFlow connect heater.waterOut to mixingValve.hotWaterIn;
        connection chillerToMixingValve : WaterFlow connect chiller.waterOut to mixingValve.coldWaterIn;
        connection mixingValveToSafetyValve : WaterFlow connect mixingValve.mixedWaterOut to safetyValve.waterIn;
        connection safetyValveToRegulator : WaterFlow connect safetyValve.waterOut to pressureRegulator.waterIn;
        connection regulatorToSensor : WaterFlow connect pressureRegulator.waterOut to sensor.waterIn;
        connection sensorToNozzle : WaterFlow connect sensor.waterOut to nozzleArray.waterIn;

        connection operatorToControl : ControlCommand connect operatorInterface.cmdOut to controlUnit.operatorCmdIn;
        connection controlToOperator : ControlCommand connect controlUnit.operatorFeedbackOut to operatorInterface.feedbackIn;
        connection controlToHeater : ControlCommand connect controlUnit.heaterCmdOut to heater.cmdIn;
        connection controlToChiller : ControlCommand connect controlUnit.chillerCmdOut to chiller.cmdIn;
        connection controlToValve : ControlCommand connect controlUnit.valveCmdOut to mixingValve.cmdIn;
        connection controlToShutoff : ControlCommand connect controlUnit.shutoffCmdOut to safetyValve.cmdIn;
        connection controlToRegulator : ControlCommand connect controlUnit.regulatorCmdOut to pressureRegulator.cmdIn;
        connection sensorToControl : SensorReading connect sensor.feedbackOut to controlUnit.sensorFeedbackIn;
        connection faultToControl : FaultAlert connect safetyValve.faultOut to controlUnit.faultIn;
    }

    part charcotSystem : CharcotShowerSystem;
}
