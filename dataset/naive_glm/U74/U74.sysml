package ICD_System {

    package ValueTypes {
        value def Voltage :> Real { unit 'V'; }
        value def Current :> Real {> Real { unit 'A'; }
        value def Energy :> Real { unit 'J'; }
        value def HeartRate :> Real { unit 'bpm'; }
        value def Duration :> Real { unit 's'; }
        value def Frequency :> Real { unit 'Hz'; }
        value def Percent :> Real { unit '%'; }
    }

    package Items {
        import ValueTypes::*;

        item def ECGSignal {
            attribute amplitude : Voltage;
            attribute sourceChamber : String;
        }
        item def ProcessedECG {
            attribute amplitude : Voltage;
            attribute sampleRate : Frequency;
        }
        item def Diagnosis {
            attribute rhythm : RhythmType;
            attribute detectedRate : HeartRate;
            attribute confidence : Percent;
        }
        item def TherapyCommand {
            attribute therapy : TherapyType;
            attribute energy : Energy;
            attribute pacingRate : HeartRate;
        }
        item def ShockPulse {
            attribute energy : Energy;
            attribute duration : Duration;
        }
        item def PacingPulse {
            attribute amplitude : Voltage;
            attribute rate : HeartRate;
        }
        item def TelemetryData {
            attribute eventLog : String;
            attribute batteryStatus : Percent;
            attribute therapyHistory : String;
        }
        item def ProgrammerCommand {
            attribute parameterName : String;
            attribute parameterValue : Real;
        }
    }

    package Enums {
        enum def RhythmType { normal, ventricularFibrillation, ventricularTachycardia, bradycardia; }
        enum def TherapyType { none, shock, pacing; }
    }

    package Ports {
        import Items::*;
        import Enums::*;

        port def ECGSensingPort {
            out rawECG : ECGSignal;
        }
        port def ProcessedSignalPort {
            in processedECGIn : ProcessedECG;
            out processedECGOut : ProcessedECG;
        }
        port def DiagnosisPort {
            in diagnosisIn : Diagnosis;
            out diagnosisOut : Diagnosis;
        }
        port def TherapyCommandPort {
            in commandIn : TherapyCommand;
            out commandOut : TherapyCommand;
        }
        port def HeartTherapyPort {
            out shock : ShockPulse;
            out pacing : PacingPulse;
        }
        port def TelemetryPort {
            out data : TelemetryData;
            in command : ProgrammerCommand;
        }
    }

    package Parts {
        import ValueTypes::*;
        import Items::*;
        import Enums::*;
        import Ports::*;

        part def BatteryModule {
            attribute nominalVoltage : Voltage = 3.2;
            attribute capacity : Energy = 30;
            attribute remainingCharge : Percent = 100;
            attribute endOfLifeThreshold : Percent = 10;

            action def Discharge {
                in load : Current;
                out remaining : Percent;
            }
        }

        part def SensingCircuit {
            port ecgIn : ECGSensingPort;
            port signalOut : ProcessedSignalPort;
            attribute gain : Real = 100;
            attribute filterBandwidth : Frequency = 200;
            attribute noiseFloor : Voltage = 0.00005;

            action def ProcessSignal {
                in raw : ECGSignal;
                out processed : ProcessedECG;
            }

            perform action process : ProcessSignal;
        }

        part def ArrhythmiaDetector {
            port signalIn : ProcessedSignalPort;
            port diagnosisOut : DiagnosisPort;
            attribute detectionWindow : Duration = 5;
            attribute vfThreshold : HeartRate = 300;
            attribute vtThreshold : HeartRate = 180;
            attribute bradycardiaThreshold : HeartRate = 40;

            action def Analyze {
                in proc : ProcessedECG;
                out diag : Diagnosis;
            }

            perform action analyze : Analyze;
        }

        part def TherapyController {
            port diagnosisIn : DiagnosisPort;
            port commandOut : TherapyCommandPort;
            attribute maxShockEnergy : Energy = 35;
            attribute pacingAmplitude : Voltage = 5;
            attribute pacingRate : HeartRate = 60;

            action def DecideTherapy {
                in diag : Diagnosis;
                out cmd : TherapyCommand;
            }

            perform action decide : DecideTherapy;
        }

        part def HighVoltageTherapyUnit {
            port commandIn : TherapyCommandPort;
            port therapyOut : HeartTherapyPort;
            attribute maxShockEnergy : Energy = 35;
            attribute capacitorVoltage : Voltage = 0;
            attribute chargeTime : Duration = 8;
            attribute pacingPulseAmplitude : Voltage = 5;
            attribute pacingPulseDuration : Duration = 0.0004;

            action def ChargeCapacitor {
                in targetEnergy : Energy;
                out chargedVoltage : Voltage;
            }

            action def DeliverShock {
                in charged : Voltage;
                out shock : ShockPulse;
            }

            action def DeliverPacing {
                out pacing : PacingPulse;
            }

            perform action charge : ChargeCapacitor;
            perform action shock : DeliverShock;
            perform action pace : DeliverPacing;
        }

        part def TelemetryUnit {
            port telemetryPort : TelemetryPort;
            attribute logSize : Integer = 1000;
            attribute transmitFrequency : Frequency = 0.5;

            action def TransmitData {
                out data : TelemetryData;
            }

            action def ReceiveCommand {
                in cmd : ProgrammerCommand;
            }

            perform action transmit : TransmitData;
            perform action receive : ReceiveCommand;
        }

        part def LeadElectrode {
            port sensingPort : ECGSensingPort;
            port therapyPort : HeartTherapyPort;
            attribute impedance : Real = 500;
        }

        part def LeadSystem {
            port heartSensingPort : ECGSensingPort;
            port heartTherapyPort : HeartTherapyPort;
            part atrialLead : LeadElectrode;
            part ventricularLead : LeadElectrode;

            connection atrialSensing connect heartSensingPort.rawECG to atrialLead.sensingPort.rawECG;
            connection ventricularSensing connect heartSensingPort.rawECG to ventricularLead.sensingPort.rawECG;
            connection atrialTherapy connect atrialLead.therapyPort to heartTherapyPort;
            connection ventricularTherapy connect ventricularLead.therapyPort to heartTherapyPort;
        }

        part def Heart {
            port ecgOut : ECGSensingPort;
            port therapyIn : HeartTherapyPort;
            attribute currentRate : HeartRate = 72;
            attribute atrialRate : HeartRate = 72;
            attribute ventricularRate : HeartRate = 72;

            action def GenerateECG {
                out signal : ECGSignal;
            }

            action def RespondToTherapy {
                in shock : ShockPulse;
                in pacing : PacingPulse;
                out newRate : HeartRate;
            }

            perform action generate : GenerateECG;
            perform action respond : RespondToTherapy;
        }

        part def Patient {
            part heart : Heart;
            attribute patientId : String;
        }

        part def ExternalProgrammer {
            port telemetryPort : TelemetryPort;
            attribute physicianId : String;

            action def QueryDevice {
                out cmd : ProgrammerCommand;
                in data : TelemetryData;
            }

            action def AdjustParameters {
                out cmd : ProgrammerCommand;
            }

            perform action query : QueryDevice;
            perform action adjust : AdjustParameters;
        }

        part def ICDDevice {
            port leadConnection : ECGSensingPort;
            port telemetryConnection : TelemetryPort;
            port therapyDelivery : HeartTherapyPort;

            part battery : BatteryModule;
            part sensing : SensingCircuit;
            part detector : ArrhythmiaDetector;
            part therapyController : TherapyController;
            part hvUnit : HighVoltageTherapyUnit;
            part telemetry : TelemetryUnit;

            connection leadToSensing connect leadConnection.rawECG to sensing.ecgIn.rawECG;
            connection sensingToDetector connect sensing.signalOut.processedECGOut to detector.signalIn.processedECGIn;
            connection detectorToController connect detector.diagnosisOut.diagnosisOut to therapyController.diagnosisIn.diagnosisIn;
            connection controllerToHVUnit connect therapyController.commandOut.commandOut to hvUnit.commandIn.commandIn;
            connection hvToTherapyDelivery connect hvUnit.therapyOut to therapyDelivery;
            connection telemetryInternal connect telemetry.telemetryPort to telemetryConnection;

            state def ICDOperatingStates {
                entry; then Monitoring;
                state Monitoring;
                state Analysis;
                state Charging;
                state ShockDelivery;
                state Pacing;
                state TherapyAssessment;

                transition Monitoring_to_Analysis
                    first Monitoring
                    if detector.diagnosisOut.diagnosisOut.rhythm != RhythmType::normal
                    then Analysis;
                transition Analysis_to_Charging
                    first Analysis
                    if therapyController.commandOut.commandOut.therapy == TherapyType::shock
                    then Charging;
                transition Analysis_to_Pacing
                    first Analysis
                    if therapyController.commandOut.commandOut.therapy == TherapyType::pacing
                    then Pacing;
                transition Charging_to_ShockDelivery
                    first Charging
                    if hvUnit.capacitorVoltage >= 750
                    then ShockDelivery;
                transition ShockDelivery_to_Assessment
                    first ShockDelivery
                    then TherapyAssessment;
                transition Pacing_to_Assessment
                    first Pacing
                    then TherapyAssessment;
                transition Assessment_to_Monitoring
                    first TherapyAssessment
                    if detector.diagnosisOut.diagnosisOut.rhythm == RhythmType::normal
                    then Monitoring;
                transition Assessment_to_Analysis
                    first TherapyAssessment
                    if detector.diagnosisOut.diagnosisOut.rhythm != RhythmType::normal
                    then Analysis;
            }

            exhibit state behavior operatingStates : ICDOperatingStates;
        }

        part def ICDSystem {
            part patient : Patient;
            part device : ICDDevice;
            part leads : LeadSystem;
            part programmer : ExternalProgrammer;

            connection heartToLeads connect patient.heart.ecgOut to leads.heartSensingPort;
            connection leadsToSensing connect leads.heartSensingPort.rawECG to device.leadConnection.rawECG;
            connection deviceToLeadsTherapy connect device.therapyDelivery to leads.heartTherapyPort;
            connection leadsToHeartTherapy connect leads.heartTherapyPort to patient.heart.therapyIn;
            connection deviceToProgrammer connect device.telemetryConnection to programmer.telemetryPort;
        }
    }

    package Requirements {
        import ValueTypes::*;
        import Enums::*;
        import Parts::*;

        requirement def ContinuousMonitoringRequirement {
            doc "The ICD shall continuously monitor the patient's heart rhythm via atrial and ventricular sensing."
            subject device : ICDDevice;
            objective {
                device.sensing.ecgIn.rawECG.sourceChamber == "atrial" or
                device.sensing.ecgIn.rawECG.sourceChamber == "ventricular"
            }
        }

        requirement def ArrhythmiaDetectionRequirement {
            doc "The ICD shall detect ventricular fibrillation, ventricular tachycardia, and bradycardia."
            subject detector : ArrhythmiaDetector;
            objective {
                detector.diagnosisOut.diagnosisOut.rhythm in {
                    RhythmType::ventricularFibrillation,
                    RhythmType::ventricularTachycardia,
                    RhythmType::bradycardia
                }
            }
        }

        requirement def ShockTherapyRequirement {
            doc "The ICD shall deliver a high-energy shock of up to 35 J within 10 seconds of detecting a lethal arrhythmia."
            subject hvUnit : HighVoltageTherapyUnit;
            objective {
                hvUnit.maxShockEnergy <= 35 and
                hvUnit.chargeTime <= 10
            }
        }

        requirement def PacingRequirement {
            doc "The ICD shall deliver pacing pulses to maintain a heart rate of at least 60 bpm when bradycardia is detected."
            subject hvUnit : HighVoltageTherapyUnit;
            objective {
                hvUnit.pacingPulseAmplitude >= 5 and
                hvUnit.pacingPulseAmplitude <= 10
            }
        }

        requirement def BatteryLifeRequirement {
            doc "The battery module shall provide at least 5 years of operation under normal conditions."
            subject battery : BatteryModule;
            objective {
                battery.capacity >= 30 and
                battery.remainingCharge > battery.endOfLifeThreshold
            }
        }

        requirement def TelemetryRequirement {
            doc "The ICD shall support wireless telemetry with an external programmer for data review and parameter adjustment."
            subject telemetry : TelemetryUnit;
            objective {
                telemetry.telemetryPort.data.eventLog != null and
                telemetry.telemetryPort.command.parameterName != null
            }
        }

        requirement def StateMachineRequirement {
            doc "The ICD shall operate through monitoring, analysis, charging, shock delivery, pacing, and therapy assessment states."
            subject device : ICDDevice;
            objective {
                device.operatingStates.Monitoring.active or
                device.operatingStates.Analysis.active or
                device.operatingStates.Charging.active or
                device.operatingStates.ShockDelivery.active or
                device.operatingStates.Pacing.active or
                device.operatingStates.TherapyAssessment.active
            }
        }

        requirement def EventLoggingRequirement {
            doc "The ICD shall log all detected arrhythmia events and delivered therapies for diagnostic review."
            subject telemetry : TelemetryUnit;
            objective {
                telemetry.logSize >= 1000
            }
        }

        requirement ICDSystemRequirement {
            doc "The ICD system shall continuously monitor, diagnose, and treat life-threatening cardiac arrhythmias autonomously."
            satisfy ContinuousMonitoringRequirement;
            satisfy ArrhythmiaDetectionRequirement;
            satisfy ShockTherapyRequirement;
            satisfy PacingRequirement;
            satisfy BatteryLifeRequirement;
            satisfy TelemetryRequirement;
            satisfy StateMachineRequirement;
            satisfy EventLoggingRequirement;
        }
    }

    package Behaviors {
        import ValueTypes::*;
        import Items::*;
        import Enums::*;
        import Parts::*;

        action def ICDOperatingCycle {
            in heartSignal : ECGSignal;
            out deliveredTherapy : TherapyType;

            action sense : SensingCircuit::ProcessSignal {
                in raw = heartSignal;
                out processed;
            }
            action analyze : ArrhythmiaDetector::Analyze {
                in proc = sense.processed;
                out diag;
            }
            action decide : TherapyController::DecideTherapy {
                in diag = analyze.diag;
                out cmd;
            }
            fork decide;
            then {
                action charge : HighVoltageTherapyUnit::ChargeCapacitor {
                    in targetEnergy = decide.cmd.energy;
                    out chargedVoltage;
                }
                action shock : HighVoltageTherapyUnit::DeliverShock {
                    in charged = charge.chargedVoltage;
                    out shockPulse;
                }
            } or {
                action pace : HighVoltageTherapyUnit::DeliverPacing {
                    out pacingPulse;
                }
            }
            join;
            then action assess : ArrhythmiaDetector::Analyze {
                in proc = sense.processed;
                out reassessment;
            }
            assign deliveredTherapy = decide.cmd.therapy;
        }
    }

    package PackageStructure {
        import ValueTypes::*;
        import Items::*;
        import Enums::*;
        import Ports::*;
        import Parts::*;
        import Requirements::*;
        import Behaviors::*;
    }

}
