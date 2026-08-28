package 'Microneedle Drug Delivery System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import MeasurementReferences::*;
    
    item def DrugFormulation;
    item def ActivationCommand;
    item def DeliveryCompleteSignal;
    item def SkinContactVerified;

    part def Body;
    part def User;

    part def DrugReservoir {
        port drugOutPort { out drugOut : DrugFormulation; }
        attribute capacity : Volume = 10 [mL];
    }

    part def MicroPump {
        port drugInPort { in drugIn : DrugFormulation; }
        port drugOutPort { out drugOut : DrugFormulation; }
        port pumpControlPort { in pumpControl : Pressure; }
        port pressureOutPort { out pressureOut : Pressure; }
        attribute currentPressure : Pressure = 0 [kPa];
    }

    part def MicroneedleArray {
        port drugInPort { in drugIn : DrugFormulation; }
        port drugToSkinPort { out drugToSkin : DrugFormulation; }
        attribute needleCount : Integer = 100;
        attribute maxNeedleLength : Length = 0.8 [mm];
    }

    part def FlowSensor {
        port drugFlowPort { in drugFlow : DrugFormulation; }
        port flowRateOutPort { out flowRateOut : VolumeFlowRate; }
    }

    part def PressureSensor {
        port pumpPressurePort { in pumpPressure : Pressure; }
        port pressureOutPort { out pressureOut : Pressure; }
    }

    part def ControlModule {
        port activationInPort { in activationIn : ActivationCommand; }
        port completeOutPort { out completeOut : DeliveryCompleteSignal; }
        port flowRateInPort { in flowRateIn : VolumeFlowRate; }
        port pressureInPort { in pressureIn : Pressure; }
        port pumpControlOutPort { out pumpControlOut : Pressure; }
        
        attribute targetDose : Volume = 2 [mL];
        attribute deliveredVolume : Volume = 0 [mL];
        attribute desiredFlowRate : VolumeFlowRate = 0.1 [mL/s];

        state def ControlStates;
        state controlStates : ControlStates {
            entry; then idle;
            state idle;
            accept ActivationCommand then preparation;
            state preparation {
                entry action primePump { }
                do action verifyContact { }
            }
            accept SkinContactVerified then delivering;
            state delivering {
                do action monitorAndAdjust { }
                accept VolumeFlowRate if deliveredVolume >= targetDose then complete;
            }
            state complete {
                entry action signalComplete { }
            }
        }
    }

    part def DrugDeliveryPatch {
        port activationPort { in activationIn : ActivationCommand; }
        port completePort { out completeOut : DeliveryCompleteSignal; }
        port toBodyPort { out drugToSkin : DrugFormulation; }

        part reservoir : DrugReservoir;
        part pump : MicroPump;
        part array : MicroneedleArray;
        part flowSensor : FlowSensor;
        part pressureSensor : PressureSensor;
        part controller : ControlModule;

        flow drugFlow1 of DrugFormulation from reservoir.drugOutPort.drugOut to pump.drugInPort.drugIn;
        flow drugFlow2 of DrugFormulation from pump.drugOutPort.drugOut to array.drugInPort.drugIn;
        flow drugFlow3 of DrugFormulation from array.drugToSkinPort.drugToSkin to toBodyPort.drugToSkin;
        
        flow sensedFlow of DrugFormulation from pump.drugOutPort.drugOut to flowSensor.drugFlowPort.drugFlow;
        flow flowRateFeedback of VolumeFlowRate from flowSensor.flowRateOutPort.flowRateOut to controller.flowRateInPort.flowRateIn;
        
        flow sensedPressure of Pressure from pump.pressureOutPort.pressureOut to pressureSensor.pumpPressurePort.pumpPressure;
        flow pressureFeedback of Pressure from pressureSensor.pressureOutPort.pressureOut to controller.pressureInPort.pressureIn;
        
        flow pumpControlFlow of Pressure from controller.pumpControlOutPort.pumpControlOut to pump.pumpControlPort.pumpControl;
        
        bind activationPort = controller.activationInPort;
        bind completePort = controller.completeOutPort;
    }

    requirement def DoseAccuracyRequirement {
        attribute maxError : Volume = 0.05 [mL];
        subject patch : DrugDeliveryPatch;
        objective {
            doc /* The system must deliver the exact prescribed dose within maxError. */
        }
    }

    requirement def NeedleSafetyRequirement {
        attribute maxDepth : Length = 1.0 [mm];
        subject array : MicroneedleArray;
        objective {
            doc /* The needles must not penetrate deeper than maxDepth. */
        }
    }

    part deliverySystem : DrugDeliveryPatch {
        part patient : Body {
            port drugInPort { in drugIn : DrugFormulation; }
        }
        part operator : User {
            port activationOutPort { out activationOut : ActivationCommand; }
            port completeInPort { in completeIn : DeliveryCompleteSignal; }
        }
        
        flow drugToPatient of DrugFormulation from toBodyPort.drugToSkin to patient.drugInPort.drugIn;
        flow activationCmd of ActivationCommand from operator.activationOutPort.activationOut to activationPort.activationIn;
        flow completeSig of DeliveryCompleteSignal from completePort.completeOut to operator.completeInPort.completeIn;
    }
}
