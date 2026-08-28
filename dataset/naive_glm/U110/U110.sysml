package RetinalProsthesisSystem {
    import ScalarValues::*;
    import ISQ::*;

    // Value Types
    value type ElectricCurrentValue :> Real { unit 'mA'; }
    value type MassValue :> Real { unit 'g'; }
    value type PowerValue :> Real { unit 'mW'; }
    value type VoltageValue :> Real { unit 'V'; }
    value type FrequencyValue :> Real { unit 'MHz'; }
    value type DataRateValue :> Real { unit 'Mbps'; }
    value type DurationValue :> Real { unit 'h'; }

    // Item Types
    item def VideoFrame;
    item def StimulationPattern;
    item def ElectricalPulse;
    item def PowerSignal;
    item def DataSignal;

    // Requirements
    requirement def FunctionalVisionRequirement {
        doc /* The system shall restore a degree of functional vision to individuals with retinal degenerative diseases. */
    }

    requirement def RealTimeOperationRequirement {
        doc /* The entire process from capturing an image to stimulating the retina shall happen in real-time. */
    }

    requirement def SafetyRequirement {
        doc /* The system shall prevent tissue damage with strict safety features. */
        attribute maxStimulationCurrent : ElectricCurrentValue = 1.0 [mA];
        attribute maxWearableMass : MassValue = 50.0 [g];
        attribute maxImplantedMass : MassValue = 5.0 [g];
    }

    requirement def BatteryLifeRequirement {
        doc /* The rechargeable battery shall power all external electronics for a full day of use. */
        attribute minDuration : DurationValue = 24.0 [h];
    }

    // Ports
    port def VideoOutPort { out item video : VideoFrame; }
    port def VideoInPort { in item video : VideoFrame; }
    port def PatternOutPort { out item pattern : StimulationPattern; }
    port def PatternInPort { in item pattern : StimulationPattern; }
    port def DataOutPort { out item data : DataSignal; }
    port def DataInPort { in item data : DataSignal; }
    port def PowerOutPort { out item power : PowerSignal; }
    port def PowerInPort { in item power : PowerSignal; }
    port def PulseOutPort { out item pulse : ElectricalPulse; }
    port def PulseInPort { in item pulse : ElectricalPulse; }

    // Parts
    part def RetinalProsthesis {
        satisfy FunctionalVisionRequirement;
        satisfy RealTimeOperationRequirement;
        satisfy SafetyRequirement;

        attribute totalWearableMass : MassValue;
        attribute totalImplantedMass : MassValue;
        
        part externalUnit : ExternalUnit;
        part implantedUnit : ImplantedUnit;

        connection wirelessDataLink connect externalUnit.dataTx to implantedUnit.dataRx;
        connection wirelessPowerLink connect externalUnit.powerTx to implantedUnit.powerRx;

        exhibit state ProsthesisStateMachine {
            state Operational;
            state Standby;
            state Diagnostic;
            
            transition initial to Operational;
            transition Operational to Standby when externalUnit.userInactive;
            transition Standby to Operational when externalUnit.userActive;
            transition Operational to Diagnostic when externalUnit.diagnosticTriggered;
            transition Standby to Diagnostic when externalUnit.diagnosticTriggered;
            transition Diagnostic to Operational when diagnosticComplete;
        }
    }

    part def ExternalUnit {
        attribute mass : MassValue;
        satisfy { constraint { mass <= SafetyRequirement::maxWearableMass; } }

        port dataTx : DataOutPort;
        port powerTx : PowerOutPort;

        part camera : Camera;
        part imageProcessor : ImageProcessingUnit;
        part rfTransmitter : RFTransmitter;
        part inductiveCoil : InductivePowerCoil;
        part battery : RechargeableBattery;

        connection videoFlow connect camera.videoOut to imageProcessor.videoIn;
        connection patternFlow connect imageProcessor.patternOut to rfTransmitter.patternIn;
        connection powerToProcessor connect battery.powerOut to imageProcessor.powerIn;
        connection powerToCamera connect battery.powerOut to camera.powerIn;
        connection powerToRf connect battery.powerOut to rfTransmitter.powerIn;
        connection powerToCoil connect battery.powerOut to inductiveCoil.powerIn;
        connection dataToTx connect rfTransmitter.dataOut to dataTx;
        connection coilPowerToTx connect inductiveCoil.powerOut to powerTx;

        attribute userInactive : Boolean;
        attribute userActive : Boolean;
        attribute diagnosticTriggered : Boolean;
    }

    part def Camera {
        port videoOut : VideoOutPort;
        port powerIn : PowerInPort;
    }

    part def ImageProcessingUnit {
        port videoIn : VideoInPort;
        port patternOut : PatternOutPort;
        port powerIn : PowerInPort;
        
        perform action processVideo {
            in video : VideoFrame;
            out pattern : StimulationPattern;
        }
    }

    part def RFTransmitter {
        port patternIn : PatternInPort;
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;
    }

    part def InductivePowerCoil {
        port powerIn : PowerInPort;
        port powerOut : PowerOutPort;
    }

    part def RechargeableBattery {
        satisfy BatteryLifeRequirement;
        port powerOut : PowerOutPort;
        attribute capacity : PowerValue;
    }

    part def ImplantedUnit {
        attribute mass : MassValue;
        satisfy { constraint { mass <= SafetyRequirement::maxImplantedMass; } }

        port dataRx : DataInPort;
        port powerRx : PowerInPort;

        part rfReceiver : RFReceiver;
        part stimulationController : SignalDecoderStimulationController;
        part electrodeArray : MicroelectrodeArray;

        connection dataToController connect rfReceiver.dataOut to stimulationController.dataIn;
        connection powerToController connect rfReceiver.powerOut to stimulationController.powerIn;
        connection powerToElectrodes connect rfReceiver.powerOut to electrodeArray.powerIn;
        connection pulseDelivery connect stimulationController.pulseOut to electrodeArray.pulseIn;
    }

    part def RFReceiver {
        port dataOut : DataOutPort;
        port powerOut : PowerOutPort;
    }

    part def SignalDecoderStimulationController {
        port dataIn : DataInPort;
        port powerIn : PowerInPort;
        port pulseOut : PulseOutPort;
        
        attribute maxCurrent : ElectricCurrentValue = 1.0 [mA];
        satisfy { constraint { maxCurrent <= SafetyRequirement::maxStimulationCurrent; } }

        perform action generatePulses {
            in pattern : StimulationPattern;
            out pulse : ElectricalPulse;
        }
    }

    part def MicroelectrodeArray {
        attribute electrodeCount : Integer = 60;
        port pulseIn : PulseInPort;
        port powerIn : PowerInPort;
    }
}
