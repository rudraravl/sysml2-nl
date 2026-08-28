package 'Needle-Free Jet Injector' {
    private import ISQ::*;
    private import ScalarValues::*;
    
    item def LiquidMedication;
    item def CompressedGas;
    item def MedicationJet;
    
    attribute def TriggerEvent;
    attribute def SafetyConfirmedEvent;
    attribute def InjectionCompleteEvent;
    
    part def MedicationAmpoule {
        attribute doseVolume : VolumeValue;
        port fluidOutPort {
            out medication : LiquidMedication;
        }
    }
    
    part def CompressedGasCartridge {
        attribute gasPressure : PressureValue;
        port safetyInPort {
            in safetySignal : Boolean;
        }
        port gasOutPort {
            out gas : CompressedGas;
        }
    }
    
    part def TriggerMechanism {
        port triggerPort {
            out triggerSignal : Boolean;
        }
    }
    
    part def SafetyInterlock {
        port triggerInPort {
            in triggerSignal : Boolean;
        }
        port skinContactPort {
            in skinContact : Boolean;
        }
        port safetyOutPort {
            out safetySignal : Boolean;
        }
    }
    
    part def PistonChamber {
        port gasInPort {
            in gas : CompressedGas;
        }
        port fluidInPort {
            in medication : LiquidMedication;
        }
        port fluidOutPort {
            out pressurizedMedication : LiquidMedication;
        }
    }
    
    part def MicroOrificeNozzle {
        attribute orificeDiameter : LengthValue;
        attribute jetDepth : LengthValue;
        port fluidInPort {
            in pressurizedMedication : LiquidMedication;
        }
        port jetOutPort {
            out jet : MedicationJet;
        }
    }
    
    action def DeliverInjection {
        in triggerSignal : Boolean;
        in skinContact : Boolean;
        out jet : MedicationJet;
        
        action activateTrigger {
            out triggerSignal = triggerSignal;
        }
        flow from activateTrigger.triggerSignal to verifySafety.triggerSignal;
        
        action verifySafety {
            in triggerSignal : Boolean;
            in skinContact : Boolean;
            out safetySignal : Boolean;
        }
        flow from verifySafety.safetySignal to releaseGas.safetySignal;
        
        action releaseGas {
            in safetySignal : Boolean;
            out gas : CompressedGas;
        }
        flow from releaseGas.gas to drivePiston.gas;
        
        action drivePiston {
            in gas : CompressedGas;
            out pressurizedMedication : LiquidMedication;
        }
        flow from drivePiston.pressurizedMedication to accelerateFluid.pressurizedMedication;
        
        action accelerateFluid {
            in pressurizedMedication : LiquidMedication;
            out jet : MedicationJet;
        }
    }
    
    state def InjectorControlStates;
    state injectorStates : InjectorControlStates {
        entry; then idle;
        state idle;
        accept TriggerEvent then armed;
        state armed;
        accept SafetyConfirmedEvent then injecting;
        state injecting;
        accept InjectionCompleteEvent then idle;
    }
    
    part def JetInjector {
        port triggerInputPort {
            in triggerSignal : Boolean;
        }
        port skinContactInputPort {
            in skinContact : Boolean;
        }
        port jetOutputPort {
            out jet : MedicationJet;
        }
        
        part ampoule : MedicationAmpoule;
        part cartridge : CompressedGasCartridge;
        part trigger : TriggerMechanism;
        part interlock : SafetyInterlock;
        part chamber : PistonChamber;
        part nozzle : MicroOrificeNozzle;
        
        connect triggerInputPort to trigger.triggerPort;
        connect trigger.triggerPort to interlock.triggerInPort;
        connect skinContactInputPort to interlock.skinContactPort;
        connect interlock.safetyOutPort to cartridge.safetyInPort;
        
        flow gasFlow of CompressedGas 
            from cartridge.gasOutPort.gas to chamber.gasInPort.gas;
        flow medFlow of LiquidMedication 
            from ampoule.fluidOutPort.medication to chamber.fluidInPort.medication;
        flow pressurizedMedFlow of LiquidMedication 
            from chamber.fluidOutPort.pressurizedMedication to nozzle.fluidInPort.pressurizedMedication;
        
        connect nozzle.jetOutPort to jetOutputPort;
        
        perform DeliverInjection {
            in triggerSignal = triggerInputPort.triggerSignal;
            in skinContact = skinContactInputPort.skinContact;
            out jet = jetOutputPort.jet;
        }
    }
    
    requirement def DoseAccuracy {
        doc /* The system shall deliver a medication dose with an accuracy of +/- 2% of the target volume. */
        attribute targetDose : VolumeValue;
        attribute tolerance : VolumeValue;
    }
    
    requirement def DeliveryDepth {
        doc /* The medication jet shall penetrate the skin to a subcutaneous depth between 2 mm and 5 mm. */
        attribute minDepth : LengthValue;
        attribute maxDepth : LengthValue;
    }
    
    requirement def SafetyInterlockReq {
        doc /* The system shall prevent gas release unless firm skin contact is verified by the safety interlock. */
    }
    
    part def JetInjectorSystem {
        part injector : JetInjector;
        requirement doseAccuracy : DoseAccuracy;
        requirement deliveryDepth : DeliveryDepth;
        requirement safetyInterlockReq : SafetyInterlockReq;
        satisfy doseAccuracy by injector;
        satisfy deliveryDepth by injector;
        satisfy safetyInterlockReq by injector;
    }
}
