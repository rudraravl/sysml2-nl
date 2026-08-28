package AC_Power_Distribution_System {
    private import ScalarValues::*;

    unit kV;
    unit A;
    unit Hz;
    unit MW;
    unit ms;

    value type Voltage :> Real { unit kV; }
    value type Current :> Real { unit A; }
    value type Frequency :> Real { unit Hz; }
    value type Power :> Real { unit MW; }
    value type Time :> Real { unit ms; }

    item def AC_Power {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute frequency : Frequency;
        attribute power : Power;
    }

    item def TripSignal;

    port def PowerOut {
        out power : AC_Power;
    }
    port def PowerIn {
        in power : AC_Power;
    }
    port def MonitorOut {
        out voltage : Voltage;
        out current : Current;
        out frequency : Frequency;
    }
    port def MonitorIn {
        in voltage : Voltage;
        in current : Current;
        in frequency : Frequency;
    }
    port def TripOut {
        out trip : TripSignal;
    }
    port def TripIn {
        in trip : TripSignal;
    }
    port def ControlOut {
        out voltageSetpoint : Voltage;
        out frequencySetpoint : Frequency;
    }
    port def ControlIn {
        in voltageSetpoint : Voltage;
        in frequencySetpoint : Frequency;
    }

    part def PowerGenerator {
        attribute nominalVoltage : Voltage = 13.8;
        attribute nominalFrequency : Frequency = 60.0;
        port powerOut : PowerOut;
        port controlIn : ControlIn;
    }

    part def StepUpTransformer {
        attribute turnsRatio : Real = 10.0;
        port powerIn : PowerIn;
        port powerOut : PowerOut;
    }

    part def CircuitBreaker {
        attribute isClosed : Boolean = true;
        port powerIn : PowerIn;
        port powerOut : PowerOut;
        port tripIn : TripIn;

        state machine {
            state Closed;
            state Open;
            transition Closed to Open when tripIn.trip;
        }
    }

    part def TransmissionLine {
        port powerIn : PowerIn;
        port powerOut : PowerOut;
        port monitorOut : MonitorOut;
    }

    part def ProtectionRelay {
        attribute overVoltageThreshold : Voltage = 165.6;
        attribute underVoltageThreshold : Voltage = 110.4;
        attribute maxCurrent : Current = 1000.0;
        port monitorIn : MonitorIn;
        port tripOut : TripOut;

        state machine {
            state Monitoring;
            state Tripped;
            transition Monitoring to Tripped
                if monitorIn.voltage > overVoltageThreshold
                or monitorIn.voltage < underVoltageThreshold
                or monitorIn.current > maxCurrent;
            transition Tripped to Monitoring
                if monitorIn.voltage <= overVoltageThreshold
                and monitorIn.voltage >= underVoltageThreshold
                and monitorIn.current <= maxCurrent;
        }
    }

    part def StepDownTransformer {
        attribute turnsRatio : Real = 0.1;
        port powerIn : PowerIn;
        port powerOut : PowerOut;
    }

    part def VoltageRegulator {
        attribute nominalVoltage : Voltage = 13.8;
        port powerIn : PowerIn;
        port powerOut : PowerOut;
    }

    part def DistributionLoad {
        attribute demandPower : Power = 10.0;
        port powerIn : PowerIn;
        port monitorOut : MonitorOut;
    }

    part def GridControlSystem {
        attribute nominalVoltage : Voltage = 13.8;
        attribute nominalFrequency : Frequency = 60.0;
        attribute voltageTolerance : Real = 0.05;
        attribute frequencyTolerance : Frequency = 0.5;
        port monitorIn : MonitorIn;
        port controlOut : ControlOut;

        action def MonitorGrid {
            out voltage : Voltage;
            out frequency : Frequency;
            out isOutOfRange : Boolean;
        }

        action def LoadBalancing {
            in voltage : Voltage;
            in frequency : Frequency;
            out adjustedVoltage : Voltage;
            out adjustedFrequency : Frequency;
            out isStable : Boolean;
        }

        state machine {
            state NormalOperation {
                entry action monitor : MonitorGrid;
            }
            state LoadBalancing {
                entry action balance : LoadBalancing;
            }
            transition NormalOperation to LoadBalancing
                if monitorIn.voltage > nominalVoltage * (1 + voltageTolerance)
                or monitorIn.voltage < nominalVoltage * (1 - voltageTolerance)
                or monitorIn.frequency > nominalFrequency + frequencyTolerance
                or monitorIn.frequency < nominalFrequency - frequencyTolerance;
            transition LoadBalancing to NormalOperation
                if monitorIn.voltage <= nominalVoltage * (1 + voltageTolerance)
                and monitorIn.voltage >= nominalVoltage * (1 - voltageTolerance)
                and monitorIn.frequency <= nominalFrequency + frequencyTolerance
                and monitorIn.frequency >= nominalFrequency - frequencyTolerance;
        }
    }

    part def ACPowerDistributionSystem {
        part generator : PowerGenerator;
        part stepUpTransformer : StepUpTransformer;
        part circuitBreaker : CircuitBreaker;
        part transmissionLine : TransmissionLine;
        part protectionRelay : ProtectionRelay;
        part stepDownTransformer : StepDownTransformer;
        part voltageRegulator : VoltageRegulator;
        part distributionLoad : DistributionLoad;
        part gridController : GridControlSystem;

        flow powerFlow1 of AC_Power
            from generator.powerOut.power to stepUpTransformer.powerIn.power;
        flow powerFlow2 of AC_Power
            from stepUpTransformer.powerOut.power to circuitBreaker.powerIn.power;
        flow powerFlow3 of AC_Power
            from circuitBreaker.powerOut.power to transmissionLine.powerIn.power;
        flow powerFlow4 of AC_Power
            from transmissionLine.powerOut.power to stepDownTransformer.powerIn.power;
        flow powerFlow5 of AC_Power
            from stepDownTransformer.powerOut.power to voltageRegulator.powerIn.power;
        flow powerFlow6 of AC_Power
            from voltageRegulator.powerOut.power to distributionLoad.powerIn.power;

        flow monitorFlowV of Voltage
            from transmissionLine.monitorOut.voltage to protectionRelay.monitorIn.voltage;
        flow monitorFlowI of Current
            from transmissionLine.monitorOut.current to protectionRelay.monitorIn.current;
        flow monitorFlowF of Frequency
            from transmissionLine.monitorOut.frequency to protectionRelay.monitorIn.frequency;

        flow tripFlow of TripSignal
            from protectionRelay.tripOut.trip to circuitBreaker.tripIn.trip;

        flow loadMonitorV of Voltage
            from distributionLoad.monitorOut.voltage to gridController.monitorIn.voltage;
        flow loadMonitorF of Frequency
            from distributionLoad.monitorOut.frequency to gridController.monitorIn.frequency;

        flow controlFlowV of Voltage
            from gridController.controlOut.voltageSetpoint to generator.controlIn.voltageSetpoint;
        flow controlFlowF of Frequency
            from gridController.controlOut.frequencySetpoint to generator.controlIn.frequencySetpoint;
    }

    requirement def VoltageStabilityRequirement {
        doc /* The voltage at the distribution load shall be maintained at 13.8 kV +/-5% under normal operating conditions. */
        attribute nominalVoltage : Voltage = 13.8;
        attribute tolerance : Real = 0.05;
    }

    requirement def FrequencyStabilityRequirement {
        doc /* The system frequency shall be maintained at 60 Hz +/-0.5 Hz under all operating conditions. */
        attribute nominalFrequency : Frequency = 60.0;
        attribute tolerance : Frequency = 0.5;
    }

    requirement def FaultProtectionRequirement {
        doc /* The protection relay shall detect fault conditions and issue a trip command within 50 milliseconds. */
        attribute maxTripTime : Time = 50.0;
    }

    requirement def PowerQualityRequirement {
        doc /* Total harmonic distortion of delivered power shall not exceed 5%. */
        attribute maxTHD : Real = 5.0;
    }

    requirement def TransmissionEfficiencyRequirement {
        doc /* Power transmission losses across the transmission line shall not exceed 3% of generated power. */
        attribute maxLossPercentage : Real = 3.0;
    }

    part acPowerSystem : ACPowerDistributionSystem;

    satisfy VoltageStabilityRequirement by acPowerSystem;
    satisfy FrequencyStabilityRequirement by acPowerSystem;
    satisfy FaultProtectionRequirement by acPowerSystem;
    satisfy PowerQualityRequirement by acPowerSystem;
    satisfy TransmissionEfficiencyRequirement by acPowerSystem;
}
