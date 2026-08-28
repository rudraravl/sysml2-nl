package NanoroboticTherapySystem {
    import ISQ::*;
    import ScalarValues::*;

    // Value Types
    value type Length :> Real { unit 'nm'; }
    value type Duration :> Real { unit 'min'; }
    value type Percentage :> Real { unit '%'; }
    value type Temperature :> Real { unit 'C'; }
    value type Acidity :> Real { unit 'pH'; }
    value type Energy :> Real { unit 'mJ'; }
    value type DrugVolume :> Real { unit 'nL'; }

    // Items
    item def Biomarker;
    item def DiseasedCell;
    item def HealthyCell;
    item def TherapeuticDrug;
    item def StatusUpdate;
    item def EnvironmentalData {
        value temp : Temperature;
        value acidity : Acidity;
    }
    item def Command;

    // Requirements
    requirement def SizeRequirement {
        doc /* The nanorobot must be less than 500 nm in size */
        attribute maxSize : Length = 500 [nm];
        constraint { size < maxSize }
    }
    requirement def DetectionConfidenceRequirement {
        doc /* Must achieve a confidence level of over 95% */
        attribute minConfidence : Percentage = 95 [%];
        constraint { confidence > minConfidence }
    }
    requirement def NavigationPrecisionRequirement {
        doc /* Arrive within 10 nm of its target */
        attribute maxDistance : Length = 10 [nm];
        constraint { distanceToTarget <= maxDistance }
    }
    requirement def MissionDurationRequirement {
        doc /* Mission lasting at least 60 minutes */
        attribute minDuration : Duration = 60 [min];
        constraint { missionDuration >= minDuration }
    }
    requirement def PayloadSafetyRequirement {
        doc /* Only release payload after definitive confirmation */
        constraint { releasePayload == true implies targetConfirmed == true }
    }

    requirement NanorobotRequirements {
        satisfy SizeRequirement;
        satisfy DetectionConfidenceRequirement;
        satisfy NavigationPrecisionRequirement;
        satisfy MissionDurationRequirement;
        satisfy PayloadSafetyRequirement;
    }

    // Ports
    port def EnvironmentalPort {
        out biomarkers : Biomarker;
        out cells : DiseasedCell;
    }
    port def TargetPort {
        out target : DiseasedCell;
    }
    port def PositionPort {
        out position : Length;
    }
    port def PayloadPort {
        out drug : TherapeuticDrug;
    }
    port def PowerPort {
        out energy : Energy;
    }
    port def CommPort {
        in commands : Command;
        out status : StatusUpdate;
        out envData : EnvironmentalData;
    }

    // Parts
    part def BiosensorArray {
        port envIn : EnvironmentalPort;
        port powerIn : PowerPort;
        port targetOut : TargetPort;
        attribute confidence : Percentage;
        attribute targetDetected : Boolean;
        
        satisfy DetectionConfidenceRequirement;
        
        action def ScanEnvironment {
            in env : EnvironmentalPort;
            out detected : Boolean;
        }
    }

    part def NavigationController {
        port targetIn : TargetPort;
        port navOut : PositionPort;
        port powerIn : PowerPort;
        attribute distanceToTarget : Length;
        
        satisfy NavigationPrecisionRequirement;
        
        action def CalculatePath {
            in target : DiseasedCell;
            out path : Length;
        }
        action def Propulsion {
            in path : Length;
            out position : Length;
        }
    }

    part def PayloadModule {
        port posIn : PositionPort;
        port payloadOut : PayloadPort;
        port powerIn : PowerPort;
        attribute drugVolume : DrugVolume = 10 [nL];
        attribute targetConfirmed : Boolean;
        attribute releasePayload : Boolean;
        
        satisfy PayloadSafetyRequirement;
        
        action def DispenseDrug {
            in release : Boolean;
            out drug : TherapeuticDrug;
        }
    }

    part def PowerManagementUnit {
        port powerOut : PowerPort;
        attribute batteryCapacity : Energy = 50 [mJ];
        attribute missionDuration : Duration;
        
        satisfy MissionDurationRequirement;
    }

    part def CommunicationModule {
        port commPort : CommPort;
        port powerIn : PowerPort;
        
        action def TransmitData {
            in data : EnvironmentalData;
            out status : StatusUpdate;
        }
        action def ReceiveCommand {
            in cmd : Command;
        }
    }

    part def TherapeuticNanorobot {
        attribute size : Length = 450 [nm];
        satisfy SizeRequirement;
        satisfy NanorobotRequirements;
        
        part biosensor : BiosensorArray;
        part navigation : NavigationController;
        part payload : PayloadModule;
        part power : PowerManagementUnit;
        part comm : CommunicationModule;
        
        port extEnv : EnvironmentalPort;
        port extComm : CommPort;
        port extPayload : PayloadPort;
        
        connection biosensorEnv connect extEnv to biosensor.envIn;
        connection targetFlow connect biosensor.targetOut to navigation.targetIn;
        connection positionFlow connect navigation.navOut to payload.posIn;
        connection payloadRelease connect payload.payloadOut to extPayload;
        connection powerBiosensor connect power.powerOut to biosensor.powerIn;
        connection powerNav connect power.powerOut to navigation.powerIn;
        connection powerPayload connect power.powerOut to payload.powerIn;
        connection powerComm connect power.powerOut to comm.powerIn;
        connection commLink connect comm.commPort to extComm;
        
        state def MissionStateMachine {
            entry; then Searching;
            
            state Searching;
            state Navigating;
            state Verifying;
            state Delivering;
            state Monitoring;
            state MissionComplete;
            
            transition from Searching to Navigating when biosensor.targetDetected;
            transition from Navigating to Verifying when navigation.distanceToTarget <= 10 [nm];
            transition from Verifying to Delivering when payload.targetConfirmed;
            transition from Verifying to Searching when !payload.targetConfirmed;
            transition from Delivering to Monitoring when payload.releasePayload;
            transition from Monitoring to Searching when payload.drugVolume > 0 [nL];
            transition from Monitoring to MissionComplete when payload.drugVolume == 0 [nL];
        }
    }

    part def BiologicalEnvironment {
        port envOut : EnvironmentalPort;
        port commOut : CommPort;
        port drugIn : PayloadPort;
        
        part diseasedCells : DiseasedCell[*];
        part healthyCells : HealthyCell[*];
        part biomarkers : Biomarker[*];
    }

    part NanoroboticTherapySystem {
        part environment : BiologicalEnvironment;
        part nanorobot : TherapeuticNanorobot;
        
        connection envInterface connect environment.envOut to nanorobot.extEnv;
        connection commInterface connect environment.commOut to nanorobot.extComm;
        connection drugDelivery connect nanorobot.extPayload to environment.drugIn;
    }
}
