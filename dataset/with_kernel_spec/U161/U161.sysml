package BedpanManagementSystem {
    private import SI::s;
    private import ScalarValues::*;

    enum def BedpanStatus {
        sterile;
        inUse;
        contaminated;
        emptying;
        sanitizing;
        inspecting;
    }

    enum def CleanlinessLevel {
        soiled;
        emptied;
        washed;
        disinfected;
        sterile;
    }

    item def Waste;
    item def SanitizingAgent;
    item def UVExposure;

    attribute def LevelAlert {
        levelLiters : Real;
        timestamp : Real;
    }
    attribute def RetrieveSignal;
    attribute def UseComplete;
    attribute def TransportToDisposal;
    attribute def EmptyComplete;
    attribute def SanitationComplete;
    attribute def InspectionPassed;
    attribute def InventoryLowAlert;

    part def Basin {
        attribute capacityLiters : Real = 2.5;
        attribute material : String = "stainless steel";
        attribute ergonomicContour : Boolean = true;
        attribute spillagePrevention : Boolean = true;
    }

    part def Handle {
        attribute material : String = "stainless steel";
        attribute gripTexture : String = "textured";
        attribute loadRatingN : Real;
    }

    part def LevelSensor {
        attribute thresholdLiters : Real = 2.2;
        attribute measuredLiters : Real;
        out alert : LevelAlert;
        action def Sense {
            in currentLevelLiters : Real;
            out alert : LevelAlert;
        }
    }

    part def BedpanUnit {
        attribute serialNumber : String;
        attribute status : BedpanStatus = BedpanStatus::sterile;
        attribute cleanliness : CleanlinessLevel = CleanlinessLevel::sterile;
        attribute capacityLiters : Real = 2.5;
        attribute currentVolumeLiters : Real = 0;
        part basin : Basin;
        part handle : Handle;
        part levelSensor : LevelSensor;
        port alertPort { out alert : LevelAlert; }
    }

    port def BedpanPort {
        in item bedpanIn : BedpanUnit;
        out item bedpanOut : BedpanUnit;
    }
    port def DisposalPort :> BedpanPort {
        out item wasteOut : Waste;
    }
    port def SanitationPort :> BedpanPort {
        in item agent : SanitizingAgent;
    }

    action def WashCycle {
        in bedpan : BedpanUnit;
        in agent : SanitizingAgent;
        attribute temperatureC : Real = 80;
        attribute pressureKPa : Real = 200;
        attribute durationSec : Real = 5;
    }

    action def DisinfectionPhase {
        in bedpan : BedpanUnit;
        in uv : UVExposure;
        attribute uvIntensity : Real;
        attribute durationSec : Real = 3;
    }

    action def Inspection {
        in bedpan : BedpanUnit;
        out passed : Boolean;
        attribute targetCleanliness : CleanlinessLevel = CleanlinessLevel::sterile;
    }

    action def Transport {
        in bedpan : BedpanUnit;
        out bedpanOut : BedpanUnit;
    }

    action def ProvideToPatient {
        in bedpan : BedpanUnit;
        out bedpanOut : BedpanUnit;
    }

    action def EmptyUsed {
        in bedpan : BedpanUnit;
        out bedpanOut : BedpanUnit;
        out waste : Waste;
    }

    action def UseBedpan {
        in bedpan : BedpanUnit;
        out bedpanOut : BedpanUnit;
    }

    action def RetrieveFromStorage {
        out bedpan : BedpanUnit;
    }

    action def RestockToStorage {
        in bedpan : BedpanUnit;
    }

    part def StorageRack {
        attribute capacityCount : Integer;
        attribute currentInventory : Integer;
        attribute minInventoryThreshold : Integer = 5;
        port storagePort : BedpanPort;
        action def Retrieve {
            out bedpan : BedpanUnit;
        }
        action def Restock {
            in bedpan : BedpanUnit;
        }
        action def MonitorInventory {
            out alert : InventoryLowAlert;
        }
    }

    part def WasteDisposal {
        attribute wasteCapacityLiters : Real;
        attribute currentWasteLiters : Real;
        port disposalPort : DisposalPort;
        action def Empty {
            in bedpan : BedpanUnit;
            out bedpanOut : BedpanUnit;
            out waste : Waste;
        }
    }

    part def SanitationFacility {
        attribute washTemperatureC : Real = 80;
        attribute washPressureKPa : Real = 200;
        attribute uvIntensity : Real;
        in item agent : SanitizingAgent;
        port sanitationPort : SanitationPort;
        action def Sanitize {
            in bedpan : BedpanUnit;
            in agent : SanitizingAgent;
            out sterile : BedpanUnit;
            out passed : Boolean;
            action wash : WashCycle {
                in bedpan = bedpan;
                in agent = agent;
            }
            then action disinfect : DisinfectionPhase {
                in bedpan = bedpan;
            }
            then action inspect : Inspection {
                in bedpan = bedpan;
                out passed = passed;
            }
        }
    }

    part def Caregiver {
        attribute id : String;
        port receiveFromStorage : BedpanPort;
        port deliverToPatient : BedpanPort;
        port receiveFromPatient : BedpanPort;
        port deliverToDisposal : DisposalPort;
    }

    part def Patient {
        attribute id : String;
        attribute bedridden : Boolean;
        attribute mobilityImpaired : Boolean;
        port patientPort : BedpanPort;
    }

    state def BedpanLifecycle {
        in bedpan : BedpanUnit;
        entry; then sterile;
        state sterile;
        transition t1
            first sterile
            accept RetrieveSignal
            then inUse;
        state inUse;
        transition t2
            first inUse
            accept UseComplete
            then contaminated;
        state contaminated;
        transition t3
            first contaminated
            accept TransportToDisposal
            then emptying;
        state emptying;
        transition t4
            first emptying
            accept EmptyComplete
            then sanitizing;
        state sanitizing {
            entry action wash : WashCycle { in bedpan = bedpan; } then action disinfect : DisinfectionPhase { in bedpan = bedpan; }
        }
        transition t5
            first sanitizing
            accept SanitationComplete
            then inspecting;
        state inspecting {
            entry action inspect : Inspection { in bedpan = bedpan; }
        }
        transition t6
            first inspecting
            accept InspectionPassed
            then sterile;
    }

    part def BedpanManagementSystem {
        part storageRack : StorageRack;
        part sanitationFacility : SanitationFacility;
        part wasteDisposal : WasteDisposal;
        part caregiver : Caregiver;
        part patient : Patient;
        part bedpans : BedpanUnit[0..*];
        state lifecycle : BedpanLifecycle[0..*];

        connector c1 from storageRack.storagePort to caregiver.receiveFromStorage;
        connector c2 from caregiver.deliverToPatient to patient.patientPort;
        connector c3 from patient.patientPort to caregiver.receiveFromPatient;
        connector c4 from caregiver.deliverToDisposal to wasteDisposal.disposalPort;
        connector c5 from wasteDisposal.disposalPort to sanitationFacility.sanitationPort;
        connector c6 from sanitationFacility.sanitationPort to storageRack.storagePort;
    }

    requirement def HygieneRequirement {
        subject system : BedpanManagementSystem;
        doc /* The system shall ensure that bedpans are sterile before patient use and prevent cross-contamination. */
    }

    requirement def CapacityRequirement {
        subject bedpan : BedpanUnit;
        doc /* Each bedpan basin shall have a capacity of approximately 2.5 liters. */
        constraint { bedpan.basin.capacityLiters == 2.5 }
    }

    requirement def LevelSensorRequirement {
        subject bedpan : BedpanUnit;
        doc /* Each bedpan shall include a level sensor that signals when the contents are nearing capacity. */
        constraint { bedpan.levelSensor.thresholdLiters < bedpan.capacityLiters }
    }

    requirement def SanitationRequirement {
        subject facility : SanitationFacility;
        doc /* The sanitation facility shall perform a high-temperature, high-pressure wash followed by disinfection and inspection before releasing any bedpan. */
        constraint { facility.washTemperatureC >= 70 }
        constraint { facility.washPressureKPa >= 100 }
    }

    requirement def SterileReturnRequirement {
        subject bedpan : BedpanUnit;
        doc /* A bedpan shall only be returned to storage when its cleanliness level is sterile. */
        constraint { bedpan.cleanliness == CleanlinessLevel::sterile }
    }

    requirement def ClosedLoopRequirement {
        subject system : BedpanManagementSystem;
        doc /* The bedpan flow shall form a closed loop: storage -> patient -> disposal -> sanitation -> storage. */
    }

    requirement def PatientDignityRequirement {
        subject patient : Patient;
        doc /* The system shall preserve patient comfort and dignity through ergonomic bedpan design and timely caregiver response. */
    }
}
