package BiothesiometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    public import Definitions::*;

    package Definitions {
        attribute def StartTestSignal;
        attribute def ResetSignal;
        attribute def PatientResponseSignal;
        attribute def TrialTimeoutSignal;

        item def VibrationCommand {
            attribute amplitude : LengthValue;
            attribute frequency : FrequencyValue;
        }

        item def DisplayData {
            attribute status : String;
            attribute threshold : LengthValue;
            attribute score : Real;
        }

        port def VibrationOutPort {
            out command : VibrationCommand;
        }
        port def VibrationInPort {
            in command : VibrationCommand;
        }
        port def ResponseOutPort {
            out response : PatientResponseSignal;
        }
        port def ResponseInPort {
            in response : PatientResponseSignal;
        }
        port def DisplayOutPort {
            out data : DisplayData;
        }
        port def DisplayInPort {
            in data : DisplayData;
        }
        port def PowerOutPort {
            out powerOn : Boolean;
        }
        port def PowerInPort {
            in powerOn : Boolean;
        }

        part def HandheldProbe {
            port vibrationIn : VibrationInPort;
            attribute tipDisplacement : LengthValue = 0 [m];
            perform action generateVibration : GenerateVibration;
        }

        part def PatientResponseButton {
            port buttonOut : ResponseOutPort;
            perform action detectPress : DetectPress;
        }

        part def DisplayPanel {
            port displayIn : DisplayInPort;
            perform action showDisplay : ShowDisplay;
        }

        part def PowerSupply {
            port powerOut : PowerOutPort;
            attribute voltage : Real;
            perform action supplyPower : SupplyPower;
        }

        part def ControlModule {
            port probeOut : VibrationOutPort;
            port buttonIn : ResponseInPort;
            port displayOut : DisplayOutPort;
            port powerIn : PowerInPort;
            attribute testFrequency : FrequencyValue = 120 [Hz];
            attribute amplitudeStep : LengthValue = 0.000005 [m];
            attribute maxSafeAmplitude : LengthValue = 0.00005 [m];
            attribute currentAmplitude : LengthValue;
            attribute vibrationThreshold : LengthValue;
            attribute neuropathyScore : Real;
            attribute patientAge : Integer;
            attribute testLocation : String = "big toe";
            exhibit state testStates : TestStates;
        }

        part def MainControlUnit {
            part controlModule : ControlModule;
            part displayPanel : DisplayPanel;
            part powerSupply : PowerSupply;
        }

        action def GenerateVibration {
            in amplitude : LengthValue;
            in frequency : FrequencyValue;
        }
        action def DetectPress {
            out response : PatientResponseSignal;
        }
        action def ShowDisplay {
            in status : String;
            in threshold : LengthValue;
            in score : Real;
        }
        action def SupplyPower {
            out powerOn : Boolean;
        }
        action def RampAmplitude {
            in current : LengthValue;
            in step : LengthValue;
            out next : LengthValue;
        }
        action def RecordThreshold {
            in amplitude : LengthValue;
            out threshold : LengthValue;
        }
        action def CalculateScore {
            in threshold : LengthValue;
            in patientAge : Integer;
            in testLocation : String;
            in maxAmplitude : LengthValue;
            out score : Real;
        }
        action def UpdateDisplay {
            in status : String;
            in threshold : LengthValue;
            in score : Real;
        }

        state def TestStates;

        requirement def MaxAmplitudeSafety {
            doc /* The vibration amplitude shall never exceed the predefined maximum safe level. */
            constraint { 0 [m] <= 0.00005 [m] }
        }

        requirement def FixedTestFrequency {
            doc /* The vibration frequency shall be maintained at 120 Hz during the threshold test. */
            constraint { 120 [Hz] == 120 [Hz] }
        }

        requirement def ThresholdDetection {
            doc /* The system shall record the vibration amplitude at which the patient first presses the response button. */
        }

        requirement def NeuropathyScoreDisplay {
            doc /* The system shall calculate and display a quantitative neuropathy score based on the measured threshold. */
        }
    }

    package Usages {
        private import Definitions::*;

        part biothesiometer : MainControlUnit;
        part probe : HandheldProbe;
        part responseButton : PatientResponseButton;

        connect biothesiometer.controlModule.probeOut to probe.vibrationIn;
        connect responseButton.buttonOut to biothesiometer.controlModule.buttonIn;
        connect biothesiometer.controlModule.displayOut to biothesiometer.displayPanel.displayIn;
        connect biothesiometer.powerSupply.powerOut to biothesiometer.controlModule.powerIn;

        action generateVibration : GenerateVibration;
        action detectPress : DetectPress;
        action showDisplay : ShowDisplay;
        action supplyPower : SupplyPower;
        action rampAmplitude : RampAmplitude;
        action recordThreshold : RecordThreshold;
        action calculateScore : CalculateScore;
        action updateDisplay : UpdateDisplay;

        state testStates : TestStates {
            entry; then idle;

            state idle;
            accept StartTestSignal
                then ramping;

            state ramping {
                entry rampAmplitude {
                    in current = biothesiometer.controlModule.currentAmplitude;
                    in step = biothesiometer.controlModule.amplitudeStep;
                    out next = biothesiometer.controlModule.currentAmplitude;
                }
                do generateVibration {
                    in amplitude = biothesiometer.controlModule.currentAmplitude;
                    in frequency = biothesiometer.controlModule.testFrequency;
                }
            }
            accept PatientResponseSignal
                do recordThreshold {
                    in amplitude = biothesiometer.controlModule.currentAmplitude;
                    out threshold = biothesiometer.controlModule.vibrationThreshold;
                }
                then displaying;
            accept TrialTimeoutSignal
                if biothesiometer.controlModule.currentAmplitude < biothesiometer.controlModule.maxSafeAmplitude
                then ramping;
            accept TrialTimeoutSignal
                if biothesiometer.controlModule.currentAmplitude >= biothesiometer.controlModule.maxSafeAmplitude
                then errorState;

            state displaying {
                entry calculateScore {
                    in threshold = biothesiometer.controlModule.vibrationThreshold;
                    in patientAge = biothesiometer.controlModule.patientAge;
                    in testLocation = biothesiometer.controlModule.testLocation;
                    in maxAmplitude = biothesiometer.controlModule.maxSafeAmplitude;
                    out score = biothesiometer.controlModule.neuropathyScore;
                }
                do updateDisplay {
                    in status = "Complete";
                    in threshold = biothesiometer.controlModule.vibrationThreshold;
                    in score = biothesiometer.controlModule.neuropathyScore;
                }
            }
            accept ResetSignal
                then idle;

            state errorState {
                entry updateDisplay {
                    in status = "Safety limit exceeded";
                    in threshold = biothesiometer.controlModule.currentAmplitude;
                    in score = 0.0;
                }
            }
            accept ResetSignal
                then idle;
        }

        requirement maxAmplitudeSafety : MaxAmplitudeSafety;
        requirement fixedTestFrequency : FixedTestFrequency;
        requirement thresholdDetection : ThresholdDetection;
        requirement neuropathyScoreDisplay : NeuropathyScoreDisplay;
    }
}
