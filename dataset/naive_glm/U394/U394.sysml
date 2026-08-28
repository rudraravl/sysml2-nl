package EmergencyMedicalResponseSystem {
    import ScalarValues::*;

    // ============ Units ============
    unit bpm;
    unit mmHg;
    unit km;
    unit min;
    unit liter;
    unit watt;
    unit percent;

    // ============ Value Types ============
    value type HeartRate :> Real { unit bpm; }
    value type SystolicPressure :> Real { unit mmHg; }
    value type DiastolicPressure :> Real { unit mmHg; }
    value type Distance :> Real { unit km; }
    value type ElapsedTime :> Real { unit min; }
    value type PowerLevel :> Real { unit watt; }
    value type Volume :> Real { unit liter; }
    value type Percentage :> Real { unit percent; }

    // ============ Enumerations ============
    enum def IncidentType {
        cardiac;
        trauma;
        respiratory;
        pediatric;
        fire;
        mva;
    }

    enum def PriorityLevel {
        priority1;
        priority2;
        priority3;
    }

    enum def SquadStatus {
        inService;
        dispatched;
        enRoute;
        onScene;
        transporting;
        atHospital;
        returning;
    }

    enum def TreatmentLevel {
        standard;
        advanced;
    }

    // ============ Item Definitions ============
    item def EmergencyCall {
        attribute callId : String;
        attribute callerName : String;
        attribute location : String;
        attribute incidentType : IncidentType;
        attribute priority : PriorityLevel;
        attribute description : String;
        attribute callReceivedTime : ElapsedTime;
    }

    item def DispatchOrder {
        attribute orderId : String;
        attribute callId : String;
        attribute sceneLocation : String;
        attribute incidentType : IncidentType;
        attribute priority : PriorityLevel;
        attribute dispatchTime : ElapsedTime;
    }

    item def PatientVitals {
        attribute heartRate : HeartRate;
        attribute systolicBP : SystolicPressure;
        attribute diastolicBP : DiastolicPressure;
        attribute respiratoryRate : Integer;
        attribute oxygenSaturation : Percentage;
        attribute timestamp : ElapsedTime;
    }

    item def MedicalOrder {
        attribute orderId : String;
        attribute orderText : String;
        attribute authorizedProcedure : String;
        attribute orderingPhysician : String;
        attribute timestamp : ElapsedTime;
    }

    item def Patient {
        attribute patientId : String;
        attribute name : String;
        attribute age : Integer;
        attribute chiefComplaint : String;
        attribute treatmentLevel : TreatmentLevel := TreatmentLevel::standard;
        attribute vitalsHistory : PatientVitals[0..*];
    }

    item def CareTransferReport {
        attribute patientId : String;
        attribute patientName : String;
        attribute finalVitals : PatientVitals;
        attribute treatmentsAdministered : String[0..*];
        attribute transferTime : ElapsedTime;
        attribute receivingPhysician : String;
    }

    item def StatusReport {
        attribute squadId : String;
        attribute status : SquadStatus;
        attribute timestamp : ElapsedTime;
        attribute location : String;
    }

    // ============ Port Definitions ============
    port def DispatchPort {
        in dispatchOrder : DispatchOrder;
        out acknowledgement : Boolean;
        out statusUpdate : StatusReport;
    }

    port def HospitalCommPort {
        in medicalOrder : MedicalOrder;
        out vitalsTransmission : PatientVitals;
        out careTransfer : CareTransferReport;
    }

    port def RadioPort {
        in incomingMessage : String;
        out outgoingMessage : String;
    }

    // ============ Medical Equipment ============
    part def Defibrillator {
        attribute deviceId : String;
        attribute maxCharge : PowerLevel = 360.0;
        attribute currentCharge : PowerLevel = 0.0;
        attribute batteryLevel : Percentage = 100.0;

        action def chargeDevice {
            in targetEnergy : PowerLevel;
            out chargedEnergy : PowerLevel;
        }

        action def deliverShock {
            in energy : PowerLevel;
        }

        action def analyzeRhythm {
            out shockAdvised : Boolean;
        }
    }

    part def OxygenTank {
        attribute tankId : String;
        attribute capacity : Volume = 680.0;
        attribute currentLevel : Volume = 680.0;
        attribute flowRate : Real = 0.0;

        action def regulateFlow {
            in targetFlow : Real;
            out actualFlow : Real;
        }
    }

    part def FirstAidKit {
        attribute kitId : String;
        attribute bandageCount : Integer = 50;
        attribute gauzeRolls : Integer = 20;
        attribute antisepticPackets : Integer = 30;
        attribute tourniquets : Integer = 4;
        attribute splints : Integer = 6;
    }

    part def RescueTools {
        attribute hydraulicCutterPresent : Boolean = true;
        attribute spreaderPresent : Boolean = true;
        attribute ropeLength : Distance = 50.0;
        attribute haliganBar : Boolean = true;
    }

    part def MedicalMonitor {
        attribute monitorId : String;
        attribute powered : Boolean = false;
        attribute currentVitals : PatientVitals;

        action def monitorVitals {
            in patient : Patient;
            out vitals : PatientVitals;
        }
    }

    part def IVKit {
        attribute kitId : String;
        attribute catheterSizes : String[0..*] = {"14G", "16G", "18G", "20G"};
        attribute salineBags : Integer = 4;
    }

    // ============ Personnel ============
    part def Paramedic {
        attribute name : String;
        attribute badgeId : String;
        attribute certificationLevel : String;
        attribute yearsExperience : Integer;

        action def assessPatient {
            in patient : Patient;
            out vitals : PatientVitals;
            out treatmentLevel : TreatmentLevel;
        }

        action def administerTreatment {
            in patient : Patient;
            in order : MedicalOrder[0..1];
            out treatedPatient : Patient;
        }
    }

    part def ParamedicCaptain :> Paramedic {
        attribute hasCommandAuthority : Boolean = true;

        action def makeSceneCommandDecision {
            in patient : Patient;
            in vitals : PatientVitals;
            out treatmentLevel : TreatmentLevel;
            out contactHospital : Boolean;
        }
    }

    // ============ Rescue Vehicle ============
    part def RescueVehicle {
        attribute vehicleId : String;
        attribute fuelLevel : Percentage = 100.0;
        attribute odometer : Distance = 0.0;
        attribute engineRunning : Boolean = false;

        part defibrillator : Defibrillator;
        part oxygenTank : OxygenTank;
        part firstAidKit : FirstAidKit;
        part rescueTools : RescueTools;
        part medicalMonitor : MedicalMonitor;
        part ivKit : IVKit;

        action def startEngine {
            out started : Boolean;
        }

        action def driveTo {
            in destination : String;
            in distance : Distance;
            out arrived : Boolean;
        }
    }

    // ============ Action Definitions ============
    action def ReceiveDispatch {
        in dispatchOrder : DispatchOrder;
        out acknowledged : Boolean;
    }

    action def RespondToScene {
        in sceneLocation : String;
        in distance : Distance;
        out arrivedAtScene : Boolean;
    }

    action def OnSceneAssessment {
        in patient : Patient;
        out vitals : PatientVitals;
        out treatmentLevel : TreatmentLevel;
        out hospitalContactNeeded : Boolean;

        action measureVitals {
            in patient : Patient;
            out vitals : PatientVitals;
        }

        action evaluateSeverity {
            in vitals : PatientVitals;
            out treatmentLevel : TreatmentLevel;
            out hospitalContactNeeded : Boolean;
        }

        flow from measureVitals.vitals to evaluateSeverity.vitals;
        flow from measureVitals.vitals to out vitals;
        flow from evaluateSeverity.treatmentLevel to out treatmentLevel;
        flow from evaluateSeverity.hospitalContactNeeded to out hospitalContactNeeded;
    }

    action def ContactHospitalForOrders {
        in vitals : PatientVitals;
        in patient : Patient;
        out medicalOrder : MedicalOrder;
    }

    action def StabilizePatient {
        in patient : Patient;
        in order : MedicalOrder[0..1];
        in treatmentLevel : TreatmentLevel;
        out stabilizedPatient : Patient;

        action performStandardCare {
            in patient : Patient;
            out treatedPatient : Patient;
        }

        action performAdvancedCare {
            in patient : Patient;
            in order : MedicalOrder;
            out treatedPatient : Patient;
        }

        flow from performStandardCare.treatedPatient to out stabilizedPatient;
        flow from performAdvancedCare.treatedPatient to out stabilizedPatient;
    }

    action def PrepareForTransport {
        in patient : Patient;
        out loadedPatient : Patient;
    }

    action def TransportToHospital {
        in patient : Patient;
        in destination : String;
        in distance : Distance;
        out arrivedAtHospital : Boolean;
        out transportedPatient : Patient;
    }

    action def TransferPatientCare {
        in patient : Patient;
        in finalVitals : PatientVitals;
        out careTransfer : CareTransferReport;
    }

    action def ReturnToStation {
        in stationLocation : String;
        in distance : Distance;
        out arrivedAtStation : Boolean;
    }

    // ============ Squad 51 ============
    part def Squad51 {
        attribute squadId : String = "Squad 51";
        attribute stationLocation : String = "Station 127";
        attribute currentStatus : SquadStatus = SquadStatus::inService;
        attribute arrivedAtScene : Boolean = false;
        attribute patientLoaded : Boolean = false;
        attribute arrivedAtHospital : Boolean = false;
        attribute careTransferred : Boolean = false;
        attribute arrivedAtStation : Boolean = false;

        part captain : ParamedicCaptain;
        part paramedics : Paramedic[2..*];
        part vehicle : RescueVehicle;

        port dispatchInterface : ~DispatchPort;
        port hospitalComm : ~HospitalCommPort;
        port squadRadio : ~RadioPort;

        state operationalStates {
            entry; then inService;

            state inService {
                entry;
            }

            transition from inService to dispatched
                accept DispatchOrder via dispatchInterface;

            state dispatched {
                entry;
            }

            transition from dispatched to enRoute
                when vehicle.engineRunning == true;

            state enRoute {
                entry;
            }

            transition from enRoute to onScene
                when arrivedAtScene == true;

            state onScene {
                entry;

                state assessing;
                state contactingHospital;
                state treating;
                state stabilizing;

                transition from assessing to contactingHospital
                    when true;
                transition from contactingHospital to treating
                    when true;
                transition from treating to stabilizing
                    when true;
            }

            transition from onScene to transporting
                when patientLoaded == true;

            state transporting {
                entry;
            }

            transition from transporting to atHospital
                when arrivedAtHospital == true;

            state atHospital {
                entry;
            }

            transition from atHospital to returning
                when careTransferred == true;

            state returning {
                entry;
            }

            transition from returning to inService
                when arrivedAtStation == true;
        }
    }

    // ============ Dispatch Center ============
    part def DispatchCenter {
        attribute centerName : String = "LA County Dispatch";
        attribute activeCalls : EmergencyCall[0..*];

        port squadDispatchPort : DispatchPort;
        port hospitalRadioPort : RadioPort;
        port squadRadioPort : RadioPort;

        action def receiveEmergencyCall {
            in call : EmergencyCall;
            out loggedCall : EmergencyCall;
        }

        action def determinePriority {
            in call : EmergencyCall;
            out priority : PriorityLevel;
        }

        action def createDispatchOrder {
            in call : EmergencyCall;
            in priority : PriorityLevel;
            out order : DispatchOrder;
        }

        action def dispatchSquad {
            in order : DispatchOrder;
            out dispatched : Boolean;
        }
    }

    // ============ Base Hospital ============
    part def BaseHospital {
        attribute hospitalName : String = "Rampart General";
        attribute physicianOnDuty : String = "Dr. Brackett";

        port squadHospitalPort : HospitalCommPort;
        port dispatchRadioPort : RadioPort;

        action def receiveVitals {
            in vitals : PatientVitals;
            out acknowledged : Boolean;
        }

        action def evaluatePatientStatus {
            in vitals : PatientVitals;
            in patient : Patient;
            out medicalOrder : MedicalOrder;
        }

        action def authorizeAdvancedProcedure {
            in procedure : String;
            out order : MedicalOrder;
        }

        action def receivePatientTransfer {
            in careTransfer : CareTransferReport;
            out accepted : Boolean;
        }
    }

    // ============ Emergency Response System ============
    part def EmergencyResponseSystem {
        attribute systemName : String = "LA County Emergency Medical Response System";

        part dispatchCenter : DispatchCenter;
        part squad51 : Squad51;
        part rampartGeneral : BaseHospital;

        connect dispatchCenter.squadDispatchPort to squad51.dispatchInterface;
        connect squad51.hospitalComm to rampartGeneral.squadHospitalPort;
        connect dispatchCenter.hospitalRadioPort to rampartGeneral.dispatchRadioPort;
        connect squad51.squadRadio to dispatchCenter.squadRadioPort;
    }

    // ============ Requirements ============
    requirement def TeamCompositionRequirement {
        subject squad : Squad51;
        doc /* Squad 51 shall be staffed by a Paramedic Captain with command authority and at least two additional paramedics. */;
        requirement {
            squad.captain.hasCommandAuthority == true and
            #squad.paramedics >= 2;
        }
    }

    requirement def ResponseTimeRequirement {
        subject squad : Squad51;
        attribute maxResponseTime : ElapsedTime = 8.0;
        doc /* Squad 51 shall arrive on scene within maxResponseTime minutes of receiving a dispatch order. */;
        requirement {
            maxResponseTime <= 8.0;
        }
    }

    requirement def CommunicationRequirement {
        subject squad : Squad51;
        subject hospital : BaseHospital;
        doc /* Squad 51 shall maintain continuous communication with Rampart General during all advanced life support procedures. */;
        requirement {
            hospital.hospitalName == "Rampart General";
        }
    }

    requirement def EquipmentReadinessRequirement {
        subject vehicle : RescueVehicle;
        doc /* The rescue vehicle shall be fully stocked with operational medical equipment and rescue tools at all times while in service. */;
        requirement {
            vehicle.defibrillator.batteryLevel > 50.0 and
            vehicle.oxygenTank.currentLevel > 0.0 and
            vehicle.firstAidKit.bandageCount > 0 and
            vehicle.rescueTools.hydraulicCutterPresent == true;
        }
    }

    requirement def PatientCareContinuityRequirement {
        subject squad : Squad51;
        subject hospital : BaseHospital;
        doc /* Patient care shall be formally transferred to hospital staff with complete vitals history and treatment record. */;
        requirement {
            squad.careTransferred == true;
        }
    }

    requirement def StatusTrackingRequirement {
        subject squad : Squad51;
        doc /* Squad 51 operational status shall be tracked and reported through all states from in service through return to service. */;
        requirement {
            squad.currentStatus in {
                SquadStatus::inService,
                SquadStatus::dispatched,
                SquadStatus::enRoute,
                SquadStatus::onScene,
                SquadStatus::transporting,
                SquadStatus::atHospital,
                SquadStatus::returning
            };
        }
    }

    requirement def VehicleCapabilityRequirement {
        subject vehicle : RescueVehicle;
        doc /* The rescue vehicle shall function as a mobile emergency room equipped with defibrillator, oxygen, medical monitor, IV supplies, and rescue tools. */;
        requirement {
            #vehicle.defibrillator == 1 and
            #vehicle.oxygenTank == 1 and
            #vehicle.medicalMonitor == 1 and
            #vehicle.ivKit == 1 and
            #vehicle.rescueTools == 1;
        }
    }
}
