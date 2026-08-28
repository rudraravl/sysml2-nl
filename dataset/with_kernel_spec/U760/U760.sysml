package MachmeterSystemModel {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        attribute def PressureValue :> Real;
        attribute def TemperatureValue :> Real;
        attribute def MachNumberValue :> Real;
        attribute def AltitudeValue :> Real;
        attribute def FrequencyValue :> Real;

        attribute def PowerOnSignal;
        attribute def PowerOffSignal;
        attribute def InitCompleteSignal;
        attribute def InvalidDataFlag;

        part def PitotStaticProbe {
            port pressureOutPort {
                out totalPressure : PressureValue;
                out staticPressure : PressureValue;
            }
        }

        part def TemperatureProbe {
            port tempOutPort {
                out ambientTemp : TemperatureValue;
            }
        }

        part def MachComputationUnit {
            port pressureInPort {
                in totalPressure : PressureValue;
                in staticPressure : PressureValue;
            }
            port tempInPort {
                in ambientTemp : TemperatureValue;
            }
            port machOutPort {
                out machNumber : MachNumberValue;
                out invalidFlag : InvalidDataFlag;
            }
            perform action validatePressure : 'Validate Pressure';
            perform action calculateMach : 'Calculate Mach';
        }

        part def DisplayUnit {
            port machInPort {
                in machNumber : MachNumberValue;
                in invalidFlag : InvalidDataFlag;
            }
            perform action updateDisplay : 'Update Display';
        }

        part def MachmeterSystem {
            attribute altitude : AltitudeValue;
            attribute accuracy : Real;
            attribute updateRate : FrequencyValue;

            part pitotProbe : PitotStaticProbe;
            part tempProbe : TemperatureProbe;
            part computationUnit : MachComputationUnit;
            part display : DisplayUnit;

            exhibit state machmeterStates : MachmeterStates;
        }

        state def MachmeterStates;

        action def 'Validate Pressure' {
            in totalPressure : PressureValue;
            in staticPressure : PressureValue;
            out isValid : Boolean;
        }

        action def 'Calculate Mach' {
            in totalPressure : PressureValue;
            in staticPressure : PressureValue;
            in ambientTemp : TemperatureValue;
            out machNumber : MachNumberValue;
        }

        action def 'Update Display' {
            in machNumber : MachNumberValue;
            in invalidFlag : InvalidDataFlag;
        }

        requirement def MachmeterAccuracyRequirement {
            doc /* The Machmeter shall be highly accurate across flight conditions up to 60,000 ft. */
            subject machmeter : MachmeterSystem;
            constraint { machmeter.altitude <= 60000 implies machmeter.accuracy <= 0.02 }
        }

        requirement def MachmeterUpdateRateRequirement {
            doc /* The display shall update at a rate of at least 10 Hz. */
            subject machmeter : MachmeterSystem;
            constraint { machmeter.updateRate >= 10 }
        }

        requirement def MachmeterDataValidationRequirement {
            doc /* The system shall validate pressure readings and flag invalid conditions. */
            subject machmeter : MachmeterSystem;
        }
    }

    package Usages {
        private import Definitions::*;

        action validatePressure : 'Validate Pressure';
        action calculateMach : 'Calculate Mach';
        action updateDisplay : 'Update Display';

        part machmeterSystem : MachmeterSystem {
            attribute :>> altitude = 0;
            attribute :>> accuracy = 0.01;
            attribute :>> updateRate = 10;

            satisfy MachmeterAccuracyRequirement;
            satisfy MachmeterUpdateRateRequirement;
            satisfy MachmeterDataValidationRequirement;

            flow totalPressureFlow of PressureValue
                from pitotProbe.pressureOutPort.totalPressure to computationUnit.pressureInPort.totalPressure;
            flow staticPressureFlow of PressureValue
                from pitotProbe.pressureOutPort.staticPressure to computationUnit.pressureInPort.staticPressure;
            flow ambientTempFlow of TemperatureValue
                from tempProbe.tempOutPort.ambientTemp to computationUnit.tempInPort.ambientTemp;
            flow machNumberFlow of MachNumberValue
                from computationUnit.machOutPort.machNumber to display.machInPort.machNumber;
            flow invalidFlagFlow of InvalidDataFlag
                from computationUnit.machOutPort.invalidFlag to display.machInPort.invalidFlag;

            state machmeterStates : MachmeterStates {
                entry; then off;
                state off;
                accept PowerOnSignal
                    then initializing;
                state initializing;
                accept InitCompleteSignal
                    then operational;
                state operational {
                    entry; then subsonic;
                    do validatePressure {
                        in totalPressure = computationUnit.pressureInPort.totalPressure;
                        in staticPressure = computationUnit.pressureInPort.staticPressure;
                    }
                    do calculateMach {
                        in totalPressure = computationUnit.pressureInPort.totalPressure;
                        in staticPressure = computationUnit.pressureInPort.staticPressure;
                        in ambientTemp = computationUnit.tempInPort.ambientTemp;
                    }
                    do updateDisplay {
                        in machNumber = computationUnit.machOutPort.machNumber;
                        in invalidFlag = computationUnit.machOutPort.invalidFlag;
                    }

                    state subsonic;
                    accept when computationUnit.machOutPort.machNumber >= 0.8 and computationUnit.machOutPort.machNumber < 1.2
                        then transonic;
                    state transonic;
                    accept when computationUnit.machOutPort.machNumber >= 1.2
                        then supersonic;
                    accept when computationUnit.machOutPort.machNumber < 0.8
                        then subsonic;
                    state supersonic;
                    accept when computationUnit.machOutPort.machNumber < 1.2 and computationUnit.machOutPort.machNumber >= 0.8
                        then transonic;
                }
                accept PowerOffSignal
                    then off;
            }
        }
    }
}
