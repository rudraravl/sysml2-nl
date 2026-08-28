package CESDevice {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value def CurrentValue :> Real {
        unit 'mA';
    }
    value def VoltageValue :> Real {
        unit 'V';
    }
    value def ImpedanceValue :> Real {
        unit 'kOhm';
    }
    value def FrequencyValue :> Real {
        unit 'Hz';
    }
    value def DurationValue :> Real {
        unit 'min';
    }
    value def TimeValue :> Real {
        unit 's';
    }
    value def BatteryCharge :> Real {
        unit 'percent';
    }

    // ---- Item types ----
    item def ElectricalSignal {
        attribute amplitude : CurrentValue;
        attribute frequency : FrequencyValue;
    }
    item def RegulatedCurrent {
        attribute level : CurrentValue;
    }
    item def ElectrodeContact {
        attribute impedance : ImpedanceValue;
        attribute good : Boolean;
    }
    item def SafetyStatus {
        attribute currentSafe : Boolean;
        attribute impedanceSafe : Boolean;
        attribute emergencyStop : Boolean;
    }
    item def UICommand {
        attribute start : Boolean;
        attribute stop : Boolean;
        attribute intensity : CurrentValue;
        attribute duration : DurationValue;
        attribute frequency : FrequencyValue;
    }
    item def UIDisplay {
        attribute remainingTime : DurationValue;
        attribute alertMessage : String;
        attribute sessionActive : Boolean;
    }

    // ---- Requirements ----
    requirement def TherapyDeliveryRequirement {
        subject device : CESDevice;
        doc /* The device shall deliver a controlled low-intensity electrical current to the brain through two ear clip electrodes. */
        attribute maxIntensity : CurrentValue = 0.5 [mA];
        constraint { device.deliveredCurrent <= maxIntensity }
    }

    requirement def ImpedanceCheckRequirement {
        subject device : CESDevice;
        doc /* Before a therapy session begins, the device shall verify electrode contact via an impedance check. */
        attribute minAcceptableImpedance : ImpedanceValue = 0.1 [kOhm];
        attribute maxAcceptableImpedance : ImpedanceValue = 50.0 [kOhm];
        constraint { device.contact.impedance >= minAcceptableImpedance and device.contact.impedance <= maxAcceptableImpedance }
    }

    requirement def SafetyMonitoringRequirement {
        subject device : CESDevice;
        doc /* A dedicated hardware safety circuit shall continuously monitor current and impedance and trigger an emergency stop if outside safe ranges. */
        attribute safeCurrentMin : CurrentValue = 0.0 [mA];
        attribute safeCurrentMax : CurrentValue = 0.5 [mA];
        attribute safeImpedanceMax : ImpedanceValue = 50.0 [kOhm];
        constraint { device.safetyStatus.emergencyStop implies device.safetyStatus.currentSafe == false or device.safetyStatus.impedanceSafe == false }
    }

    requirement def BatteryRequirement {
        subject device : CESDevice;
        doc /* The device shall be powered by a rechargeable battery pack. */
        attribute minChargeForTherapy : BatteryCharge = 20.0 [percent];
        constraint { device.battery.charge >= minChargeForTherapy }
    }

    requirement def UIDisplayRequirement {
        subject device : CESDevice;
        doc /* The user interface shall display remaining session time and active safety alerts. */
        constraint { device.display.remainingTime >= 0.0 [min] }
    }

    // ---- Port definitions ----
    port def ElectricalOutPort {
        out signal : ElectricalSignal;
    }
    port def ElectricalInPort {
        in signal : ElectricalSignal;
    }
    port def RegulatedCurrentPort {
        out current : RegulatedCurrent;
    }
    port def RegulatedCurrentInPort {
        in current : RegulatedCurrent;
    }
    port def ControlPort {
        out command : UICommand;
    }
    port def ControlInPort {
        in command : UICommand;
    }
    port def DisplayPort {
        out display : UIDisplay;
    }
    port def DisplayInPort {
        in display : UIDisplay;
    }
    port def ContactPort {
        out contact : ElectrodeContact;
    }
    port def ContactInPort {
        in contact : ElectrodeContact;
    }
    port def SafetyPort {
        out status : SafetyStatus;
    }
    port def SafetyInPort {
        in status : SafetyStatus;
    }
    port def PowerPort {
        out voltage : VoltageValue;
    }
    port def PowerInPort {
        in voltage : VoltageValue;
    }

    // ---- Parts ----
    part def BatteryPack {
        attribute charge : BatteryCharge = 100.0 [percent];
        port powerOut : PowerPort;
    }

    part def Microcontroller {
        port powerIn : PowerInPort;
        port uiIn : ControlInPort;
        port displayOut : DisplayPort;
        port waveformCmdOut : ElectricalOutPort;
        port contactIn : ContactInPort;
        port safetyIn : SafetyInPort;

        attribute deliveredCurrent : CurrentValue;
        attribute sessionDuration : DurationValue;
        attribute sessionFrequency : FrequencyValue;
        attribute sessionIntensity : CurrentValue;
        attribute remainingTime : DurationValue;

        state def TherapyControl {
            entry; then Idle;

            state Idle;
            state ImpedanceCheck;
            state AlertContact;
            state Active;
            state EmergencyStopped;

            transition Idle_to_ImpedanceCheck
                first Idle
                if uiIn.command.start == true
                then ImpedanceCheck;

            transition ImpedanceCheck_to_Active
                first ImpedanceCheck
                if contactIn.contact.good == true
                then Active;

            transition ImpedanceCheck_to_AlertContact
                first ImpedanceCheck
                if contactIn.contact.good == false
                then AlertContact;

            transition AlertContact_to_ImpedanceCheck
                first AlertContact
                if uiIn.command.start == true
                then ImpedanceCheck;

            transition Active_to_EmergencyStopped
                first Active
                if safetyIn.status.emergencyStop == true
                then EmergencyStopped;

            transition Active_to_Idle
                first Active
                if remainingTime <= 0.0 [min] or uiIn.command.stop == true
                then Idle;

            transition EmergencyStopped_to_Idle
                first EmergencyStopped
                if uiIn.command.stop == true
                then Idle;
        }

        action performImpedanceCheck {
            in contact : ElectrodeContact;
            out result : Boolean;
        }

        action generateWaveformCommand {
            in intensity : CurrentValue;
            in frequency : FrequencyValue;
            out signal : ElectricalSignal;
        }

        action updateDisplay {
            in remaining : DurationValue;
            in alert : String;
            out display : UIDisplay;
        }
    }

    part def UIPanel {
        port powerIn : PowerInPort;
        port commandOut : ControlPort;
        port displayIn : DisplayInPort;

        attribute selectedIntensity : CurrentValue = 0.1 [mA];
        attribute selectedDuration : DurationValue = 20.0 [min];
        attribute selectedFrequency : FrequencyValue = 0.5 [Hz];

        action acceptUserInput {
            out command : UICommand;
        }
    }

    part def WaveformGenerator {
        port powerIn : PowerInPort;
        port signalCmdIn : ElectricalInPort;
        port signalOut : ElectricalOutPort;

        action generateSignal {
            in cmd : ElectricalSignal;
            out signal : ElectricalSignal;
        }
    }

    part def CurrentRegulator {
        port powerIn : PowerInPort;
        port signalIn : ElectricalInPort;
        port regulatedOut : RegulatedCurrentPort;
        port contactFeedback : ContactInPort;

        attribute skinImpedance : ImpedanceValue;
        attribute targetCurrent : CurrentValue;
        attribute measuredCurrent : CurrentValue;

        action regulateCurrent {
            in input : ElectricalSignal;
            in contact : ElectrodeContact;
            out regulated : RegulatedCurrent;
        }
    }

    part def SafetyCircuit {
        port powerIn : PowerInPort;
        port currentIn : RegulatedCurrentInPort;
        port contactIn : ContactInPort;
        port statusOut : SafetyPort;

        attribute safeCurrentMin : CurrentValue = 0.0 [mA];
        attribute safeCurrentMax : CurrentValue = 0.5 [mA];
        attribute safeImpedanceMax : ImpedanceValue = 50.0 [kOhm];

        action monitorParameters {
            in current : RegulatedCurrent;
            in contact : ElectrodeContact;
            out status : SafetyStatus;
        }

        action emergencyStop {
            out status : SafetyStatus;
        }
    }

    part def EarClipElectrode {
        port currentIn : RegulatedCurrentInPort;
        port contactOut : ContactPort;

        attribute contactImpedance : ImpedanceValue = 1.0 [kOhm];
        attribute attached : Boolean = false;
    }

    part def ElectrodeAssembly {
        part leftClip : EarClipElectrode;
        part rightClip : EarClipElectrode;
        port currentIn : RegulatedCurrentInPort;
        port contactOut : ContactPort;
    }

    part def HandheldUnit {
        part battery : BatteryPack;
        part controller : Microcontroller;
        part ui : UIPanel;
        part waveformGen : WaveformGenerator;
        port powerIn : PowerInPort;
        port currentReg : CurrentRegulator;
        port safety : SafetyCircuit;
        part electrodes : ElectrodeAssembly;

        attribute deliveredCurrent : CurrentValue;
        attribute contact : ElectrodeContact;
        attribute safetyStatus : SafetyStatus;
        attribute display : UIDisplay;

        // Internal connections
        connection batteryToController connect battery.powerOut to controller.powerIn;
        connection batteryToUI connect battery.powerOut to ui.powerIn;
        connection batteryToWaveformGen connect battery.powerOut to waveformGen.powerIn;
        connection batteryToCurrentReg connect battery.powerOut to currentReg.powerIn;
        connection batteryToSafety connect battery.powerOut to safety.powerIn;

        connection uiToController connect ui.commandOut to controller.uiIn;
        connection controllerToUI connect controller.displayOut to ui.displayIn;

        connection controllerToWaveformGen connect controller.waveformCmdOut to waveformGen.signalCmdIn;
        connection waveformGenToCurrentReg connect waveformGen.signalOut to currentReg.signalIn;

        connection currentRegToElectrodes connect currentReg.regulatedOut to electrodes.currentIn;
        connection electrodesToCurrentReg connect electrodes.contactOut to currentReg.contactFeedback;

        connection electrodesToController connect electrodes.contactOut to controller.contactIn;
        connection electrodesToSafety connect electrodes.contactOut to safety.contactIn;

        connection currentRegToSafety connect currentReg.regulatedOut to safety.currentIn;
        connection safetyToController connect safety.statusOut to controller.safetyIn;
    }

    part def CESDevice {
        part handheld : HandheldUnit;

        attribute deliveredCurrent : CurrentValue;
        attribute contact : ElectrodeContact;
        attribute safetyStatus : SafetyStatus;
        attribute display : UIDisplay;
        attribute battery : BatteryCharge;

        satisfy TherapyDeliveryRequirement {
            subject device = self;
        }
        satisfy ImpedanceCheckRequirement {
            subject device = self;
        }
        satisfy SafetyMonitoringRequirement {
            subject device = self;
        }
        satisfy BatteryRequirement {
            subject device = self;
        }
        satisfy UIDisplayRequirement {
            subject device = self;
        }
    }
}
