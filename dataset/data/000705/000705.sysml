package NasopharyngealAirwaySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def TubeLength :> LengthValue;
    attribute def TubeDiameter :> LengthValue;
    attribute def AirflowRate :> VolumetricFlowRate;
    attribute def OxygenSaturation :> Real;
    attribute def ResistanceValue :> Real;

    enum def AirwayStatus {
        obstructed;
        partiallyPatent;
        fullyPatent;
    }

    enum def PatientConsciousness {
        conscious;
        semiconscious;
        unconscious;
    }

    enum def DeviceState {
        stored;
        prepared;
        inserted;
        functioning;
        removed;
    }

    item def Air {
        attribute oxygenContent : Real;
    }

    item def Lubricant {
        attribute isWaterBased : Boolean;
    }

    port def AirwayPort {
        in item airIn : Air;
        out item airOut : Air;
        attribute flowRate : AirflowRate;
    }

    part def Patient {
        attribute consciousness : PatientConsciousness;
        attribute airwayStatus : AirwayStatus;
        attribute oxygenSaturation : OxygenSaturation;
        attribute nasalPassageDepth : TubeLength;
        
        port nasalOpening : AirwayPort;
        port pharynx : AirwayPort;
        port lungs : AirwayPort;
    }

    part def NasopharyngealTube {
        attribute length : TubeLength;
        attribute outerDiameter : TubeDiameter;
        attribute innerDiameter : TubeDiameter;
        attribute material : String;
        attribute hasBeveledTip : Boolean;
        attribute airflowResistance : ResistanceValue;
        
        port proximalEnd : AirwayPort {
            doc /* External opening at nose */
        }
        
        port distalEnd : AirwayPort {
            doc /* Internal opening in pharynx */
        }
    }

    part def FlangeCap {
        attribute preventsOverInsertion : Boolean;
        attribute securesPosition : Boolean;
    }

    part def NasopharyngealAirway {
        attribute deviceState : DeviceState;
        attribute isPatent : Boolean;
        
        part tube : NasopharyngealTube {
            attribute :>> length = 120[mm];
            attribute :>> outerDiameter = 7.0[mm];
            attribute :>> innerDiameter = 5.5[mm];
            attribute :>> material = "medical-grade silicone";
            attribute :>> hasBeveledTip = true;
            attribute :>> airflowResistance = 0.5;
        }
        
        part flange : FlangeCap {
            attribute :>> preventsOverInsertion = true;
            attribute :>> securesPosition = true;
        }
        
        connection tubeFlange connect tube to flange;
    }

    action def AssessPatientAirway {
        in patient : Patient;
        out needsIntervention : Boolean;
        out appropriateSize : TubeDiameter;
    }

    action def PrepareDevice {
        in device : NasopharyngealAirway;
        in lubricant : Lubricant;
        out readyDevice : NasopharyngealAirway;
    }

    action def InsertDevice {
        in device : NasopharyngealAirway;
        in patient : Patient;
        out insertionSuccessful : Boolean;
    }

    action def MonitorAirwayPatency {
        in patient : Patient;
        in device : NasopharyngealAirway;
        out airwayPatent : Boolean;
        out oxygenLevel : OxygenSaturation;
    }

    action def AdjustDevice {
        in device : NasopharyngealAirway;
        in patient : Patient;
        out adjustmentComplete : Boolean;
    }

    action def RemoveDevice {
        in device : NasopharyngealAirway;
        in patient : Patient;
        out removalComplete : Boolean;
    }

    action def MaintainPatentAirway {
        doc /* Primary system function: Establish and maintain a patent airway 
             * from nasal opening to pharynx, bypassing upper airway obstruction */
        
        in targetPatient : Patient;
        in npaDevice : NasopharyngealAirway;
        in lubricantSupply : Lubricant;
        out airwayMaintained : Boolean;
        
        first start;
        
        then action assess : AssessPatientAirway {
            in patient = targetPatient;
            out requiresNPA : Boolean;
            out tubeSize : TubeDiameter;
        }
        
        then decide assessmentBranch;
            if assess.requiresNPA then prepareNPA;
            else skipProcedure;
        
        action prepareNPA : PrepareDevice {
            in device = npaDevice;
            in lubricant = lubricantSupply;
            out prepared : NasopharyngealAirway;
        }
        
        then action insertNPA : InsertDevice {
            in device = prepareNPA.prepared;
            in patient = targetPatient;
            out inserted : Boolean;
        }
        
        then merge monitoringLoop;
        
        then action monitor : MonitorAirwayPatency {
            in patient = targetPatient;
            in device = npaDevice;
            out patent : Boolean;
            out saturation : OxygenSaturation;
        }
        
        then decide monitoringBranch;
            if monitor.patent then checkSaturation;
            else adjustOrRemove;
        
        action checkSaturation {
            doc /* Check if oxygen saturation is adequate */
        }
        
        then decide saturationBranch;
            if monitor.saturation >= 92 then continueMonitoring;
            else adjustOrRemove;
        
        action continueMonitoring {
            doc /* Airway remains patent, continue monitoring */
        }
        
        then monitoringLoop;
        
        action adjustOrRemove : AdjustDevice {
            in device = npaDevice;
            in patient = targetPatient;
            out adjusted : Boolean;
        }
        
        then decide adjustmentBranch;
            if adjustOrRemove.adjusted then monitoringLoop;
            else removeNPA;
        
        action removeNPA : RemoveDevice {
            in device = npaDevice;
            in patient = targetPatient;
            out removed : Boolean;
        }
        
        then endProcedure;
        
        action skipProcedure {
            doc /* Patient does not require NPA */
        }
        
        then endProcedure;
        
        merge endProcedure;
        then done;
    }

    state def AirwayDeviceLifecycle {
        entry; then idle;
        
        state idle {
            entry assign deviceState = DeviceState::stored;
        }
        
        transition idle_to_prepared
            first idle
            accept PreparationStarted
            then prepared;
        
        state prepared {
            entry assign deviceState = DeviceState::prepared;
        }
        
        transition prepared_to_inserted
            first prepared
            accept InsertionCompleted
            then inserted;
        
        state inserted {
            entry assign deviceState = DeviceState::inserted;
        }
        
        transition inserted_to_functioning
            first inserted
            accept PatencyConfirmed
            then functioning;
        
        state functioning {
            entry assign deviceState = DeviceState::functioning;
            entry assign isPatent = true;
        }
        
        transition functioning_to_inserted
            first functioning
            accept PatencyLost
            then inserted;
        
        transition functioning_to_removed
            first functioning
            accept RemovalInitiated
            then removed;
        
        transition inserted_to_removed
            first inserted
            accept RemovalInitiated
            then removed;
        
        state removed {
            entry assign deviceState = DeviceState::removed;
            entry assign isPatent = false;
        }
        
        transition removed_to_idle
            first removed
            accept DeviceCleaned
            then idle;
    }

    constraint def LengthCompatibility {
        in tubeLength : TubeLength;
        in nasalDepth : TubeLength;
        tubeLength >= nasalDepth and tubeLength <= nasalDepth + 20[mm]
    }

    constraint def DiameterCompatibility {
        in tubeDiameter : TubeDiameter;
        in minDiameter : TubeDiameter;
        in maxDiameter : TubeDiameter;
        tubeDiameter >= minDiameter and tubeDiameter <= maxDiameter
    }

    constraint def FlowAdequacy {
        in actualFlow : AirflowRate;
        in requiredFlow : AirflowRate;
        actualFlow >= requiredFlow
    }

    constraint def OxygenationAdequacy {
        in saturation : OxygenSaturation;
        saturation >= 92
    }

    requirement <'REQ-NPA-001'> primaryFunction {
        doc /* The nasopharyngeal airway system shall establish and maintain 
             * a patent airway passage from the nasal opening through the 
             * nasopharynx to the oropharynx, bypassing upper airway obstruction 
             * caused by the tongue or soft palate in semiconscious or 
             * unconscious patients. */
        subject npaSystem : NasopharyngealAirway;
    }

    requirement <'REQ-NPA-002'> airwayPatency {
        doc /* The device shall maintain continuous airflow with minimal resistance */
        subject device : NasopharyngealAirway;
        require constraint {
            device.tube.airflowResistance <= 1.0
        }
    }

    requirement <'REQ-NPA-003'> properSizing {
        doc /* The tube length shall be compatible with patient anatomy */
        subject tube : NasopharyngealTube;
        in patient : Patient;
        assert lengthFit : LengthCompatibility {
            in tubeLength = tube.length;
            in nasalDepth = patient.nasalPassageDepth;
        }
    }

    requirement <'REQ-NPA-004'> safetyFeatures {
        doc /* The device shall prevent over-insertion and maintain position */
        subject device : NasopharyngealAirway;
        require constraint {
            device.flange.preventsOverInsertion == true and
            device.flange.securesPosition == true
        }
    }

    requirement <'REQ-NPA-005'> materialSafety {
        doc /* The tube shall be constructed of biocompatible material */
        subject tube : NasopharyngealTube;
        require constraint {
            tube.material == "medical-grade silicone" or
            tube.material == "medical-grade polyvinyl chloride"
        }
    }

    requirement <'REQ-NPA-006'> oxygenationMaintenance {
        doc /* The system shall support adequate oxygenation */
        in patient : Patient;
        assert oxygenAdequacy : OxygenationAdequacy {
            in saturation = patient.oxygenSaturation;
        }
    }

    requirement <'REQ-NPA-007'> flowCapacity {
        doc /* The device shall allow adequate airflow for spontaneous breathing */
        subject device : NasopharyngealAirway;
        assert flowAdequacy : FlowAdequacy {
            in actualFlow = device.tube.proximalEnd.flowRate;
            in requiredFlow = 15[L/min];
        }
    }

    part npaSystem : NasopharyngealAirway {
        attribute :>> deviceState = DeviceState::stored;
        attribute :>> isPatent = false;
        
        perform action systemOperation[*] references MaintainPatentAirway;
    }

    item treatedPatient : Patient {
        attribute :>> consciousness = PatientConsciousness::unconscious;
        attribute :>> airwayStatus = AirwayStatus::obstructed;
        attribute :>> oxygenSaturation = 88;
        attribute :>> nasalPassageDepth = 110[mm];
    }

    item lubricantUsed : Lubricant {
        attribute :>> isWaterBased = true;
    }

    connection airwayPath connect npaSystem.tube.proximalEnd to treatedPatient.nasalOpening;
    connection pharyngealPath connect npaSystem.tube.distalEnd to treatedPatient.pharynx;
    connection respiratoryPath connect treatedPatient.pharynx to treatedPatient.lungs;

    satisfy primaryFunction by npaSystem;
    satisfy airwayPatency by npaSystem;
    satisfy properSizing by npaSystem.tube;
    satisfy safetyFeatures by npaSystem;
    satisfy materialSafety by npaSystem.tube;
    satisfy oxygenationMaintenance by treatedPatient;
    satisfy flowCapacity by npaSystem;
}
