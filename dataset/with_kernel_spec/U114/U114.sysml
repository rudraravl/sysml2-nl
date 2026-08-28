package MedicalDeviceReprocessingFacility {
    private import ScalarValues::*;
    private import SI::*;

    attribute def TemperatureValue :> Real;
    attribute def PressureValue :> Real;
    attribute def DurationValue :> Real;
    attribute def FrequencyValue :> Real;
    attribute def ConcentrationValue :> Real;
    attribute def BioburdenCount :> Real;
    attribute def EndotoxinLevel :> Real;
    attribute def SterilityAssuranceLevel :> Real;

    item def MedicalDevice {
        attribute serialNumber : String;
        attribute reprocessCount : Integer = 0;
        attribute isDamaged : Boolean = false;
        attribute isClean : Boolean = false;
        attribute isDry : Boolean = false;
        attribute isFunctional : Boolean = false;
        attribute isSterile : Boolean = false;
        attribute isPackaged : Boolean = false;
        attribute bioburden : BioburdenCount;
        attribute endotoxinLevel : EndotoxinLevel;
        attribute salAchieved : SterilityAssuranceLevel;
    }

    item def CleaningSolution {
        attribute solutionType : String;
        attribute concentration : ConcentrationValue;
    }

    item def SterilizingAgent {
        attribute agentType : String;
        attribute concentration : ConcentrationValue;
    }

    item def SterilePackage {
        attribute packageId : String;
        attribute label : String;
        attribute deviceSerialNumber : String;
        attribute reprocessCount : Integer;
    }

    port def DevicePort {
        inout device : MedicalDevice;
    }

    action def InspectAndSort {
        attribute inspectionCriteria : String;
    }

    action def PreClean {
        attribute soakDuration : DurationValue;
    }

    action def AutomatedWash {
        in solution : CleaningSolution;
        attribute washDuration : DurationValue;
    }

    action def UltrasonicClean {
        attribute frequency : FrequencyValue;
        attribute duration : DurationValue;
    }

    action def Rinse {
        attribute duration : DurationValue;
    }

    action def Dry {
        attribute temperature : TemperatureValue;
        attribute duration : DurationValue;
    }

    action def FunctionalTest {
        attribute testCriteria : String;
    }

    action def Sterilize {
        in agent : SterilizingAgent;
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute duration : DurationValue;
    }

    action def SterilityTest {
        attribute salTarget : SterilityAssuranceLevel;
    }

    action def PackageDevice {
        attribute packageType : String;
        out packagedDevice : SterilePackage;
    }

    action def ReprocessDevice {
        in device : MedicalDevice;
        out packagedDevice : SterilePackage;

        action inspect : InspectAndSort;
        action preClean : PreClean;
        action wash : AutomatedWash;
        action ultrasonic : UltrasonicClean;
        action rinse : Rinse;
        action dry : Dry;
        action functionalTest : FunctionalTest;
        action sterilize : Sterilize;
        action sterilityTest : SterilityTest;
        action packDevice : PackageDevice;

        first start;
        then inspect;
        then preClean;
        then wash;
        then ultrasonic;
        then rinse;
        then dry;
        then functionalTest;
        then sterilize;
        then sterilityTest;
        then packDevice;
        then done;
    }

    state machine def FacilityOperation {
        state idle;
        state processing;
        state maintenance;
        state emergencyStop;

        transition t1 first idle to processing;
        transition t2 first processing to idle;
        transition t3 first idle to maintenance;
        transition t4 first maintenance to idle;
        transition t5 first processing to emergencyStop;
        transition t6 first emergencyStop to idle;
    }

    constraint def BioburdenCheck;
    constraint def EndotoxinCheck;
    constraint def SALCheck;
    constraint def TraceabilityCheck;
    constraint def PackagingCheck;

    requirement def BioburdenReduction {
        doc /* The bioburden of reprocessed devices must be below the specified limit. */
        subject device : MedicalDevice;
        require constraint bioburdenLimitMet : BioburdenCheck;
    }

    requirement def EndotoxinLimit {
        doc /* The endotoxin level must be below 0.25 EU/mL. */
        subject device : MedicalDevice;
        require constraint endotoxinLimitMet : EndotoxinCheck;
    }

    requirement def SterilityAssurance {
        doc /* The Sterility Assurance Level must be 10^-6 or better. */
        subject device : MedicalDevice;
        require constraint salMet : SALCheck;
    }

    requirement def DeviceTraceability {
        doc /* Every device must have a serial number and reprocess count for traceability. */
        subject device : MedicalDevice;
        require constraint traceabilityComplete : TraceabilityCheck;
    }

    requirement def SterilePackaging {
        doc /* Reprocessed devices must be sealed in sterile packaging with proper labeling. */
        subject device : MedicalDevice;
        require constraint packagingComplete : PackagingCheck;
    }

    part def PreInspectionStation {
        port deviceIn : DevicePort;
        port deviceOut : DevicePort;
        port rejectOut : DevicePort;
    }

    part def PreCleaningStation {
        port deviceIn : DevicePort;
        port deviceOut : DevicePort;
        attribute soakTemperature : TemperatureValue;
    }

    part def AutomatedWashingStation {
        port deviceIn : DevicePort;
        port deviceOut : DevicePort;
        attribute solution : CleaningSolution;
    }

    part def UltrasonicCleaningStation {
        port deviceIn : DevicePort;
        port deviceOut : DevicePort;
        attribute frequency : FrequencyValue;
    }

    part def RinseStation {
        port deviceIn : DevicePort;
        port deviceOut : DevicePort;
    }

    part def DryingStation {
        port deviceIn : DevicePort;
        port deviceOut : DevicePort;
        attribute temperature : TemperatureValue;
    }

    part def FunctionalTestingStation {
        port deviceIn : DevicePort;
        port deviceOut : DevicePort;
        port rejectOut : DevicePort;
    }

    part def SterilizationChamber {
        port deviceIn : DevicePort;
        port deviceOut : DevicePort;
        attribute agent : SterilizingAgent;
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
    }

    part def SterilityTestingStation {
        port deviceIn : DevicePort;
        port deviceOut : DevicePort;
        port rejectOut : DevicePort;
    }

    part def PackagingStation {
        port deviceIn : DevicePort;
        port deviceOut : DevicePort;
    }

    part def StorageUnit {
        port deviceIn : DevicePort;
        attribute capacity : Integer;
    }

    part def ReprocessingFacility;

    action reprocessDeviceAction : ReprocessDevice;

    part reprocessingFacility : ReprocessingFacility {
        perform reprocessDeviceAction;

        part preInspectionStation : PreInspectionStation;
        part preCleaningStation : PreCleaningStation;
        part automatedWashingStation : AutomatedWashingStation;
        part ultrasonicCleaningStation : UltrasonicCleaningStation;
        part rinseStation : RinseStation;
        part dryingStation : DryingStation;
        part functionalTestingStation : FunctionalTestingStation;
        part sterilizationChamber : SterilizationChamber;
        part sterilityTestingStation : SterilityTestingStation;
        part packagingStation : PackagingStation;
        part storageUnit : StorageUnit;

        flow preInspectionStation.deviceOut to preCleaningStation.deviceIn;
        flow preInspectionStation.rejectOut to storageUnit.deviceIn;
        flow preCleaningStation.deviceOut to automatedWashingStation.deviceIn;
        flow automatedWashingStation.deviceOut to ultrasonicCleaningStation.deviceIn;
        flow ultrasonicCleaningStation.deviceOut to rinseStation.deviceIn;
        flow rinseStation.deviceOut to dryingStation.deviceIn;
        flow dryingStation.deviceOut to functionalTestingStation.deviceIn;
        flow functionalTestingStation.deviceOut to sterilizationChamber.deviceIn;
        flow functionalTestingStation.rejectOut to storageUnit.deviceIn;
        flow sterilizationChamber.deviceOut to sterilityTestingStation.deviceIn;
        flow sterilityTestingStation.deviceOut to packagingStation.deviceIn;
        flow sterilityTestingStation.rejectOut to storageUnit.deviceIn;
        flow packagingStation.deviceOut to storageUnit.deviceIn;

        state facilityState : FacilityOperation;

        attribute bioburdenLimit : BioburdenCount = 10;
        attribute endotoxinLimit : EndotoxinLevel = 0.25;
        attribute salLimit : SterilityAssuranceLevel = 1e-6;

        requirement bioburdenReq : BioburdenReduction;
        requirement endotoxinReq : EndotoxinLimit;
        requirement salReq : SterilityAssurance;
        requirement traceabilityReq : DeviceTraceability;
        requirement packagingReq : SterilePackaging;

        satisfy bioburdenReq by ultrasonicCleaningStation;
        satisfy endotoxinReq by rinseStation;
        satisfy salReq by sterilizationChamber;
        satisfy traceabilityReq by packagingStation;
        satisfy packagingReq by packagingStation;

        assert satisfy bioburdenReq by reprocessingFacility;
        assert satisfy endotoxinReq by reprocessingFacility;
        assert satisfy salReq by reprocessingFacility;
        assert satisfy traceabilityReq by reprocessingFacility;
        assert satisfy packagingReq by reprocessingFacility;
    }

    verification def ReprocessingVerification {
        subject device : MedicalDevice;
        objective {
            doc /* Verify that a reprocessed device meets all safety, sterility, and traceability requirements. */
        }
    }

    verification deviceReprocessingVerification : ReprocessingVerification {
        subject testDevice : MedicalDevice;
    }

    individual def TestDevice1 :> MedicalDevice;
    individual def TestDevice2 :> MedicalDevice;
    individual def TestFacility :> ReprocessingFacility;

    individual testFacility : TestFacility :> reprocessingFacility {
        timeslice reprocessing1 {
            perform action :>> reprocessDeviceAction {
                in individual :>> device : TestDevice1 {
                    :>> serialNumber = "SN-001";
                    :>> reprocessCount = 3;
                    :>> isDamaged = false;
                    :>> isFunctional = true;
                    :>> bioburden = 100;
                    :>> endotoxinLevel = 0.1;
                    :>> salAchieved = 1e-7;
                }
            }
        }
        then timeslice reprocessing2 {
            perform action :>> reprocessDeviceAction {
                in individual :>> device : TestDevice2 {
                    :>> serialNumber = "SN-002";
                    :>> reprocessCount = 1;
                    :>> isDamaged = false;
                    :>> isFunctional = true;
                    :>> bioburden = 50;
                    :>> endotoxinLevel = 0.05;
                    :>> salAchieved = 1e-6;
                }
            }
        }
    }
}
