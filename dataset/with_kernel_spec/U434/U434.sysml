package AutomatedUrineCollectionDevice {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def VolumeValue :> Real { unit VolumeUnit; }
    attribute def PressureValue :> Real { unit PressureUnit; }

    attribute def StartCollectionSignal;
    attribute def ManualSealSignal;
    attribute def SealCompleteSignal;
    attribute def ResetSignal;
    attribute def OverflowAlertSignal;

    item def Urine;
    item def VolumeReading { attribute value : VolumeValue; }
    item def PressureReading { attribute value : PressureValue; }
    item def SealCommand { attribute engage : Boolean; }
    item def SealStatus { attribute sealed : Boolean; }
    item def OverflowCommand { attribute activate : Boolean; }

    port def VolumeDataPort { out reading : VolumeReading; }
    port def PressureDataPort { out reading : PressureReading; }
    port def SealCommandPort { in command : SealCommand; out status : SealStatus; }
    port def OverflowCommandPort { in command : OverflowCommand; }
    port def ControlSignalPort {
        in start : StartCollectionSignal;
        in manualSeal : ManualSealSignal;
        in reset : ResetSignal;
        in sealComplete : SealCompleteSignal;
    }

    action def MonitorVolume { out currentVolume : VolumeValue; }
    action def MonitorPressure { out currentPressure : PressureValue; }
    action def ActivateSealingAssembly;
    action def PerformSeal;
    action def ActivateOverflowProtection;
    action def ResetDevice;

    part def CollectionReservoir {
        attribute capacity : VolumeValue = 500 [mL];
        attribute material : String = "medical-grade polymer";
        attribute currentVolume : VolumeValue = 0 [mL];
        attribute currentPressure : PressureValue = 0 [kPa];
        port urineIn : Urine;
    }

    part def VolumeMonitor {
        port sensorOut : VolumeDataPort;
        perform action monitorVolume : MonitorVolume;
    }

    part def PressureMonitor {
        port sensorOut : PressureDataPort;
        perform action monitorPressure : MonitorPressure;
    }

    part def OverflowProtectionSystem {
        port cmdIn : OverflowCommandPort;
        perform action activateOverflowProtection : ActivateOverflowProtection;
    }

    part def SealingAssembly {
        port cmdIn : SealCommandPort;
        perform action activateSealingAssembly : ActivateSealingAssembly;
        perform action performSeal : PerformSeal;
    }

    part def ControlModule {
        attribute nearFullThreshold : VolumeValue = 450 [mL];
        attribute fullThreshold : VolumeValue = 500 [mL];
        attribute criticalPressureThreshold : PressureValue = 10 [kPa];

        port volumeIn : VolumeDataPort;
        port pressureIn : PressureDataPort;
        port controlIn : ControlSignalPort;
        port sealCmdOut : SealCommandPort;
        port overflowCmdOut : OverflowCommandPort;

        exhibit state deviceStates : DeviceStates;
    }

    state def DeviceStates {
        in reservoir : CollectionReservoir;
        in volumeMonitor : VolumeMonitor;
        in pressureMonitor : PressureMonitor;
        in sealingAssembly : SealingAssembly;
        in overflowProtection : OverflowProtectionSystem;
        in controlModule : ControlModule;

        action monitorVolumeAction : MonitorVolume;
        action monitorPressureAction : MonitorPressure;
        action activateSealingAction : ActivateSealingAssembly;
        action performSealAction : PerformSeal;
        action resetAction : ResetDevice;

        entry; then standby;

        state standby;
        accept StartCollectionSignal
            then active;

        state active {
            do monitorVolumeAction;
            do monitorPressureAction;
        }
        accept when monitorVolumeAction.currentVolume >= controlModule.nearFullThreshold
            then nearFull;

        state nearFull {
            do monitorVolumeAction;
            do monitorPressureAction;
        }
        accept when monitorVolumeAction.currentVolume >= controlModule.fullThreshold
            do send new SealCommand() to sealingAssembly
            then sealing;
        accept ManualSealSignal
            do send new SealCommand() to sealingAssembly
            then sealing;
        accept when monitorPressureAction.currentPressure > controlModule.criticalPressureThreshold
            do send new OverflowCommand() to overflowProtection
            then sealing;

        state sealing {
            entry activateSealingAction;
            do performSealAction;
        }
        accept SealCompleteSignal
            then sealed;

        state sealed;
        accept ResetSignal
            do resetAction
            then standby;
    }

    part def UrineCollectionDevice {
        part reservoir : CollectionReservoir;
        part volumeMonitor : VolumeMonitor;
        part pressureMonitor : PressureMonitor;
        part overflowProtection : OverflowProtectionSystem;
        part controlModule : ControlModule;
        part sealingAssembly : SealingAssembly;

        connect volumeMonitor.sensorOut to controlModule.volumeIn;
        connect pressureMonitor.sensorOut to controlModule.pressureIn;
        connect controlModule.sealCmdOut to sealingAssembly.cmdIn;
        connect controlModule.overflowCmdOut to overflowProtection.cmdIn;
    }

    requirement def MaxCapacityRequirement {
        attribute text : String = "The collection reservoir shall be capable of holding up to 500 mL of fluid.";
    }

    requirement def MaterialRequirement {
        attribute text : String = "The collection reservoir shall be constructed from medical-grade polymer.";
    }

    requirement def PressureSafetyRequirement {
        attribute text : String = "The system shall activate overflow protection if internal pressure exceeds the critical threshold of 10 kPa.";
    }

    requirement def AutomatedSealingRequirement {
        attribute text : String = "The device shall automatically initiate the sealing process when the reservoir reaches full capacity.";
    }

    requirement def ManualSealingRequirement {
        attribute text : String = "The device shall allow manual triggering of the sealing process at any time during collection.";
    }

    requirement def HygienicContainmentRequirement {
        attribute text : String = "The sealing assembly shall hygienically seal the reservoir to ensure secure containment for safe handling and disposal.";
    }

    requirement def LifecycleRequirement {
        attribute text : String = "The device shall cycle through standby, active, near full, full, sealing, and sealed states, returning to standby upon reset.";
    }

    part device : UrineCollectionDevice {
        requirement maxCapReq : MaxCapacityRequirement;
        requirement matReq : MaterialRequirement;
        requirement presReq : PressureSafetyRequirement;
        requirement autoSealReq : AutomatedSealingRequirement;
        requirement manualSealReq : ManualSealingRequirement;
        requirement hygReq : HygienicContainmentRequirement;
        requirement lifeReq : LifecycleRequirement;

        satisfy maxCapReq by reservoir.capacity;
        satisfy matReq by reservoir.material;
        satisfy presReq by overflowProtection;
        satisfy autoSealReq by sealingAssembly;
        satisfy manualSealReq by controlModule;
        satisfy hygReq by sealingAssembly;
        satisfy lifeReq by controlModule.deviceStates;
    }
}
