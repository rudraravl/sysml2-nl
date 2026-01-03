package LungFluteSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import NumericalFunctions::*;

    attribute def Biocompatible;

    enum def MucusState {
        adherent;
        mobilized;
        expectorated;
    }

    item def ExhaledAir {
        attribute flowRate : VolumeFlowRateValue;
        attribute pressure : PressureValue;
    }

    item def AcousticVibration {
        attribute frequency : FrequencyValue;
        attribute amplitude : PressureValue;
    }

    item def AirwayMucus {
        attribute state : MucusState;
        attribute viscosity : Real;
    }

    port def AirflowPort {
        in item airIn : ExhaledAir;
        out item airOut : ExhaledAir;
    }

    port def VibrationPort {
        out item vibration : AcousticVibration;
    }

    part def Mouthpiece {
        attribute material : Biocompatible;
        port airIntake : AirflowPort;
    }

    part def ReedMechanism {
        attribute resonantFrequency : FrequencyValue;
        port airInput : AirflowPort;
        port vibrationOutput : VibrationPort;

        action def GenerateVibration {
            in airflow : ExhaledAir;
            out vibration : AcousticVibration {
                attribute :>> frequency = resonantFrequency;
                attribute amplitude = airflow.pressure * 0.8;
            }
        }
    }

    part def ResonanceChamber {
        attribute chamberLength : LengthValue;
        attribute chamberDiameter : LengthValue;
        port vibrationInput : VibrationPort;
        port airOutput : AirflowPort;

        action def AmplifyVibration {
            in inputVibration : AcousticVibration;
            out amplifiedVibration : AcousticVibration {
                attribute :>> frequency = inputVibration.frequency;
                attribute amplitude = inputVibration.amplitude * 1.5;
            }
        }
    }

    part def CheckValve {
        port airPath : AirflowPort;

        action def PreventInhalation {
            in airDirection : Real;
            out blocked : Boolean;
        }
    }

    part def LungFluteDevice {
        attribute targetFrequency : FrequencyValue = 18.0 [Hz];
        attribute targetBackpressure : PressureValue = 1000.0 [Pa];
        attribute isBiocompatible : Biocompatible = true;

        part mouthpiece : Mouthpiece;
        part reed : ReedMechanism {
            attribute :>> resonantFrequency = targetFrequency;
        }
        part chamber : ResonanceChamber {
            attribute :>> chamberLength = 15.0 [cm];
            attribute :>> chamberDiameter = 3.0 [cm];
        }
        part valve : CheckValve;

        port userInterface : AirflowPort;
        port atmospherePort : AirflowPort;
        port therapeuticOutput : VibrationPort;

        connection mouthToReed connect mouthpiece.airIntake to reed.airInput;
        connection reedToChamber connect reed.vibrationOutput to chamber.vibrationInput;
        connection chamberToValve connect chamber.airOutput to valve.airPath;
        connection valveToAtmosphere connect valve.airPath to atmospherePort;
        connection userToMouth connect userInterface to mouthpiece.airIntake;
        connection therapeuticVibration connect reed.vibrationOutput to therapeuticOutput;
    }

    part def RespiratorySystem {
        part airways {
            item mucus : AirwayMucus[1..*] {
                attribute :>> state = MucusState::adherent;
                attribute :>> viscosity = 1.0;
            }
        }
        port breathingPort;

        state def MucusMobilizationSM {
            entry; then Adherent;
            state Adherent;
            state Mobilizing;
            state Mobilized;
            state Expectorated;

            transition AdherentToMobilizing
                first Adherent
                accept AcousticVibration
                then Mobilizing;

            transition MobilizingToMobilized
                first Mobilizing
                if airways.mucus[1].viscosity < 0.5
                then Mobilized;

            transition MobilizedToExpectorated
                first Mobilized
                accept at after 30 [s]
                then Expectorated;
        }
    }

    part def Patient {
        part lungs : RespiratorySystem;
        port mouth;

        connection internalAirway connect mouth to lungs.breathingPort;
    }

    action def PerformMucusClearanceTherapy {
        in device : LungFluteDevice;
        inout patient : Patient;
        out therapyEffective : Boolean;

        first start;
        then merge breathingCycle;

        then action exhale {
            doc /* Patient exhales through the lung flute device. */
            out exhalation : ExhaledAir {
                attribute flowRate = 0.5 [L/s];
                attribute pressure = device.targetBackpressure;
            }
        }

        then action generateVibration {
            doc /* Reed mechanism converts airflow into acoustic vibration. */
            in airflow = exhale.exhalation;
            out vibration : AcousticVibration;
            perform device.reed.GenerateVibration {
                in airflow = airflow;
                out vibration = vibration;
            }
        }

        then action amplifyVibration {
            doc /* Resonance chamber amplifies the vibration. */
            in inputVibration = generateVibration.vibration;
            out amplifiedVibration : AcousticVibration;
            perform device.chamber.AmplifyVibration {
                in inputVibration = inputVibration;
                out amplifiedVibration = amplifiedVibration;
            }
        }

        then action transmitToAirways {
            doc /* Acoustic vibration propagates through airways to mobilize mucus. */
            in vibration = amplifyVibration.amplifiedVibration;
        }

        then decide evaluateTherapy;
            if patient.lungs.airways.mucus[1].state == MucusState::mobilized then success;
            else continueTherapy;

        action continueTherapy {
            then breathingCycle;
        }

        action success {
            attribute :>> therapyEffective = true;
        }

        then done;
    }

    part mucusClearanceSystem : LungFluteDevice {
        part treatedPatient : Patient;

        interface patientDeviceInterface connect treatedPatient.mouth to userInterface;

        perform action therapy[*] ordered : PerformMucusClearanceTherapy {
            in device = mucusClearanceSystem;
            inout patient = treatedPatient;
        }
    }

    requirement <'HLR-001'> primaryTherapeuticFunction {
        doc /* The Lung Flute system shall facilitate mobilization and clearance of 
             * mucus from the patient's airways through generation of controlled 
             * low-frequency acoustic vibrations during exhalation.
             */
        subject system : LungFluteDevice;
    }

    requirement <'SYS-REQ-001'> acousticFrequencyRange {
        doc /* The device shall generate acoustic vibrations with a frequency 
             * between 15 Hz and 22 Hz to effectively mobilize airway mucus.
             */
        subject device : LungFluteDevice;
        assert constraint {
            device.targetFrequency >= 15.0 [Hz] and
            device.targetFrequency <= 22.0 [Hz]
        }
    }

    requirement <'SYS-REQ-002'> backpressureControl {
        doc /* The device shall maintain exhalation backpressure between 
             * 500 Pa and 1500 Pa to ensure therapeutic effectiveness 
             * without causing patient discomfort.
             */
        subject device : LungFluteDevice;
        assert constraint {
            device.targetBackpressure >= 500.0 [Pa] and
            device.targetBackpressure <= 1500.0 [Pa]
        }
    }

    requirement <'SYS-REQ-003'> biocompatibilityRequirement {
        doc /* All patient-contacting surfaces shall be constructed from 
             * biocompatible materials to ensure safety during use.
             */
        subject device : LungFluteDevice;
        assert constraint {
            device.isBiocompatible
        }
    }

    requirement <'SYS-REQ-004'> unidirectionalAirflow {
        doc /* The device shall incorporate a check valve to prevent 
             * inhalation through the device, ensuring unidirectional 
             * exhalation-only airflow.
             */
        subject valve : LungFluteDevice::valve;
    }

    satisfy primaryTherapeuticFunction by mucusClearanceSystem {
        require acousticFrequencyRange;
        require backpressureControl;
        require biocompatibilityRequirement;
        require unidirectionalAirflow;
    }
}
