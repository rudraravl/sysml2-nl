package MedicalDeviceReprocessingFacility {
    import ScalarValues::*;
    import MeasurementReferences::*;

    // Value Types and Units
    unit def Celsius;
    unit def Pascal;
    unit def CFU;
    unit def EU;
    unit def Hertz;

    value def Temperature :> Real { unit Celsius; }
    value def Pressure :> Real { unit Pascal; }
    value def BioburdenLevel :> Real { unit CFU; }
    value def EndotoxinLevel :> Real { unit EU; }
    value def Frequency :> Real { unit Hertz; }
    value def ReprocessCount :> Integer;

    // Items
    item def MedicalDevice {
        attribute reprocessCount : ReprocessCount = 0;
        attribute bioburden : BioburdenLevel;
        attribute endotoxin : EndotoxinLevel;
        attribute isFunctional : Boolean;
        attribute isSterile : Boolean;
        attribute isDamaged : Boolean;
    }
    
    item def CleaningSolution;
    item def SterilizingAgent;
    item def PackagingMaterial;

    // Ports
    port def DeviceFlow {
        in item device : MedicalDevice;
    }
    
    port def RejectedFlow {
        out item device : MedicalDevice;
    }

    // Requirements
    requirement def BioburdenReduction {
        subject device : MedicalDevice;
        constraint { device.bioburden <= 10.0 [CFU] }
    }
    
    requirement def EndotoxinLimit {
        subject device : MedicalDevice;
        constraint { device.endotoxin <= 0.5 [EU] }
    }
    
    requirement def Traceability {
        subject device : MedicalDevice;
        constraint { device.reprocessCount > 0 }
    }
    
    requirement def SterilityAssurance {
        subject device : MedicalDevice;
        constraint { device.isSterile == true }
    }

    // Parts (Stations)
    part def PreInspectionStation {
        port inFlow : DeviceFlow;
        port outFlow : DeviceFlow;
        port rejectFlow : RejectedFlow;
        
        action inspect {
            in device : MedicalDevice;
            out accepted : MedicalDevice;
            out rejected : MedicalDevice;
            
            decide if device.isDamaged;
            then rejectAction;
            then acceptAction;
            
            action rejectAction {
                out rejected : MedicalDevice = device;
            }
            action acceptAction {
                out accepted : MedicalDevice = device;
            }
        }
    }

    part def PreCleaningStation {
        port inFlow : DeviceFlow;
        port outFlow : DeviceFlow;
        in item solution : CleaningSolution;
        
        action soak {
            in device : MedicalDevice;
            out cleaned : MedicalDevice;
        }
    }

    part def AutomatedWashingStation {
        port inFlow : DeviceFlow;
        port outFlow : DeviceFlow;
        in item solution : CleaningSolution;
        
        action wash {
            in device : MedicalDevice;
            out washed : MedicalDevice;
        }
    }

    part def UltrasonicCleaningStation {
        port inFlow : DeviceFlow;
        port outFlow : DeviceFlow;
        attribute frequency : Frequency = 40000 [Hertz];
        
        action ultrasonicClean {
            in device : MedicalDevice;
            out cleaned : MedicalDevice;
        }
    }

    part def RinseStation {
        port inFlow : DeviceFlow;
        port outFlow : DeviceFlow;
        
        action rinse {
            in device : MedicalDevice;
            out rinsed : MedicalDevice;
        }
    }

    part def DryingStation {
        port inFlow : DeviceFlow;
        port outFlow : DeviceFlow;
        attribute temperature : Temperature = 80 [Celsius];
        
        action dry {
            in device : MedicalDevice;
            out dried : MedicalDevice;
        }
    }

    part def FunctionalTestingStation {
        port inFlow : DeviceFlow;
        port outFlow : DeviceFlow;
        port rejectFlow : RejectedFlow;
        
        action test {
            in device : MedicalDevice;
            out accepted : MedicalDevice;
            out rejected : MedicalDevice;
            
            decide if device.isFunctional;
            then passAction;
            then failAction;
            
            action passAction {
                out accepted : MedicalDevice = device;
            }
            action failAction {
                out rejected : MedicalDevice = device;
            }
        }
    }

    part def SterilizationChamber {
        port inFlow : DeviceFlow;
        port outFlow : DeviceFlow;
        in item agent : SterilizingAgent;
        attribute temperature : Temperature = 121 [Celsius];
        attribute pressure : Pressure = 200000 [Pascal];
        
        action sterilize {
            in device : MedicalDevice;
            out sterilized : MedicalDevice;
        }
    }

    part def SterilityTestingStation {
        port inFlow : DeviceFlow;
        port outFlow : DeviceFlow;
        port rejectFlow : RejectedFlow;
        
        action test {
            in device : MedicalDevice;
            out accepted : MedicalDevice;
            out rejected : MedicalDevice;
            
            decide if device.isSterile;
            then passAction;
            then failAction;
            
            action passAction {
                out accepted : MedicalDevice = device;
            }
            action failAction {
                out rejected : MedicalDevice = device;
            }
        }
    }

    part def PackagingStation {
        port inFlow : DeviceFlow;
        port outFlow : DeviceFlow;
        in item material : PackagingMaterial;
        
        action package {
            in device : MedicalDevice;
            out packaged : MedicalDevice;
        }
    }

    part def StorageUnit {
        port inFlow : DeviceFlow;
        
        action store {
            in device : MedicalDevice;
        }
    }

    // Facility
    part def ReprocessingFacility {
        part preInspection : PreInspectionStation;
        part preCleaning : PreCleaningStation;
        part autoWash : AutomatedWashingStation;
        part ultrasonic : UltrasonicCleaningStation;
        part rinse : RinseStation;
        part drying : DryingStation;
        part funcTest : FunctionalTestingStation;
        part sterilizer : SterilizationChamber;
        part sterilityTest : SterilityTestingStation;
        part packaging : PackagingStation;
        part storage : StorageUnit;
        
        // Connections
        connect preInspection.outFlow to preCleaning.inFlow;
        connect preCleaning.outFlow to autoWash.inFlow;
        connect autoWash.outFlow to ultrasonic.inFlow;
        connect ultrasonic.outFlow to rinse.inFlow;
        connect rinse.outFlow to drying.inFlow;
        connect drying.outFlow to funcTest.inFlow;
        connect funcTest.outFlow to sterilizer.inFlow;
        connect sterilizer.outFlow to sterilityTest.inFlow;
        connect sterilityTest.outFlow to packaging.inFlow;
        connect packaging.outFlow to storage.inFlow;
        
        // State Machine for Facility Operation
        state def FacilityOperation {
            entry; then Idle;
            
            state Idle;
            state Processing;
            
            transition from Idle to Processing 
                when preInspection.inFlow.device->notEmpty();
                
            transition from Processing to Idle 
                when storage.inFlow.device->notEmpty();
        }
    }
}
