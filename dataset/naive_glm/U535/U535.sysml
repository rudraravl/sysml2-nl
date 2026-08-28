package MatCSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value def Mass :> Real {
        unit kg;
    }
    value def Temperature :> Real {
        unit degC;
    }
    value def Pressure :> Real {
        unit bar;
    }
    value def Duration :> Real {
        unit h;
    }
    value def FlowRate :> Real {
        unit kg/h;
    }
    value def Voltage :> Real {
        unit V;
    }
    value def Power :> Real {
        unit W;
    }

    // ===== Item Types =====
    item def RawMaterial {
        attribute mass : Mass;
    }
    item def ProcessedMaterial {
        attribute mass : Mass;
        attribute qualityGrade : String;
    }
    item def Sample {
        attribute qualityGrade : String;
    }

    // ===== Port Definitions =====
    port def MaterialPort {
        in item : RawMaterial;
        out item : ProcessedMaterial;
    }
    port def SamplePort {
        out item : Sample;
    }
    port def PowerPort {
        in voltage : Voltage;
        in power : Power;
    }
    port def ControlPort {
        in command : String;
        out status : String;
    }

    // ===== Requirements =====
    requirement def ReceptorCapacityRequirement {
        subject receptor : MaterialReceptor;
        requirement receptor.capacity == 500 [kg];
    }
    requirement def ProcessingTemperatureRequirement {
        subject chamber : ProcessingChamber;
        requirement chamber.targetTemperature == 300 [degC];
        requirement chamber.operatingPressure == 1.01325 [bar];
    }
    requirement def DispenserRateRequirement {
        subject dispenser : MaterialDispenser;
        requirement dispenser.dispenseRate == 10 [kg/h];
        requirement dispenser.bufferCapacity == 100 [kg];
    }
    requirement def SafetyShutdownRequirement {
        subject controller : SystemController;
        requirement controller.emergencyShutdown == true implies controller.currentState == "Fault";
    }
    requirement def QualityAssuranceRequirement {
        subject analyzer : QualityAnalyzer;
        requirement analyzer.passed == true implies analyzer.sample.qualityGrade == "A";
    }

    // ===== Component Parts =====
    part def MaterialReceptor {
        attribute capacity : Mass = 500 [kg];
        attribute currentLoad : Mass = 0 [kg];
        port materialOut : MaterialPort;
        port powerIn : PowerPort;
        port controlIn : ControlPort;

        action def ReceiveMaterial {
            in rawMat : RawMaterial;
            out receivedMat : RawMaterial;
        }
        action def FeedMaterial {
            in mat : RawMaterial;
            out fedMat : RawMaterial;
        }
    }

    part def ProcessingChamber {
        attribute targetTemperature : Temperature = 300 [degC];
        attribute operatingPressure : Pressure = 1.01325 [bar];
        attribute treatmentDuration : Duration = 2 [h];
        attribute currentTemperature : Temperature = 20 [degC];
        port materialIn : MaterialPort;
        port materialOut : MaterialPort;
        port powerIn : PowerPort;
        port controlIn : ControlPort;

        action def HeatMaterial {
            in mat : RawMaterial;
            out heatedMat : ProcessedMaterial;
        }
        action def HoldTreatment {
            in mat : ProcessedMaterial;
            out treatedMat : ProcessedMaterial;
        }
    }

    part def QualityAnalyzer {
        attribute passed : Boolean = false;
        attribute qualityThreshold : String = "A";
        port materialIn : MaterialPort;
        port materialOut : MaterialPort;
        port rejectOut : MaterialPort;
        port powerIn : PowerPort;
        port controlIn : ControlPort;

        action def TakeSample {
            in mat : ProcessedMaterial;
            out sample : Sample;
        }
        action def AnalyzeSample {
            in sample : Sample;
            out result : Boolean;
        }
    }

    part def MaterialDispenser {
        attribute dispenseRate : FlowRate = 10 [kg/h];
        attribute bufferCapacity : Mass = 100 [kg];
        attribute currentBuffer : Mass = 0 [kg];
        port materialIn : MaterialPort;
        port materialOut : MaterialPort;
        port powerIn : PowerPort;
        port controlIn : ControlPort;

        action def BufferMaterial {
            in mat : ProcessedMaterial;
            out bufferedMat : ProcessedMaterial;
        }
        action def DispenseMaterial {
            in mat : ProcessedMaterial;
            out dispensedMat : ProcessedMaterial;
        }
    }

    part def SystemController {
        attribute currentState : String = "Offline";
        attribute emergencyShutdown : Boolean = false;
        port operatorInterface : ControlPort;
        port receptorControl : ControlPort;
        port chamberControl : ControlPort;
        port analyzerControl : ControlPort;
        port dispenserControl : ControlPort;
        port powerControl : ControlPort;

        state machine ControllerStates {
            state Offline;
            state Initializing;
            state Ready;
            state Processing;
            state Dispensing;
            state Fault;

            transition from Offline to Initializing when operatorInterface.command == "Initialize";
            transition from Initializing to Ready when receptorControl.status == "Ready" and chamberControl.status == "Ready" and analyzerControl.status == "Ready" and dispenserControl.status == "Ready";
            transition from Ready to Processing when operatorInterface.command == "StartBatch";
            transition from Processing to Dispensing when analyzerControl.status == "Passed";
            transition from Processing to Processing when analyzerControl.status == "Failed";
            transition from Dispensing to Ready when dispenserControl.status == "Complete";
            transition from any to Fault when emergencyShutdown == true;
            transition from Fault to Offline when operatorInterface.command == "Reset";
        }

        action def MonitorComponents {
            in receptorStatus : String;
            in chamberStatus : String;
            in analyzerStatus : String;
            in dispenserStatus : String;
            out systemStatus : String;
        }
        action def ExecuteBatch {
            in command : String;
            out sequence : String;
        }
    }

    part def PowerDistribution {
        attribute inputVoltage : Voltage = 480 [V];
        attribute outputVoltage : Voltage = 240 [V];
        port highVoltageIn : PowerPort;
        port receptorPower : PowerPort;
        port chamberPower : PowerPort;
        port analyzerPower : PowerPort;
        port dispenserPower : PowerPort;
        port controllerPower : PowerPort;
        port controlIn : ControlPort;

        action def DistributePower {
            in inputPower : Power;
            out receptorPwr : Power;
            out chamberPwr : Power;
            out analyzerPwr : Power;
            out dispenserPwr : Power;
            out controllerPwr : Power;
        }
    }

    // ===== System Assembly =====
    part def MatCSystem {
        part receptor : MaterialReceptor {
            satisfy ReceptorCapacityRequirement;
        }
        part chamber : ProcessingChamber {
            satisfy ProcessingTemperatureRequirement;
        }
        part analyzer : QualityAnalyzer {
            satisfy QualityAssuranceRequirement;
        }
        part dispenser : MaterialDispenser {
            satisfy DispenserRateRequirement;
        }
        part controller : SystemController {
            satisfy SafetyShutdownRequirement;
        }
        part powerDist : PowerDistribution;

        // Power connections
        connection powerMain to powerDist.highVoltageIn;
        connection powerDist.receptorPower to receptor.powerIn;
        connection powerDist.chamberPower to chamber.powerIn;
        connection powerDist.analyzerPower to analyzer.powerIn;
        connection powerDist.dispenserPower to dispenser.powerIn;
        connection powerDist.controllerPower to controller.operatorInterface;

        // Control connections
        connection controller.receptorControl to receptor.controlIn;
        connection controller.chamberControl to chamber.controlIn;
        connection controller.analyzerControl to analyzer.controlIn;
        connection controller.dispenserControl to dispenser.controlIn;
        connection controller.powerControl to powerDist.controlIn;

        // Material flow connections
        connection receptor.materialOut to chamber.materialIn;
        connection chamber.materialOut to analyzer.materialIn;
        connection analyzer.materialOut to dispenser.materialIn;
        connection analyzer.rejectOut to receptor.materialOut;

        // System-level state machine
        state machine SystemOperation {
            state Offline;
            state Initializing;
            state Ready;
            state Processing;
            state Dispensing;
            state Fault;

            transition from Offline to Initializing when controller.operatorInterface.command == "Initialize";
            transition from Initializing to Ready when controller.receptorControl.status == "Ready" and controller.chamberControl.status == "Ready" and controller.analyzerControl.status == "Ready" and controller.dispenserControl.status == "Ready";
            transition from Ready to Processing when controller.operatorInterface.command == "StartBatch";
            transition from Processing to Dispensing when controller.analyzerControl.status == "Passed";
            transition from Dispensing to Ready when controller.dispenserControl.status == "Complete";
            transition from any to Fault when controller.emergencyShutdown == true;
            transition from Fault to Offline when controller.operatorInterface.command == "Reset";
        }

        // System-level processing action
        action def ProcessBatch {
            in rawMaterial : RawMaterial;
            out finalProduct : ProcessedMaterial;

            action receive : receptor.ReceiveMaterial {
                in rawMat = rawMaterial;
            }
            action feed : receptor.FeedMaterial {
                in mat = receive.receivedMat;
            }
            action heat : chamber.HeatMaterial {
                in mat = feed.fedMat;
            }
            action hold : chamber.HoldTreatment {
                in mat = heat.heatedMat;
            }
            action sample : analyzer.TakeSample {
                in mat = hold.treatedMat;
            }
            action analyze : analyzer.AnalyzeSample {
                in sample = sample.sample;
            }
            action buffer : dispenser.BufferMaterial {
                in mat = hold.treatedMat;
            }
            action dispense : dispenser.DispenseMaterial {
                in mat = buffer.bufferedMat;
                out dispensedMat = finalProduct;
            }
        }
    }
}
