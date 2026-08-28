package EsophagealDopplerMonitoringSystem {

    import ScalarValues::*;

    package Units {
        unit mm;
        unit cm;
        unit m;
        unit mm2;
        unit kg;
        unit yr;
        unit Hz;
        unit MHz;
        unit mm_per_s;
        unit cm_per_s;
        unit mL;
        unit L;
        unit L_per_min;
        unit bpm;
        unit s;
        unit ms;
        unit pct;
        unit W;
        unit V;
        unit A;
    }

    package ValueTypes {
        import Units::*;

        value type Length_mm = Real { unit = mm; }
        value type Length_cm = Real { unit = cm; }
        value type Length_m = Real { unit = m; }
        value type Area_mm2 = Real { unit = mm2; }
        value type Mass_kg = Real { unit = kg; }
        value type Age_yr = Real { unit = yr; }
        value type Frequency_Hz = Real { unit = Hz; }
        value type Frequency_MHz = Real { unit = MHz; }
        value type Velocity_mm_per_s = Real { unit = mm_per_s; }
        value type Velocity_cm_per_s = Real { unit = cm_per_s; }
        value type Volume_mL = Real { unit = mL; }
        value type Volume_L = Real { unit = L; }
        value type FlowRate_L_per_min = Real { unit = L_per_min; }
        value type HeartRate_bpm = Real { unit = bpm; }
        value type Time_s = Real { unit = s; }
        value type Time_ms = Real { unit = ms; }
        value type Percent = Real { unit = pct; }
        value type Power_W = Real { unit = W; }
        value type Voltage_V = Real { unit = V; }
        value type Current_A = Real { unit = A; }
    }

    package Items {
        import ValueTypes::*;

        item def UltrasoundPulse {
            attribute frequency : Frequency_MHz;
            attribute duration : Time_ms;
            attribute acousticPower : Percent;
        }

        item def EchoSignal {
            attribute amplitude : Real;
            attribute frequencyShift : Frequency_Hz;
            attribute timestamp : Time_s;
            attribute depth : Length_mm;
        }

        item def VelocityWaveform {
            attribute samples : Velocity_mm_per_s[0..*];
            attribute sampleRate : Frequency_Hz;
            attribute signalQuality : Percent;
            attribute windowDuration : Time_s;
        }

        item def PatientData {
            attribute age : Age_yr;
            attribute height : Length_cm;
            attribute weight : Mass_kg;
            attribute sex : String;
        }

        item def HemodynamicParameters {
            attribute strokeVolume : Volume_mL;
            attribute cardiacOutput : FlowRate_L_per_min;
            attribute heartRate : HeartRate_bpm;
            attribute flowTime : Time_s;
            attribute peakVelocity : Velocity_cm_per_s;
            attribute meanVelocity : Velocity_cm_per_s;
        }

        item def DisplayData {
            attribute waveform : VelocityWaveform;
            attribute parameters : HemodynamicParameters;
            attribute alarmStatus : String;
            attribute timestamp : Time_s;
        }

        item def ControlCommand {
            attribute commandType : String;
            attribute value : Real;
        }

        item def PowerSignal {
            attribute voltage : Voltage_V;
            attribute current : Current_A;
        }

        item def AlarmEvent {
            attribute alarmType : String;
            attribute severity : String;
            attribute timestamp : Time_s;
        }
    }

    package Ports {
        import Items::*;

        port def UltrasoundFlowPort {
            out item pulse : UltrasoundPulse;
            in item echo : EchoSignal;
        }

        port def EchoFlowPort {
            out item echo : EchoSignal;
        }

        port def WaveformFlowPort {
            out item waveform : VelocityWaveform;
        }

        port def PatientFlowPort {
            out item patient : PatientData;
        }

        port def ParametersFlowPort {
            out item parameters : HemodynamicParameters;
        }

        port def DisplayFlowPort {
            out item display : DisplayData;
        }

        port def ControlFlowPort {
            out item command : ControlCommand;
            in item status : String;
        }

        port def AlarmFlowPort {
            out item alarm : AlarmEvent;
        }

        port def PowerFlowPort {
            out item power : PowerSignal;
        }
    }

    package Parts {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;

        part def Aorta {
            attribute diameter : Length_mm;
            attribute crossSectionalArea : Area_mm2;
            attribute bloodVelocity : Velocity_cm_per_s;
            port ultrasoundInterface : ~UltrasoundFlowPort;
        }

        part def Patient {
            attribute patientData : PatientData;
            part descendingAorta : Aorta;
        }

        part def UltrasoundTransducer {
            attribute operatingFrequency : Frequency_MHz = 4.0;
            attribute pulseDuration : Time_ms = 1.0;
            attribute elementCount : Integer = 4;
            port ultrasoundPort : UltrasoundFlowPort;
            port echoDataOut : EchoFlowPort;
            port powerIn : ~PowerFlowPort;
            port controlIn : ~ControlFlowPort;

            action def EmitPulse {
                out pulse : UltrasoundPulse;
            }
            action def ReceiveEcho {
                in echo : EchoSignal;
                out echoData : EchoSignal;
            }
            action def Transduce {
                in pulse : UltrasoundPulse;
                out echo : EchoSignal;
            }

            perform emit : EmitPulse;
            perform transduce : Transduce;
            perform receive : ReceiveEcho;

            flow from emit.pulse to ultrasoundPort.pulse;
            flow from ultrasoundPort.echo to transduce.pulse;
            flow from transduce.echo to receive.echo;
            flow from receive.echoData to echoDataOut.echo;
        }

        part def EsophagealProbe {
            attribute totalLength : Length_cm = 100.0;
            attribute outerDiameter : Length_mm = 5.0;
            attribute flexibilityRating : Percent = 85.0;
            attribute insertionDepth : Length_cm;
            part transducer : UltrasoundTransducer;
            port powerIn : ~PowerFlowPort;
            port controlIn : ~ControlFlowPort;
            connection powerPass connect powerIn to transducer.powerIn;
            connection controlPass connect controlIn to transducer.controlIn;
        }

        part def SignalProcessingUnit {
            attribute samplingRate : Frequency_Hz = 1000.0;
            attribute filterBandwidth : Frequency_Hz = 500.0;
            attribute minSignalQuality : Percent = 70.0;
            port echoDataIn : ~EchoFlowPort;
            port waveformOut : WaveformFlowPort;
            port powerIn : ~PowerFlowPort;
            port controlIn : ~ControlFlowPort;

            action def CleanSignal {
                in rawEcho : EchoSignal;
                out cleanedEcho : EchoSignal;
            }
            action def AnalyzeDopplerShift {
                in echo : EchoSignal;
                out velocity : Velocity_mm_per_s;
            }
            action def GenerateWaveform {
                in velocity : Velocity_mm_per_s;
                out waveform : VelocityWaveform;
            }
            action def AssessQuality {
                in waveform : VelocityWaveform;
                out quality : Percent;
            }

            perform clean : CleanSignal;
            perform analyze : AnalyzeDopplerShift;
            perform generate : GenerateWaveform;
            perform assess : AssessQuality;

            flow from echoDataIn.echo to clean.rawEcho;
            flow from clean.cleanedEcho to analyze.echo;
            flow from analyze.velocity to generate.velocity;
            flow from generate.waveform to assess.waveform;
            flow from generate.waveform to waveformOut.waveform;
        }

        part def HemodynamicCalculator {
            attribute estimatedAortaDiameter : Length_mm;
            attribute aortaCrossSectionalArea : Area_mm2;
            port waveformIn : ~WaveformFlowPort;
            port patientDataIn : ~PatientFlowPort;
            port parametersOut : ParametersFlowPort;
            port powerIn : ~PowerFlowPort;
            port controlIn : ~ControlFlowPort;

            action def EstimateAortaDiameter {
                in patient : PatientData;
                out diameter : Length_mm;
            }
            action def ComputeCrossSectionalArea {
                in diameter : Length_mm;
                out area : Area_mm2;
            }
            action def ComputeStrokeVolume {
                in waveform : VelocityWaveform;
                in area : Area_mm2;
                out strokeVolume : Volume_mL;
            }
            action def ComputeHeartRate {
                in waveform : VelocityWaveform;
                out heartRate : HeartRate_bpm;
            }
            action def ComputeCardiacOutput {
                in strokeVolume : Volume_mL;
                in heartRate : HeartRate_bpm;
                out cardiacOutput : FlowRate_L_per_min;
            }
            action def ComputeFlowTime {
                in waveform : VelocityWaveform;
                out flowTime : Time_s;
            }
            action def ComputePeakVelocity {
                in waveform : VelocityWaveform;
                out peakVelocity : Velocity_cm_per_s;
            }
            action def AssembleParameters {
                in strokeVolume : Volume_mL;
                in cardiacOutput : FlowRate_L_per_min;
                in heartRate : HeartRate_bpm;
                in flowTime : Time_s;
                in peakVelocity : Velocity_cm_per_s;
                out parameters : HemodynamicParameters;
            }

            perform estimateDiameter : EstimateAortaDiameter;
            perform computeArea : ComputeCrossSectionalArea;
            perform computeSV : ComputeStrokeVolume;
            perform computeHR : ComputeHeartRate;
            perform computeCO : ComputeCardiacOutput;
            perform computeFT : ComputeFlowTime;
            perform computePV : ComputePeakVelocity;
            perform assemble : AssembleParameters;

            flow from patientDataIn.patient to estimateDiameter.patient;
            flow from estimateDiameter.diameter to computeArea.diameter;
            flow from computeArea.area to computeSV.area;
            flow from waveformIn.waveform to computeSV.waveform;
            flow from waveformIn.waveform to computeHR.waveform;
            flow from waveformIn.waveform to computeFT.waveform;
            flow from waveformIn.waveform to computePV.waveform;
            flow from computeSV.strokeVolume to computeCO.strokeVolume;
            flow from computeHR.heartRate to computeCO.heartRate;
            flow from computeSV.strokeVolume to assemble.strokeVolume;
            flow from computeCO.cardiacOutput to assemble.cardiacOutput;
            flow from computeHR.heartRate to assemble.heartRate;
            flow from computeFT.flowTime to assemble.flowTime;
            flow from computePV.peakVelocity to assemble.peakVelocity;
            flow from assemble.parameters to parametersOut.parameters;
        }

        part def DisplayUnit {
            attribute screenBrightness : Percent = 70.0;
            attribute refreshRate : Frequency_Hz = 60.0;
            attribute displayResolution : String = "1024x768";
            port waveformIn : ~WaveformFlowPort;
            port parametersIn : ~ParametersFlowPort;
            port alarmIn : ~AlarmFlowPort;
            port powerIn : ~PowerFlowPort;
            port controlIn : ~ControlFlowPort;

            action def RenderWaveform {
                in waveform : VelocityWaveform;
            }
            action def RenderParameters {
                in parameters : HemodynamicParameters;
            }
            action def RenderAlarm {
                in alarm : AlarmEvent;
            }
            action def UpdateScreen {
                in waveform : VelocityWaveform;
                in parameters : HemodynamicParameters;
                in alarm : AlarmEvent;
            }

            perform update : UpdateScreen;

            flow from waveformIn.waveform to update.waveform;
            flow from parametersIn.parameters to update.parameters;
            flow from alarmIn.alarm to update.alarm;
        }

        part def ControlModule {
            attribute systemMode : String = "Off";
            attribute powerOn : Boolean = false;
            attribute startMonitoring : Boolean = false;
            attribute stopMonitoring : Boolean = false;
            attribute faultDetected : Boolean = false;
            attribute faultCleared : Boolean = false;
            attribute signalQualityThreshold : Percent = 70.0;
            port controlOut : ControlFlowPort;
            port alarmOut : AlarmFlowPort;
            port patientDataOut : PatientFlowPort;
            port powerIn : ~PowerFlowPort;

            action def EvaluateSignalQuality {
                in quality : Percent;
                out alarmTrigger : Boolean;
            }
            action def ProcessUserInput {
                in input : String;
                out command : ControlCommand;
            }
            action def MonitorFaults {
                out fault : Boolean;
            }
            action def GenerateAlarm {
                in trigger : Boolean;
                out alarm : AlarmEvent;
            }

            perform evaluateQuality : EvaluateSignalQuality;
            perform processInput : ProcessUserInput;
            perform monitorFaults : MonitorFaults;
            perform generateAlarm : GenerateAlarm;

            flow from evaluateQuality.alarmTrigger to generateAlarm.trigger;
            flow from generateAlarm.alarm to alarmOut.alarm;

            state machine controlSM {
                initial state Off {
                    entry { systemMode = "Off"; }
                }
                state Standby {
                    entry { systemMode = "Standby"; }
                }
                state Monitoring {
                    entry { systemMode = "Monitoring"; }
                    do { /* continuous acquisition, processing, calculation, and display update cycle */ }
                    exit { systemMode = "Standby"; }
                }
                state Fault {
                    entry { systemMode = "Fault"; }
                }
                transition off_to_standby Off to Standby when powerOn;
                transition standby_to_monitoring Standby to Monitoring when startMonitoring;
                transition monitoring_to_standby Monitoring to Standby when stopMonitoring;
                transition off_to_fault Off to Fault when faultDetected;
                transition standby_to_fault Standby to Fault when faultDetected;
                transition monitoring_to_fault Monitoring to Fault when faultDetected;
                transition fault_to_standby Fault to Standby when faultCleared;
            }
        }

        part def PowerSupply {
            attribute inputVoltage : Voltage_V = 220.0;
            attribute outputVoltage : Voltage_V = 12.0;
            attribute maxPower : Power_W = 100.0;
            attribute isOn : Boolean = false;
            port powerOut : PowerFlowPort;

            action def SupplyPower {
                out power : PowerSignal;
            }
            action def PowerOnAction {
                out status : Boolean;
            }
            action def PowerOffAction {}

            perform supply : SupplyPower;
            perform powerOnAct : PowerOnAction;
            perform powerOffAct : PowerOffAction;

            flow from supply.power to powerOut.power;
        }

        part def EsophagealDopplerMonitor {
            attribute systemName : String = "Esophageal Doppler Monitor";
            attribute manufacturer : String = "Medical Devices Inc.";
            attribute modelNumber : String = "EDM-2000";

            part patient : Patient;
            part probe : EsophagealProbe;
            part signalProcessor : SignalProcessingUnit;
            part hemodynamicCalculator : HemodynamicCalculator;
            part display : DisplayUnit;
            part controller : ControlModule;
            part powerSupply : PowerSupply;

            connection powerToProbe connect powerSupply.powerOut to probe.powerIn;
            connection powerToSignalProcessor connect powerSupply.powerOut to signalProcessor.powerIn;
            connection powerToHemodynamic connect powerSupply.powerOut to hemodynamicCalculator.powerIn;
            connection powerToDisplay connect powerSupply.powerOut to display.powerIn;
            connection powerToController connect powerSupply.powerOut to controller.powerIn;

            connection echoToProcessor connect probe.transducer.echoDataOut to signalProcessor.echoDataIn;
            connection waveformToCalculator connect signalProcessor.waveformOut to hemodynamicCalculator.waveformIn;
            connection waveformToDisplay connect signalProcessor.waveformOut to display.waveformIn;
            connection parametersToDisplay connect hemodynamicCalculator.parametersOut to display.parametersIn;
            connection alarmToDisplay connect controller.alarmOut to display.alarmIn;

            connection controlToProbe connect controller.controlOut to probe.controlIn;
            connection controlToSignalProcessor connect controller.controlOut to signalProcessor.controlIn;
            connection controlToHemodynamic connect controller.controlOut to hemodynamicCalculator.controlIn;
            connection controlToDisplay connect controller.controlOut to display.controlIn;

            connection patientDataToCalculator connect controller.patientDataOut to hemodynamicCalculator.patientDataIn;

            connection ultrasoundToAorta connect probe.transducer.ultrasoundPort to patient.descendingAorta.ultrasoundInterface;
        }
    }

    package Requirements {
        import ValueTypes::*;
        import Items::*;

        requirement def SystemRequirement {
            attribute id : String;
            attribute text : String;
        }

        requirement def PerformanceRequirement {
            attribute id : String;
            attribute text : String;
        }

        requirement def SafetyRequirement {
            attribute id : String;
            attribute text : String;
        }

        requirement SystemShallMonitorHeartFunction : SystemRequirement {
            attribute id = "REQ-001";
            attribute text = "The system shall continuously assess the patient's heart function and fluid status in clinical settings such as surgery or intensive care.";
        }

        requirement ProbeShallBeMinimallyInvasive : SafetyRequirement {
            attribute id = "REQ-002";
            attribute text = "The esophageal probe shall be thin and flexible for safe, minimally invasive insertion into the patient's esophagus.";
            attribute maxOuterDiameter : Length_mm = 6.0;
            attribute minFlexibility : Percent = 80.0;
        }

        requirement TransducerShallEmitUltrasound : PerformanceRequirement {
            attribute id = "REQ-003";
            attribute text = "The ultrasound transducer shall emit high-frequency ultrasound pulses into the descending aorta and capture returning echoes from moving red blood cells.";
            attribute minFrequency : Frequency_MHz = 2.0;
            attribute maxFrequency : Frequency_MHz = 8.0;
        }

        requirement SignalProcessorShallComputeVelocity : PerformanceRequirement {
            attribute id = "REQ-004";
            attribute text = "The signal processing unit shall clean the echo signal, analyze the Doppler shift to calculate blood velocity, generate a real-time velocity waveform, and continuously assess signal quality.";
            attribute minSamplingRate : Frequency_Hz = 500.0;
            attribute minSignalQuality : Percent = 70.0;
        }

        requirement HemodynamicCalculatorShallComputeParameters : SystemRequirement {
            attribute id = "REQ-005";
            attribute text = "The hemodynamic calculator shall compute stroke volume, cardiac output, heart rate, and flow time using the blood velocity waveform and patient-specific data including age, height, and weight.";
        }

        requirement DisplayShallShowRealtimeData : PerformanceRequirement {
            attribute id = "REQ-006";
            attribute text = "The display unit shall show a real-time graph of the blood velocity waveform alongside key calculated hemodynamic parameters.";
            attribute minRefreshRate : Frequency_Hz = 30.0;
        }

        requirement ControlModuleShallManageOperation : SystemRequirement {
            attribute id = "REQ-007";
            attribute text = "The control module shall manage the system's overall operation, process user inputs, and monitor for faults or poor signal conditions.";
        }

        requirement SystemShallAlarmOnPoorSignal : SafetyRequirement {
            attribute id = "REQ-008";
            attribute text = "The system shall trigger an alarm when signal quality falls below an acceptable threshold or when a fault is detected.";
            attribute signalQualityThreshold : Percent = 70.0;
        }

        requirement SystemShallHaveOperatingModes : SystemRequirement {
            attribute id = "REQ-009";
            attribute text = "The system shall operate in Off, Standby, Monitoring, and Fault states, transitioning based on power state, user commands, and fault conditions.";
        }

        requirement PowerSupplyShallProvidePower : PerformanceRequirement {
            attribute id = "REQ-010";
            attribute text = "The power supply shall provide stable power to all system components.";
            attribute outputVoltage : Voltage_V = 12.0;
            attribute maxPower : Power_W = 100.0;
        }

        requirement SystemShallUsePatientData : SystemRequirement {
            attribute id = "REQ-011";
            attribute text = "The system shall use patient-specific data including age, height, and weight to estimate the aortic diameter for hemodynamic calculations.";
        }

        requirement SystemShallProvideBeatByBeatUpdate : PerformanceRequirement {
            attribute id = "REQ-012";
            attribute text = "The system shall provide a live, beat-by-beat view of the patient's cardiovascular performance during monitoring.";
        }
    }
}
