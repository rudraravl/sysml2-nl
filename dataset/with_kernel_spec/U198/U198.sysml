package AutomatedExternalDefibrillator {
    private import ScalarValues::*;

    attribute def Energy :> Real;
    attribute def Voltage :> Real;
    attribute def Impedance :> Real;
    attribute def ECGAmplitude :> Real;
    attribute def Duration :> Real;

    item def ECGSignal {
        attribute amplitude : ECGAmplitude;
    }
    item def EnergyPulse {
        attribute energy : Energy;
        attribute peakVoltage : Voltage;
        attribute duration : Duration;
    }
    item def ImpedanceMeasurement {
        attribute resistance : Impedance;
    }
    item def VoicePrompt;
    item def DisplayInstruction;
    item def UserCommand;

    part def MicrocontrollerUnit {
        in item advice : Boolean;
        out item chargeCommand : Boolean;
        out item deliverCommand : Boolean;
        out item prompt : VoicePrompt;
        out item instruction : DisplayInstruction;
        in item userInput : UserCommand;
    }

    part def BatteryModule {
        in item chargeCommand : Boolean;
        out item energy : EnergyPulse;
        attribute capacity : Energy = 300.0;
    }

    part def ECGAnalysisModule {
        in item ecg : ECGSignal;
        out item advice : Boolean;
    }

    part def HighVoltageCapacitor {
        in item energy : EnergyPulse;
        out item storedEnergy : EnergyPulse;
    }

    part def TherapyDeliveryCircuit {
        in item storedEnergy : EnergyPulse;
        in item deliverCommand : Boolean;
        in item measuredImpedance : ImpedanceMeasurement;
        out item therapy : EnergyPulse;
    }

    part def OperatorInterface {
        in item prompt : VoicePrompt;
        in item instruction : DisplayInstruction;
        out item userInput : UserCommand;
    }

    part def DefibrillationElectrodes {
        out item ecg : ECGSignal;
        in item therapy : EnergyPulse;
        out item impedance : ImpedanceMeasurement;
    }

    part def Patient;

    part def AED {
        part microcontroller : MicrocontrollerUnit;
        part battery : BatteryModule;
        part ecgModule : ECGAnalysisModule;
        part hvCapacitor : HighVoltageCapacitor;
        part therapyCircuit : TherapyDeliveryCircuit;
        part operatorInterface : OperatorInterface;
        part electrodes : DefibrillationElectrodes;
        ref patient : Patient;

        flow from electrodes.ecg to ecgModule.ecg;
        flow from ecgModule.advice to microcontroller.advice;
        flow from microcontroller.chargeCommand to battery.chargeCommand;
        flow from battery.energy to hvCapacitor.energy;
        flow from hvCapacitor.storedEnergy to therapyCircuit.storedEnergy;
        flow from microcontroller.deliverCommand to therapyCircuit.deliverCommand;
        flow from electrodes.impedance to therapyCircuit.measuredImpedance;
        flow from therapyCircuit.therapy to electrodes.therapy;
        flow from microcontroller.prompt to operatorInterface.prompt;
        flow from microcontroller.instruction to operatorInterface.instruction;
        flow from operatorInterface.userInput to microcontroller.userInput;

        action def AnalyzeECG {
            in item ecg : ECGSignal;
            out item isShockable : Boolean;
        }
        action def ChargeCapacitor {
            in item energy : EnergyPulse;
            out item storedEnergy : EnergyPulse;
        }
        action def DeliverShock {
            in item energy : EnergyPulse;
            in item impedance : ImpedanceMeasurement;
            out item therapy : EnergyPulse;
        }
        action def PromptUser {
            out item prompt : VoicePrompt;
            out item instruction : DisplayInstruction;
        }

        action def AEDOperation {
            first start;
            then action promptApplyPads : PromptUser;
            then merge continueMonitoring;
            then action analyze : AnalyzeECG {
                out item isShockable;
            }
            then decide;
                if analyze.isShockable then promptStandClear;
                if not analyze.isShockable then promptCPR;
            action promptStandClear : PromptUser;
            then action charge : ChargeCapacitor;
            then action promptPressButton : PromptUser;
            then action deliver : DeliverShock;
            then action promptReanalyzing : PromptUser;
            then continueMonitoring;
            action promptCPR : PromptUser;
            then done;
        }
    }

    requirement def ShockableRhythmDetection {
        text "The AED shall automatically analyze the patient's ECG signal and accurately identify shockable rhythms such as ventricular fibrillation and pulseless ventricular tachycardia.";
    }

    requirement def ControlledEnergyDelivery {
        text "The AED shall deliver a biphasic truncated exponential shock with energy between 150J and 200J for adults, automatically compensating for patient impedance measured between 25 and 175 Ohms.";
    }

    requirement def BatteryCapacity {
        text "The battery module shall provide enough capacity to deliver a minimum of 200 shocks or provide at least 10 hours of continuous ECG monitoring.";
    }

    requirement def OperatorGuidance {
        text "The operator interface shall provide clear, unambiguous visual and voice prompts to guide an untrained bystander through the complete resuscitation sequence, including pad placement, stand clear warning, and shock delivery.";
    }

    requirement def ReanalysisAfterShock {
        text "After delivering a shock, the AED shall immediately re-analyze the patient's heart rhythm to assess response and determine if further shocks are necessary.";
    }

    satisfy ShockableRhythmDetection by ECGAnalysisModule;
    satisfy ControlledEnergyDelivery by TherapyDeliveryCircuit;
    satisfy BatteryCapacity by BatteryModule;
    satisfy OperatorGuidance by OperatorInterface;
    satisfy ReanalysisAfterShock by MicrocontrollerUnit;
}
