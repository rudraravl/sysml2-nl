package NanoroboticsTargetedTherapySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def NanometerValue :> LengthValue {
        attribute :>> num : Real;
        attribute :>> mRef : LengthUnit = SI::nm;
    }
    
    attribute def MicrometerValue :> LengthValue {
        attribute :>> num : Real;
        attribute :>> mRef : LengthUnit = SI::m;
    }
    
    attribute def ConcentrationValue :> Real;
    
    attribute def BiomarkerSignature;
    attribute def TherapeuticAgent;
    attribute def CellIdentifier;
    
    item def DrugPayload {
        attribute agent : TherapeuticAgent;
        attribute dosage : MassValue;
        attribute concentration : ConcentrationValue;
        attribute isReleased : Boolean := false;
    }
    
    item def TargetCell {
        attribute cellID : CellIdentifier;
        attribute biomarkerLevel : ConcentrationValue;
        attribute position : NanometerValue[3];
        attribute isDiseasedCell : Boolean;
    }
    
    item def EnvironmentalData {
        attribute temperature : TemperatureValue;
        attribute pH : Real;
        attribute flowVelocity : SpeedValue;
    }
    
    port def BiosensorPort {
        in item detectedSignal : BiomarkerSignature;
        out attribute signalIntensity : ConcentrationValue;
    }
    
    port def ActuatorPort {
        in attribute thrustCommand : ForceValue[3];
        out attribute actualThrust : ForceValue[3];
    }
    
    port def PayloadReleasePort {
        in attribute releaseSignal : Boolean;
        out item releasedDrug : DrugPayload;
    }
    
    port def PowerSupplyPort {
        out attribute voltage : ISQ::ElectricPotentialValue;
        out attribute current : ISQ::ElectricCurrentValue;
    }
    
    port def CommunicationPort {
        in item command : String;
        out item telemetry : EnvironmentalData;
    }
    
    part def BiosensorArray {
        attribute detectionThreshold : ConcentrationValue;
        attribute sensitivity : Real;
        attribute scanRadius : MicrometerValue;
        
        port sensorOutput : ~BiosensorPort;
        
        action def ScanForBiomarkers {
            in scanRegion : NanometerValue[3];
            in threshold : ConcentrationValue;
            out detectedCells : TargetCell[*];
            out maxSignal : ConcentrationValue;
        }
    }
    
    part def NavigationController {
        attribute currentPosition : NanometerValue[3];
        attribute targetPosition : NanometerValue[3];
        attribute navigationAccuracy : NanometerValue;
        
        port actuatorControl : ActuatorPort;
        
        action def ComputeTrajectory {
            in start : NanometerValue[3];
            in target : NanometerValue[3];
            in environmentalConditions : EnvironmentalData;
            out waypoints : NanometerValue[3][*];
            out estimatedTime : TimeValue;
        }
        
        action def AdjustPosition {
            in targetVector : NanometerValue[3];
            in currentVelocity : SpeedValue;
            out thrustVector : ForceValue[3];
        }
    }
    
    part def PayloadModule {
        attribute capacity : ISQ::VolumeValue;
        attribute remainingPayload : ISQ::VolumeValue;
        attribute releaseRate : ISQ::VolumeFlowRateValue;
        
        port payloadPort : ~PayloadReleasePort;
        
        action def DispenseTherapeutic {
            in targetConfirmed : Boolean;
            in dosageAmount : MassValue;
            out dispensedPayload : DrugPayload;
            out remainingCapacity : ISQ::VolumeValue;
        }
    }
    
    part def PowerManagementUnit {
        attribute batteryCapacity : EnergyValue;
        attribute currentCharge : EnergyValue;
        attribute powerConsumption : PowerValue;
        
        port powerOut : ~PowerSupplyPort;
        
        action def AllocatePower {
            in requestedPower : PowerValue;
            in priority : Integer;
            out grantedPower : PowerValue;
            out remainingEnergy : EnergyValue;
        }
    }
    
    part def CommunicationModule {
        attribute transmissionRange : LengthValue;
        attribute dataRate : Real;
        
        port commPort : ~CommunicationPort;
        
        action def TransmitStatus {
            in statusData : EnvironmentalData;
            in position : NanometerValue[3];
            out transmissionSuccess : Boolean;
        }
        
        action def ReceiveCommand {
            out commandReceived : String;
            out commandValid : Boolean;
        }
    }
    
    action def IdentifyDiseaseCell {
        in scannedCells : TargetCell[*];
        in biomarkerThreshold : ConcentrationValue;
        out targetCell : TargetCell;
        out confidenceLevel : Real;
    }
    
    action def NavigateToCell {
        in targetLocation : NanometerValue[3];
        in currentLocation : NanometerValue[3];
        in obstacles : NanometerValue[3][*];
        out navigationPath : NanometerValue[3][*];
        out arrivalTime : TimeValue;
    }
    
    action def DeliverTherapy {
        in targetCell : TargetCell;
        in payload : DrugPayload;
        in deliveryDuration : TimeValue;
        out deliveryComplete : Boolean;
        out effectivenessEstimate : Real;
    }
    
    action def TargetedTherapyMission {
        in missionParameters : String;
        out missionStatus : String;
        
        first start;
        then merge searchLoop;
        
        action scanEnvironment : IdentifyDiseaseCell {
            in scannedCells : TargetCell[*];
            in biomarkerThreshold : ConcentrationValue;
            out targetCell : TargetCell;
            out confidenceLevel : Real;
        }
        
        then decide;
            if scanEnvironment.confidenceLevel >= 0.85 then navigateToTarget;
            if scanEnvironment.confidenceLevel < 0.85 then searchLoop;
        
        action navigateToTarget : NavigateToCell {
            in targetLocation : NanometerValue[3];
            in currentLocation : NanometerValue[3];
            in obstacles : NanometerValue[3][*];
            out navigationPath : NanometerValue[3][*];
            out arrivalTime : TimeValue;
        }
        
        then action verifyTarget : IdentifyDiseaseCell {
            in scannedCells : TargetCell[*];
            in biomarkerThreshold : ConcentrationValue;
            out targetCell : TargetCell;
            out confidenceLevel : Real;
        }
        
        then decide;
            if verifyTarget.confidenceLevel >= 0.95 then deliverDrug;
            if verifyTarget.confidenceLevel < 0.95 then searchLoop;
        
        action deliverDrug : DeliverTherapy {
            in targetCell : TargetCell;
            in payload : DrugPayload;
            in deliveryDuration : TimeValue;
            out deliveryComplete : Boolean;
            out effectivenessEstimate : Real;
        }
        
        then done;
    }
    
    part therapeuticNanorobot {
        attribute robotDimensions : NanometerValue[3];
        attribute operationalLifetime : TimeValue;
        attribute maxSpeed : SpeedValue;
        
        perform action mission[*] ordered references TargetedTherapyMission;
        
        part biosensors : BiosensorArray {
            attribute :>> detectionThreshold = 0.1;
            attribute :>> sensitivity = 0.98;
            
            perform mission.scanEnvironment;
            perform mission.verifyTarget;
        }
        
        part navigation : NavigationController {
            perform mission.navigateToTarget;
        }
        
        part payloadSystem : PayloadModule {
            perform mission.deliverDrug;
        }
        
        part powerUnit : PowerManagementUnit;
        
        part communications : CommunicationModule;
        
        connect biosensors.sensorOutput to navigation.actuatorControl;
        connect payloadSystem.payloadPort to navigation.actuatorControl;
        connect powerUnit.powerOut to biosensors.sensorOutput;
        connect powerUnit.powerOut to navigation.actuatorControl;
        connect powerUnit.powerOut to payloadSystem.payloadPort;
        connect powerUnit.powerOut to communications.commPort;
    }
    
    state machine def NanorobotOperationalStates {
        initial state Initialization;
        
        state Searching {
            entry action {
                doc /* Actively scanning environment for disease biomarkers */
            }
        }
        
        state Navigating {
            entry action {
                doc /* Moving toward identified target cell */
            }
        }
        
        state Verifying {
            entry action {
                doc /* Confirming target cell identity at close range */
            }
        }
        
        state Delivering {
            entry action {
                doc /* Releasing therapeutic payload to target */
            }
        }
        
        state Monitoring {
            entry action {
                doc /* Observing therapeutic effect post-delivery */
            }
        }
        
        state Depleted;
        
        transition from Initialization to Searching on activationSignal;
        transition from Searching to Navigating when targetDetected;
        transition from Navigating to Verifying when targetReached;
        transition from Verifying to Delivering when targetConfirmed;
        transition from Verifying to Searching when targetRejected;
        transition from Delivering to Monitoring when deliveryComplete;
        transition from Monitoring to Searching when monitoringComplete;
        transition from Monitoring to Depleted when payloadExhausted;
    }
    
    requirement def SystemGoal;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;
    requirement def ReliabilityRequirement;
    
    requirement <'NR-SYS-001'> primaryMissionObjective : SystemGoal {
        doc /* The nanorobotics system shall autonomously navigate through biological 
             environments to identify diseased cells using molecular biomarker detection, 
             and deliver targeted therapeutic payloads with high precision to minimize 
             damage to healthy tissue. */
        
        subject therapeuticNanorobot;
        
        require targetingPrecision;
        require payloadDeliveryControl;
        require biocompatibility;
        require autonomousOperation;
    }
    
    requirement <'NR-PERF-001'> targetingPrecision : PerformanceRequirement {
        doc /* The nanorobot shall identify target diseased cells with a minimum 
             confidence level of 95% based on biomarker signature analysis before 
             initiating therapeutic payload delivery. */
        
        subject therapeuticNanorobot.biosensors;
        
        require constraint {
            therapeuticNanorobot.biosensors.sensitivity >= 0.95
        }
    }
    
    requirement <'NR-PERF-002'> navigationAccuracy : PerformanceRequirement {
        doc /* The nanorobot shall navigate to within 10 nanometers of the target 
             cell center to ensure effective therapeutic delivery. */
        
        subject therapeuticNanorobot.navigation;
    }
    
    requirement <'NR-SAFE-001'> payloadDeliveryControl : SafetyRequirement {
        doc /* The nanorobot shall release therapeutic payload only after positive 
             verification of target cell identity to prevent off-target effects and 
             damage to healthy cells. */
        
        subject therapeuticNanorobot.payloadSystem;
    }
    
    requirement <'NR-SAFE-002'> biocompatibility : SafetyRequirement {
        doc /* The nanorobot physical dimensions shall not exceed 500 nanometers in 
             any dimension to enable safe navigation through capillaries and cellular 
             environments without causing mechanical damage. */
        
        subject therapeuticNanorobot;
    }
    
    requirement <'NR-REL-001'> autonomousOperation : ReliabilityRequirement {
        doc /* The nanorobot shall operate autonomously for a minimum mission duration 
             of 60 minutes on stored energy, performing target identification, navigation, 
             and therapeutic delivery without external intervention. */
        
        subject therapeuticNanorobot;
    }
    
    requirement <'NR-REL-002'> payloadCapacity : ReliabilityRequirement {
        doc /* The nanorobot shall carry sufficient therapeutic payload to treat a 
             minimum of 5 target cells during a single mission. */
        
        subject therapeuticNanorobot.payloadSystem;
    }
}
