package 'Artificial Urinary Sphincter System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ControlCommand;
    attribute def ActivationSignal;
    attribute def SystemState;
    
    item def Saline;
    
    port def FluidPort {
        out attribute fluidFlow : VolumeFlowRateValue;
        in attribute fluidReturn : VolumeFlowRateValue;
    }
    
    port def PressurePort {
        out attribute pressureReading : PressureValue;
    }
    
    port def ControlPort {
        in attribute command : ControlCommand;
    }
    
    port def PatientInterfacePort {
        in attribute activationRequest : ActivationSignal;
    }
    
    part def InflatableCuff {
        attribute cuffPressure : PressureValue;
        attribute cuffVolume : VolumeValue;
        attribute urethralOcclusion : Real;
        port fluidInput : FluidPort;
        port pressureOutput : PressurePort;
    }
    
    part def FluidReservoir {
        attribute storedVolume : VolumeValue;
        attribute maxCapacity : VolumeValue;
        port fluidOutput : FluidPort;
        port fluidInput : FluidPort;
    }
    
    part def ControlPump {
        attribute pumpRate : VolumeFlowRateValue;
        attribute isActive : Boolean;
        port controlInput : ControlPort;
        port fluidInlet : FluidPort;
        port fluidOutlet : FluidPort;
    }
    
    part def ReleaseValve {
        attribute valvePosition : Real;
        attribute isOpen : Boolean;
        port controlInput : ControlPort;
        port fluidInlet : FluidPort;
        port fluidOutlet : FluidPort;
    }
    
    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        port sensorInput : PressurePort;
        port dataOutput;
    }
    
    part def ControlModule {
        attribute targetPressure : PressureValue;
        attribute currentState : SystemState;
        port patientInput : PatientInterfacePort;
        port sensorInput;
        port pumpControl : ControlPort;
        port valveControl : ControlPort;
    }
    
    part def ActivationButton {
        attribute isPressed : Boolean;
        port userInterface : PatientInterfacePort;
    }
    
    action def MonitorCuffPressure {
        in currentPressure : PressureValue;
        in targetPressure : PressureValue;
        out pressureStatus : Real;
    }
    
    action def ActivatePump {
        in targetPressure : PressureValue;
        out pumpCommand : ControlCommand;
    }
    
    action def OpenValve {
        out valveCommand : ControlCommand;
    }
    
    action def CloseValve {
        out valveCommand : ControlCommand;
    }
    
    action def ProcessActivation {
        in patientRequest : ActivationSignal;
        in currentPressure : PressureValue;
        out systemResponse : ControlCommand;
    }
    
    state def SphincterOperationStates {
        in attribute cuffPressure : PressureValue;
        in attribute minPressure : PressureValue;
        in attribute targetPressure : PressureValue;
        in attribute voidingDuration : TimeValue;
        attribute systemState : SystemState;
        
        entry; then occluding;
        
        state occluding;
        
        transition occluding_to_deflating
            first occluding
            accept voidRequest : ActivationSignal
            then deflating;
        
        state deflating;
        
        transition deflating_to_voiding
            first deflating
            if cuffPressure <= minPressure
            then voiding;
        
        state voiding;
        
        transition voiding_to_reinflating
            first voiding
            after voidingDuration
            then reinflating;
        
        state reinflating;
        
        transition reinflating_to_occluding
            first reinflating
            if cuffPressure >= targetPressure
            then occluding;
    }
    
    action def ManageUrinaryControl {
        in patientActivation : ActivationSignal;
        out cuffPressure : PressureValue;
        out urethralOcclusion : Real;
        
        first start;
        then merge controlLoop;
        
        then action monitorPressure : MonitorCuffPressure {
            in currentPressure : PressureValue;
            in targetPressure : PressureValue;
            out pressureStatus : Real;
        }
        
        then action processRequest : ProcessActivation {
            in patientRequest = patientActivation;
            in currentPressure = monitorPressure.currentPressure;
            out systemResponse : ControlCommand;
        }
        
        then decide;
            if processRequest.systemResponse == "deflate" then deflateSequence;
            if processRequest.systemResponse == "inflate" then inflateSequence;
            else maintainSequence;
        
        action deflateSequence {
            action openValve : OpenValve {
                out valveCommand : ControlCommand;
            }
        }
        then controlLoop;
        
        action inflateSequence {
            action activatePump : ActivatePump {
                in targetPressure : PressureValue;
                out pumpCommand : ControlCommand;
            }
        }
        then controlLoop;
        
        action maintainSequence {
            action closeValve : CloseValve {
                out valveCommand : ControlCommand;
            }
        }
        then controlLoop;
    }
    
    part def ArtificialUrinarySphincter;
    
    action manageUrinaryControl : ManageUrinaryControl;
    
    part artificialUrinarySphincter : ArtificialUrinarySphincter {
        perform action urinaryControl[*] ordered references manageUrinaryControl;
        
        part activationButton : ActivationButton {
            perform urinaryControl.processRequest;
        }
        
        part controlModule : ControlModule {
            perform urinaryControl.processRequest;
        }
        
        part pressureSensor : PressureSensor {
            perform urinaryControl.monitorPressure;
        }
        
        part controlPump : ControlPump {
            perform urinaryControl.inflateSequence;
        }
        
        part releaseValve : ReleaseValve {
            perform urinaryControl.deflateSequence;
        }
        
        part inflatableCuff : InflatableCuff;
        
        part fluidReservoir : FluidReservoir;
        
        connect activationButton.userInterface to controlModule.patientInput;
        connect pressureSensor.dataOutput to controlModule.sensorInput;
        connect controlModule.pumpControl to controlPump.controlInput;
        connect controlModule.valveControl to releaseValve.controlInput;
        connect inflatableCuff.pressureOutput to pressureSensor.sensorInput;
        connect fluidReservoir.fluidOutput to controlPump.fluidInlet;
        connect controlPump.fluidOutlet to inflatableCuff.fluidInput;
        connect inflatableCuff.fluidInput to releaseValve.fluidInlet;
        connect releaseValve.fluidOutlet to fluidReservoir.fluidInput;
    }
    
    requirement def ContinenceMaintenanceRequirement {
        doc /* The artificial urinary sphincter shall maintain sufficient urethral occlusion 
               pressure to prevent involuntary urine leakage during normal daily activities 
               including standing, walking, and physical exertion. */
        
        subject cuff : InflatableCuff;
        
        require constraint {
            cuff.urethralOcclusion >= 0.85
        }
    }
    
    requirement def VoidingEnablementRequirement {
        doc /* The artificial urinary sphincter shall enable voluntary voiding by deflating 
               the urethral cuff to zero pressure within 8 seconds of patient activation, 
               allowing unobstructed urine flow. */
        
        subject system : ArtificialUrinarySphincter;
        
        require constraint {
            deflationTime <= 8.0
        }
        
        attribute deflationTime : TimeValue;
    }
    
    requirement def AutomaticReclosureRequirement {
        doc /* The artificial urinary sphincter shall automatically re-inflate the urethral 
               cuff to restore continence within 2 to 5 minutes after deflation, without 
               requiring additional patient intervention. */
        
        subject system : ArtificialUrinarySphincter;
        
        require constraint {
            reinflationTime >= 120.0 and reinflationTime <= 300.0
        }
        
        attribute reinflationTime : TimeValue;
    }
    
    requirement def SafetyPressureLimitRequirement {
        doc /* The artificial urinary sphincter shall limit maximum cuff pressure to prevent 
               urethral tissue ischemia, erosion, or damage during long-term use. */
        
        subject cuff : InflatableCuff;
        
        require constraint {
            cuff.cuffPressure <= maxSafePressure
        }
        
        attribute maxSafePressure : PressureValue;
    }
    
    requirement def SystemReliabilityRequirement {
        doc /* The artificial urinary sphincter shall operate reliably for a minimum service 
               life of 10 years with at least 4 activation cycles per day, maintaining 
               functional performance throughout the device lifetime. */
        
        attribute minimumLifetimeCycles : Real;
        attribute minimumServiceYears : Real;
    }
    
    requirement sphincterSystemRequirements {
        doc /* The artificial urinary sphincter system shall restore urinary continence in 
               patients with sphincter insufficiency by providing controllable mechanical 
               occlusion of the urethra, enabling both passive continence and voluntary 
               voiding on demand. */
        
        subject artificialUrinarySphincter : ArtificialUrinarySphincter;
        
        require continenceMaintenance : ContinenceMaintenanceRequirement;
        require voidingEnablement : VoidingEnablementRequirement;
        require automaticReclosure : AutomaticReclosureRequirement;
        require safetyPressureLimit : SafetyPressureLimitRequirement;
        require systemReliability : SystemReliabilityRequirement;
    }
}
