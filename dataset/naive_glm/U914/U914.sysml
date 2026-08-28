package ThinFilmDepositionControl {

    // ---- Value types with units ----
    package Units {
        import ISQ::*;
        import ScalarValues::*;

        type FrequencyDef :> Real { :>> unit = 'Hz'; }
        type Frequency = FrequencyDef;

        type ThicknessDef :> Real { :>> unit = 'nm'; }
        type Thickness = ThicknessDef;

        type MassDef :> Real { :>> unit = 'kg'; }
        type Mass = MassDef;

        type DensityDef :> Real { :>> unit = 'kg/m^3'; }
        type Density = DensityDef;

        type AcousticImpedanceDef :> Real { :>> unit = 'kg/(m^2*s)'; }
        type AcousticImpedance = AcousticImpedanceDef;

        type DepositionRateDef :> Real { :>> unit = 'nm/s'; }
        type DepositionRate = DepositionRateDef;

        type TimeDef :> Real { :>> unit = 's'; }
        type Time = TimeDef;

        type DimensionlessDef :> Real { :>> unit = '1'; }
        type Dimensionless = DimensionlessDef;
    }

    // ---- Item types ----
    package Items {
        import Units::*;

        item def FrequencyReading {
            attribute value : Frequency;
            attribute timestamp : Time;
        }

        item def ThicknessReading {
            attribute thickness : Thickness;
            attribute rate : DepositionRate;
            attribute timestamp : Time;
        }

        item def MaterialProperties {
            attribute density : Density;
            attribute acousticImpedance : AcousticImpedance;
            attribute name : String;
        }

        item def ShutterCommand {
            attribute close : Boolean;
        }

        item def ProcessParameters {
            attribute targetThickness : Thickness;
            attribute tolerance : Thickness;
        }

        item def DisplayData {
            attribute thickness : Thickness;
            attribute rate : DepositionRate;
            attribute targetThickness : Thickness;
            attribute shutterClosed : Boolean;
        }

        item def VaporFlux {
            attribute materialName : String;
        }
    }

    // ---- Port definitions ----
    package Ports {
        import Items::*;

        port def FrequencyOut {
            out freqReading : FrequencyReading;
        }

        port def FrequencyIn {
            in freqReading : FrequencyReading;
        }

        port def ThicknessOut {
            out thicknessReading : ThicknessReading;
        }

        port def ThicknessIn {
            in thicknessReading : ThicknessReading;
        }

        port def ShutterCmdOut {
            out cmd : ShutterCommand;
        }

        port def ShutterCmdIn {
            in cmd : ShutterCommand;
        }

        port def DisplayDataOut {
            out data : DisplayData;
        }

        port def DisplayDataIn {
            in data : DisplayData;
        }

        port def MaterialPropsOut {
            out props : MaterialProperties;
        }

        port def MaterialPropsIn {
            in props : MaterialProperties;
        }

        port def ProcessParamsOut {
            out params : ProcessParameters;
        }

        port def ProcessParamsIn {
            in params : ProcessParameters;
        }

        port def VaporFluxPort {
            out flux : VaporFlux;
        }
    }

    // ---- Requirements ----
    package Requirements {
        import Units::*;
        import Items::*;

        requirement def ThicknessAccuracyRequirement {
            attribute requiredAccuracy : Thickness = 1.0 [nm];
            subject measurement : ThicknessReading;
            require { measurement.thickness <= requiredAccuracy }
        }

        requirement def RealTimeMonitoringRequirement {
            attribute maxLatency : Time = 0.1 [s];
            require { /* latency from sensor to display <= maxLatency */ }
        }

        requirement def AutoStopRequirement {
            subject target : Thickness;
            subject measured : Thickness;
            subject tolerance : Thickness;
            require { abs(measured - target) <= tolerance }
        }

        requirement def DepositionRateRequirement {
            attribute minRate : DepositionRate = 0.01 [nm/s];
            attribute maxRate : DepositionRate = 10.0 [nm/s];
            subject rate : DepositionRate;
            require { rate >= minRate and rate <= maxRate }
        }
    }

    // ---- Parts ----
    package Components {
        import Units::*;
        import Items::*;
        import Ports::*;

        part def QuartzCrystalSensor {
            attribute initialFrequency : Frequency = 6.0e6 [Hz];
            attribute currentFrequency : Frequency;
            attribute accumulatedMass : Mass = 0.0 [kg];

            port freqOut : FrequencyOut;

            action def SenseFrequency {
                in crystalFreq : Frequency;
                out reading : FrequencyReading;
            }

            action sense : SenseFrequency {
                in crystalFreq = currentFrequency;
                out reading -> freqOut.freqReading;
            }

            state defenum SensorState {
                entry; then Idle;
                state Idle;
                state Sensing {
                    entry { send sense; }
                }
                transition Idle to Sensing when trigger;
                transition Sensing to Idle when stop;
            }

            attribute trigger : Boolean = false;
            attribute stop : Boolean = false;
        }

        part def FrequencyCounter {
            attribute measuredFrequency : Frequency;
            attribute resolution : Frequency = 0.01 [Hz];
            attribute samplingInterval : Time = 0.05 [s];

            port freqIn : FrequencyIn;
            port freqOut : FrequencyOut;

            action def CountFrequency {
                in raw : FrequencyReading;
                out counted : FrequencyReading;
            }

            action count : CountFrequency {
                in raw = freqIn.freqReading;
                out counted -> freqOut.freqReading;
            }

            state defenum CounterState {
                entry; then Waiting;
                state Waiting;
                state Counting {
                    entry { send count; }
                }
                transition Waiting to Counting when freqIn.freqReading@;
                transition Counting to Waiting when done;
            }

            attribute done : Boolean = false;
        }

        part def ThicknessCalculator {
            attribute materialProps : MaterialProperties;
            attribute lastThickness : Thickness = 0.0 [nm];
            attribute lastRate : DepositionRate = 0.0 [nm/s];
            attribute lastTimestamp : Time = 0.0 [s];

            port freqIn : FrequencyIn;
            port propsIn : MaterialPropsIn;
            port thicknessOut : ThicknessOut;

            action def CalculateThickness {
                in freqReading : FrequencyReading;
                in props : MaterialProperties;
                out thicknessReading : ThicknessReading;

                private attribute deltaF : Frequency;
                private attribute deltaT : Time;
            }

            action calculate : CalculateThickness {
                in freqReading = freqIn.freqReading;
                in props = propsIn.props;
                out thicknessReading -> thicknessOut.thicknessReading;
            }

            state defenum CalcState {
                entry; then Ready;
                state Ready;
                state Calculating {
                    entry { send calculate; }
                }
                transition Ready to Calculating when freqIn.freqReading@;
                transition Calculating to Ready when complete;
            }

            attribute complete : Boolean = false;
        }

        part def ProcessController {
            attribute processParams : ProcessParameters;
            attribute shutterClosed : Boolean = false;
            attribute measuredThickness : Thickness = 0.0 [nm];
            attribute measuredRate : DepositionRate = 0.0 [nm/s];

            port thicknessIn : ThicknessIn;
            port paramsIn : ProcessParamsIn;
            port shutterCmdOut : ShutterCmdOut;
            port displayOut : DisplayDataOut;

            action def EvaluateThickness {
                in reading : ThicknessReading;
                in params : ProcessParameters;
                out cmd : ShutterCommand;
                out display : DisplayData;
            }

            action evaluate : EvaluateThickness {
                in reading = thicknessIn.thicknessReading;
                in params = paramsIn.params;
                out cmd -> shutterCmdOut.cmd;
                out display -> displayOut.data;
            }

            state defenum ControllerState {
                entry; then Monitoring;
                state Monitoring {
                    entry { send evaluate; }
                }
                state TargetReached {
                    entry { shutterClosed = true; }
                }
                transition Monitoring to TargetReached
                    when thicknessIn.thicknessReading.thickness >= paramsIn.params.targetThickness - paramsIn.params.tolerance;
            }
        }

        part def Shutter {
            attribute isOpen : Boolean = true;
            attribute actuationTime : Time = 0.2 [s];

            port cmdIn : ShutterCmdIn;
            port fluxIn : VaporFluxPort;
            port fluxOut : VaporFluxPort;

            action def ActuateShutter {
                in cmd : ShutterCommand;
                out flux : VaporFlux;
            }

            action actuate : ActuateShutter {
                in cmd = cmdIn.cmd;
                out flux -> fluxOut.flux;
            }

            state defenum ShutterState {
                entry; then Open;
                state Open {
                    entry { isOpen = true; }
                }
                state Closed {
                    entry { isOpen = false; }
                }
                transition Open to Closed when cmdIn.cmd.close@;
            }
        }

        part def DisplayUnit {
            attribute displayedThickness : Thickness = 0.0 [nm];
            attribute displayedRate : DepositionRate = 0.0 [nm/s];
            attribute displayedTarget : Thickness = 0.0 [nm];
            attribute refreshRate : Time = 0.1 [s];

            port displayIn : DisplayDataIn;

            action def UpdateDisplay {
                in data : DisplayData;
            }

            action update : UpdateDisplay {
                in data = displayIn.data;
            }

            state defenum DisplayState {
                entry; then Active;
                state Active {
                    entry { send update; }
                }
            }
        }

        part def MaterialSource {
            attribute materialName : String = "SiO2";
            attribute materialProps : MaterialProperties;

            port propsOut : MaterialPropsOut;
            port fluxOut : VaporFluxPort;

            action def EmitVapor {
                out flux : VaporFlux;
            }

            action emit : EmitVapor {
                out flux -> fluxOut.flux;
            }

            state defenum SourceState {
                entry; then Off;
                state Off;
                state Evaporating {
                    entry { send emit; }
                }
                transition Off to Evaporating when start;
                transition Evaporating to Off when stop;
            }

            attribute start : Boolean = false;
            attribute stop : Boolean = false;
        }

        part def OperatorConsole {
            attribute targetThickness : Thickness = 500.0 [nm];
            attribute tolerance : Thickness = 2.0 [nm];

            port paramsOut : ProcessParamsOut;

            action def SetParameters {
                out params : ProcessParameters;
            }

            action configure : SetParameters {
                out params -> paramsOut.params;
            }
        }
    }

    // ---- System assembly ----
    package System {
        import Units::*;
        import Items::*;
        import Ports::*;
        import Components::*;

        part def DepositionChamber {
            attribute chamberPressure : Real = 1.0e-6;
            attribute substrateName : String = "SemiconductorWafer";

            port fluxIn : VaporFluxPort;
        }

        part def ThinFilmDepositionSystem {
            part operatorConsole : OperatorConsole;
            part materialSource : MaterialSource;
            part shutter : Shutter;
            part chamber : DepositionChamber;
            part crystalSensor : QuartzCrystalSensor;
            part frequencyCounter : FrequencyCounter;
            part thicknessCalculator : ThicknessCalculator;
            part processController : ProcessController;
            part displayUnit : DisplayUnit;

            // Material properties flow
            connection materialSource.propsOut to thicknessCalculator.propsIn;

            // Process parameters flow
            connection operatorConsole.paramsOut to processController.paramsIn;

            // Vapor flux path: source -> shutter -> chamber
            connection materialSource.fluxOut to shutter.fluxIn;
            connection shutter.fluxOut to chamber.fluxIn;

            // Frequency measurement chain
            connection crystalSensor.freqOut to frequencyCounter.freqIn;
            connection frequencyCounter.freqOut to thicknessCalculator.freqIn;

            // Thickness data to controller
            connection thicknessCalculator.thicknessOut to processController.thicknessIn;

            // Shutter command from controller
            connection processController.shutterCmdOut to shutter.cmdIn;

            // Display data from controller
            connection processController.displayOut to displayUnit.displayIn;

            // Requirements satisfaction
            satisfy Requirements::ThicknessAccuracyRequirement {
                subject measurement = thicknessCalculator.thicknessOut.thicknessReading;
            }
            satisfy Requirements::AutoStopRequirement {
                subject target = processController.paramsIn.params.targetThickness;
                subject measured = processController.thicknessIn.thicknessReading.thickness;
                subject tolerance = processController.paramsIn.params.tolerance;
            }
            satisfy Requirements::RealTimeMonitoringRequirement {
                /* end-to-end latency from crystalSensor to displayUnit */
            }
            satisfy Requirements::DepositionRateRequirement {
                subject rate = thicknessCalculator.thicknessOut.thicknessReading.rate;
            }
        }
    }
}
