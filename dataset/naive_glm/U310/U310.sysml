package MENS {
    import ISQ::*;
    import SI::*;
    import ScalarValues::*;

    // ============================================================
    // Value Definitions
    // ============================================================
    value def Microcurrent :> ElectricCurrent;
    value def PulseVoltage :> ElectricPotentialDifference;
    value def PulseFrequency :> Frequency;
    value def PulseDuration :> Time;
    value def TissueImpedance :> ElectricResistance;
    value def ChargeCapacity :> ElectricCharge;
    value def PowerLevel :> Power;

    // ============================================================
    // Enumerations
    // ============================================================
    enum def TherapyMode { continuous; burst; modulated; }
    enum def CommandType { start; stop; pause; resume; configure; }
    enum def ContactQuality { good; fair; poor; lost; }
    enum def AlertType { overCurrent; overVoltage; electrodeOff; lowBattery; selfTestFail; thermalFault; }
    enum def Severity { info; warning; critical; }
    enum def DeviceState { off; selfTest; ready; running; paused; fault; charging; }

    // ============================================================
    // Item Definitions
    // ============================================================
    item def ElectricalPower {
        attribute voltage : PulseVoltage;
        attribute current : Microcurrent;
    }

    item def TherapyParameters {
        attribute intensity : Microcurrent := 50e-6 [A];
        attribute frequency : PulseFrequency := 10 [Hz];
        attribute pulseWidth : PulseDuration := 200e-6 [s];
        attribute sessionDuration : PulseDuration := 1800 [s];
        attribute mode : TherapyMode := TherapyMode::continuous;
    }

    item def ControlCommand {
        attribute commandType : CommandType;
        attribute parameters : TherapyParameters;
    }

    item def PulseSignal {
        attribute amplitude : Microcurrent;
        attribute frequency : PulseFrequency;
        attribute width : PulseDuration;
        attribute mode : TherapyMode;
    }

    item def RegulatedPulse {
        attribute current : Microcurrent;
        attribute voltage : PulseVoltage;
        attribute frequency : PulseFrequency;
        attribute width : PulseDuration;
    }

    item def ImpedanceData {
        attribute value : TissueImpedance;
        attribute contactQuality : ContactQuality;
        attribute timestamp : PulseDuration;
    }

    item def SafetyAlert {
        attribute alertType : AlertType;
        attribute severity : Severity;
        attribute description : String;
    }

    item def StatusUpdate {
        attribute deviceState : DeviceState;
        attribute batteryLevel : Real;
        attribute therapyProgress : Real;
        attribute elapsedTime : PulseDuration;
        attribute remainingTime : PulseDuration;
        attribute deliveredCurrent : Microcurrent;
        attribute measuredImpedance : TissueImpedance;
    }

    // ============================================================
    // Port Definitions
    // ============================================================
    port def PowerOutPort { out power : ElectricalPower; }
    port def PowerInPort { in power : ElectricalPower; }

    port def ControlOutPort { out command : ControlCommand; }
    port def ControlInPort { in command : ControlCommand; }

    port def SignalOutPort { out signal : PulseSignal; }
    port def SignalInPort { in signal : PulseSignal; }

    port def RegulatedSignalOutPort { out signal : RegulatedPulse; }
    port def RegulatedSignalInPort { in signal : RegulatedPulse; }

    port def FeedbackOutPort { out feedback : ImpedanceData; }
    port def FeedbackInPort { in feedback : ImpedanceData; }

    port def AlarmOutPort { out alert : SafetyAlert; }
    port def AlarmInPort { in alert : SafetyAlert; }

    port def StatusOutPort { out status : StatusUpdate; }
    port def StatusInPort { in status : StatusUpdate; }

    port def ElectrodeSenseOutPort { out impedance : ImpedanceData; }
    port def ElectrodeSenseInPort { in impedance : ImpedanceData; }

    // ============================================================
    // Part Definitions
    // ============================================================

    part def BatteryModule {
        attribute capacity : ChargeCapacity := 14400 [C];
        attribute currentLevel : Real := 100;
        attribute nominalVoltage : PulseVoltage := 3.7 [V];
        attribute isCharging : Boolean := false;
        attribute minOperatingLevel : Real := 5;

        port powerOut : PowerOutPort;

        action def generatePower(out p : ElectricalPower) {
            p.voltage := nominalVoltage;
            p.current := 0.5 [A];
        }

        state batteryState {
            entry; then Operational;
            state Operational;
            state Low {
                entry { /* emit low battery warning */ }
            }
            state Depleted {
                entry { /* disable power output */ }
            }
            state Charging;
            transition Operational -> Low when currentLevel < 20;
            transition Low -> Depleted when currentLevel < minOperatingLevel;
            transition Operational -> Charging when isCharging;
            transition Low -> Charging when isCharging;
            transition Charging -> Operational when currentLevel >= 100;
        }
    }

    part def UserInterface {
        attribute configuredParameters : TherapyParameters;
        attribute displayBrightness : Real := 70;
        attribute buttonCount : Integer := 5;

        port powerIn : PowerInPort;
        port controlOut : ControlOutPort;
        port statusIn : StatusInPort;

        action def configureSession(in params : TherapyParameters) {
            configuredParameters := params;
        }

        action def startTherapy :> ControlOutPort {
            out command : ControlCommand;
        }

        action def stopTherapy :> ControlOutPort {
            out command : ControlCommand;
        }

        action def displayStatus(in status : StatusUpdate) {
            /* render status on display */
        }

        state uiState {
            entry; then Idle;
            state Idle;
            state Configuring;
            state Monitoring;
            transition Idle -> Configuring when configureSession;
            transition Configuring -> Idle when configuredParameters;
            transition Idle -> Monitoring when startTherapy;
            transition Monitoring -> Idle when stopTherapy;
        }
    }

    part def PulseGenerator {
        attribute activeParameters : TherapyParameters;
        attribute mode : TherapyMode := TherapyMode::continuous;
        attribute isGenerating : Boolean := false;
        attribute outputFrequency : PulseFrequency;
        attribute outputPulseWidth : PulseDuration;
        attribute outputAmplitude : Microcurrent;

        port powerIn : PowerInPort;
        port controlIn : ControlInPort;
        port signalOut : SignalOutPort;

        action def generatePulse(out sig : PulseSignal) {
            sig.amplitude := activeParameters.intensity;
            sig.frequency := activeParameters.frequency;
            sig.width := activeParameters.pulseWidth;
            sig.mode := activeParameters.mode;
        }

        action def applyCommand(in cmd : ControlCommand) {
            if cmd.commandType == CommandType::configure {
                activeParameters := cmd.parameters;
            }
            if cmd.commandType == CommandType::start {
                isGenerating := true;
            }
            if cmd.commandType == CommandType::stop {
                isGenerating := false;
            }
            if cmd.commandType == CommandType::pause {
                isGenerating := false;
            }
            if cmd.commandType == CommandType::resume {
                isGenerating := true;
            }
        }

        state generatorState {
            entry; then Idle;
            state Idle;
            state GeneratingContinuous;
            state GeneratingBurst;
            state GeneratingModulated;
            state Paused;
            transition Idle -> GeneratingContinuous when (isGenerating and mode == TherapyMode::continuous);
            transition Idle -> GeneratingBurst when (isGenerating and mode == TherapyMode::burst);
            transition Idle -> GeneratingModulated when (isGenerating and mode == TherapyMode::modulated);
            transition GeneratingContinuous -> Paused when !isGenerating;
            transition GeneratingBurst -> Paused when !isGenerating;
            transition GeneratingModulated -> Paused when !isGenerating;
            transition Paused -> GeneratingContinuous when (isGenerating and mode == TherapyMode::continuous);
            transition Paused -> GeneratingBurst when (isGenerating and mode == TherapyMode::burst);
            transition Paused -> GeneratingModulated when (isGenerating and mode == TherapyMode::modulated);
            transition GeneratingContinuous -> Idle when stop;
            transition GeneratingBurst -> Idle when stop;
            transition GeneratingModulated -> Idle when stop;
        }
    }

    part def CurrentRegulator {
        attribute targetCurrent : Microcurrent;
        attribute measuredCurrent : Microcurrent;
        attribute outputCurrent : Microcurrent;
        attribute outputVoltage : PulseVoltage;
        attribute tolerance : Real := 0.02;
        attribute isRegulating : Boolean := false;

        port powerIn : PowerInPort;
        port signalIn : SignalInPort;
        port signalOut : RegulatedSignalOutPort;
        port feedbackIn : FeedbackInPort;

        action def regulate(in inSignal : PulseSignal, in feedback : ImpedanceData, out outSignal : RegulatedPulse) {
            attribute impedance : TissueImpedance := feedback.value;
            attribute requiredVoltage : PulseVoltage := targetCurrent * impedance;
            outSignal.current := targetCurrent;
            outSignal.voltage := requiredVoltage;
            outSignal.frequency := inSignal.frequency;
            outSignal.width := inSignal.width;
        }

        state regulatorState {
            entry; then Passive;
            state Passive;
            state Regulating;
            state Adjusting;
            transition Passive -> Regulating when signalIn;
            transition Regulating -> Adjusting when feedbackIn;
            transition Adjusting -> Regulating when outputCurrent;
            transition Regulating -> Passive when !isRegulating;
        }
    }

    part def SafetyMonitor {
        attribute maxSafeCurrent : Microcurrent := 1000e-6 [A];
        attribute maxSafeVoltage : PulseVoltage := 30 [V];
        attribute faultDetected : Boolean := false;
        attribute activeAlert : SafetyAlert;

        port powerIn : PowerInPort;
        port senseIn : RegulatedSignalInPort;
        port alarmIn : AlarmInPort;
        port alarmOut : AlarmOutPort;

        action def checkOutput(in signal : RegulatedPulse) {
            if signal.current > maxSafeCurrent {
                activeAlert.alertType := AlertType::overCurrent;
                activeAlert.severity := Severity::critical;
                faultDetected := true;
            }
            if signal.voltage > maxSafeVoltage {
                activeAlert.alertType := AlertType::overVoltage;
                activeAlert.severity := Severity::critical;
                faultDetected := true;
            }
        }

        action def processExternalAlert(in alert : SafetyAlert) {
            if alert.severity == Severity::critical {
                faultDetected := true;
                activeAlert := alert;
            }
        }

        state safetyState {
            entry; then Monitoring;
            state Monitoring;
            state Fault {
                entry { /* disable all output */ }
            }
            transition Monitoring -> Fault when faultDetected;
            transition Fault -> Monitoring when !faultDetected;
        }
    }

    part def ImpedanceSensor {
        attribute measuredImpedance : TissueImpedance;
        attribute baselineImpedance : TissueImpedance := 500 [ohm];
        attribute lossThreshold : Real := 3.0;
        attribute samplingRate : PulseFrequency := 10 [Hz];
        attribute contactQuality : ContactQuality := ContactQuality::good;

        port powerIn : PowerInPort;
        port senseIn : ElectrodeSenseInPort;
        port feedbackOut : FeedbackOutPort;
        port alarmOut : AlarmOutPort;

        action def measureImpedance(in electrodeData : ImpedanceData, out feedback : ImpedanceData, out alert : SafetyAlert) {
            measuredImpedance := electrodeData.value;
            contactQuality := electrodeData.contactQuality;
            feedback := electrodeData;
            if contactQuality == ContactQuality::lost {
                alert.alertType := AlertType::electrodeOff;
                alert.severity := Severity::critical;
                alert.description := "Electrode contact lost";
            }
            if contactQuality == ContactQuality::poor {
                alert.alertType := AlertType::electrodeOff;
                alert.severity := Severity::warning;
                alert.description := "Poor electrode contact";
            }
        }

        action def evaluateContact(in impedance : TissueImpedance) : ContactQuality {
            if impedance > baselineImpedance * lossThreshold {
                return ContactQuality::lost;
            }
            if impedance > baselineImpedance * 2.0 {
                return ContactQuality::poor;
            }
            if impedance > baselineImpedance * 1.5 {
                return ContactQuality::fair;
            }
            return ContactQuality::good;
        }

        state sensorState {
            entry; then Idle;
            state Idle;
            state Measuring;
            state Alerting;
            transition Idle -> Measuring when senseIn;
            transition Measuring -> Idle when !senseIn;
            transition Measuring -> Alerting when contactQuality == ContactQuality::lost;
            transition Alerting -> Measuring when contactQuality != ContactQuality::lost;
        }
    }

    part def ElectrodeAssembly {
        attribute padCount : Integer := 2;
        attribute padArea : Real := 0.004 [m^2];
        attribute contactQuality : ContactQuality := ContactQuality::good;
        attribute isConnected : Boolean := false;

        port signalIn : RegulatedSignalInPort;
        port senseOut : ElectrodeSenseOutPort;

        action def deliverToPatient(in signal : RegulatedPulse) {
            /* conduct regulated pulse through skin-surface pads */
        }

        action def senseImpedance(out data : ImpedanceData) {
            data.value := 500 [ohm];
            data.contactQuality := contactQuality;
        }

        state electrodeState {
            entry; then Disconnected;
            state Disconnected;
            state Connected;
            state PoorContact;
            transition Disconnected -> Connected when isConnected;
            transition Connected -> Disconnected when !isConnected;
            transition Connected -> PoorContact when contactQuality == ContactQuality::poor;
            transition PoorContact -> Connected when contactQuality == ContactQuality::good;
            transition PoorContact -> Disconnected when contactQuality == ContactQuality::lost;
        }
    }

    // ============================================================
    // Top-Level Device
    // ============================================================
    part def MENSDevice {
        attribute deviceSerialNumber : String;
        attribute firmwareVersion : String := "1.0.0";
        attribute isPoweredOn : Boolean := false;

        part battery : BatteryModule;
        part ui : UserInterface;
        part generator : PulseGenerator;
        part regulator : CurrentRegulator;
        part safety : SafetyMonitor;
        part sensor : ImpedanceSensor;
        part electrodes : ElectrodeAssembly;

        // Power distribution
        connect battery.powerOut to ui.powerIn;
        connect battery.powerOut to generator.powerIn;
        connect battery.powerOut to regulator.powerIn;
        connect battery.powerOut to safety.powerIn;
        connect battery.powerOut to sensor.powerIn;

        // Control flow
        connect ui.controlOut to generator.controlIn;

        // Signal generation and regulation
        connect generator.signalOut to regulator.signalIn;
        connect regulator.signalOut to electrodes.signalIn;

        // Safety monitoring (parallel tap on regulated output)
        connect regulator.signalOut to safety.senseIn;

        // Impedance feedback loop
        connect electrodes.senseOut to sensor.senseIn;
        connect sensor.feedbackOut to regulator.feedbackIn;
        connect sensor.alarmOut to safety.alarmIn;

        // Status reporting
        connect safety.alarmOut to ui.statusIn;

        // Device-level state machine
        state deviceState {
            entry; then Off;

            state Off {
                entry { isPoweredOn := false; }
            }
            state SelfTest {
                entry {
                    /* verify battery, check electrode contact, validate circuitry */
                }
            }
            state Ready {
                entry { /* await user start command */ }
            }
            state Running {
                entry { /* therapy in progress */ }
            }
            state Paused;
            state Fault {
                entry { /* halt all output, display alert */ }
            }
            state Charging;

            transition Off -> SelfTest when powerButtonPressed;
            transition SelfTest -> Ready when selfTestPassed;
            transition SelfTest -> Fault when selfTestFailed;
            transition Ready -> Running when therapyStarted;
            transition Running -> Paused when pauseCommand;
            transition Paused -> Running when resumeCommand;
            transition Running -> Ready when therapyCompleted;
            transition Running -> Fault when safetyAlert;
            transition Paused -> Fault when safetyAlert;
            transition Ready -> Fault when safetyAlert;
            transition Fault -> Ready when faultCleared;
            transition Fault -> Off when powerButtonPressed;
            transition Off -> Charging when chargerConnected;
            transition Charging -> Off when chargerDisconnected;
        }

        action def performSelfTest() : Boolean {
            attribute batteryOk : Boolean := battery.currentLevel > battery.minOperatingLevel;
            attribute electrodesOk : Boolean := electrodes.contactQuality != ContactQuality::lost;
            attribute circuitryOk : Boolean := true;
            return batteryOk and electrodesOk and circuitryOk;
        }

        action def runTherapySession(in params : TherapyParameters) {
            attribute elapsed : PulseDuration := 0 [s];
            while elapsed < params.sessionDuration {
                /* generate, regulate, and deliver pulses */
                /* monitor impedance and safety */
                elapsed := elapsed + 1 [s];
            }
        }
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement def PowerRequirement {
        subject device : MENSDevice;
        objective {
            device.battery.capacity >= 14400 [C] and
            device.battery.nominalVoltage >= 3.6 [V]
        }
    }

    requirement def MicrocurrentSafetyRequirement {
        subject device : MENSDevice;
        objective {
            device.safety.maxSafeCurrent <= 1000e-6 [A] and
            device.safety.maxSafeVoltage <= 30 [V]
        }
    }

    requirement def ElectrodeContactRequirement {
        subject device : MENSDevice;
        objective {
            device.sensor.contactQuality != ContactQuality::lost implies device.deviceState != DeviceState::fault
        }
    }

    requirement def TherapyConfigurationRequirement {
        subject device : MENSDevice;
        attribute minIntensity : Microcurrent := 1e-6 [A];
        attribute maxIntensity : Microcurrent := 1000e-6 [A];
        attribute minFrequency : PulseFrequency := 0.5 [Hz];
        attribute maxFrequency : PulseFrequency := 1000 [Hz];
        attribute minPulseWidth : PulseDuration := 10e-6 [s];
        attribute maxPulseWidth : PulseDuration := 1000e-6 [s];
        objective {
            device.ui.configuredParameters.intensity >= minIntensity and
            device.ui.configuredParameters.intensity <= maxIntensity and
            device.ui.configuredParameters.frequency >= minFrequency and
            device.ui.configuredParameters.frequency <= maxFrequency and
            device.ui.configuredParameters.pulseWidth >= minPulseWidth and
            device.ui.configuredParameters.pulseWidth <= maxPulseWidth
        }
    }

    requirement def FaultResponseRequirement {
        subject device : MENSDevice;
        objective {
            device.deviceState == DeviceState::running and device.sensor.contactQuality == ContactQuality::lost
            implies device.deviceState == DeviceState::fault
        }
    }

    requirement def PortabilityRequirement {
        subject device : MENSDevice;
        attribute maxMass : Real := 0.3 [kg];
        attribute maxVolume : Real := 0.0002 [m^3];
        objective {
            /* device mass and volume within portable limits */
        }
    }

    requirement def ContinuousOperationRequirement {
        subject device : MENSDevice;
        attribute minOperationTime : PulseDuration := 14400 [s];
        objective {
            device.battery.capacity / 0.5 [A] >= minOperationTime
        }
    }

    // ============================================================
    // Requirement Satisfaction
    // ============================================================
    satisfaction powerSatisfaction : PowerRequirement {
        subject device : MENSDevice;
    }
    satisfaction safetySatisfaction : MicrocurrentSafetyRequirement {
        subject device : MENSDevice;
    }
    satisfaction contactSatisfaction : ElectrodeContactRequirement {
        subject device : MENSDevice;
    }
    satisfaction configSatisfaction : TherapyConfigurationRequirement {
        subject device : MENSDevice;
    }
    satisfaction faultSatisfaction : FaultResponseRequirement {
        subject device : MENSDevice;
    }
    satisfaction portabilitySatisfaction : PortabilityRequirement {
        subject device : MENSDevice;
    }
    satisfaction operationSatisfaction : ContinuousOperationRequirement {
        subject device : MENSDevice;
    }
}
