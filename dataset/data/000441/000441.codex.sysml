package DefibrillationSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Voltage :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def Current :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def Energy :> ISQ::energy {
        unit = SI::joule;
    }

    attribute def Time :> ISQ::duration {
        unit = SI::second;
    }

    attribute def Impedance :> ISQ::electricResistance {
        unit = SI::ohm;
    }

    attribute def HeartRate :> ISQ::frequency {
        unit = SI::hertz;
    }

    attribute def BatteryCharge :> ScalarValues::Real {
        unit = SI::percent;
    }

    enum def ShockMode {
        manual;
        advisory;
        automated;
    }

    enum def PatientRhythm {
        unknown;
        sinus;
        ventricularFibrillation;
        pulselessVentricularTachycardia;
        asystole;
        artifact;
    }

    enum def DeviceReadiness {
        unavailable;
        standby;
        analyzing;
        charging;
        armed;
        deliveringShock;
        postShock;
        faulted;
    }

    item def ECGSignal {
        attribute sampleRate : HeartRate;
        attribute amplitude_mV : Real;
        attribute rhythm : PatientRhythm;
        attribute artifactPresent : Boolean;
    }

    item def TherapyPulse {
        attribute selectedEnergy : Energy;
        attribute peakVoltage : Voltage;
        attribute peakCurrent : Current;
        attribute deliveredEnergy : Energy;
        attribute pulseDuration : Time;
        attribute biphasic : Boolean;
    }

    item def OperatorCommand {
        attribute powerOn : Boolean;
        attribute analyze : Boolean;
        attribute charge : Boolean;
        attribute shock : Boolean;
        attribute disarm : Boolean;
        attribute energySetting : Energy;
        attribute mode : ShockMode;
    }

    item def VoicePrompt {
        attribute messageCode : String;
        attribute priority : Integer;
    }

    item def StatusMessage {
        attribute readiness : DeviceReadiness;
        attribute batteryPercent : BatteryCharge;
        attribute faultCode : String;
        attribute shockAdvised : Boolean;
    }

    item def PatientContact {
        attribute padAttached : Boolean;
        attribute measuredImpedance : Impedance;
        attribute motionDetected : Boolean;
    }

    port def ECGAcquisitionPort {
        in item contact : PatientContact;
        in item ecg : ECGSignal;
    }

    port def TherapyOutputPort {
        out item pulse : TherapyPulse;
        in item contact : PatientContact;
    }

    port def OperatorInterfacePort {
        in item command : OperatorCommand;
        out item prompt : VoicePrompt;
        out item status : StatusMessage;
    }

    port def PowerPort {
        out attribute supplyVoltage : Voltage;
        out attribute availableCharge : BatteryCharge;
    }

    part def ElectrodePadSet {
        port patientSense : ECGAcquisitionPort;
        port therapyPath : TherapyOutputPort;

        attribute attached : Boolean;
        attribute impedance : Impedance;
        attribute maximumSafeImpedance : Impedance = 200 [SI::ohm];
        attribute minimumSafeImpedance : Impedance = 25 [SI::ohm];

        action attachToPatient {
            in item contact : PatientContact;
            out attribute attachedNow : Boolean;
            attachedNow = contact.padAttached;
        }
    }

    part def ECGAnalyzer {
        port acquisition : ECGAcquisitionPort;

        attribute currentRhythm : PatientRhythm = PatientRhythm::unknown;
        attribute shockableDetected : Boolean = false;
        attribute minimumAnalysisTime : Time = 6 [SI::second];
        attribute maximumAnalysisTime : Time = 12 [SI::second];

        action analyzeRhythm {
            in item signal : ECGSignal;
            out attribute rhythm : PatientRhythm;
            out attribute shockAdvised : Boolean;

            rhythm = signal.rhythm;
            shockAdvised =
                signal.artifactPresent == false and
                (signal.rhythm == PatientRhythm::ventricularFibrillation or
                 signal.rhythm == PatientRhythm::pulselessVentricularTachycardia);
        }
    }

    part def EnergyStorageModule {
        port power : PowerPort;

        attribute capacitorVoltage : Voltage = 0 [SI::volt];
        attribute storedEnergy : Energy = 0 [SI::joule];
        attribute maximumEnergy : Energy = 360 [SI::joule];
        attribute chargeTimeLimit : Time = 10 [SI::second];

        action chargeCapacitor {
            in attribute requestedEnergy : Energy;
            out attribute ready : Boolean;
            out attribute chargedEnergy : Energy;

            chargedEnergy = requestedEnergy;
            ready = requestedEnergy <= maximumEnergy;
        }

        action dischargeCapacitor {
            in attribute loadImpedance : Impedance;
            in attribute commandedEnergy : Energy;
            out item therapy : TherapyPulse;

            therapy.selectedEnergy = commandedEnergy;
            therapy.deliveredEnergy = commandedEnergy;
            therapy.peakVoltage = 1800 [SI::volt];
            therapy.peakCurrent = 45 [SI::ampere];
            therapy.pulseDuration = 0.010 [SI::second];
            therapy.biphasic = true;
        }
    }

    part def ShockController {
        port operatorInterface : OperatorInterfacePort;
        port therapyOutput : TherapyOutputPort;

        attribute mode : ShockMode = ShockMode::advisory;
        attribute selectedEnergy : Energy = 200 [SI::joule];
        attribute shockEnabled : Boolean = false;
        attribute shockAdvised : Boolean = false;
        attribute lastDeliveredEnergy : Energy = 0 [SI::joule];

        action selectEnergy {
            in item command : OperatorCommand;
            out attribute energy : Energy;

            energy = command.energySetting;
        }

        action authorizeShock {
            in attribute advised : Boolean;
            in item command : OperatorCommand;
            out attribute authorized : Boolean;

            authorized =
                (mode == ShockMode::manual and command.shock) or
                (mode == ShockMode::advisory and advised and command.shock) or
                (mode == ShockMode::automated and advised);
        }
    }

    part def UserInterface {
        port controls : OperatorInterfacePort;

        attribute displayReadiness : DeviceReadiness = DeviceReadiness::standby;
        attribute audiblePromptEnabled : Boolean = true;

        action issuePrompt {
            in attribute readiness : DeviceReadiness;
            in attribute advised : Boolean;
            out item prompt : VoicePrompt;

            prompt.priority = 1;
            prompt.messageCode =
                if advised then "SHOCK_ADVISED" else "NO_SHOCK_ADVISED";
        }

        action updateStatus {
            in attribute readiness : DeviceReadiness;
            in attribute battery : BatteryCharge;
            in attribute advised : Boolean;
            out item status : StatusMessage;

            status.readiness = readiness;
            status.batteryPercent = battery;
            status.shockAdvised = advised;
            status.faultCode = "";
        }
    }

    part def BatterySubsystem {
        port supply : PowerPort;

        attribute nominalVoltage : Voltage = 14.4 [SI::volt];
        attribute chargeRemaining : BatteryCharge = 100 [%];
        attribute minimumOperationalCharge : BatteryCharge = 20 [%];

        action supplyPower {
            out attribute voltage : Voltage;
            out attribute percent : BatteryCharge;

            voltage = nominalVoltage;
            percent = chargeRemaining;
        }
    }

    part def SafetyInterlock {
        attribute padsConnected : Boolean = false;
        attribute impedanceAcceptable : Boolean = false;
        attribute operatorClearConfirmed : Boolean = false;
        attribute internalFaultPresent : Boolean = false;

        action evaluateReadiness {
            in item contact : PatientContact;
            in attribute fault : Boolean;
            out attribute therapyAllowed : Boolean;

            therapyAllowed =
                contact.padAttached and
                contact.measuredImpedance >= 25 [SI::ohm] and
                contact.measuredImpedance <= 200 [SI::ohm] and
                fault == false;
        }
    }

    part def DefibrillatorSystem {
        port patientECG : ECGAcquisitionPort;
        port patientTherapy : TherapyOutputPort;
        port operatorPanel : OperatorInterfacePort;

        part pads : ElectrodePadSet;
        part analyzer : ECGAnalyzer;
        part storage : EnergyStorageModule;
        part controller : ShockController;
        part ui : UserInterface;
        part battery : BatterySubsystem;
        part interlock : SafetyInterlock;

        attribute readiness : DeviceReadiness = DeviceReadiness::standby;
        attribute primaryFunction : String =
            "Detect shockable cardiac rhythm and deliver controlled electrical defibrillation energy to the patient through electrode pads.";

        connect patientECG to pads.patientSense;
        connect pads.patientSense to analyzer.acquisition;
        connect patientTherapy to pads.therapyPath;
        connect pads.therapyPath to controller.therapyOutput;
        connect operatorPanel to ui.controls;
        connect operatorPanel to controller.operatorInterface;
        connect battery.supply to storage.power;

        action performDefibrillationCycle {
            in item ecg : ECGSignal;
            in item contact : PatientContact;
            in item command : OperatorCommand;
            out item status : StatusMessage;
            out item pulse : TherapyPulse;

            first analyzer.analyzeRhythm(signal = ecg);
            then interlock.evaluateReadiness(contact = contact, fault = false);
            then controller.selectEnergy(command = command);
            then controller.authorizeShock(
                advised = analyzer.analyzeRhythm.shockAdvised,
                command = command
            );
            then storage.chargeCapacitor(requestedEnergy = controller.selectEnergy.energy);
            then storage.dischargeCapacitor(
                loadImpedance = contact.measuredImpedance,
                commandedEnergy = controller.selectEnergy.energy
            );
            then ui.updateStatus(
                readiness = DeviceReadiness::postShock,
                battery = battery.chargeRemaining,
                advised = analyzer.analyzeRhythm.shockAdvised
            );

            pulse = storage.dischargeCapacitor.therapy;
            status = ui.updateStatus.status;
        }

        state def DefibrillatorOperationalStates {
            state off;
            state standby;
            state padsCheck;
            state analyzing;
            state shockNotAdvised;
            state charging;
            state armed;
            state deliveringShock;
            state postShockAssessment;
            state fault;

            entry action offEntry {
                readiness = DeviceReadiness::unavailable;
            }

            entry action standbyEntry {
                readiness = DeviceReadiness::standby;
            }

            entry action analyzingEntry {
                readiness = DeviceReadiness::analyzing;
            }

            entry action chargingEntry {
                readiness = DeviceReadiness::charging;
            }

            entry action armedEntry {
                readiness = DeviceReadiness::armed;
            }

            entry action shockEntry {
                readiness = DeviceReadiness::deliveringShock;
            }

            transition first off then standby
                accept OperatorCommand
                if command.powerOn;

            transition standby then padsCheck
                accept PatientContact
                if contact.padAttached;

            transition padsCheck then analyzing
                accept OperatorCommand
                if command.analyze;

            transition analyzing then shockNotAdvised
                if analyzer.shockableDetected == false;

            transition analyzing then charging
                if analyzer.shockableDetected == true and interlock.internalFaultPresent == false;

            transition charging then armed
                if storage.storedEnergy >= controller.selectedEnergy;

            transition armed then deliveringShock
                accept OperatorCommand
                if command.shock and controller.shockEnabled;

            transition armed then standby
                accept OperatorCommand
                if command.disarm;

            transition deliveringShock then postShockAssessment;

            transition postShockAssessment then analyzing
                accept OperatorCommand
                if command.analyze;

            transition postShockAssessment then standby
                accept OperatorCommand
                if command.disarm;

            transition standby then fault
                if battery.chargeRemaining < battery.minimumOperationalCharge;

            transition analyzing then fault
                if interlock.internalFaultPresent;

            transition charging then fault
                if interlock.internalFaultPresent;

            transition fault then standby
                accept OperatorCommand
                if command.powerOn and battery.chargeRemaining >= battery.minimumOperationalCharge;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject defib : DefibrillatorSystem;

        doc /* The defibrillation system shall provide the high-level primary function of evaluating a patient's cardiac rhythm and, when a shockable rhythm is detected and safety conditions are satisfied, delivering a controlled biphasic electrical pulse through electrode pads to support restoration of effective cardiac rhythm. */

        require constraint {
            defib.primaryFunction ==
            "Detect shockable cardiac rhythm and deliver controlled electrical defibrillation energy to the patient through electrode pads."
        }
    }

    requirement def RhythmAnalysisRequirement {
        subject analyzer : ECGAnalyzer;

        doc /* The analyzer shall classify the patient ECG rhythm and identify ventricular fibrillation or pulseless ventricular tachycardia as shockable rhythms when artifact is not present. */

        require constraint {
            analyzer.minimumAnalysisTime <= 12 [SI::second] and
            analyzer.maximumAnalysisTime <= 15 [SI::second]
        }
    }

    requirement def TherapyEnergyRequirement {
        subject controller : ShockController;

        doc /* The controller shall select a therapeutic energy between 120 J and 360 J for adult biphasic defibrillation therapy. */

        require constraint {
            controller.selectedEnergy >= 120 [SI::joule] and
            controller.selectedEnergy <= 360 [SI::joule]
        }
    }

    requirement def PatientImpedanceSafetyRequirement {
        subject pads : ElectrodePadSet;

        doc /* The system shall inhibit defibrillation energy delivery unless measured patient impedance is within the allowed therapy range. */

        require constraint {
            pads.minimumSafeImpedance == 25 [SI::ohm] and
            pads.maximumSafeImpedance == 200 [SI::ohm]
        }
    }

    requirement def ChargeTimeRequirement {
        subject storage : EnergyStorageModule;

        doc /* The energy storage module shall charge to the selected therapy energy within the specified charge time limit when battery charge is sufficient. */

        require constraint {
            storage.chargeTimeLimit <= 10 [SI::second] and
            storage.maximumEnergy >= 360 [SI::joule]
        }
    }

    requirement def BatteryReadinessRequirement {
        subject battery : BatterySubsystem;

        doc /* The battery subsystem shall support operation only when remaining battery charge is at or above the minimum operational threshold. */

        require constraint {
            battery.minimumOperationalCharge >= 20 [%]
        }
    }

    requirement def ShockAuthorizationRequirement {
        subject controller : ShockController;

        doc /* In advisory mode, the controller shall permit shock delivery only after a shockable rhythm decision and an explicit operator shock command. */

        require constraint {
            controller.mode != ShockMode::advisory or
            (controller.shockAdvised and controller.shockEnabled)
        }
    }

    satisfy PrimaryFunctionRequirement by DefibrillatorSystem;
    satisfy RhythmAnalysisRequirement by ECGAnalyzer;
    satisfy TherapyEnergyRequirement by ShockController;
    satisfy PatientImpedanceSafetyRequirement by ElectrodePadSet;
    satisfy ChargeTimeRequirement by EnergyStorageModule;
    satisfy BatteryReadinessRequirement by BatterySubsystem;
    satisfy ShockAuthorizationRequirement by ShockController;

    part defibUnit : DefibrillatorSystem {
        attribute readiness = DeviceReadiness::standby;

        part pads {
            attribute attached = false;
            attribute impedance = 75 [SI::ohm];
        }

        part analyzer {
            attribute currentRhythm = PatientRhythm::unknown;
        }

        part controller {
            attribute mode = ShockMode::advisory;
            attribute selectedEnergy = 200 [SI::joule];
        }

        part battery {
            attribute chargeRemaining = 95 [%];
        }
    }
}