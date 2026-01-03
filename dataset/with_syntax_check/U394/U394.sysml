package 'Squad 51 Emergency Response System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def EmergencyCode {
        attribute code : Integer;
        attribute description : String;
        attribute priority : Integer;
    }
    
    attribute def GPSCoordinates {
        attribute latitude : Real;
        attribute longitude : Real;
    }
    
    attribute def VitalSigns {
        attribute heartRate : Real;
        attribute bloodPressure : String;
        attribute respiratoryRate : Real;
        attribute oxygenSaturation : Real;
        attribute consciousness : String;
    }
    
    attribute def DispatchInfo {
        attribute incidentNumber : String;
        attribute location : GPSCoordinates;
        attribute emergencyType : EmergencyCode;
        attribute dispatchTime : TimeValue;
    }
    
    item def MedicalEquipment {
        attribute equipmentType : String;
        attribute quantity : Integer;
        attribute operationalStatus : Boolean;
    }
    
    item def MedicalSupplies {
        attribute supplyType : String;
        attribute quantity : Integer;
        attribute expirationDate : String;
    }
    
    item def RescueEquipment {
        attribute toolType : String;
        attribute condition : String;
    }
    
    port def RadioPort {
        in item dispatchMessage : DispatchInfo;
        out item statusUpdate : String;
    }
    
    port def MedicalPort {
        in item patientVitals : VitalSigns;
        out item treatmentProtocol : String;
    }
    
    part def Paramedic {
        attribute name : String;
        attribute certificationLevel : String;
        attribute yearsExperience : Integer;
        port radio : RadioPort;
        port medicalInterface : MedicalPort;
    }
    
    part def ParamedicCaptain :> Paramedic {
        attribute commandAuthority : Boolean;
        attribute incidentCommandTrained : Boolean;
    }
    
    part def RescueVehicle {
        attribute vehicleID : String;
        attribute fuelLevel : Real;
        attribute maxSpeed : SpeedValue;
        attribute currentLocation : GPSCoordinates;
        port vehicleRadio : RadioPort;
        item medicalEquipment : MedicalEquipment[1..*];
        item medicalSupplies : MedicalSupplies[1..*];
        item rescueEquipment : RescueEquipment[1..*];
    }
    
    part def DispatchCenter {
        attribute centerID : String;
        port dispatchRadio : RadioPort;
        action def SendDispatch {
            in emergencyCall : EmergencyCode;
            in location : GPSCoordinates;
            out dispatch : DispatchInfo;
        }
    }
    
    part def BaseHospital {
        attribute hospitalName : String;
        port hospitalRadio : RadioPort;
        port medicalControl : MedicalPort;
        action def ProvideMedicalDirection {
            in vitals : VitalSigns;
            in situation : String;
            out orders : String;
        }
    }
    
    action def ReceiveDispatch {
        in dispatch : DispatchInfo;
        out acknowledged : Boolean;
    }
    
    action def RespondToScene {
        in destination : GPSCoordinates;
        in currentPosition : GPSCoordinates;
        in speed : SpeedValue;
        out arrivalTime : TimeValue;
        out arrived : Boolean;
    }
    
    action def AssessPatient {
        in sceneConditions : String;
        out vitals : VitalSigns;
        out patientCount : Integer;
        out assessmentComplete : Boolean;
    }
    
    action def RequestMedicalControl {
        in patientVitals : VitalSigns;
        in proposedTreatment : String;
        out authorization : String;
        out authorized : Boolean;
    }
    
    action def PerformTreatment {
        in treatmentProtocol : String;
        in patientVitals : VitalSigns;
        out treatmentComplete : Boolean;
        out updatedVitals : VitalSigns;
    }
    
    action def PrepareForTransport {
        in patient : VitalSigns;
        out secured : Boolean;
    }
    
    action def TransportToHospital {
        in hospitalLocation : GPSCoordinates;
        in patientCondition : VitalSigns;
        in transportSpeed : SpeedValue;
        out eta : TimeValue;
        out delivered : Boolean;
    }
    
    action def TransferCare {
        in patientReport : String;
        in vitals : VitalSigns;
        out transferComplete : Boolean;
    }
    
    action def ReturnToService {
        in baseLocation : GPSCoordinates;
        out readyForService : Boolean;
    }
    
    action def EmergencyResponse {
        in dispatchCall : DispatchInfo;
        out missionComplete : Boolean;
        
        attribute sceneLocation : GPSCoordinates;
        attribute baseLocation : GPSCoordinates;
        attribute hospitalLocation : GPSCoordinates;
        attribute responseSpeed : SpeedValue := 25.0 * (m/s);
        attribute patientStatus : VitalSigns;
        attribute medicalOrders : String;
        
        first start;
        
        then action receiveDispatch : ReceiveDispatch {
            in dispatch = dispatchCall;
            out acknowledged;
        }
        
        then action respondToScene : RespondToScene {
            in destination = dispatchCall.location;
            in currentPosition = baseLocation;
            in speed = responseSpeed;
            out arrivalTime;
            out arrived;
        }
        
        then action assessPatient : AssessPatient {
            in sceneConditions = dispatchCall.emergencyType.description;
            out vitals;
            out patientCount;
            out assessmentComplete;
        }
        
        then assign patientStatus := assessPatient.vitals;
        
        then decide;
            if assessPatient.vitals.consciousness == "Unconscious" or 
               assessPatient.vitals.heartRate > 120.0 or 
               assessPatient.vitals.heartRate < 50.0 then requestControl;
            else performTreatment;
        
        action requestControl : RequestMedicalControl {
            in patientVitals = patientStatus;
            in proposedTreatment = "Advanced Life Support";
            out authorization;
            out authorized;
        }
        then assign medicalOrders := requestControl.authorization;
        then performTreatment;
        
        action performTreatment : PerformTreatment {
            in treatmentProtocol = medicalOrders;
            in patientVitals = patientStatus;
            out treatmentComplete;
            out updatedVitals;
        }
        
        then assign patientStatus := performTreatment.updatedVitals;
        
        then action prepareForTransport : PrepareForTransport {
            in patient = patientStatus;
            out secured;
        }
        
        then action transportToHospital : TransportToHospital {
            in hospitalLocation = hospitalLocation;
            in patientCondition = patientStatus;
            in transportSpeed = responseSpeed;
            out eta;
            out delivered;
        }
        
        then action transferCare : TransferCare {
            in patientReport = "Patient treated and transported";
            in vitals = patientStatus;
            out transferComplete;
        }
        
        then action returnToService : ReturnToService {
            in baseLocation = baseLocation;
            out readyForService;
        }
        
        then assign missionComplete := returnToService.readyForService;
        
        then done;
    }
    
    part def Squad51 {
        attribute squadDesignation : String;
        attribute status : String;
        attribute stationLocation : GPSCoordinates;
    }
    
    state def SquadOperationalState {
        entry; 
        then inService;
        
        state inService;
        
        transition inService_to_dispatched
            first inService
            accept dispatchReceived : DispatchInfo
            then dispatched;
        
        state dispatched;
        
        transition dispatched_to_onScene
            first dispatched
            then onScene;
        
        state onScene;
        
        transition onScene_to_transporting
            first onScene
            then transporting;
        
        state transporting;
        
        transition transporting_to_atHospital
            first transporting
            then atHospital;
        
        state atHospital;
        
        transition atHospital_to_inService
            first atHospital
            then inService;
    }
    
    part squad51System : Squad51 {
        doc /* Squad 51 is an advanced life support emergency medical response unit.
               Its primary function is to provide rapid, professional emergency medical care
               and rescue services to the community. The squad responds to emergency calls,
               assesses and stabilizes patients at the scene, provides advanced medical
               interventions under physician direction, and safely transports patients to
               appropriate medical facilities. Squad 51 operates as a coordinated team of
               highly trained paramedics equipped with specialized medical and rescue equipment,
               working in continuous communication with dispatch and hospital medical control
               to deliver critical pre-hospital emergency care. */
        
        attribute squadDesignation = "Squad 51";
        attribute status : String;
        attribute stationLocation : GPSCoordinates;
        
        part captain : ParamedicCaptain {
            attribute name = "Captain Stanley";
            attribute certificationLevel = "Paramedic";
            attribute yearsExperience = 15;
            attribute commandAuthority = true;
            attribute incidentCommandTrained = true;
        }
        
        part paramedic1 : Paramedic {
            attribute name = "Paramedic Gage";
            attribute certificationLevel = "Paramedic";
            attribute yearsExperience = 8;
        }
        
        part paramedic2 : Paramedic {
            attribute name = "Paramedic DeSoto";
            attribute certificationLevel = "Paramedic";
            attribute yearsExperience = 10;
        }
        
        part rescueVehicle : RescueVehicle {
            attribute vehicleID = "Squad 51";
            attribute fuelLevel = 0.85;
            attribute maxSpeed = 35.0 * (m/s);
        }
        
        connection captainToRadio : RadioConnection
            connect captain.radio to rescueVehicle.vehicleRadio;
        
        connection paramedic1ToRadio : RadioConnection
            connect paramedic1.radio to rescueVehicle.vehicleRadio;
        
        connection paramedic2ToRadio : RadioConnection
            connect paramedic2.radio to rescueVehicle.vehicleRadio;
        
        perform action emergencyResponse[*] ordered references EmergencyResponse;
        
        exhibit state operationalState : SquadOperationalState;
    }
    
    part dispatchCenter : DispatchCenter {
        attribute centerID = "LA County Fire Dispatch";
    }
    
    part rampartHospital : BaseHospital {
        attribute hospitalName = "Rampart General Hospital";
        
        perform action provideMedicalDirection : ProvideMedicalDirection;
    }
    
    connection def RadioConnection {
        end source : RadioPort[1];
        end target : RadioPort[1];
    }
    
    connection dispatchToSquad : RadioConnection
        connect dispatchCenter.dispatchRadio to squad51System.rescueVehicle.vehicleRadio;
    
    connection squadToHospital : RadioConnection
        connect squad51System.rescueVehicle.vehicleRadio to rampartHospital.hospitalRadio;
    
    connection medicalControlLink : MedicalConnection
        connect squad51System.captain.medicalInterface to rampartHospital.medicalControl;
    
    connection def MedicalConnection {
        end source : MedicalPort[1];
        end target : MedicalPort[1];
    }
    
    requirement def ResponseTimeRequirement {
        doc /* Squad 51 shall respond to emergency calls and arrive on scene 
               within 8 minutes of dispatch for 90% of calls. */
        subject squad : Squad51;
    }
    
    requirement def MedicalCapabilityRequirement {
        doc /* Squad 51 shall be equipped and staffed to provide Advanced Life Support
               including cardiac monitoring, defibrillation, intravenous therapy, and
               advanced airway management. */
        subject squad : Squad51;
    }
    
    requirement def CommunicationRequirement {
        doc /* Squad 51 shall maintain continuous radio communication capability
               with dispatch and base hospital medical control. */
        subject squad : Squad51;
    }
    
    requirement def StaffingRequirement {
        doc /* Squad 51 shall be staffed with a minimum of two certified paramedics
               on duty at all times. */
        subject squad : Squad51;
    }
    
    requirement squad51Requirements {
        doc /* Squad 51 shall meet all operational requirements for emergency
               medical response and patient care. */
        require responseTime : ResponseTimeRequirement;
        require medicalCapability : MedicalCapabilityRequirement;
        require communications : CommunicationRequirement;
        require staffing : StaffingRequirement;
    }
}
