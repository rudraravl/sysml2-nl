package MicroneedleDrugDeliverySystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def NeedleLengthValue :> LengthValue;
    attribute def NeedleDiameterValue :> LengthValue;
    attribute def DrugVolumeValue :> VolumeValue;
    attribute def DrugFlowRateValue :> VolumetricFlowRateValue;
    attribute def SkinPenetrationDepthValue :> LengthValue;
    attribute def ApplicationPressureValue :> PressureValue;
    attribute def DeliveryDurationValue :> TimeValue;
    
    item def DrugFormulation {
        attribute volume : DrugVolumeValue;
        attribute concentration : Real;
        attribute viscosity : Real;
    }
    
    port def FluidPort {
        in item drugIn : DrugFormulation;
        out item drugOut : DrugFormulation;
    }
    
    port def SkinInterfacePort {
        out pressure : ApplicationPressureValue;
        out penetrationDepth : SkinPenetrationDepthValue;
    }
    
    attribute def ActivationCommand;
    attribute def StatusFeedback;
    
    port def ControlSignalPort {
        in activationCmd : ActivationCommand;
        out statusFb : StatusFeedback;
    }
    
    part def MicroneedleArray {
        attribute needleCount : Integer;
        attribute needleLength : NeedleLengthValue;
        attribute needleDiameter : NeedleDiameterValue;
        attribute arrayArea : AreaValue;
        
        port skinInterface : SkinInterfacePort;
        port drugInlet : FluidPort;
    }
    
    part def DrugReservoir {
        attribute capacity : DrugVolumeValue;
        attribute currentVolume : DrugVolumeValue;
        attribute refillable : Boolean;
        
        port outlet : FluidPort;
    }
    
    part def MicrofluidicPump {
        attribute maxFlowRate : DrugFlowRateValue;
        attribute operatingPressure : PressureValue;
        
        port inlet : FluidPort;
        port outlet : FluidPort;
        port control : ControlSignalPort;
    }
    
    part def PressureSensor {
        attribute measurementRange : PressureValue;
        attribute accuracy : Real;
        
        port sensing : SkinInterfacePort;
        port dataOutput : ControlSignalPort;
    }
    
    part def FlowController {
        attribute targetFlowRate : DrugFlowRateValue;
        attribute targetDose : DrugVolumeValue;
        
        port pumpControl : ControlSignalPort;
        port sensorInput : ControlSignalPort;
    }
    
    part def AdhesiveBacking {
        attribute adhesiveStrength : ForceValue;
        attribute wearDuration : TimeValue;
    }
    
    action def InitializeSystem {
        out systemReady : Boolean;
    }
    
    action def PenetrateSkin {
        in applicationPressure : ApplicationPressureValue;
        in needleLength : NeedleLengthValue;
        out penetrationDepth : SkinPenetrationDepthValue;
        out penetrationSuccess : Boolean;
    }
    
    action def PumpDrug {
        in targetVolume : DrugVolumeValue;
        in flowRate : DrugFlowRateValue;
        in availableVolume : DrugVolumeValue;
        out deliveredVolume : DrugVolumeValue;
    }
    
    action def MonitorDelivery {
        in currentVolume : DrugVolumeValue;
        in targetVolume : DrugVolumeValue;
        out deliveryComplete : Boolean;
        out deliveryProgress : Real;
    }
    
    action def TerminateDelivery {
        out systemSafe : Boolean;
    }
    
    action def DeliveryControl {
        in prescribedDose : DrugVolumeValue;
        in prescribedRate : DrugFlowRateValue;
        in reservoirVolume : DrugVolumeValue;
        out totalDelivered : DrugVolumeValue;
        out deliverySuccess : Boolean;
        
        first start;
        then action init : InitializeSystem {
            out systemReady;
        }
        then decide;
            if init.systemReady then penetrate;
            else terminate;
        
        action penetrate : PenetrateSkin {
            in applicationPressure;
            in needleLength;
            out penetrationDepth;
            out penetrationSuccess;
        }
        then decide;
            if penetrate.penetrationSuccess then pump;
            else terminate;
        
        action pump : PumpDrug {
            in targetVolume = prescribedDose;
            in flowRate = prescribedRate;
            in availableVolume = reservoirVolume;
            out deliveredVolume;
        }
        then merge monitorLoop;
        
        action monitor : MonitorDelivery {
            in currentVolume = pump.deliveredVolume;
            in targetVolume = prescribedDose;
            out deliveryComplete;
            out deliveryProgress;
        }
        then decide;
            if monitor.deliveryComplete then terminate;
            else monitorLoop;
        
        action terminate : TerminateDelivery {
            out systemSafe;
        }
        then assign totalDelivered := pump.deliveredVolume;
        then assign deliverySuccess := monitor.deliveryComplete;
        then done;
    }
    
    state def PatchLifecycle {
        entry; then initial;
        state initial;
        transition initial_to_packaged first initial then packaged;
        
        state packaged;
        state applied;
        state penetrating;
        state delivering;
        state completed;
        state disposed;
        
        transition packaged_to_applied first packaged then applied;
        transition applied_to_penetrating first applied then penetrating;
        transition penetrating_to_delivering first penetrating then delivering;
        transition delivering_to_completed first delivering then completed;
        transition completed_to_disposed first completed then disposed;
    }
    
    part def MicroneedlePatch {
        doc /* A transdermal drug delivery system using an array of microscopic needles 
               to painlessly penetrate the skin's outer layer and deliver therapeutic agents 
               directly into the dermis for rapid systemic absorption. */
        
        part needleArray : MicroneedleArray {
            attribute needleCount = 100;
            attribute needleLength = 800.0 [um];
            attribute needleDiameter = 50.0 [um];
        }
        
        part reservoir : DrugReservoir {
            attribute capacity = 2.0 [ml];
            attribute refillable = false;
        }
        
        part pump : MicrofluidicPump {
            attribute maxFlowRate = 0.1 [ml/min];
        }
        
        part pressureSensor : PressureSensor;
        
        part controller : FlowController;
        
        part backing : AdhesiveBacking {
            attribute wearDuration = 24.0 [h];
        }
        
        port patientInterface : SkinInterfacePort;
        
        connect reservoir.outlet to pump.inlet;
        connect pump.outlet to needleArray.drugInlet;
        connect needleArray.skinInterface to patientInterface;
        connect needleArray.skinInterface to pressureSensor.sensing;
        connect pressureSensor.dataOutput to controller.sensorInput;
        connect controller.pumpControl to pump.control;
        
        perform action deliveryControl : DeliveryControl;
        
        exhibit state lifecycle : PatchLifecycle;
    }
    
    requirement def SystemRequirement;
    
    requirement <'REQ-001'> TransdermalDelivery : SystemRequirement {
        doc /* The microneedle patch shall deliver drug formulations across the skin barrier 
               into the dermal layer for systemic absorption. */
        
        subject patch : MicroneedlePatch;
        
        require constraint {
            patch.needleArray.needleLength >= 500.0 [um] and 
            patch.needleArray.needleLength <= 1500.0 [um]
        }
    }
    
    requirement <'REQ-002'> PainlessApplication : SystemRequirement {
        doc /* The microneedle array shall penetrate only the epidermis without reaching 
               nerve endings to ensure painless application. */
        
        subject needles : MicroneedleArray;
        
        require constraint {
            needles.needleLength < 1000.0 [um]
        }
    }
    
    requirement <'REQ-003'> DoseAccuracy : SystemRequirement {
        doc /* The system shall deliver the prescribed drug dose with accuracy within ±5% 
               of the target volume. */
        
        subject patch : MicroneedlePatch;
        
        require constraint {
            abs(patch.controller.targetDose - patch.deliveryControl.totalDelivered) <= 
            patch.controller.targetDose * 0.05
        }
    }
    
    requirement <'REQ-004'> ControlledRelease : SystemRequirement {
        doc /* The system shall maintain a controlled drug release rate as specified by 
               the therapeutic protocol. */
        
        subject controller : FlowController;
        
        require constraint {
            controller.targetFlowRate <= controller.pumpControl.maxFlowRate
        }
    }
    
    requirement <'REQ-005'> PrimaryFunction : SystemRequirement {
        doc /* The primary function of the microneedle patch system is to enable minimally 
               invasive, controlled transdermal delivery of therapeutic drugs by creating 
               temporary microchannels through the stratum corneum. */
        
        subject system : MicroneedlePatch;
        
        assume constraint {
            system.reservoir.currentVolume > 0.0 [ml]
        }
        
        require TransdermalDelivery;
        require PainlessApplication by system.needleArray;
        require DoseAccuracy;
        require ControlledRelease by system.controller;
    }
    
    part microneedleSystem : MicroneedlePatch {
        satisfy PrimaryFunction;
    }
}
