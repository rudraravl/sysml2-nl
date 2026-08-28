package OFM_System {
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value type FlowRate specializes Real { unit "uL/min"; }
    value type PressureValue specializes Real { unit "kPa"; }
    value type TemperatureValue specializes Real { unit "degC"; }
    value type VolumeValue specializes Real { unit "uL"; }
    value type ConcentrationValue specializes Real { unit "umol/L"; }
    value type DurationValue specializes Real { unit "min"; }
    value type LengthValue specializes Real { unit "mm"; }
    value type PowerValue specializes Real { unit "mW"; }

    // ===== Item Definitions =====
    item def PerfusionFluid {
        attribute temperature : TemperatureValue;
        attribute volume : VolumeValue;
        attribute sterile : Boolean = true;
        attribute composition : String = "isotonic saline";
    }

    item def InterstitialFluid {
        attribute metaboliteConcentration : ConcentrationValue;
        attribute drugConcentration : ConcentrationValue;
        attribute pH : Real;
    }

    item def SampledFluid {
        attribute targetAnalyteConcentration : ConcentrationValue;
        attribute collectionTime : DurationValue;
        attribute sampleVolume : VolumeValue;
        attribute sourceFluid : PerfusionFluid;
    }

    item def Sample {
        attribute identifier : String;
        attribute fluid : SampledFluid;
        attribute collectionTimestamp : DurationValue;
        attribute sequenceNumber : Integer;
    }

    item def PressureReading {
        attribute value : PressureValue;
        attribute timestamp : DurationValue;
    }

    item def FlowRateReading {
        attribute value : FlowRate;
        attribute timestamp : DurationValue;
    }

    item def TemperatureReading {
        attribute value : TemperatureValue;
        attribute timestamp : DurationValue;
    }

    item def SystemCommand {
        attribute commandType : String;
        attribute parameter : Real;
        attribute timestamp : DurationValue;
    }

    item def SystemStatus {
        attribute statusCode : String;
        attribute errorCode : Integer;
        attribute timestamp : DurationValue;
    }

    // ===== Port Definitions =====
    port def FluidOutPort {
        out item : PerfusionFluid;
    }

    port def FluidInPort {
        in item : PerfusionFluid;
    }

    port def SampledFluidOutPort {
        out item : SampledFluid;
    }

    port def SampledFluidInPort {
        in item : SampledFluid;
    }

    port def FlowCommandPort {
        in attribute targetFlowRate : FlowRate;
        out attribute measuredFlowRate : FlowRate;
        out attribute flowStatus : String;
    }

    port def PressureSensorPort {
        out item : PressureReading;
    }

    port def PressureAlertPort {
        out attribute pressureExceeded : Boolean;
        out attribute currentPressure : PressureValue;
        out attribute shutdownRequested : Boolean;
    }

    port def TemperatureControlPort {
        in attribute setPoint : TemperatureValue;
        out item : TemperatureReading;
        out attribute heatingActive : Boolean;
    }

    port def SystemControlPort {
        in item : SystemCommand;
        out item : SystemStatus;
    }

    port def SampleOutputPort {
        out item : Sample;
    }

    // ===== Connection Definitions =====
    connection def FluidConnection {
        end source : FluidOutPort;
        end target : FluidInPort;
        item : PerfusionFluid;
    }

    connection def SampledFluidConnection {
        end source : SampledFluidOutPort;
        end target : SampledFluidInPort;
        item : SampledFluid;
    }

    connection def FlowControlConnection {
        end source : FlowCommandPort;
        end target : FlowCommandPort;
    }

    connection def PressureSensorConnection {
        end source : PressureSensorPort;
        end target : PressureSensorPort;
        item : PressureReading;
    }

    connection def PressureAlertConnection {
        end source : PressureAlertPort;
        end target : PressureAlertPort;
    }

    connection def TemperatureControlConnection {
        end source : TemperatureControlPort;
        end target : TemperatureControlPort;
        item : TemperatureReading;
    }

    connection def SystemControlConnection {
        end source : SystemControlPort;
        end target : SystemControlPort;
        item : SystemCommand;
        item : SystemStatus;
    }

    connection def SampleOutputConnection {
        end source : SampleOutputPort;
        end target : SampleOutputPort;
        item : Sample;
    }

    // ===== Requirement Definitions =====
    requirement def ContinuousMonitoringRequirement {
        doc "The OFM system shall perform continuous, real-time monitoring of biochemical substances in interstitial fluid for the duration of a perfusion session.";
        attribute minSessionDuration : DurationValue = 60.0;
        attribute maxSessionDuration : DurationValue = 480.0;
    }

    requirement def FlowRatePrecisionRequirement {
        doc "The microfluidic pump shall maintain a constant flow rate within +/- 2% of the set point.";
        attribute targetFlowRate : FlowRate = 1.0;
        attribute tolerancePercent : Real = 2.0;
    }

    requirement def TemperatureRegulationRequirement {
        doc "The temperature regulator shall maintain perfusion fluid at physiological temperature between 36.5 and 37.5 degC.";
        attribute minTemp : TemperatureValue = 36.5;
        attribute maxTemp : TemperatureValue = 37.5;
    }

    requirement def PressureSafetyRequirement {
        doc "The pressure monitor shall trigger a safety shutdown if fluid pressure exceeds 20 kPa to prevent tissue damage.";
        attribute maxSafePressure : PressureValue = 20.0;
        attribute warningThreshold : PressureValue = 15.0;
    }

    requirement def SampleCollectionRequirement {
        doc "The sample collector shall gather perfusate into distinct samples at predefined time intervals.";
        attribute collectionInterval : DurationValue = 10.0;
        attribute sampleVolume : VolumeValue = 10.0;
        attribute maxSampleCount : Integer = 100;
    }

    requirement def SterilityRequirement {
        doc "All fluid-path components shall maintain sterility of the perfusion fluid from reservoir to sample collector.";
    }

    requirement def ProbeMembraneRequirement {
        doc "The microperfusion probe shall incorporate a semi-permeable membrane that permits passive diffusion of target molecules from interstitial fluid into the perfusion stream.";
        attribute membraneLength : LengthValue = 4.0;
        attribute membraneDiameter : LengthValue = 0.2;
        attribute poreSize : LengthValue = 0.00002;
    }

    requirement def LongSessionReliabilityRequirement {
        doc "The system shall support continuous perfusion sessions of up to 8 hours without interruption, excluding consumable refill intervals.";
        attribute maxContinuousOperation : DurationValue = 480.0;
    }

    // ===== State Machine Definitions =====
    state def PumpOperationState {
        initial Off;
        state Off {
            entry action { currentFlowRate = 0.0; isRunning = false; }
        }
        state Starting {
            entry action { isRunning = true; }
        }
        state Running {
            entry action { currentFlowRate = nominalFlowRate; }
        }
        state Faulted {
            entry action { currentFlowRate = 0.0; isRunning = false; }
        }
        transition off_to_starting first Off if (targetFlowRateReceived > 0.0) to Starting;
        transition starting_to_running first Starting if (currentFlowRate >= nominalFlowRate * 0.98) to Running;
        transition running_to_off first Running if (targetFlowRateReceived == 0.0) to Off;
        transition off_to_faulted first Off if (pressureExceeded) to Faulted;
        transition starting_to_faulted first Starting if (pressureExceeded) to Faulted;
        transition running_to_faulted first Running if (pressureExceeded) to Faulted;
    }

    state def TemperatureRegulationState {
        initial Idle;
        state Idle;
        state Heating;
        state Stable;
        state Overtemp;
        transition idle_to_heating first Idle if (currentTemperature < setPoint - tolerance) to Heating;
        transition heating_to_stable first Heating if (currentTemperature >= setPoint - tolerance) to Stable;
        transition stable_to_heating first Stable if (currentTemperature < setPoint - tolerance) to Heating;
        transition stable_to_overtemp first Stable if (currentTemperature > 40.0) to Overtemp;
        transition overtemp_to_idle first Overtemp if (resetCommand) to Idle;
    }

    state def CollectorOperationState {
        initial Idle;
        state Idle {
            entry action { currentSampleCount = 0; elapsedTime = 0.0; }
        }
        state Collecting;
        state Advancing;
        state Full {
            entry action { collectorFull = true; }
        }
        transition idle_to_collecting first Idle if (startCollectionCommand) to Collecting;
        transition collecting_to_advancing first Collecting if (elapsedTime >= sampleInterval) to Advancing;
        transition advancing_to_collecting first Advancing if (advanceComplete) to Collecting;
        transition collecting_to_full first Collecting if (currentSampleCount >= maxSampleCount) to Full;
        transition full_to_idle first Full if (resetCommand) to Idle;
    }

    state def PressureMonitoringState {
        initial Normal;
        state Normal;
        state Warning;
        state Critical {
            entry action { shutdownRequested = true; }
        }
        transition normal_to_warning first Normal if (currentPressure > warningThreshold) to Warning;
        transition warning_to_normal first Warning if (currentPressure <= warningThreshold) to Normal;
        transition warning_to_critical first Warning if (currentPressure > maxSafePressure) to Critical;
        transition normal_to_critical first Normal if (currentPressure > maxSafePressure) to Critical;
        transition critical_to_normal first Critical if (currentPressure <= warningThreshold && acknowledgeCommand) to Normal;
    }

    state def SystemOperationState {
        initial PoweredOff;
        state PoweredOff {
            entry action { isOperational = false; }
        }
        state Initializing;
        state Ready;
        state PerfusionRunning;
        state Sampling;
        state SafetyShutdown {
            entry action { pump.currentFlowRate = 0.0; }
        }
        state ErrorRecovery;
        state Maintenance;
        transition poweroff_to_init first PoweredOff if (powerOnCommand) to Initializing;
        transition init_to_ready first Initializing if (initializationComplete) to Ready;
        transition ready_to_running first Ready if (startPerfusionCommand) to PerfusionRunning;
        transition running_to_sampling first PerfusionRunning if (sampleIntervalElapsed) to Sampling;
        transition sampling_to_running first Sampling if (sampleCollected) to PerfusionRunning;
        transition running_to_shutdown first PerfusionRunning if (pressureExceedsThreshold) to SafetyShutdown;
        transition sampling_to_shutdown first Sampling if (pressureExceedsThreshold) to SafetyShutdown;
        transition shutdown_to_error first SafetyShutdown to ErrorRecovery;
        transition error_to_maintenance first ErrorRecovery if (diagnosticComplete) to Maintenance;
        transition maintenance_to_ready first Maintenance if (resetComplete) to Ready;
        transition running_to_ready first PerfusionRunning if (stopPerfusionCommand) to Ready;
        transition ready_to_poweroff first Ready if (powerOffCommand) to PoweredOff;
    }

    // ===== Part Definitions =====
    part def FluidReservoir {
        attribute capacity : VolumeValue = 500.0;
        attribute currentVolume : VolumeValue = 500.0;
        attribute isSterile : Boolean = true;
        attribute fluidTemperature : TemperatureValue = 25.0;

        port fluidOut : FluidOutPort;
        port tempControl : TemperatureControlPort;
        port systemControl : SystemControlPort;

        action def DispenseFluid {
            in requestedVolume : VolumeValue;
            out fluid : PerfusionFluid;
        }

        action def RefillReservoir {
            in newVolume : VolumeValue;
            out refillComplete : Boolean;
        }

        action def UpdateTemperature {
            in reading : TemperatureReading;
            out updatedTemp : TemperatureValue;
        }
    }

    part def MicrofluidicPump {
        attribute nominalFlowRate : FlowRate = 1.0;
        attribute currentFlowRate : FlowRate = 0.0;
        attribute maxPressure : PressureValue = 25.0;
        attribute isRunning : Boolean = false;
        attribute targetFlowRateReceived : FlowRate = 0.0;
        attribute pressureExceeded : Boolean = false;

        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port flowCommand : FlowCommandPort;
        port pressureSensor : PressureSensorPort;
        port pressureAlert : PressureAlertPort;
        port systemControl : SystemControlPort;

        action def PumpFluid {
            in fluid : PerfusionFluid;
            in targetRate : FlowRate;
            out pumpedFluid : PerfusionFluid;
            out measuredRate : FlowRate;
            out pressureReading : PressureReading;
        }

        action def EmergencyStop {
            out stopped : Boolean;
        }

        exhibit PumpOperationState;
    }

    part def TemperatureRegulator {
        attribute setPoint : TemperatureValue = 37.0;
        attribute currentTemperature : TemperatureValue = 25.0;
        attribute heatingEnabled : Boolean = false;
        attribute tolerance : TemperatureValue = 0.5;
        attribute maxHeatingPower : PowerValue = 500.0;

        port tempControl : TemperatureControlPort;
        port systemControl : SystemControlPort;

        action def RegulateTemperature {
            in currentTemp : TemperatureValue;
            in targetTemp : TemperatureValue;
            out adjustedTemp : TemperatureValue;
            out heatingPower : PowerValue;
        }

        action def CalibrateSensor {
            out calibrationComplete : Boolean;
        }

        exhibit TemperatureRegulationState;
    }

    part def MicroperfusionProbe {
        attribute membraneLength : LengthValue = 4.0;
        attribute membraneDiameter : LengthValue = 0.2;
        attribute poreSize : LengthValue = 0.00002;
        attribute insertionDepth : LengthValue = 2.0;
        attribute isInserted : Boolean = false;
        attribute exchangeEfficiency : Real = 0.65;

        port fluidIn : FluidInPort;
        port fluidOut : SampledFluidOutPort;
        port systemControl : SystemControlPort;

        action def PerformExchange {
            in perfusate : PerfusionFluid;
            in interstitialFluid : InterstitialFluid;
            out enrichedFluid : SampledFluid;
        }

        action def InsertProbe {
            in targetDepth : LengthValue;
            out inserted : Boolean;
        }

        action def RemoveProbe {
            out removed : Boolean;
        }

        action def FlushProbe {
            in flushFluid : PerfusionFluid;
            out flushed : Boolean;
        }
    }

    part def SampleCollector {
        attribute sampleInterval : DurationValue = 10.0;
        attribute sampleVolume : VolumeValue = 10.0;
        attribute maxSampleCount : Integer = 100;
        attribute currentSampleCount : Integer = 0;
        attribute elapsedTime : DurationValue = 0.0;
        attribute collectorFull : Boolean = false;
        attribute samples : Sample[0..*];

        port fluidIn : SampledFluidInPort;
        port sampleOutput : SampleOutputPort;
        port systemControl : SystemControlPort;

        action def CollectSample {
            in fluid : SampledFluid;
            out sample : Sample;
        }

        action def AdvanceCollector {
            out advanceComplete : Boolean;
        }

        action def EjectSample {
            in sample : Sample;
            out ejectedSample : Sample;
        }

        action def ResetCollector {
            out resetComplete : Boolean;
        }

        exhibit CollectorOperationState;
    }

    part def FlowController {
        attribute targetFlowRate : FlowRate = 1.0;
        attribute measuredFlowRate : FlowRate = 0.0;
        attribute integralError : Real = 0.0;
        attribute proportionalGain : Real = 0.8;
        attribute integralGain : Real = 0.2;
        attribute tolerance : FlowRate = 0.02;

        port flowCommand : FlowCommandPort;
        port systemControl : SystemControlPort;

        action def ComputeFlowCorrection {
            in target : FlowRate;
            in measured : FlowRate;
            out correction : FlowRate;
        }

        action def MonitorFlowRate {
            in reading : FlowRateReading;
            out adjustedTarget : FlowRate;
        }

        action def CalibrateFlow {
            out calibrationComplete : Boolean;
        }
    }

    part def PressureMonitor {
        attribute maxSafePressure : PressureValue = 20.0;
        attribute warningThreshold : PressureValue = 15.0;
        attribute currentPressure : PressureValue = 0.0;
        attribute alarmActive : Boolean = false;
        attribute shutdownRequested : Boolean = false;
        attribute acknowledgeCommand : Boolean = false;

        port pressureSensor : PressureSensorPort;
        port pressureAlert : PressureAlertPort;
        port systemControl : SystemControlPort;

        action def MonitorPressure {
            in reading : PressureReading;
            out alarm : Boolean;
            out shutdownRequired : Boolean;
        }

        action def AcknowledgeAlarm {
            out acknowledged : Boolean;
        }

        action def CalibratePressureSensor {
            out calibrationComplete : Boolean;
        }

        exhibit PressureMonitoringState;
    }

    // ===== Top-Level System Definition =====
    part def OFMSystem {
        attribute systemId : String = "OFM-001";
        attribute sessionDuration : DurationValue = 0.0;
        attribute maxSessionDuration : DurationValue = 480.0;
        attribute isOperational : Boolean = false;
        attribute powerOnCommand : Boolean = false;
        attribute powerOffCommand : Boolean = false;
        attribute startPerfusionCommand : Boolean = false;
        attribute stopPerfusionCommand : Boolean = false;
        attribute initializationComplete : Boolean = false;
        attribute sampleIntervalElapsed : Boolean = false;
        attribute sampleCollected : Boolean = false;
        attribute pressureExceedsThreshold : Boolean = false;
        attribute diagnosticComplete : Boolean = false;
        attribute resetComplete : Boolean = false;

        part reservoir : FluidReservoir;
        part pump : MicrofluidicPump;
        part temperatureRegulator : TemperatureRegulator;
        part probe : MicroperfusionProbe;
        part sampleCollector : SampleCollector;
        part flowController : FlowController;
        part pressureMonitor : PressureMonitor;

        // Fluid path connections
        connection reservoirToPump : FluidConnection
            connect reservoir.fluidOut to pump.fluidIn;
        connection pumpToProbe : FluidConnection
            connect pump.fluidOut to probe.fluidIn;
        connection probeToCollector : SampledFluidConnection
            connect probe.fluidOut to sampleCollector.fluidIn;

        // Control connections
        connection flowControlLink : FlowControlConnection
            connect flowController.flowCommand to pump.flowCommand;
        connection pressureSensorLink : PressureSensorConnection
            connect pump.pressureSensor to pressureMonitor.pressureSensor;
        connection pressureAlertLink : PressureAlertConnection
            connect pressureMonitor.pressureAlert to pump.pressureAlert;
        connection temperatureControlLink : TemperatureControlConnection
            connect temperatureRegulator.tempControl to reservoir.tempControl;

        // System-level actions
        action def InitializeSystem {
            in components : String[1..*];
            out initialized : Boolean;
        }

        action def StartPerfusion {
            in targetFlowRate : FlowRate;
            in targetTemperature : TemperatureValue;
            out started : Boolean;
        }

        action def StopPerfusion {
            out stopped : Boolean;
        }

        action def EmergencyShutdown {
            doc "Immediately halt pump and isolate fluid path when pressure exceeds safe threshold.";
            out shutdownComplete : Boolean;
        }

        action def RunDiagnostics {
            out diagnosticResult : String;
        }

        action def PerformMaintenance {
            in maintenanceType : String;
            out maintenanceComplete : Boolean;
        }

        exhibit SystemOperationState;

        // Requirement satisfactions
        satisfy ContinuousMonitoringRequirement by self;
        satisfy FlowRatePrecisionRequirement by pump;
        satisfy TemperatureRegulationRequirement by temperatureRegulator;
        satisfy PressureSafetyRequirement by pressureMonitor;
        satisfy SampleCollectionRequirement by sampleCollector;
        satisfy SterilityRequirement by reservoir;
        satisfy ProbeMembraneRequirement by probe;
        satisfy LongSessionReliabilityRequirement by self;
    }
}
