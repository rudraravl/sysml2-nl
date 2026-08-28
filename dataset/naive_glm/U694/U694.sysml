package GeigerCounterSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Units ----
    unit volt { :>> symbol = "V"; }
    unit count { :>> symbol = "count"; }
    unit cpm { :>> symbol = "CPM"; }
    unit microsievertPerHour { :>> symbol = "uSv/h"; }
    unit second { :>> symbol = "s"; }

    // ---- Value Types ----
    value type Voltage :> Real { :>> unit = volt; }
    value type Count :> Integer { :>> unit = count; }
    value type CountsPerMinute :> Real { :>> unit = cpm; }
    value type DoseRate :> Real { :>> unit = microsievertPerHour; }
    value type Duration :> Real { :>> unit = second; }

    // ---- Enumerations ----
    enum def SafetyLevel {
        background;
        elevated;
        warning;
        danger;
    }

    // ---- Item Types ----
    item def IonizingParticle {
        attribute energy : Real;  // keV
    }

    item def ElectricalPulse {
        attribute amplitude : Voltage;
        attribute timestamp : Real;
    }

    item def RadiationReading {
        attribute cpm : CountsPerMinute;
        attribute doseRate : DoseRate;
        attribute safetyLevel : SafetyLevel;
    }

    // ---- Port Definitions ----
    port def ParticleInPort {
        in item particle : IonizingParticle;
    }

    port def PulseOutPort {
        out item pulse : ElectricalPulse;
    }

    port def PulseInPort {
        in item pulse : ElectricalPulse;
    }

    port def HVOutPort {
        out attribute voltage : Voltage;
    }

    port def HVInPort {
        in attribute voltage : Voltage;
    }

    port def ReadingOutPort {
        out item reading : RadiationReading;
    }

    port def ReadingInPort {
        in item reading : RadiationReading;
    }

    // ---- Part Definitions ----

    part def HighVoltagePowerSupply {
        attribute nominalVoltage : Voltage = 450 [V];
        attribute tolerance : Real = 0.05;
        port hvOut : HVOutPort;

        action generateHV {
            out voltage : Voltage = nominalVoltage;
        }
    }

    part def GeigerMullerTube {
        attribute gasType : String = "Neon-Halogen";
        attribute operatingVoltage : Voltage = 450 [V];
        attribute deadTime : Duration = 0.0002 [s];
        attribute efficiency : Real = 0.30;

        port particleIn : ParticleInPort;
        port hvIn : HVInPort;
        port pulseOut : PulseOutPort;

        attribute currentVoltage : Voltage;

        action detectParticle {
            in particle : IonizingParticle via particleIn;
            out pulse : ElectricalPulse via pulseOut;
        }

        action avalancheDischarge {
            in particle : IonizingParticle;
            out pulse : ElectricalPulse;
        }
    }

    part def AudioIndicator {
        attribute clickVolume : Real = 0.5;
        attribute enabled : Boolean = true;
        port pulseIn : PulseInPort;

        action produceClick {
            in pulse : ElectricalPulse via pulseIn;
        }
    }

    part def CentralProcessingUnit {
        attribute countingPeriod : Duration = 60 [s];
        attribute pulseCount : Count = 0;
        attribute currentCPM : CountsPerMinute = 0;
        attribute currentDoseRate : DoseRate = 0;
        attribute currentSafetyLevel : SafetyLevel = background;
        attribute conversionFactor : Real = 0.0057;  // uSv/h per CPM

        port pulseIn : PulseInPort;
        port readingOut : ReadingOutPort;

        action countPulses {
            in pulse : ElectricalPulse via pulseIn;
            out count : Count;
        }

        action calculateCPM {
            in count : Count;
            in period : Duration = countingPeriod;
            out cpm : CountsPerMinute;
        }

        action convertToDoseRate {
            in cpm : CountsPerMinute;
            out doseRate : DoseRate;
        }

        action classifySafetyLevel {
            in cpm : CountsPerMinute;
            out level : SafetyLevel;
        }

        action emitReading {
            in cpm : CountsPerMinute;
            in doseRate : DoseRate;
            in level : SafetyLevel;
            out reading : RadiationReading via readingOut;
        }

        exhibit SafetyLevelStateMachine {
            state background;
            state elevated;
            state warning;
            state danger;

            transition initial to background;
            transition background to elevated
                when currentCPM > 30 { then currentSafetyLevel = elevated; }
            transition elevated to warning
                when currentCPM > 60 { then currentSafetyLevel = warning; }
            transition warning to danger
                when currentCPM > 120 { then currentSafetyLevel = danger; }
            transition danger to warning
                when currentCPM <= 120 { then currentSafetyLevel = warning; }
            transition warning to elevated
                when currentCPM <= 60 { then currentSafetyLevel = elevated; }
            transition elevated to background
                when currentCPM <= 30 { then currentSafetyLevel = background; }
        }
    }

    part def VisualDisplay {
        attribute displayedCPM : CountsPerMinute = 0;
        attribute displayedDoseRate : DoseRate = 0;
        attribute displayedLevel : SafetyLevel = background;
        attribute backlightOn : Boolean = true;
        port readingIn : ReadingInPort;

        action displayReading {
            in reading : RadiationReading via readingIn;
            then displayedCPM = reading.cpm;
            then displayedDoseRate = reading.doseRate;
            then displayedLevel = reading.safetyLevel;
        }
    }

    part def AlarmUnit {
        attribute safetyThreshold : CountsPerMinute = 120 [CPM];
        attribute alarmActive : Boolean = false;
        attribute alarmVolume : Real = 0.8;
        port readingIn : ReadingInPort;

        action compareThreshold {
            in reading : RadiationReading via readingIn;
            out triggered : Boolean;
            then if reading.cpm > safetyThreshold {
                triggered = true;
            } else {
                triggered = false;
            }
        }

        action activateAlarm {
            in triggered : Boolean;
            then alarmActive = triggered;
        }
    }

    part def Battery {
        attribute capacity : Real = 2000;  // mAh
        attribute currentCharge : Real = 2000;
        attribute voltage : Voltage = 3.7 [V];

        action supplyPower {
            out voltage : Voltage;
        }
    }

    part def UserInterface {
        attribute powerButtonState : Boolean = false;
        attribute modeButtonState : Boolean = false;
    }

    // ---- System Assembly ----
    part def PortableGeigerCounter {
        attribute manufacturer : String = "RadTech";
        attribute model : String = "GC-100";
        attribute weight : Real = 0.35;  // kg

        part battery : Battery;
        part hvSupply : HighVoltagePowerSupply;
        part gmTube : GeigerMullerTube;
        part audioIndicator : AudioIndicator;
        part cpu : CentralProcessingUnit;
        part display : VisualDisplay;
        part alarm : AlarmUnit;
        part ui : UserInterface;

        connection battery.supplyPower.voltage to hvSupply.hvOut.voltage;
        connection hvSupply.hvOut to gmTube.hvIn;
        connection gmTube.pulseOut to audioIndicator.pulseIn;
        connection gmTube.pulseOut to cpu.pulseIn;
        connection cpu.readingOut to display.readingIn;
        connection cpu.readingOut to alarm.readingIn;
    }

    // ---- Requirements ----
    requirement def DetectIonizingRadiation {
        doc :>> The system shall detect and measure ionizing radiation in the environment;
        subject :>> counter : PortableGeigerCounter;
        objective :>> counter.gmTube shall detect IonizingParticle;
    }

    requirement def ProvideRealTimeFeedback {
        doc :>> The system shall provide real-time feedback to the user about radiation level;
        subject :>> counter : PortableGeigerCounter;
        objective :>> counter.audioIndicator shall produce a click for each detected particle;
    }

    requirement def IssueUnsafeWarnings {
        doc :>> The system shall issue warnings if radiation becomes unsafe;
        subject :>> counter : PortableGeigerCounter;
        objective :>> counter.alarm shall activate when radiation exceeds 120 CPM;
    }

    requirement def Supply450Volts {
        doc :>> A dedicated high-voltage power supply shall provide 450 volts to the Geiger-Muller tube;
        subject :>> supply : HighVoltagePowerSupply;
        attribute :>> requiredVoltage : Voltage = 450 [V];
        objective :>> supply.nominalVoltage == requiredVoltage;
    }

    requirement def NeonHalogenGas {
        doc :>> The Geiger-Muller tube shall be filled with Neon-Halogen gas;
        subject :>> tube : GeigerMullerTube;
        objective :>> tube.gasType == "Neon-Halogen";
    }

    requirement def ProduceClickSound {
        doc :>> The audio indicator shall produce a click sound for each detected particle;
        subject :>> indicator : AudioIndicator;
        objective :>> indicator.produceClick shall execute for each ElectricalPulse received;
    }

    requirement def CountPulsesOver60Seconds {
        doc :>> The processor shall count incoming pulses over a 60-second period to calculate CPM;
        subject :>> cpu : CentralProcessingUnit;
        attribute :>> requiredPeriod : Duration = 60 [s];
        objective :>> cpu.countingPeriod == requiredPeriod;
    }

    requirement def ConvertCPMToDoseRate {
        doc :>> The processor shall convert CPM into a radiation dose rate;
        subject :>> cpu : CentralProcessingUnit;
        objective :>> cpu.convertToDoseRate shall produce DoseRate from CountsPerMinute;
    }

    requirement def DisplayCPMReading {
        doc :>> The display shall show the current radiation level in CPM;
        subject :>> display : VisualDisplay;
        objective :>> display.displayedCPM shall reflect the current CountsPerMinute;
    }

    requirement def AlarmAtThreshold {
        doc :>> The alarm unit shall compare the reading against a preset safety threshold of 120 CPM and activate an audible alarm if exceeded;
        subject :>> alarm : AlarmUnit;
        attribute :>> threshold : CountsPerMinute = 120 [CPM];
        objective :>> alarm.safetyThreshold == threshold and alarm.alarmActive shall be true when reading.cpm > threshold;
    }

    requirement def ClassifySafetyLevels {
        doc :>> The system shall classify measured radiation into background, elevated, warning, and danger levels;
        subject :>> cpu : CentralProcessingUnit;
        objective :>> cpu.currentSafetyLevel shall be one of SafetyLevel::background, SafetyLevel::elevated, SafetyLevel::warning, or SafetyLevel::danger;
    }

    requirement def PortableOperation {
        doc :>> The system shall be portable and battery-powered;
        subject :>> counter : PortableGeigerCounter;
        objective :>> counter.battery shall supply power and counter.weight shall not exceed 0.5 kg;
    }

    // ---- Requirement Satisfaction ----
    satisfaction DetectIonizingRadiation by PortableGeigerCounter;
    satisfaction ProvideRealTimeFeedback by PortableGeigerCounter;
    satisfaction IssueUnsafeWarnings by PortableGeigerCounter;
    satisfaction Supply450Volts by HighVoltagePowerSupply;
    satisfaction NeonHalogenGas by GeigerMullerTube;
    satisfaction ProduceClickSound by AudioIndicator;
    satisfaction CountPulsesOver60Seconds by CentralProcessingUnit;
    satisfaction ConvertCPMToDoseRate by CentralProcessingUnit;
    satisfaction DisplayCPMReading by VisualDisplay;
    satisfaction AlarmAtThreshold by AlarmUnit;
    satisfaction ClassifySafetyLevels by CentralProcessingUnit;
    satisfaction PortableOperation by PortableGeigerCounter;
}
