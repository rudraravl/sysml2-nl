package MicroneedleDrugDeliverySystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def Volume :> Real { unit 'mL'; }
    value def FlowRate :> Real { unit 'mL/min'; }
    value def Pressure :> Real { unit 'kPa'; }
    value def Length :> Real { unit 'mm'; }
    value def Dose :> Real { unit 'mg'; }
    value def Concentration :> Real { unit 'mg/mL'; }
    value def ElectricPower :> Real { unit 'mW'; }
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'mA'; }
    value def Temperature :> Real { unit 'degC'; }
    value def TimeDuration :> Real { unit 's'; }

    // ===== Item Types =====
    item def DrugFormulation {
        attribute concentration : Concentration;
        attribute volume : Volume;
        attribute name : String;
    }

    item def DrugFlow {
        attribute flowRate : FlowRate;
        attribute volumeDelivered : Volume;
    }

    item def SkinInterface {
        attribute contactDetected : Boolean;
        attribute skinTemperature : Temperature;
    }

    // ===== Port Definitions =====
    port def DrugFlowPort {
        out item drugFlow : DrugFlow;
    }

    port def DrugFlowInPort {
        in item drugFlow : DrugFlow;
    }

    port def PressureSignalPort {
        out attribute pressure : Pressure;
    }

    port def FlowSignalPort {
        out attribute flowRate : FlowRate;
        out attribute volumeDelivered : Volume;
    }

    port def ControlSignalPort {
        out attribute pumpEnable : Boolean;
        out attribute targetPressure : Pressure;
        out attribute targetFlowRate : FlowRate;
    }

    port def CommandPort {
        in attribute activate : Boolean;
        in attribute targetDose : Dose;
        in attribute deliveryRate : FlowRate;
        out attribute deliveryComplete : Boolean;
        out attribute systemStatus : String;
    }

    port def SkinContactPort {
        out attribute contactDetected : Boolean;
        out attribute skinTemperature : Temperature;
    }

    port def PowerPort {
        in attribute voltage : Voltage;
        in attribute current : Current;
    }

    // ===== Requirements =====
    requirement def DoseAccuracyRequirement {
        doc "The system shall deliver the prescribed dose within ±5% accuracy."
        attribute prescribedDose : Dose;
        attribute deliveredDose : Dose;
        constraint { (deliveredDose >= prescribedDose * 0.95) and (deliveredDose <= prescribedDose * 1.05) }
    }

    requirement def FlowRateStabilityRequirement {
        doc "The system shall maintain the flow rate within ±10% of the target rate during delivery."
        attribute targetRate : FlowRate;
        attribute actualRate : FlowRate;
        constraint { (actualRate >= targetRate * 0.90) and (actualRate <= targetRate * 1.10) }
    }

    requirement def NeedleDepthRequirement {
        doc "Each microneedle shall penetrate no deeper than 0.8 mm into the skin."
        attribute maxPenetrationDepth : Length = 0.8;
        attribute needleLength : Length;
        constraint { needleLength <= maxPenetrationDepth }
    }

    requirement def SafetyStopRequirement {
        doc "The system shall automatically stop delivery if pressure exceeds 50 kPa."
        attribute maxSafePressure : Pressure = 50.0;
        attribute actualPressure : Pressure;
        constraint { actualPressure <= maxSafePressure }
    }

    requirement def DeliveryCompletionRequirement {
        doc "The system shall signal delivery completion within 2 seconds of full dose administration."
        attribute maxSignalDelay : TimeDuration = 2.0;
        attribute actualSignalDelay : TimeDuration;
        constraint { actualSignalDelay <= maxSignalDelay }
    }

    requirement def SkinContactRequirement {
        doc "The system shall verify proper skin contact before initiating drug delivery."
        attribute contactConfirmed : Boolean;
        constraint { contactConfirmed == true }
    }

    // ===== Parts =====

    part def DrugReservoir {
        attribute capacity : Volume = 2.0;
        attribute currentVolume : Volume;
        attribute drugConcentration : Concentration;
        attribute drugName : String;
        port drugOut : DrugFlowPort;
        port powerIn : PowerPort;

        action def FillReservoir {
            in fillVolume : Volume;
            in fillConcentration : Concentration;
            then UpdateVolume;
        }
        action UpdateVolume {
            currentVolume := currentVolume + fillVolume;
            drugConcentration := fillConcentration;
        }
    }

    part def MicroPump {
        attribute maxPressure : Pressure = 50.0;
        attribute nominalFlowRate : FlowRate = 0.05;
        attribute currentPressure : Pressure;
        attribute enabled : Boolean = false;
        port drugIn : DrugFlowInPort;
        port drugOut : DrugFlowPort;
        port controlIn : ControlSignalPort;
        port powerIn : PowerPort;

        action def PumpDrug {
            in targetPressure : Pressure;
            in targetFlowRate : FlowRate;
            then GeneratePressure;
        }
        action GeneratePressure {
            currentPressure := targetPressure;
        }
        action PushDrug {
            drugOut.drugFlow.flowRate := nominalFlowRate;
        }
    }

    part def MicroneedleArray {
        attribute needleCount : Integer = 100;
        attribute needleLength : Length = 0.5;
        attribute needleDiameter : Length = 0.05;
        attribute penetrationDepth : Length;
        port drugIn : DrugFlowInPort;
        port skinContact : SkinContactPort;

        action def PenetrateSkin {
            penetrationDepth := needleLength;
        }
        action def DeliverDrug {
            in drugFlow : DrugFlow;
        }
    }

    part def FlowSensor {
        attribute measuredFlowRate : FlowRate;
        attribute cumulativeVolume : Volume = 0.0;
        attribute samplingInterval : TimeDuration = 0.1;
        port flowSignalOut : FlowSignalPort;
        port drugIn : DrugFlowInPort;
        port powerIn : PowerPort;

        action def MeasureFlow {
            in incomingFlow : DrugFlow;
            then UpdateCumulativeVolume;
        }
        action UpdateCumulativeVolume {
            cumulativeVolume := cumulativeVolume + (measuredFlowRate * samplingInterval / 60.0);
        }
    }

    part def PressureSensor {
        attribute measuredPressure : Pressure;
        attribute samplingInterval : TimeDuration = 0.05;
        attribute maxSafePressure : Pressure = 50.0;
        port pressureSignalOut : PressureSignalPort;
        port powerIn : PowerPort;

        action def MeasurePressure {
            in pumpPressure : Pressure;
            measuredPressure := pumpPressure;
        }
        action def CheckSafety {
            if measuredPressure > maxSafePressure {
                // Trigger safety stop
            }
        }
    }

    part def ControlModule {
        attribute targetDose : Dose;
        attribute targetFlowRate : FlowRate;
        attribute deliveredVolume : Volume = 0.0;
        attribute deliveredDose : Dose = 0.0;
        attribute drugConcentration : Concentration;
        attribute pumpEnabled : Boolean = false;
        attribute targetPressure : Pressure = 20.0;
        attribute systemActive : Boolean = false;
        attribute deliveryComplete : Boolean = false;
        attribute skinContactConfirmed : Boolean = false;
        attribute statusMessage : String = "Idle";

        port commandPort : CommandPort;
        port flowFeedbackIn : FlowSignalPort;
        port pressureFeedbackIn : PressureSignalPort;
        port skinContactIn : SkinContactPort;
        port controlOut : ControlSignalPort;
        port powerIn : PowerPort;

        state def ControlStateMachine {
            entry; then Idle;

            state Idle {
                entry { statusMessage := "Idle"; }
                on commandPort.activate if commandPort.targetDose > 0 {
                    targetDose := commandPort.targetDose;
                    targetFlowRate := commandPort.deliveryRate;
                    systemActive := true;
                } then Preparation;
            }

            state Preparation {
                entry { statusMessage := "Preparation: Checking skin contact"; }
                do CheckSkinContact;
                on skinContactIn.contactDetected if skinContactIn.contactDetected == true {
                    skinContactConfirmed := true;
                    statusMessage := "Skin contact confirmed, priming pump";
                } then Priming;
            }

            action CheckSkinContact {
                // Verify skin contact via sensor input
            }

            state Priming {
                entry { statusMessage := "Priming pump"; }
                do PrimePump;
                then Delivering;
            }

            action PrimePump {
                targetPressure := 10.0;
                pumpEnabled := true;
            }

            state Delivering {
                entry { statusMessage := "Delivering medication"; }
                do MonitorAndAdjust;
                on deliveredDose >= targetDose then Complete;
                on pressureFeedbackIn.pressure > 50.0 then SafetyStop;
            }

            action MonitorAndAdjust {
                // Read flow sensor feedback
                deliveredVolume := flowFeedbackIn.volumeDelivered;
                deliveredDose := deliveredVolume * drugConcentration;
                // Adjust pump pressure based on flow rate deviation
                if flowFeedbackIn.flowRate < targetFlowRate * 0.90 {
                    targetPressure := targetPressure + 1.0;
                } else if flowFeedbackIn.flowRate > targetFlowRate * 1.10 {
                    targetPressure := targetPressure - 1.0;
                }
                // Output control signals
                controlOut.pumpEnable := true;
                controlOut.targetPressure := targetPressure;
                controlOut.targetFlowRate := targetFlowRate;
            }

            state Complete {
                entry {
                    pumpEnabled := false;
                    deliveryComplete := true;
                    statusMessage := "Delivery complete";
                    commandPort.deliveryComplete := true;
                    commandPort.systemStatus := statusMessage;
                }
                then Idle;
            }

            state SafetyStop {
                entry {
                    pumpEnabled := false;
                    statusMessage := "Safety stop: Pressure exceeded safe limit";
                    commandPort.systemStatus := statusMessage;
                }
                then Idle;
            }
        }
    }

    part def PowerSupply {
        attribute outputVoltage : Voltage = 3.7;
        attribute outputCurrent : Current = 500.0;
        attribute capacity_mAh : Real = 300.0;
        port powerOut : PowerPort;
    }

    part def WearablePatchEnclosure {
        attribute material : String = "Medical-grade silicone";
        attribute adhesiveType : String = "Hypoallergenic adhesive";
        attribute dimensions_mm : String = "50x50x5";
    }

    // ===== Top-Level System =====
    part def MicroneedlePatchSystem {
        attribute systemId : String;
        attribute firmwareVersion : String = "1.0.0";

        satisfy DoseAccuracyRequirement;
        satisfy FlowRateStabilityRequirement;
        satisfy NeedleDepthRequirement;
        satisfy SafetyStopRequirement;
        satisfy DeliveryCompletionRequirement;
        satisfy SkinContactRequirement;

        part reservoir : DrugReservoir {
            attribute currentVolume : Volume = 1.0;
            attribute drugConcentration : Concentration = 10.0;
            attribute drugName : String = "Insulin";
        }

        part pump : MicroPump {
            attribute currentPressure : Pressure = 0.0;
        }

        part needleArray : MicroneedleArray {
            attribute needleCount : Integer = 100;
            attribute needleLength : Length = 0.5;
        }

        part flowSensor : FlowSensor {
            attribute measuredFlowRate : FlowRate = 0.0;
        }

        part pressureSensor : PressureSensor {
            attribute measuredPressure : Pressure = 0.0;
        }

        part controller : ControlModule {
            attribute drugConcentration : Concentration = 10.0;
        }

        part powerSupply : PowerSupply;

        part enclosure : WearablePatchEnclosure;

        // ===== Connections =====
        connection reservoir.drugOut to pump.drugIn;
        connection pump.drugOut to flowSensor.drugIn;
        connection flowSensor.drugIn to needleArray.drugIn;
        connection flowSensor.flowSignalOut to controller.flowFeedbackIn;
        connection pressureSensor.pressureSignalOut to controller.pressureFeedbackIn;
        connection needleArray.skinContact to controller.skinContactIn;
        connection controller.controlOut to pump.controlIn;

        connection powerSupply.powerOut to reservoir.powerIn;
        connection powerSupply.powerOut to pump.powerIn;
        connection powerSupply.powerOut to flowSensor.powerIn;
        connection powerSupply.powerOut to pressureSensor.powerIn;
        connection powerSupply.powerOut to controller.powerIn;

        // ===== System-level behavior =====
        action def SystemDeliverySequence {
            first ApplyPatch;
            then IssueActivationCommand;
            then PreparationPhase;
            then DeliveryPhase;
            then CompletionPhase;
        }

        action ApplyPatch {
            // User applies patch to skin
        }

        action IssueActivationCommand {
            controller.commandPort.activate := true;
            controller.commandPort.targetDose := 5.0;
            controller.commandPort.deliveryRate := 0.05;
        }

        action PreparationPhase {
            // Controller verifies skin contact and primes pump
        }

        action DeliveryPhase {
            // Pump activates, controller monitors and adjusts
            // Continues until target dose is reached
        }

        action CompletionPhase {
            // System stops, signals delivery complete
        }
    }

    // ===== Instances =====
    part patientPatch : MicroneedlePatchSystem {
        attribute systemId := "MND-001";
    }
}
